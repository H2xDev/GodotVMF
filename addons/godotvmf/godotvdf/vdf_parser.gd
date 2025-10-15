@tool
@static_unload
class_name VDFParser extends RefCounted;

# Precompile the regular expressions only once
static var _propRegex := RegEx.create_from_string('^"?(.*?)?"?\\s+"?(.*?)?"?(?:$|(\\s\\[.+\\]))$');
static var _vectorRegex := RegEx.create_from_string('^([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)$');
static var _colorRegex := RegEx.create_from_string('^([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)$');
static var _uvRegex := RegEx.create_from_string('\\[([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)\\]\\s([-\\d\\.e]+)');
static var _planeRegex := RegEx.create_from_string('\\(([\\d\\-\\.e]+\\s[\\d\\-\\.e]+\\s[\\d\\-\\.e]+)\\)\\s?\\(([\\d\\-\\.e]+\\s[\\d\\-\\.e]+\\s[\\d\\-\\.e]+)\\)\\s?\\(([\\d\\-\\.e]+\\s[\\d\\-\\.e]+\\s[\\d\\-\\.e]+)\\)');
static var _commentRegex := RegEx.create_from_string('\\s+?\\/\\/.+');

## Returns Dictionary representation of the Valve Data Format file located at [file_path].
## Returns null and prints an error if the file could not be read or parsed.
static func parse(file_path: String, keys_to_lower := false) -> Variant:
	if not file_path:
		push_error('ValveFormatParser: No file path provided');
		return null;

	if not FileAccess.file_exists(file_path):
		push_error('ValveFormatParser: File does not exist: ' + file_path);
		return null;

	var file := FileAccess.open(file_path, FileAccess.READ);
	var src = file.get_as_text();

	file.close();
	return parse_from_string(src, keys_to_lower);

static func parse_value(line: String) -> Variant:
	var m = _vectorRegex.search(line)
	if m:
		return Vector3(m.get_string(1).to_float(), m.get_string(2).to_float(), m.get_string(3).to_float());
	m = _colorRegex.search(line)
	if m:
		return Color(
			m.get_string(1).to_float() / 255,
			m.get_string(2).to_float() / 255,
			m.get_string(3).to_float() / 255,
			m.get_string(4).to_float() / 255
		);
	m = _uvRegex.search(line)
	if m:
		return {
			"x": m.get_string(1).to_float(),
			"y": m.get_string(2).to_float(),
			"z": m.get_string(3).to_float(),
			"shift": m.get_string(4).to_float(),
			"scale": m.get_string(5).to_float()
		};
	m = _planeRegex.search(line)
	if m:
		var plane := [];
		for i in range(1, 4):
			var values = m.get_string(i).split_floats(' ');
			plane.append(Vector3(values[0], values[1], values[2]));
		
		var v = Plane(plane[0], plane[1], plane[2]);

		if not v:
			push_error('ValveFormatParser: Failed to create plane from: ' + line);
			return null;
		
		return {"value": v, "points": plane, "vecsum": plane[0] + plane[1] + plane[2]};
	if line.is_valid_int():
		return int(line);
	if line.is_valid_float():
		return float(line);
	return line;
static func define_structure(hierarchy: Array, line: String, keys_to_lower = false):
	var _name := line.strip_edges().replace('{', '').replace('"', '');
	if keys_to_lower:
		_name = _name.to_lower();
	var newStruct = {};
	var current = hierarchy[-1];
	# Optimize the property appending logic
	if _name in current:
		if current[_name] is Array:
			current[_name].append(newStruct);
		else:
			current[_name] = [current[_name], newStruct];
	else:
		current[_name] = newStruct;

	hierarchy.append(newStruct);

static func define_property(hierarchy: Array, line: String, keys_to_lower = false):
	var m := _propRegex.search(line);
	var propName := m.get_string(1);
	var propValue := parse_value(m.get_string(2));

	if keys_to_lower:
		propName = propName.to_lower();

	# Optimize the property handling logic
	if propName in hierarchy[-1]:
		if hierarchy[-1][propName] is Array:
			hierarchy[-1][propName].append(propValue);
		else:
			hierarchy[-1][propName] = [hierarchy[-1][propName], propValue];
	else:
		hierarchy[-1][propName] = propValue;

static func finish_structure(hierarchy: Array):
	hierarchy.pop_back();

static func parse_from_string(source: String, keys_to_lower := false):
	var out := {};
	var hierarchy: Array = [out];
	var lines := source.split('\n');
	var line: String = '';
	var previous_line: String = line;

	for l in lines:
		line = _commentRegex.sub(l.strip_edges(), '');
		if line.begins_with('//') or line == '':
			continue;

		if line[0] == '{':
			define_structure(hierarchy, previous_line, keys_to_lower);
		elif line.ends_with('{'):
			define_structure(hierarchy, line, keys_to_lower);
		elif line[0] == '}' or line.ends_with('}'):
			finish_structure(hierarchy);
		elif _propRegex.search(line):
			define_property(hierarchy, line, keys_to_lower);

		previous_line = line;

	return out;

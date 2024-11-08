@tool
@static_unload
class_name VDFParser extends RefCounted;

static var _propRegex := RegEx.create_from_string('^"?(.*?)?"?\\s+"?(.*?)?"?(?:$|(\\s\\[.+\\]))$');
static var _vectorRegex := RegEx.create_from_string('^([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)$');
static var _colorRegex := RegEx.create_from_string('^([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)$');
static var _uvRegex := RegEx.create_from_string('\\[([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)\\]\\s([-\\d\\.e]+)');;
static var _planeRegex := RegEx.create_from_string('\\(([\\d\\-.e]+\\s[\\d\\-.e]+\\s[\\d\\-.e]+)\\)\\s?\\(([\\d\\-.e]+\\s[\\d\\-.e]+\\s[\\d\\-.e]+)\\)\\s?\\(([\\d\\-.e]+\\s[\\d\\-.e]+\\s[\\d\\-.e]+)\\)');
static var _commentRegex := RegEx.create_from_string('\\s+?\\/\\/.+');

static func parse(filePath: String, keysToLower := false):
	var out := {};
	var parseTime := Time.get_ticks_msec();

	if not filePath:
		push_error('ValveFormatParser: No file path provided');
		return null;

	if not FileAccess.file_exists(filePath):
		push_error('ValveFormatParser: File does not exist: ' + filePath);
		return null;

	var file := FileAccess.open(filePath, FileAccess.READ);

	var hierarchy: Array = [out];

	var closeStructure = func():
		hierarchy.pop_back();

	var defineStructure = func(p: String):
		var _name := p.strip_edges().replace('{', '').replace('"', '');

		if keysToLower:
			_name = _name.to_lower();

		var newStruct = {};
		var current = hierarchy[-1];

		if _name in current:
			if current[_name] is Array:
				current[_name].append(newStruct);
			else:
				current[_name] = [current[_name], newStruct];
		else:
			current[_name] = newStruct;

		hierarchy.append(newStruct);

	var parseValue = func(valueString: String):
		if (_vectorRegex.search(valueString)):
			var vector := Vector3(0, 0, 0);
			var values := valueString.split_floats(' ');

			vector.x = values[0];
			vector.y = values[1];
			vector.z = values[2];
			return vector;
		if (_colorRegex.search(valueString)):
			var color = Color(0, 0, 0, 0);
			var m := _colorRegex.search(valueString);

			color.r = m.get_string(1).to_float() / 255;
			color.g = m.get_string(2).to_float() / 255;
			color.b = m.get_string(3).to_float() / 255;
			color.a = m.get_string(4).to_float() / 255;
			return color;
		elif (_uvRegex.search(valueString)):
			var uv = {}
			var m := _uvRegex.search(valueString);

			uv.x = m.get_string(1).to_float();
			uv.y = m.get_string(2).to_float();
			uv.z = m.get_string(3).to_float();
			uv.shift = m.get_string(4).to_float();
			uv.scale = m.get_string(5).to_float();

			return uv;
		elif (_planeRegex.search(valueString)):
			var plane: Array[Vector3] = [];
			var m := _planeRegex.search(valueString);

			for i: int in range(1, 4):
				var vector := Vector3(0, 0, 0);
				var values := m.get_string(i).split_floats(' ');

				vector.x = values[0];
				vector.y = values[1];
				vector.z = values[2];

				plane.append(vector);

			var v = Plane(plane[0], plane[1], plane[2]);

			if not v:
				push_error('ValveFormatParser: Failed to create plane from: ' + valueString);
				return null;

			return {
				"value": v,
				"points": plane,
				"vecsum": plane[0] + plane[1] + plane[2],
			}
		elif valueString.is_valid_int():
			return int(valueString);
		elif valueString.is_valid_float():
			return float(valueString);
		else:
			return valueString;

	var defineProp = func(l: String):
		var m := _propRegex.search(l);

		var propName := m.get_string(1);
		var propValue := parseValue.call(m.get_string(2));

		if keysToLower:
			propName = propName.to_lower();
		
		if propName in hierarchy[-1]:
			if hierarchy[-1][propName] is Array:
				hierarchy[-1][propName].append(propValue);
			else:
				hierarchy[-1][propName] = [hierarchy[-1][propName], propValue];
		else:
			hierarchy[-1][propName] = propValue;
			
	var lines := file.get_as_text().split('\n');
	var line: String = '';
	var previousLine: String = line;

	for l in lines:
		line = _commentRegex.sub(l.strip_edges(), '');

		if line.begins_with('//'):
			line = file.get_line();
			continue;

		if line == '': # Skip empty lines
			line = file.get_line();
		elif line[0] == '{':
			defineStructure.call(previousLine);
		elif line.ends_with('{'):
			defineStructure.call(line);
		elif line[0] == '}' or line.ends_with('}'):
			closeStructure.call();
		elif _propRegex.search(line):
			defineProp.call(line);

		previousLine = line;

	parseTime = Time.get_ticks_msec() - parseTime;

	if parseTime > 1000:
		push_warning('ValveFormatParser: Parsing took ' + str(parseTime) + 'ms');

	return out;

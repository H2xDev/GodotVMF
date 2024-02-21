class_name ValveFormatParser;

static func parse(filePath):
	var out = {};
	var parseTime = Time.get_ticks_msec();

	var propRegex = RegEx.new();
	propRegex.compile('^"?(.*?)?"?\\s+"?(.*?)?"?(?:$|(\\s\\[.+\\]))$');

	var vectorRegex = RegEx.new();
	vectorRegex.compile('^([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)$');

	var colorRegex = RegEx.new();
	colorRegex.compile('^([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)$');

	var uvRegex = RegEx.new();
	uvRegex.compile('\\[([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)\\s([-\\d\\.e]+)\\]\\s([-\\d\\.e]+)');

	var planeRegex = RegEx.new();
	planeRegex.compile('\\(([\\d\\-.e]+\\s[\\d\\-.e]+\\s[\\d\\-.e]+)\\)\\s?\\(([\\d\\-.e]+\\s[\\d\\-.e]+\\s[\\d\\-.e]+)\\)\\s?\\(([\\d\\-.e]+\\s[\\d\\-.e]+\\s[\\d\\-.e]+)\\)')

	if not filePath:
		return null;

	if not FileAccess.file_exists(filePath):
		return null;

	var file = FileAccess.open(filePath, FileAccess.READ);

	var hierarchy = [out];

	var closeStructure = func():
		hierarchy.pop_back();

	var defineStructure = func(p):
		var _name = p.strip_edges().replace('{', '').replace('"', '');
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

	var parseValue = func(valueString):

		if (vectorRegex.search(valueString)):
			var vector = Vector3(0, 0, 0);
			var values = valueString.split(' ');

			vector.x = float(values[0]);
			vector.y = float(values[1]);
			vector.z = float(values[2]);
			return vector;

		if (colorRegex.search(valueString)):
			var color = {};
			var m = colorRegex.search(valueString);

			color.r = float(m.get_string(1)) / 255;
			color.g = float(m.get_string(2)) / 255;
			color.b = float(m.get_string(3)) / 255;
			color.a = float(m.get_string(4)) / 255;
			return color;
		else: if (uvRegex.search(valueString)):
			var uv = {}
			var m = uvRegex.search(valueString);

			uv.x = float(m.get_string(1));
			uv.y = float(m.get_string(2));
			uv.z = float(m.get_string(3));
			uv.shift = float(m.get_string(4));
			uv.scale = float(m.get_string(5));

			return uv;
		else: if (planeRegex.search(valueString)):
			var plane = [];
			var m = planeRegex.search(valueString);

			for i in range(1, 4):
				var vector = Vector3(0, 0, 0);
				var values = m.get_string(i).split(' ');

				vector.x = float(values[0]);
				vector.y = float(values[1]);
				vector.z = float(values[2]);

				plane.append(vector);

			return {
				"value": Plane(plane[0], plane[1], plane[2]),
				"points": plane,
			}
		else: if valueString.is_valid_float():
			return float(valueString);
		else: if valueString.is_valid_int():
			return int(valueString);
		else:
			return valueString;

	var defineProp = func(l):
		var m = propRegex.search(l);

		var propName = m.get_string(1);
		var propValue = parseValue.call(m.get_string(2));
		
		if propName in hierarchy[-1]:
			if hierarchy[-1][propName] is Array:
				hierarchy[-1][propName].append(propValue);
			else:
				hierarchy[-1][propName] = [hierarchy[-1][propName], propValue];
		else:
			hierarchy[-1][propName] = propValue;
	var lines = file.get_as_text().split('\n');
	var line = '';
	var previousLine = line;

	for l in lines:
		line = l.strip_edges();

		if line.begins_with('//'):
			line = file.get_line();
			continue;

		if line == '': # Skip empty lines
			line = file.get_line();
		else: if line[0] == '{':
			defineStructure.call(previousLine);
		else: if line.ends_with('{'):
			defineStructure.call(line);
		else: if line[0] == '}' or line.ends_with('}'):
			closeStructure.call();
		else: if propRegex.search(line):
			defineProp.call(line);

		previousLine = line;

	parseTime = Time.get_ticks_msec() - parseTime;

	if parseTime > 2000:
		VMFLogger.warn('ValveFormatParser: Parsing took ' + str(parseTime) + 'ms');

	return out;

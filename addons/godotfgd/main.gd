@tool
class_name FGDGenerator extends EditorPlugin

var entity_template = "\n".join([
	"@{type} base({base}) {modificators} = {entity_name} : \"{description}\" [",
	"	spawnflags(Flags) = [",
	"{spawnflags}",
	"	]",
	"",
	"{properties}",
	"",
	"{outputs}",
	"",
	"{inputs}",
	"]"
]);

const FLAG_TEMPLATE = "		{flag_index} : \"{flag_name}\" : {value}";
const INPUT_TEMPLATE = "	input {input_name}({input_type}) : \"\"";
const SIGNAL_TEMPLATE = "	output {signal_name}({signal_type}) : \"\"";
const PROPERTY_TEMPLATE = "	{property_name}({property_type}) : \"{property_name_normalized}\" : {property_default} : \"{property_description}\"";
const BOOL_PROPERTY_TEMPLATE = "	{property_name}(choices) : \"{property_name_normalized}\" : {property_default} = [\
		\"0\" : \"No\"\
		\"1\" : \"Yes\"\
	]";

const CHOICES_TEMPLATE = "	{property_name}(choices) : \"{property_name_normalized}\" : {property_default} = [{choices}\
	]";

const QUOTE_WRAPPED = "\"{0}\"";

const TYPE_CHOICES = 1001;
const TYPE_DICTIONARY = {
	TYPE_NIL: "void",
	TYPE_FLOAT: "float",
	TYPE_INT: "integer",
	TYPE_BOOL: "choices",
	TYPE_STRING: "string",
	TYPE_OBJECT: "target_destination",
	TYPE_VECTOR3: "angle",
	TYPE_CHOICES: "choices",
};

var script_hashes = {};

func get_aliases_scripts():
	return VMFConfig.import.entity_aliases.values() \
		.map(func(alias): return load(alias)._bundled.variants[0].resource_path);

func is_entity_scripts_changed():
	var files = DirAccess.get_files_at(VMFConfig.import.entities_folder);
	files.append_array(get_aliases_scripts());

	var is_changed = false;
	for file in files:
		if file.get_extension() != "gd": continue;
		var path = VMFConfig.import.entities_folder + '/' + file if not file.begins_with("res://") else file;
		var hash = FileAccess.get_md5(path);
		var filename = path.get_file().replace(".gd", "");

		if not is_changed:
			is_changed = script_hashes.get(filename, "") != hash;
		script_hashes[filename] = hash;
	
	return is_changed;

func recompose_fgd(resources = null):
	if not is_entity_scripts_changed(): return;

	var files = Array(DirAccess.get_files_at(VMFConfig.import.entities_folder));
	var aliases = get_aliases_scripts().filter(func (file): not files.has(file));
	files.append_array(aliases);

	var scripts: Array = files \
		.filter(func(file): if file.get_extension() == "gd": return true) \
		.map(func(file): 
			var file_path = VMFConfig.import.entities_folder + '/' + file \
				if not file.begins_with("res://") \
				else file;

			return load(file_path);
			) \
		.filter(func(script):
			var decorators = get_prop_decorators(script, script.get_global_name());
			return decorators.has("entity"));

	var file_name = ProjectSettings.get('application/config/name').to_snake_case();
	var fgd_file = FileAccess.open('res://{0}.fgd'.format([file_name]), FileAccess.WRITE);

	for script in scripts:
		fgd_file.store_string(get_entity_description(script) + "\n\n");

	fgd_file.close();
	VMFLogger.log("FGD recomposed");

func _enter_tree():
	get_editor_interface().get_resource_filesystem().sources_changed.connect(recompose_fgd);
	recompose_fgd();

func _exit_tree():
	get_editor_interface().get_resource_filesystem().sources_changed.disconnect(recompose_fgd);

func get_flags(script: Script):
	var index = 0;
	var flags = script.get_script_constant_map() \
		.keys() \
		.filter(func(n: String): return n.begins_with("FLAG_"));

	var base_flags = script.get_base_script().get_script_constant_map().keys() \
		.filter(func(n: String): return n.begins_with("FLAG_"));
	
	flags.append_array(base_flags);

	for flag in flags:
		var value = script[flag];
		var name = flag.replace("FLAG_", "").replace("_", " ").capitalize();
		var type = name.split(" ")[0];

		flags[index] = FLAG_TEMPLATE.format({
			"flag_index": value,
			"flag_name": name,
			"value": 0,
		});

		index += 1;
	
	return "\n".join(flags);

func get_inputs(script: Script):
	var inputs = script.get_script_method_list() \
	.filter(func(method):
		var is_pascal_cased = method.name == method.name.to_pascal_case();
		if is_pascal_cased: return true;

		return get_prop_decorators(script, method.name).has("exposed")
	) \
	.map(func(method):
		var type = method.args[0].name if method.args.size() > 0 else "void";
		if type.begins_with("_"): type = "void";

		var decorators = get_prop_decorators(script, method.name);
		var name = decorators.get("exposed", "");
		name = name if name != "" else method.name;
		name = name.replace("_", " ").capitalize().replace(" ", "");

		return INPUT_TEMPLATE.format({
			"input_name": name,
			"input_type": type,
		}));

	return "\n".join(inputs);

func get_outputs(script: Script):
	var outputs = script.get_script_signal_list().map(func(sig):
		var type = sig.args[0].name if sig.args.size() > 0 else "void";
		if type.begins_with("_"): type = "void";

		return SIGNAL_TEMPLATE.format({
			"signal_name": sig.name,
			"signal_type": type,
		}));
	
	return "\n".join(outputs);

func get_properties(script: Script):
	var properties = script.get_script_property_list() \
	.filter(func(prop): 
		return get_prop_decorators(script, prop.name).has("exposed");
	) \
	.map(func(prop): 
		var default_value = get_prop_default_value(script, prop.name);
		var description = get_prop_description(script, prop.name);
		var template = PROPERTY_TEMPLATE;
		var decorators = get_prop_decorators(script, prop.name);
		var prop_name_normalized = decorators.get("exposed", "");
		prop_name_normalized = prop_name_normalized if prop_name_normalized != "" else prop.name.replace("_", " ").capitalize();

		match prop.type:
			TYPE_BOOL:
				default_value = "1" if default_value == "true" else "0";
				template = BOOL_PROPERTY_TEMPLATE;
			TYPE_VECTOR3:
				var scr = GDScript.new();
				scr.set_source_code("static func eval(): return " + default_value);
				scr.reload();
				default_value = str(scr.eval()).replace("(", "").replace(")", "").replace(",", "");
			TYPE_INT:
				prop.type = TYPE_CHOICES if prop.class_name != "" else prop.type;

		var choices := "";

		if prop.type == TYPE_CHOICES:
			template = CHOICES_TEMPLATE;

			var enum_name = prop.class_name.split(".")[1];
			var values = script[enum_name];

			for choice_name in values.keys():
				var choice_value = values.get(choice_name);

				choices += "\n\t\t" + QUOTE_WRAPPED.format([choice_value]) + " : " + QUOTE_WRAPPED.format([choice_name.capitalize()]);

			var selected_key = default_value.split('.')[1];
			default_value = values.get(selected_key);

		if prop.type != TYPE_INT && prop.type != TYPE_CHOICES && prop.type != TYPE_STRING:
			default_value = QUOTE_WRAPPED.format([default_value]);

		var type_to_output = decorators.get("type", TYPE_DICTIONARY[prop.type] if prop.type in TYPE_DICTIONARY else "void");

		return template.format({
			"property_name": prop.name,
			"property_name_normalized": prop_name_normalized,
			"property_type": type_to_output,
			"property_default": default_value,
			"property_description": description,
			"choices": choices,
		}));

	properties.append(BOOL_PROPERTY_TEMPLATE.format({
		"property_name": "StartDisabled",
		"property_name_normalized": "Start Disabled",
		"property_type": "choices",
		"property_default": "0",
		"property_description": "If enabled, entity will be disabled on spawn",
	}));

	return "\n".join(properties);

func get_entity_description(script: Script):
	var class_decorator = get_prop_decorators(script, script.get_global_name());

	return entity_template.format({
		entity_name 	= script.get_global_name(),
		spawnflags 		= get_flags(script),
		inputs 			= get_inputs(script),
		outputs 		= get_outputs(script),
		properties 		= get_properties(script),
		type 			= class_decorator.entity,
		base 			= class_decorator.get("base", "Targetname, Origin"),
		description 	= get_prop_description(script, script.get_global_name()),
		modificators 	= class_decorator.get("appearance", ""),
	}).replace("\r\r", "\n");

func get_property_line_index(script: Script, property_name: String):
	if not is_instance_valid(script): return -1;

	var source = script.source_code.split("\n");
	var line_index = 0;

	for line in source:
		var property_pattern = "var " + property_name;
		var is_property = line.begins_with(property_pattern) or (line.contains(property_pattern) and line.contains("@export"));
		var is_method = line.begins_with("func " + property_name);
		var is_class = line.begins_with("class_name " + property_name);

		if not is_property and not is_method and not is_class:
			line_index += 1;
			continue;

		return line_index;

	return -1;

func get_prop_default_value(script: Script, property_name: String):
	if not is_instance_valid(script): return "";

	var source = script.source_code.split("\n");
	var line_index = get_property_line_index(script, property_name);
	if line_index == -1: return get_prop_default_value(script.get_base_script(), property_name);

	var line = source[line_index];
	line = line.replace("\n", "").replace(";", "").replace("\r", "");

	var value = line.split("=")[1] if line.contains("=") else "";
	value = value.trim_prefix(" ").trim_suffix(" ").replace(":", "");

	return value;

func get_prop_decorators(script: Script, property_name: String):
	if not is_instance_valid(script): return {};

	var description = get_prop_description(script, property_name, false);
	var decorators = {};

	var lines = description.split("\n");
	for line in lines:
		line = line.trim_prefix(" ").trim_suffix(" ");
		if not line.begins_with("@"): continue;

		var name = line.split(" ")[0].trim_prefix("@");
		var value = line.split("@" + name)[1].trim_prefix(" ").trim_suffix(" ");

		if name in decorators:
			decorators[name] += "\n" + value;
		else:
			decorators[name] = value;

	return decorators;

func get_prop_description(script: Script, property_name: String, no_decorators = true):
	if not is_instance_valid(script): return "";

	var source = script.source_code.replace("\r\n", "\n").split("\n");

	var description = "";
	var line_index = get_property_line_index(script, property_name);

	if line_index == -1:
		return get_prop_description(script.get_base_script(), property_name, no_decorators);

	line_index -= 1;
	var comment_line = source[line_index];

	while comment_line.begins_with("##"):
		comment_line = comment_line.trim_prefix("##").trim_prefix(" ").trim_suffix(" ").replace("\n", "").replace("\r", "");

		if no_decorators and comment_line.begins_with("@"):
			line_index -= 1;
			comment_line = source[line_index];
			continue;

		description = comment_line + "\n" + description;
		line_index -= 1;
		comment_line = source[line_index];

	return description.trim_suffix("\n");

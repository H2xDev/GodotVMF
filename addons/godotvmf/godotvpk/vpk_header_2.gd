class_name VPKHeaderV2 extends VPKHeader

static func _schema(): return {
	"signature": VMFStruct.Type.UINT_32,
	"version": VMFStruct.Type.UINT_32,
	"tree_size": VMFStruct.Type.UINT_32,
	"file_data_section_size": VMFStruct.Type.UINT_32,
	"archive_md5_section_size": VMFStruct.Type.UINT_32,
	"other_md5_section_size": VMFStruct.Type.UINT_32,
	"signature_section_size": VMFStruct.Type.UINT_32,
}

var file_data_section_size: int;
var archive_md5_section_size: int;
var other_md5_section_size: int;
var signature_section_size: int;

func _to_string() -> String:
	return "VPKHeaderV2(signature=0x%X, version=%d, tree_size=%d, file_data_section_size=%d, archive_md5_section_size=%d, other_md5_section_size=%d, signature_section_size=%d)" % [signature, version, tree_size, file_data_section_size, archive_md5_section_size, other_md5_section_size, signature_section_size];

class_name VPKDirectoryEntry extends RefCounted

static func _schema(): return {
	"crc32": VMFStruct.Type.UINT_32,
	"preload_bytes": VMFStruct.Type.UINT_16,
	"archive_index": VMFStruct.Type.UINT_16,
	"offset": VMFStruct.Type.UINT_32,
	"length": VMFStruct.Type.UINT_32,
	"terminator": VMFStruct.Type.UINT_16,
}

var crc32: int;
var preload_bytes: int;
var archive_index: int;
var offset: int;
var length: int;
var terminator: int;

func _to_string() -> String:
	return "VPKDirectoryEntry(crc32=0x%X, preload_bytes=%d, archive_index=%d, entry_offset=%d, entry_length=%d, terminator=0x%X)" % [crc32, preload_bytes, archive_index, offset, length, terminator];

func as_dict() -> Dictionary:
	return {
		"crc32": crc32,
		"preload_bytes": preload_bytes,
		"archive_index": archive_index,
		"offset": offset,
		"length": length,
		"terminator": terminator,
	}

class_name VPKHeader extends RefCounted

const CORRECT_SIGNATURE: int = 0x55AA1234;

static func _schema(): return {
	"signature": VMFStruct.Type.UINT_32,
	"version": VMFStruct.Type.UINT_32,
	"tree_size": VMFStruct.Type.UINT_32,
}

var signature: int;
var version: int;
var tree_size: int;

var is_valid: bool:
	get: return signature == CORRECT_SIGNATURE;

func _to_string() -> String:
	# Signature should be provided in hex format
	return "VPKHeader(signature=0x%X, version=%d, tree_size=%d)" % [signature, version, tree_size];

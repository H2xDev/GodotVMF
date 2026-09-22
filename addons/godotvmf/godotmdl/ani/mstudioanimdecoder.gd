class_name MStudioAnimDecoder extends RefCounted

static func decode_float16(val: int) -> float:
	var sign: int = (val >> 15) & 1
	var exp: int = (val >> 10) & 0x1F
	var mant: int = val & 0x3FF
	
	if exp == 0:
		if mant == 0:
			return 0.0 if sign == 0 else -0.0
		else:
			return (1.0 if sign == 0 else -1.0) * pow(2.0, -14.0) * (float(mant) / 1024.0)
	elif exp == 31:
		if mant == 0:
			return INF if sign == 0 else -INF
		else:
			return NAN
	else:
		return (1.0 if sign == 0 else -1.0) * pow(2.0, exp - 15.0) * (1.0 + float(mant) / 1024.0)

static func read_vector48(file: FileAccess) -> Vector3:
	return Vector3(
		decode_float16(file.get_16()),
		decode_float16(file.get_16()),
		decode_float16(file.get_16())
	)

static func read_quaternion48(file: FileAccess) -> Quaternion:
	var x_val = file.get_16()
	var y_val = file.get_16()
	var z_wneg = file.get_16()
	
	var x = (float(x_val) - 32768.0) / 32768.0
	var y = (float(y_val) - 32768.0) / 32768.0
	var z = (float(z_wneg & 0x7FFF) - 16384.0) / 16384.0
	var wneg = (z_wneg >> 15) & 1
	
	var w_sq = 1.0 - x*x - y*y - z*z
	var w = sqrt(max(0.0, w_sq))
	if wneg:
		w = -w
		
	return Quaternion(x, y, z, w)

static func read_quaternion64(file: FileAccess) -> Quaternion:
	var v1 = file.get_32()
	var v2 = file.get_32()
	
	var x_val = v1 & 0x1FFFFF
	var y_val = (v1 >> 21) | ((v2 & 0x3FF) << 11)
	var z_val = (v2 >> 10) & 0x1FFFFF
	var wneg = (v2 >> 31) & 1
	
	var x = (float(x_val) - 1048576.0) / 1048576.5
	var y = (float(y_val) - 1048576.0) / 1048576.5
	var z = (float(z_val) - 1048576.0) / 1048576.5
	
	var w_sq = 1.0 - x*x - y*y - z*z
	var w = sqrt(max(0.0, w_sq))
	if wneg:
		w = -w
		
	return Quaternion(x, y, z, w)

## Converts Source Engine RadianEuler (angles.x=pitch, angles.y=yaw, angles.z=roll)
## to a Quaternion using the same formula as Source SDK's AngleQuaternion(RadianEuler).
static func angle_quaternion(angles: Vector3) -> Quaternion:
	var sy = sin(angles.z * 0.5)
	var cy = cos(angles.z * 0.5)
	var sp = sin(angles.x * 0.5)
	var cp = cos(angles.x * 0.5)
	var sr = sin(angles.y * 0.5)
	var cr = cos(angles.y * 0.5)
	return Quaternion(
		sr*cp*cy - cr*sp*sy,
		cr*sp*cy + sr*cp*sy,
		cr*cp*sy - sr*sp*cy,
		cr*cp*cy + sr*sp*sy
	)

static func decode_anim_values(file: FileAccess, start_address: int, num_frames: int) -> Array[int]:
	var values: Array[int] = []
	if start_address == 0:
		return values
		
	file.seek(start_address)
	var k = 0
	while k < num_frames:
		var valid = file.get_8()
		var total = file.get_8()
		if total == 0:
			break
			
		var valid_values = []
		for j in range(valid):
			valid_values.append(ByteReader.read_signed_short(file))
			
		for j in range(total):
			if j < valid:
				values.append(valid_values[j])
			else:
				if valid_values.size() > 0:
					values.append(valid_values[-1])
				else:
					values.append(0)
		k += total
	return values

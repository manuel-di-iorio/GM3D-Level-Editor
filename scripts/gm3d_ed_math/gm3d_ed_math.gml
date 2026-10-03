// Computes forward vector from yaw and pitch.
function __gm3d_ed_cam_forward(_yaw, _pitch) {
	var _y = degtorad(_yaw);
	var _p = degtorad(_pitch);
	var _cp = cos(_p);
	return new GM3D_Vec3(sin(_y) * _cp, sin(_p), -cos(_y) * _cp);
}

// Computes cube face corner indices for axis.
function __gm3d_ed_cube_face_idx(_a, _s) {
	var _b = (_a + 1) mod 3;
	var _c = (_a + 2) mod 3;
	var _sg = [
		[-1, -1],
		[1, -1],
		[1, 1],
		[-1, 1],
	];
	var _out = [];
	for (var _k = 0; _k < 4; _k++) {
		var _sv = [0, 0, 0];
		_sv[_a] = _s;
		_sv[_b] = _sg[_k][0];
		_sv[_c] = _sg[_k][1];
		array_push(_out, (_sv[0] > 0 ? 1 : 0) + (_sv[1] > 0 ? 2 : 0) + (_sv[2] > 0 ? 4 : 0));
	}
	return _out;
}

// Interpolates between two quaternions spherically.
function __gm3d_ed_quat_slerp(_a, _b, _t) {
	var _dot = _a[0] * _b[0] + _a[1] * _b[1] + _a[2] * _b[2] + _a[3] * _b[3];
	var _b0 = _b[0];
	var _b1 = _b[1];
	var _b2 = _b[2];
	var _b3 = _b[3];
	if (_dot < 0) {
		_dot = -_dot;
		_b0 = -_b0;
		_b1 = -_b1;
		_b2 = -_b2;
		_b3 = -_b3;
	}
	var _s0 = 1 - _t;
	var _s1 = _t;
	if (_dot < 0.9995) {
		var _th = arccos(clamp(_dot, -1, 1));
		var _s = sin(_th);
		_s0 = sin((1 - _t) * _th) / _s;
		_s1 = sin(_t * _th) / _s;
	}
	var _q = new GM3D_Quaternion();
	_q.x = _a[0] * _s0 + _b0 * _s1;
	_q.y = _a[1] * _s0 + _b1 * _s1;
	_q.z = _a[2] * _s0 + _b2 * _s1;
	_q.w = _a[3] * _s0 + _b3 * _s1;
	return _q.normalizeSafe(0.000001);
}

// Creates quaternion from four-element array.
function __gm3d_ed_quat_from_array(_a) {
	var _q = new GM3D_Quaternion();
	_q.x = _a[0];
	_q.y = _a[1];
	_q.z = _a[2];
	_q.w = _a[3];
	return _q;
}

// Computes squared distance point to segment.
function __gm3d_ed_point_seg_dist2(_px, _py, _ax, _ay, _bx, _by) {
	var _dx = _bx - _ax;
	var _dy = _by - _ay;
	var _l2 = _dx * _dx + _dy * _dy;
	var _t = 0.0;
	if (_l2 > 0.000001) {
		_t = ((_px - _ax) * _dx + (_py - _ay) * _dy) / _l2;
		_t = clamp(_t, 0.0, 1.0);
	}
	var _cx = _ax + _dx * _t;
	var _cy = _ay + _dy * _t;
	var _qx = _px - _cx;
	var _qy = _py - _cy;
	return _qx * _qx + _qy * _qy;
}

// Finds closest squared distance to polyline.
function __gm3d_ed_point_polyline_dist2(_px, _py, _pts) {
	var _n = array_length(_pts);
	if (_n < 2) {
		return 1000000000;
	}
	var _best = 1000000000;
	for (var i = 0; i < _n - 1; ++i) {
		var _a = _pts[i];
		var _b = _pts[i + 1];
		var _d = __gm3d_ed_point_seg_dist2(_px, _py, _a[0], _a[1], _b[0], _b[1]);
		if (_d < _best) {
			_best = _d;
		}
	}
	return _best;
}

// Converts quaternion to three basis vectors.
function __gm3d_ed_quat_basis(_q) {
	var _x = _q.x;
	var _y = _q.y;
	var _z = _q.z;
	var _w = _q.w;
	var _xx = _x * _x;
	var _yy = _y * _y;
	var _zz = _z * _z;
	var _xy = _x * _y;
	var _xz = _x * _z;
	var _yz = _y * _z;
	var _wx = _w * _x;
	var _wy = _w * _y;
	var _wz = _w * _z;
	return [
		new GM3D_Vec3(1 - 2 * (_yy + _zz), 2 * (_xy + _wz), 2 * (_xz - _wy)),
		new GM3D_Vec3(2 * (_xy - _wz), 1 - 2 * (_xx + _zz), 2 * (_yz + _wx)),
		new GM3D_Vec3(2 * (_xz + _wy), 2 * (_yz - _wx), 1 - 2 * (_xx + _yy)),
	];
}

// Interpolates vectors at near clip plane.
function __gm3d_ed_clip_lerp(_a, _b, _eps) {
	var _t = (_a.w - _eps) / (_a.w - _b.w);
	return new GM3D_Vec4(_a.x + (_b.x - _a.x) * _t, _a.y + (_b.y - _a.y) * _t, _a.z + (_b.z - _a.z) * _t, _eps);
}

// Tests if point lies inside triangle.
function __gm3d_ed_tri_hit(_px, _py, _ax, _ay, _bx, _by, _cx, _cy) {
	var _d1 = (_px - _bx) * (_ay - _by) - (_ax - _bx) * (_py - _by);
	var _d2 = (_px - _cx) * (_by - _cy) - (_bx - _cx) * (_py - _cy);
	var _d3 = (_px - _ax) * (_cy - _ay) - (_cx - _ax) * (_py - _ay);
	var _neg = _d1 < 0 || _d2 < 0 || _d3 < 0;
	var _pos = _d1 > 0 || _d2 > 0 || _d3 > 0;
	return !(_neg && _pos);
}

// Snaps value to nearest step increment.
function __gm3d_ed_snap(_v, _step) {
	if (_step <= 0) {
		return _v;
	}
	return round(_v / _step) * _step;
}

// Returns effective move snap step (grid cell when linked).
function __gm3d_ed_snap_step(_ed) {
	if (variable_struct_exists(_ed, "snap_to_grid") && _ed.snap_to_grid == true && variable_struct_exists(_ed, "grid_step") && is_real(_ed.grid_step)) {
		return clamp(_ed.grid_step, 0.1, 8);
	}
	if (variable_struct_exists(_ed, "snap_pos") && is_real(_ed.snap_pos)) {
		return max(0.01, _ed.snap_pos);
	}
	return 0.5;
}

// Converts quaternion to Euler angles.
function __gm3d_ed_quat_to_euler(_q) {
	var _qx = _q.x;
	var _qy = _q.y;
	var _qz = _q.z;
	var _qw = _q.w;
	var _bad = false;
	_bad = is_nan(_qx) || is_nan(_qy) || is_nan(_qz) || is_nan(_qw);
	if (_bad) {
		return [0, 0, 0];
	}
	var _l = sqrt(_qx * _qx + _qy * _qy + _qz * _qz + _qw * _qw);
	if (_l > 0.000001) {
		_qx /= _l;
		_qy /= _l;
		_qz /= _l;
		_qw /= _l;
	}
	var _ex = arctan2(2 * (_qw * _qx + _qy * _qz), 1 - 2 * (_qx * _qx + _qy * _qy));
	var _ey = arcsin(clamp(2 * (_qw * _qy - _qz * _qx), -1, 1));
	var _ez = arctan2(2 * (_qw * _qz + _qx * _qy), 1 - 2 * (_qy * _qy + _qz * _qz));
	return [_ex, _ey, _ez];
}

// Converts Euler angles to quaternion.
function __gm3d_ed_euler_to_quat(_ex, _ey, _ez) {
	var _c1 = cos(_ex * 0.5);
	var _c2 = cos(_ey * 0.5);
	var _c3 = cos(_ez * 0.5);
	var _s1 = sin(_ex * 0.5);
	var _s2 = sin(_ey * 0.5);
	var _s3 = sin(_ez * 0.5);
	var _q = new GM3D_Quaternion();
	_q.x = _s1 * _c2 * _c3 - _c1 * _s2 * _s3;
	_q.y = _c1 * _s2 * _c3 + _s1 * _c2 * _s3;
	_q.z = _c1 * _c2 * _s3 - _s1 * _s2 * _c3;
	_q.w = _c1 * _c2 * _c3 + _s1 * _s2 * _s3;
	return _q.normalizeSafe(0.000001);
}

// Sorts array of structs by field.
function __gm3d_ed_sort_by_field(_arr, _field, _asc) {
	for (var _a = 1; _a < array_length(_arr); _a++) {
		var _it = _arr[_a];
		var _b = _a - 1;
		if (_asc) {
			while (_b >= 0 && _arr[_b][$ _field] > _it[$ _field]) {
				_arr[_b + 1] = _arr[_b];
				_b--;
			}
		} else {
			while (_b >= 0 && _arr[_b][$ _field] < _it[$ _field]) {
				_arr[_b + 1] = _arr[_b];
				_b--;
			}
		}
		_arr[_b + 1] = _it;
	}
	return _arr;
}

/// @module gm3d_ed_camera
/// Camera fly, orbit, home, animation and view forward.

/// Returns the camera forward in world space from its quaternion.
function __gm3d_ed_view_forward(_ed) {
	var _q = _ed.rt.cam.getLocalRotation();
	var _x = _q.x;
	var _y = _q.y;
	var _z = _q.z;
	var _w = _q.w;
	var _f = new GM3D_Vec3(2.0 * (_x * _z + _w * _y), 2.0 * (_y * _z - _w * _x), 1.0 - 2.0 * (_x * _x + _y * _y));
	_f.normalizeSafe(0.000001);
	return _f;
}

/// Stores the boot camera pose as Home.
function __gm3d_ed_cam_remember(_ed) {
	_ed.cam_home = undefined;
	if (_ed == undefined || _ed.rt == undefined || _ed.rt.cam == undefined) {
		return;
	}
	var _p = _ed.rt.cam.getLocalPosition();
	var _q = _ed.rt.cam.getLocalRotation();
	_ed.cam_home = { pos: [_p.x, _p.y, _p.z], rot: [_q.x, _q.y, _q.z, _q.w] };
}

/// Restores the boot camera pose.
function __gm3d_ed_cam_home(_ed) {
	if (_ed == undefined || _ed.cam_home == undefined || _ed.rt == undefined || _ed.rt.cam == undefined) {
		return;
	}
	var _h = _ed.cam_home;
	_ed.rt.cam.setLocalPosition(new GM3D_Vec3(_h.pos[0], _h.pos[1], _h.pos[2]));
	var _q = new GM3D_Quaternion();
	_q.x = _h.rot[0];
	_q.y = _h.rot[1];
	_q.z = _h.rot[2];
	_q.w = _h.rot[3];
	_ed.rt.cam.setLocalRotation(_q);
}

/// Applies orbit deltas to the camera node.
/// @param {Real} _ddx/_ddy mouse deltas in pixels
/// @return {Array} [yaw, pitch] in degrees
function __gm3d_ed_orbit_apply(_ed, _ddx, _ddy) {
	var _node = _ed.rt.cam;
	var _vf = __gm3d_ed_view_forward(_ed);
	var _yaw = radtodeg(arctan2(_vf.x, -_vf.z)) + _ddx * 0.18;
	var _pitch = clamp(radtodeg(arcsin(clamp(_vf.y, -1.0, 1.0))) + _ddy * 0.18, -85.0, 85.0);
	var _f = __gm3d_ed_cam_forward(_yaw, _pitch);
	var _upv = GM3D_Vec3.up();
	if (abs(_f.x * _upv.x + _f.y * _upv.y + _f.z * _upv.z) >= 0.999) {
		_upv = GM3D_Vec3.forward();
	}
	_node.setLocalRotation(GM3D_Quaternion.fromLookRotation(_f, _upv).normalizeSafe(0.000001));
	return [_yaw, _pitch];
}

/// Flies, pans, orbits and dollies the camera node.
/// @param {Real} _dt seconds since last frame
/// @param {Bool} _allowKeys/_allowZoom input gates
function __gm3d_ed_cam_fly(_ed, _vp, _dt, _allowKeys, _allowZoom) {
	var _node = _ed.rt.cam;
	if (_node == undefined) {
		return;
	}
	var _vf = __gm3d_ed_view_forward(_ed);
	var _yaw = radtodeg(arctan2(_vf.x, -_vf.z));
	var _pitch = radtodeg(arcsin(clamp(_vf.y, -1.0, 1.0)));
	var _orbit = _allowKeys && mouse_check_button(mb_right);
	var _pan = _allowKeys && mouse_check_button(mb_middle);
	if (_orbit) {
		var _yp = __gm3d_ed_orbit_apply(_ed, window_mouse_get_delta_x(), window_mouse_get_delta_y());
		_yaw = _yp[0];
		_pitch = _yp[1];
	}

	var _boost = keyboard_check(vk_shift) ? 3.0 : 1.0;
	var _step = _dt * 4.0 * _boost;
	var _move = _allowKeys && !keyboard_check(vk_control);
	var _fw = _move ? keyboard_check(ord("W")) - keyboard_check(ord("S")) : 0.0;
	var _rt = _move ? keyboard_check(ord("D")) - keyboard_check(ord("A")) : 0.0;
	var _up = _move ? keyboard_check(ord("E")) - keyboard_check(ord("Q")) : 0.0;
	var _wheel = 0;
	if (_allowZoom) {
		if (mouse_wheel_up()) {
			_wheel = -1;
		} else if (mouse_wheel_down()) {
			_wheel = 1;
		}
	}
	if (!_orbit && !_pan && _fw == 0 && _rt == 0 && _up == 0 && _wheel == 0) {
		return;
	}
	_ed.cam_anim = undefined;

	var _f = __gm3d_ed_cam_forward(_yaw, _pitch);
	var _pfx = _f.x;
	var _pfz = _f.z;
	var _pl = sqrt(_pfx * _pfx + _pfz * _pfz);
	if (_pl <= 0.000001) {
		_pfx = 1.0;
		_pfz = 0.0;
	} else {
		_pfx /= _pl;
		_pfz /= _pl;
	}
	var _prx = -_pfz;
	var _prz = _pfx;

	var _pp = _node.getLocalPosition();
	var _nx = _pp.x - (_pfx * _fw + _prx * _rt) * _step;
	var _nz = _pp.z - (_pfz * _fw + _prz * _rt) * _step;
	var _ny = _pp.y + _up * _step;
	var _zl = 1.2 * _boost;
	_nx += _f.x * _wheel * _zl;
	_ny += _f.y * _wheel * _zl;
	_nz += _f.z * _wheel * _zl;
	if (_pan) {
		var _qb = __gm3d_ed_quat_basis(_node.getLocalRotation());
		var _rx = _qb[0];
		var _ux = _qb[1];
		var _tx2 = _pp.x - _f.x * 10;
		var _ty2 = _pp.y - _f.y * 10;
		var _tz2 = _pp.z - _f.z * 10;
		if (array_length(_ed.sel) > 0) {
			var _pv2 = __gm3d_ed_gizmo_pivot(_ed.sel);
			_tx2 = _pv2.x;
			_ty2 = _pv2.y;
			_tz2 = _pv2.z;
		}
		var _ddx = _tx2 - _pp.x;
		var _ddy = _ty2 - _pp.y;
		var _ddz = _tz2 - _pp.z;
		var _dlen = sqrt(_ddx * _ddx + _ddy * _ddy + _ddz * _ddz);
		if (_dlen > 0.001) {
			var _k2 = (2 * _dlen * tan(_vp.fovY * 0.5)) / max(_vp.winH, 1);
			var _mdx = window_mouse_get_delta_x();
			var _mdy = window_mouse_get_delta_y();
			_nx += (-_rx.x * _mdx + _ux.x * _mdy) * _k2;
			_ny += (-_rx.y * _mdx + _ux.y * _mdy) * _k2;
			_nz += (-_rx.z * _mdx + _ux.z * _mdy) * _k2;
		}
	}
	_node.setLocalPosition(new GM3D_Vec3(_nx, _ny, _nz));
	// World up only; pitch clamp keeps inputs non-parallel.
	var _upv = GM3D_Vec3.up();
	_node.setLocalRotation(GM3D_Quaternion.fromLookRotation(_f, _upv).normalizeSafe(0.000001));
}

/// Snaps the camera to face a cube normal, keeping distance.
/// @param {Any} _n face normal as world unit vector
function __gm3d_ed_viewcube_snap(_ed, _n) {
	if (_ed == undefined || _ed.rt == undefined || _ed.rt.cam == undefined) {
		return;
	}
	var _f0 = __gm3d_ed_view_forward(_ed);
	var _up = GM3D_Vec3.up();
	var _nn = new GM3D_Vec3(_n.x, _n.y, _n.z);
	var _tilted = false;
	if (abs(_n.x * _up.x + _n.y * _up.y + _n.z * _up.z) >= 0.99) {
		var _hx = _f0.x;
		var _hz = _f0.z;
		var _hl = sqrt(_hx * _hx + _hz * _hz);
		if (_hl > 0.001) {
			_nn = new GM3D_Vec3(_n.x + (_hx / _hl) * 0.035, _n.y, _n.z + (_hz / _hl) * 0.035);
			_nn.normalizeSafe(0.000001);
			_tilted = true;
		}
	}
	var _node = _ed.rt.cam;
	var _cq = _node.getLocalRotation();
	var _tq = _cq;
	if (_tilted || abs(_n.x * _up.x + _n.y * _up.y + _n.z * _up.z) < 0.99) {
		_tq = GM3D_Quaternion.fromLookRotation(_nn, _up).normalizeSafe(0.000001);
	}
	var _pp = _node.getLocalPosition();
	var _ax = _pp.x;
	var _ay = _pp.y;
	var _az = _pp.z;
	if (array_length(_ed.sel) > 0) {
		var _pv = __gm3d_ed_gizmo_pivot(_ed.sel);
		_ax = _pv.x;
		_ay = _pv.y;
		_az = _pv.z;
	} else {
		_ax = _pp.x - _f0.x * 10;
		_ay = _pp.y - _f0.y * 10;
		_az = _pp.z - _f0.z * 10;
	}
	var _dx = _pp.x - _ax;
	var _dy = _pp.y - _ay;
	var _dz = _pp.z - _az;
	var _dl = sqrt(_dx * _dx + _dy * _dy + _dz * _dz);
	if (_dl < 0.001) {
		return;
	}
	_ed.cam_anim = {
		t: 0,
		dur: 0.4,
		q0: [_cq.x, _cq.y, _cq.z, _cq.w],
		q1: [_tq.x, _tq.y, _tq.z, _tq.w],
		p0: [_pp.x, _pp.y, _pp.z],
		p1: [_ax + _nn.x * _dl, _ay + _nn.y * _dl, _az + _nn.z * _dl],
	};
}

/// Advances the smooth camera rotation and glide.
function __gm3d_ed_cam_anim_step(_ed, _dt) {
	var _an = _ed.cam_anim;
	if (_an == undefined) {
		return;
	}
	_an.t += _dt / max(_an.dur, 0.01);
	if (_an.t >= 1) {
		_ed.rt.cam.setLocalPosition(new GM3D_Vec3(_an.p1[0], _an.p1[1], _an.p1[2]));
		_ed.rt.cam.setLocalRotation(__gm3d_ed_quat_slerp(_an.q0, _an.q1, 1));
		_ed.cam_anim = undefined;
		return;
	}
	var _e = _an.t * _an.t * (3 - 2 * _an.t);
	_ed.rt.cam.setLocalPosition(
		new GM3D_Vec3(
			_an.p0[0] + (_an.p1[0] - _an.p0[0]) * _e,
			_an.p0[1] + (_an.p1[1] - _an.p0[1]) * _e,
			_an.p0[2] + (_an.p1[2] - _an.p0[2]) * _e,
		),
	);
	_ed.rt.cam.setLocalRotation(__gm3d_ed_quat_slerp(_an.q0, _an.q1, _e));
}

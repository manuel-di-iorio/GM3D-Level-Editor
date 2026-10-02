// Computes normalized camera forward direction vector.
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

// Stores current camera position and rotation as home.
function __gm3d_ed_cam_remember(_ed) {
	_ed.cam_home = undefined;
	if (_ed == undefined || _ed.rt == undefined || _ed.rt.cam == undefined) {
		return;
	}
	var _p = _ed.rt.cam.getLocalPosition();
	var _q = _ed.rt.cam.getLocalRotation();
	_ed.cam_home = { pos: [_p.x, _p.y, _p.z], rot: [_q.x, _q.y, _q.z, _q.w] };
}

// Ensures separate editor viewport camera exists and selects it.
function __gm3d_ed_viewcam_ensure(_ed) {
	if (_ed == undefined || _ed.rt == undefined || _ed.rt.scene == undefined) {
		return undefined;
	}
	if (_ed.viewcam == undefined) {
		var _node = _ed.rt.scene.createNode("__editor_camera");
		if (_node == undefined) {
			return undefined;
		}
		var _cc = new GM3D_CameraComponent();
		_node.addComponent(_cc);
		_cc.setEnabled(false);
		_ed.viewcam = _node;
	}
	_ed.rt.cam = _ed.viewcam;
	return _ed.viewcam;
}

// Seeds editor camera from given gameplay camera pose and settings.
function __gm3d_ed_viewcam_seed_from(_ed, _src) {
	if (_ed == undefined) {
		return false;
	}
	__gm3d_ed_viewcam_ensure(_ed);
	var _vc = _ed.viewcam;
	if (_vc == undefined || _src == undefined) {
		return false;
	}
	var _p = _src.getLocalPosition();
	var _q = _src.getLocalRotation();
	_vc.setLocalPosition(new GM3D_Vec3(_p.x, _p.y, _p.z));
	_vc.setLocalRotation(_q.clone());
	__gm3d_ed_camera_apply(_vc, __gm3d_ed_camera_read(_src));
	var _cc = _vc.getCameraComponent();
	if (_cc != undefined) {
		_cc.setEnabled(true);
	}
	_ed.rt.scene.update(0);
	__gm3d_ed_cam_remember(_ed);
	return true;
}

// Seeds editor camera from resolved gameplay camera.
function __gm3d_ed_viewcam_seed(_ed) {
	if (_ed == undefined) {
		return false;
	}
	var _g = __gm3d_ed_gamecam_resolve(_ed);
	if (_g == undefined) {
		__gm3d_ed_viewcam_ensure(_ed);
		if (_ed.viewcam != undefined) {
			var _ec = _ed.viewcam.getCameraComponent();
			if (_ec != undefined) {
				_ec.setEnabled(true);
			}
		}
		__gm3d_ed_cam_remember(_ed);
		return false;
	}
	return __gm3d_ed_viewcam_seed_from(_ed, _g);
}

// Restores camera to remembered home position instantly or animated.
function __gm3d_ed_cam_home(_ed, _smooth = false) {
	if (_ed == undefined || _ed.cam_home == undefined || _ed.rt == undefined || _ed.rt.cam == undefined) {
		return;
	}
	var _h = _ed.cam_home;
	var _tp = new GM3D_Vec3(_h.pos[0], _h.pos[1], _h.pos[2]);
	var _tq = new GM3D_Quaternion();
	_tq.x = _h.rot[0];
	_tq.y = _h.rot[1];
	_tq.z = _h.rot[2];
	_tq.w = _h.rot[3];
	if (!_smooth) {
		_ed.rt.cam.setLocalPosition(_tp);
		_ed.rt.cam.setLocalRotation(_tq);
		_ed.cam_anim = undefined;
		return;
	}
	var _pp = _ed.rt.cam.getLocalPosition();
	var _cq = _ed.rt.cam.getLocalRotation();
	_ed.cam_anim = {
		t: 0,
		dur: 0.5,
		q0: [_cq.x, _cq.y, _cq.z, _cq.w],
		q1: [_tq.x, _tq.y, _tq.z, _tq.w],
		p0: [_pp.x, _pp.y, _pp.z],
		p1: [_tp.x, _tp.y, _tp.z],
	};
}

// Rotates camera yaw and pitch from mouse deltas.
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

// Handles orbit, pan, zoom, and fly camera controls.
function __gm3d_ed_cam_fly(_ed, _input, _dt) {
	var _vp = _input.vp;
	var _allowKeys = _input.camera_keys;
	var _allowZoom = _input.camera_zoom;
	var _node = _ed.rt.cam;
	if (_node == undefined) {
		return;
	}
	_ed.cam_speed_notice = max(0, _ed.cam_speed_notice - _dt);
	var _vf = __gm3d_ed_view_forward(_ed);
	var _yaw = radtodeg(arctan2(_vf.x, -_vf.z));
	var _pitch = radtodeg(arcsin(clamp(_vf.y, -1.0, 1.0)));
	var _alt = keyboard_check(vk_alt);
	var _owner = __gm3d_ed_input_owner_sync(_ed);
	var _can_start = _allowKeys && _allowZoom && _owner == undefined && _ed.giz.drag == -1 && !_ed.press_vp;
	if (_can_start) {
		if (_alt && mouse_check_button(mb_left)) {
			_owner = "camera_orbit";
		} else if (_alt && mouse_check_button(mb_right)) {
			_owner = "camera_zoom";
		} else if (!_alt && mouse_check_button(mb_right)) {
			_owner = "camera_fly";
		} else if (mouse_check_button(mb_middle)) {
			_owner = "camera_pan";
		}
		_ed.input_owner = _owner;
	}
	var _orbit = _allowKeys && _owner == "camera_orbit" && _alt && mouse_check_button(mb_left);
	var _pan = _allowKeys && _owner == "camera_pan" && mouse_check_button(mb_middle);
	var _zoom = _allowKeys && _owner == "camera_zoom" && _alt && mouse_check_button(mb_right);
	var _fly = _allowKeys && _owner == "camera_fly" && !_alt && mouse_check_button(mb_right);
	if (_orbit && !_ed.cam_orbit) {
		var _origin = _node.getLocalPosition();
		_ed.cam_orbit_target = new GM3D_Vec3(
			_origin.x - _vf.x * 10,
			_origin.y - _vf.y * 10,
			_origin.z - _vf.z * 10,
		);
		_ed.cam_orbit_radius = 10;
	}
	if (_zoom && !_ed.cam_zoom) {
		var _zoom_pos = _node.getLocalPosition();
		_ed.cam_zoom_target = array_length(_ed.sel) > 0
			? __gm3d_ed_gizmo_pivot(_ed.sel)
			: new GM3D_Vec3(_zoom_pos.x - _vf.x * 10, _zoom_pos.y - _vf.y * 10, _zoom_pos.z - _vf.z * 10);
	}
	_ed.cam_orbit = _orbit;
	_ed.cam_pan = _pan;
	_ed.cam_zoom = _zoom;
	_ed.cam_fly = _fly;
	if (
		(_owner == "camera_orbit" && !_orbit) ||
		(_owner == "camera_pan" && !_pan) ||
		(_owner == "camera_zoom" && !_zoom) ||
		(_owner == "camera_fly" && !_fly)
	) {
		_ed.input_owner = undefined;
	}
	if (_orbit || _fly) {
		var _yp = __gm3d_ed_orbit_apply(_ed, window_mouse_get_delta_x(), window_mouse_get_delta_y());
		_yaw = _yp[0];
		_pitch = _yp[1];
	}

	var _boost = keyboard_check(vk_shift) ? 2.0 : 1.0;
	var _step = _dt * _ed.cam_fly_speed * _boost;
	var _move = _fly && !keyboard_check(vk_control);
	var _fw = _move ? keyboard_check(ord("W")) - keyboard_check(ord("S")) : 0.0;
	var _rt = _move ? keyboard_check(ord("A")) - keyboard_check(ord("D")) : 0.0;
	var _up = _move ? keyboard_check(ord("E")) - keyboard_check(ord("Q")) : 0.0;
	var _wheel = 0;
	if (_allowZoom && _allowKeys) {
		if (mouse_wheel_up()) {
			_wheel = -1;
		} else if (mouse_wheel_down()) {
			_wheel = 1;
		}
	}
	if (_fly && _wheel != 0) {
		_ed.cam_fly_speed = clamp(_ed.cam_fly_speed * (_wheel < 0 ? 1.2 : 1 / 1.2), 0.1, 1000);
		_ed.cam_speed_notice = 2;
		_wheel = 0;
	}
	if (!_orbit && !_pan && !_zoom && !_fly && _wheel == 0) {
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
	var _nx = _pp.x + (-_pfx * _fw + _prx * _rt) * _step;
	var _nz = _pp.z + (-_pfz * _fw + _prz * _rt) * _step;
	var _ny = _pp.y - _f.y * _fw * _step + _up * _step;
	if (_orbit) {
		_nx = _ed.cam_orbit_target.x + _f.x * _ed.cam_orbit_radius;
		_ny = _ed.cam_orbit_target.y + _f.y * _ed.cam_orbit_radius;
		_nz = _ed.cam_orbit_target.z + _f.z * _ed.cam_orbit_radius;
	}
	if (_zoom || _wheel != 0) {
		var _target = _zoom ? _ed.cam_zoom_target : (array_length(_ed.sel) > 0
			? __gm3d_ed_gizmo_pivot(_ed.sel)
			: new GM3D_Vec3(_pp.x - _f.x * 10, _pp.y - _f.y * 10, _pp.z - _f.z * 10));
		var _zx = _nx - _target.x;
		var _zy = _ny - _target.y;
		var _zz = _nz - _target.z;
		var _zoom_factor = _zoom ? 1 + window_mouse_get_delta_y() * 0.001 : (_wheel < 0 ? 0.9 : 1.1);
		_zoom_factor = max(_zoom_factor, 0.01);
		_nx = _target.x + _zx * _zoom_factor;
		_ny = _target.y + _zy * _zoom_factor;
		_nz = _target.z + _zz * _zoom_factor;
	}
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

	var _upv = GM3D_Vec3.up();
	_node.setLocalRotation(GM3D_Quaternion.fromLookRotation(_f, _upv).normalizeSafe(0.000001));

	if (_orbit || _pan || _zoom || _fly) {
		__gm3d_ed_wrap_camera(_ed);
	}
}

// Animates camera to align with selected viewcube direction.
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

// Advances smooth camera transition toward target pose.
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

// Calculates average world position of selected nodes.
function __gm3d_ed_gizmo_pivot(_sel) {
	var _n = array_length(_sel);
	if (_n == 0) {
		return undefined;
	}
	var _cx = 0;
	var _cy = 0;
	var _cz = 0;
	for (var _i = 0; _i < _n; _i++) {
		var _p = _sel[_i].getWorldPosition();
		_cx += _p.x;
		_cy += _p.y;
		_cz += _p.z;
	}
	return new GM3D_Vec3(_cx / _n, _cy / _n, _cz / _n);
}

// Returns active gizmo axes in world or local orientation.
function __gm3d_ed_gizmo_dirs(_ed) {
	if (_ed.giz.orient == 1 && array_length(_ed.sel) > 0) {
		var _last = _ed.sel[array_length(_ed.sel) - 1];
		var _wq = undefined;
		try {
			_wq = _last.getWorldRotation();
		} catch (_e) {
			_wq = undefined;
		}
        _wq ??= _last.getLocalRotation();
		return __gm3d_ed_quat_basis(_wq);
	}
	return [new GM3D_Vec3(1, 0, 0), GM3D_Vec3.up(), GM3D_Vec3.forward()];
}

// Computes pixel-constant gizmo handle length at pivot.
function __gm3d_ed_gizmo_len(_ed, _vp, _pivot) {
	return __gm3d_ed_gizmo_world_size(_vp, _pivot, _ed.giz.size);
}

// Converts desired pixel size to world units.
function __gm3d_ed_gizmo_world_size(_vp, _pivot, _pixels) {
	var _a = __gm3d_ed_world_to_screen(_vp, _pivot);
	if (_a == undefined) {
		return 1;
	}
	var _b = __gm3d_ed_world_to_screen(
		_vp,
		new GM3D_Vec3(_pivot.x + _vp.camRight.x, _pivot.y + _vp.camRight.y, _pivot.z + _vp.camRight.z)
	);
	if (_b == undefined) {
		return 1;
	}
	var _dx = _b[0] - _a[0];
	var _dy = _b[1] - _a[1];
	var _len = sqrt(_dx * _dx + _dy * _dy);
	if (_len < 0.5) {
		return 1;
	}
	return _pixels / _len;
}

// Converts world movement delta into node local space.
function __gm3d_ed_gizmo_world_delta_to_local(_node, _delta) {
	if (_node.parent == undefined) {
		return _delta.clone();
	}
	var _inv = _node.parent.getWorldMatrix().clone();
	_inv.invert();
	var _a = new GM3D_Vec3(0, 0, 0);
	var _b = _delta.clone();
	var _ta = _inv.transformPoint(_a);
	var _tb = _inv.transformPoint(_b);
	if (_ta != undefined) {
		_a = _ta;
	}
	if (_tb != undefined) {
		_b = _tb;
	}
	_b.sub(_a);
	return _b;
}

// Builds world-space circle points for rotation ring.
function __gm3d_ed_gizmo_ring_world(_pivot, _axis, _ws) {
	var _world = [];
	var _seg = 36;
	for (var _i = 0; _i <= _seg; _i++) {
		array_push(_world, __gm3d_ed_gizmo_ring_point(_pivot, _axis, _ws, (_i / _seg) * pi * 2));
	}
	return _world;
}

// Computes single point on rotation ring circle.
function __gm3d_ed_gizmo_ring_point(_pivot, _axis, _ws, _t) {
	var _ref = GM3D_Vec3.up();
	if (abs(_axis.dot(_ref)) >= 0.99) {
		_ref = GM3D_Vec3.forward();
	}
	var _u = new GM3D_Vec3();
	_u.crossVectors(_axis, _ref);
	_u.normalizeSafe(0.000001);
	var _v = new GM3D_Vec3();
	_v.crossVectors(_axis, _u);
	return new GM3D_Vec3(
		_pivot.x + (cos(_t) * _u.x + sin(_t) * _v.x) * _ws,
		_pivot.y + (cos(_t) * _u.y + sin(_t) * _v.y) * _ws,
		_pivot.z + (cos(_t) * _u.z + sin(_t) * _v.z) * _ws,
	);
}

// Projects rotation ring to screen pixel coordinates.
function __gm3d_ed_gizmo_ring_pts(_vp, _pivot, _axis, _ws) {
	var _mapped = __gm3d_ed_world_corners_to_screen(_vp, __gm3d_ed_gizmo_ring_world(_pivot, _axis, _ws));
	var _pts = [];
	for (var _j = 0; _j < array_length(_mapped); _j++) {
		if (_mapped[_j] != undefined) {
			array_push(_pts, _mapped[_j]);
		}
	}
	return _pts;
}

// Finds front-facing rotation ring segments for display.
function __gm3d_ed_gizmo_ring_front(_vp, _pivot, _axis, _ws) {
	var _world = __gm3d_ed_gizmo_ring_world(_pivot, _axis, _ws);
	var _cp = _vp.camNode.getWorldPosition();
	var _vx = _cp.x - _pivot.x;
	var _vy = _cp.y - _pivot.y;
	var _vz = _cp.z - _pivot.z;
	var _vl = sqrt(_vx * _vx + _vy * _vy + _vz * _vz);
	var _out = [];
	for (var _k = 0; _k < array_length(_world); _k++) {
		var _w = _world[_k];
		var _front = false;
		if (_vl > 0.0001) {
			_front = ((_w.x - _pivot.x) * _vx + (_w.y - _pivot.y) * _vy + (_w.z - _pivot.z) * _vz) > 0;
		}
		array_push(_out, { s: __gm3d_ed_world_to_screen(_vp, _w), front: _front });
	}
	return _out;
}

// Intersects ray with sphere returning hit point.
function __gm3d_ed_ray_sphere(_origin, _dir, _cx, _cy, _cz, _r) {
	var _ox = _origin.x - _cx;
	var _oy = _origin.y - _cy;
	var _oz = _origin.z - _cz;
	var _b = _ox * _dir.x + _oy * _dir.y + _oz * _dir.z;
	var _c = _ox * _ox + _oy * _oy + _oz * _oz - _r * _r;
	var _h = _b * _b - _c;
	if (_h < 0) {
		return undefined;
	}
	var _t = -_b - sqrt(_h);
	if (_t < 0) {
		return undefined;
	}
	return new GM3D_Vec3(_origin.x + _dir.x * _t, _origin.y + _dir.y * _t, _origin.z + _dir.z * _t);
}

// Finds nearest surface point on sphere to ray.
function __gm3d_ed_sphere_nearest(_origin, _dir, _cx, _cy, _cz, _r) {
	var _ox = _origin.x - _cx;
	var _oy = _origin.y - _cy;
	var _oz = _origin.z - _cz;
	var _t = -(_ox * _dir.x + _oy * _dir.y + _oz * _dir.z);
	if (_t < 0) {
		_t = 0;
	}
	var _px = _ox + _dir.x * _t;
	var _py = _oy + _dir.y * _t;
	var _pz = _oz + _dir.z * _t;
	var _l = sqrt(_px * _px + _py * _py + _pz * _pz);
	if (_l < 0.000001) {
		return undefined;
	}
	return new GM3D_Vec3(_cx + _px / _l * _r, _cy + _py / _l * _r, _cz + _pz / _l * _r);
}

// Creates rotation quaternion between two direction vectors.
function __gm3d_ed_trackball_arc(_ax, _ay, _az, _bx, _by, _bz) {
	var _cx = _ay * _bz - _az * _by;
	var _cy = _az * _bx - _ax * _bz;
	var _cz = _ax * _by - _ay * _bx;
	var _s = sqrt(_cx * _cx + _cy * _cy + _cz * _cz);
	if (_s < 0.000001) {
		return undefined;
	}
	var _d = clamp(_ax * _bx + _ay * _by + _az * _bz, -1.0, 1.0);
	return GM3D_Quaternion.fromAxisAngle(new GM3D_Vec3(_cx / _s, _cy / _s, _cz / _s), arccos(_d));
}

// Measures squared mouse distance to front ring segments.
function __gm3d_ed_ring_front_dist2(_mx, _my, _ring) {
	var _best = 1000000000;
	for (var _i = 0; _i < array_length(_ring) - 1; _i++) {
		var _a = _ring[_i];
		var _b = _ring[_i + 1];
		if (_a.s == undefined || _b.s == undefined || !_a.front || !_b.front) {
			continue;
		}
		var _d = __gm3d_ed_point_seg_dist2(_mx, _my, _a.s[0], _a.s[1], _b.s[0], _b.s[1]);
		if (_d < _best) {
			_best = _d;
		}
	}
	return _best;
}

// Computes normalized view direction from pivot to camera.
function __gm3d_ed_gizmo_cam_view(_vp, _pivot) {
	if (_vp == undefined || _vp.camNode == undefined || _pivot == undefined) {
		return undefined;
	}
	var _cp = _vp.camNode.getWorldPosition();
	var _view = new GM3D_Vec3(_cp.x - _pivot.x, _cp.y - _pivot.y, _cp.z - _pivot.z);
	_view.normalizeSafe(0.000001);
	return _view;
}

// Builds planar translation handle quad from two axes.
function __gm3d_ed_gizmo_quad(_pivot, _dirs, _a, _h, _view = undefined) {
	var _b = (_a + 1) mod 3;
	var _c = (_a + 2) mod 3;
	var _sb = 1.0;
	var _sc = 1.0;
	if (_view != undefined) {
		if (_dirs[_b].dot(_view) < 0) {
			_sb = -1.0;
		}
		if (_dirs[_c].dot(_view) < 0) {
			_sc = -1.0;
		}
	}
	var _pb = _pivot.clone();
	_pb.addScaledVector(_dirs[_b], _h * _sb);
	var _pc = _pivot.clone();
	_pc.addScaledVector(_dirs[_c], _h * _sc);
	var _pbc = _pivot.clone();
	_pbc.addScaledVector(_dirs[_b], _h * _sb);
	_pbc.addScaledVector(_dirs[_c], _h * _sc);
	return [_pivot, _pb, _pbc, _pc];
}

// Detects which gizmo handle mouse currently hovers.
function __gm3d_ed_gizmo_hover(_ed, _vp, _mx, _my) {
	if (array_length(_ed.sel) == 0) {
		return -1;
	}
	if (!__gm3d_ed_gizmo_allowed(_ed)) {
		return -1;
	}
	var _pivot = __gm3d_ed_gizmo_pivot(_ed.sel);
	var _ps = __gm3d_ed_world_to_screen(_vp, _pivot);
	if (_ps == undefined) {
		return -1;
	}
	if (_ed.giz.tool == Gm3dEdTool.Translate || _ed.giz.tool == Gm3dEdTool.Scale) {
		if ((_mx - _ps[0]) * (_mx - _ps[0]) + (_my - _ps[1]) * (_my - _ps[1]) <= 64) {
			return -2;
		}
	}
	var _dirs = __gm3d_ed_gizmo_dirs(_ed);
	var _ws = __gm3d_ed_gizmo_len(_ed, _vp, _pivot);
	var _qview = __gm3d_ed_gizmo_cam_view(_vp, _pivot);
	var _f = __gm3d_ed_view_forward(_ed);
	var _look = new GM3D_Vec3(-_f.x, -_f.y, -_f.z);
	if (_ed.giz.tool == Gm3dEdTool.Translate) {

		var _qb = -1;
		var _qb_area = -1;
		for (var _q = 0; _q < 3; _q++) {
			var _sp = __gm3d_ed_clip_screen_poly(_vp, __gm3d_ed_gizmo_quad(_pivot, _dirs, _q, _ws * 0.3, _qview));
			if (array_length(_sp) < 3) {
				continue;
			}
			var _inside = false;
			for (var _t = 1; _t < array_length(_sp) - 1; _t++) {
				if (__gm3d_ed_tri_hit(_mx, _my, _sp[0][0], _sp[0][1], _sp[_t][0], _sp[_t][1], _sp[_t + 1][0], _sp[_t + 1][1])) {
					_inside = true;
					break;
				}
			}
			if (!_inside) {
				continue;
			}
			var _area = 0;
			var _nq = array_length(_sp);
			for (var _e = 0; _e < _nq; _e++) {
				var _p0 = _sp[_e];
				var _p1 = _sp[(_e + 1) mod _nq];
				_area += _p0[0] * _p1[1] - _p1[0] * _p0[1];
			}
			_area = abs(_area) * 0.5;
			if (_area > _qb_area) {
				_qb_area = _area;
				_qb = _q;
			}
		}
		if (_qb != -1) {
			return 3 + _qb;
		}

		var _pad2 = 36.0;
		var _pb = -1;
		var _pb_d = 1000000000;
		for (var _q2 = 0; _q2 < 3; _q2++) {
			var _sp2 = __gm3d_ed_clip_screen_poly(_vp, __gm3d_ed_gizmo_quad(_pivot, _dirs, _q2, _ws * 0.3, _qview));
			var _n2 = array_length(_sp2);
			if (_n2 < 3) {
				continue;
			}
			var _dmin = 1000000000;
			for (var _e2 = 0; _e2 < _n2; _e2++) {
				var _a2 = _sp2[_e2];
				var _b2 = _sp2[(_e2 + 1) mod _n2];
				var _dd = __gm3d_ed_point_seg_dist2(_mx, _my, _a2[0], _a2[1], _b2[0], _b2[1]);
				if (_dd < _dmin) {
					_dmin = _dd;
				}
			}
			if (_dmin <= _pad2 && _dmin < _pb_d) {
				_pb_d = _dmin;
				_pb = _q2;
			}
		}
		if (_pb != -1) {
			return 3 + _pb;
		}
	}
	var _best = -1;
	var _bestD = 400.0;
	for (var _a = 0; _a < 3; _a++) {
		var _d;
		if (_ed.giz.tool == Gm3dEdTool.Rotate) {
			_d = __gm3d_ed_ring_front_dist2(_mx, _my, __gm3d_ed_gizmo_ring_front(_vp, _pivot, _dirs[_a], _ws));
		} else {
			var _e = __gm3d_ed_world_to_screen(
				_vp,
				new GM3D_Vec3(_pivot.x + _dirs[_a].x * _ws, _pivot.y + _dirs[_a].y * _ws, _pivot.z + _dirs[_a].z * _ws)
			);
			if (_e == undefined) {
				continue;
			}
			_d = __gm3d_ed_point_seg_dist2(_mx, _my, _ps[0], _ps[1], _e[0], _e[1]);
			_d = min(_d, (_mx - _e[0]) * (_mx - _e[0]) + (_my - _e[1]) * (_my - _e[1]));
		}
		if (_d < _bestD) {
			_bestD = _d;
			_best = _a;
		}
	}
	if (_ed.giz.tool == Gm3dEdTool.Rotate) {
		var _vr2 = __gm3d_ed_gizmo_ring_pts(_vp, _pivot, _look, _ws);
		var _rd = __gm3d_ed_point_polyline_dist2(_mx, _my, _vr2);
		if (_rd < _bestD) {
			_best = 6;
		}

		if (_best == -1) {
			var _rr2 = 0;
			for (var _ri = 0; _ri < array_length(_vr2); _ri++) {
				var _ddx = _vr2[_ri][0] - _ps[0];
				var _ddy = _vr2[_ri][1] - _ps[1];
				var _dl2 = _ddx * _ddx + _ddy * _ddy;
				if (_dl2 > _rr2) {
					_rr2 = _dl2;
				}
			}
			if (_rr2 > 1) {
				var _mcx = _mx - _ps[0];
				var _mcy = _my - _ps[1];
				if (_mcx * _mcx + _mcy * _mcy <= _rr2) {
					_best = 7;
				}
			}
		}
	}
	return _best;
}

// Initializes gizmo drag state and interaction plane.
function __gm3d_ed_gizmo_begin(_ed, _vp, _mx, _my) {
	var _g = _ed.giz;
	_g.starts = [];
	_ed.hist_before = __gm3d_ed_history_snap(_ed);
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		array_push(_g.starts, {
			pos: _ed.sel[_i].getLocalPosition().clone(),
			sca: _ed.sel[_i].getLocalScale().clone(),
			rot: _ed.sel[_i].getLocalRotation().clone(),
		});
	}
	var _pivot = __gm3d_ed_gizmo_pivot(_ed.sel);
	_g.pivot = _pivot.clone();
	_g.center = _g.drag < 0;
	_g.planar = _g.drag >= 3 && _g.drag <= 5;
	var _dirs = __gm3d_ed_gizmo_dirs(_ed);
	var _ax = 0;
	if (_g.drag == 6) {
		_g.dir = __gm3d_ed_view_forward(_ed);
	} else if (_g.drag == 7) {

		_g.dir = __gm3d_ed_view_forward(_ed);
		_g.tblen = __gm3d_ed_gizmo_len(_ed, _vp, _pivot);
		_g.tb_mx = _mx;
		_g.tb_my = _my;
	} else if (_g.planar) {
		_g.dir = _dirs[_g.drag - 3];
	} else {
		_ax = _g.center ? 0 : _g.drag;
		_g.dir = _dirs[_ax];
	}
	_g.axis_idx = _ax;
	_g.world_len = 0.0001;
	for (var _j = 0; _j < array_length(_g.starts); _j++) {
		var _s = _g.starts[_j].sca;
		var _c = _ax == 0 ? _s.x : _ax == 1 ? _s.y : _s.z;
		_g.world_len = max(_g.world_len, abs(_c));
	}
	if (_g.center && _g.tool == Gm3dEdTool.Translate) {
		var _cf = __gm3d_ed_view_forward(_ed);
		_g.plane_n = new GM3D_Vec3(-_cf.x, -_cf.y, -_cf.z);
	} else if (_g.planar) {
		_g.plane_n = _g.dir.clone();
	} else {
		var _cp = _vp.camNode.getWorldPosition();
		var _view = new GM3D_Vec3(_cp.x - _pivot.x, _cp.y - _pivot.y, _cp.z - _pivot.z);
		_view.normalizeSafe(0.000001);
		_g.plane_n = _view.clone();
		_g.plane_n.addScaledVector(_g.dir, -_view.dot(_g.dir));
		if (_g.plane_n.lengthSq() < 0.000001) {
			_g.plane_n.crossVectors(_g.dir, _vp.camUp);
		}
		_g.plane_n.normalizeSafe(0.000001);
	}
	var _ray = __gm3d_ed_screen_ray(_vp, _mx, _my);
	_g.start_hit = __gm3d_ed_ray_plane(_ray.origin, _ray.dir, _pivot, _g.plane_n);
	if (_g.start_hit == undefined) {
		_g.start_hit = _pivot.clone();
	}
	_g.mx0 = _mx;
	_g.my0 = _my;
	var _ps = __gm3d_ed_world_to_screen(_vp, _pivot);
    _ps ??= [_mx, _my];
	_g.piv_sx = _ps[0];
	_g.piv_sy = _ps[1];
	_g.rot_mx = _mx;
	_g.rot_my = _my;
	_g.rot_tx = 1;
	_g.rot_ty = 0;
	_g.total_ang = 0;
	_g.display_ang = 0;
	_g.sector_t0 = 0;
	if (_g.tool == Gm3dEdTool.Rotate && _g.drag != 7) {
		var _ring_ws = __gm3d_ed_gizmo_len(_ed, _vp, _pivot);
		var _best_d2 = 1000000000;
		var _sample_count = 144;
		for (var _sample = 0; _sample < _sample_count; _sample++) {
			var _sample_t = (_sample / _sample_count) * 2 * pi;
			var _sample_s = __gm3d_ed_world_to_screen(
				_vp,
				__gm3d_ed_gizmo_ring_point(_pivot, _g.dir, _ring_ws, _sample_t)
			);
			if (_sample_s == undefined) {
				continue;
			}
			var _sample_dx = _sample_s[0] - _mx;
			var _sample_dy = _sample_s[1] - _my;
			var _sample_d2 = _sample_dx * _sample_dx + _sample_dy * _sample_dy;
			if (_sample_d2 < _best_d2) {
				_best_d2 = _sample_d2;
				_g.sector_t0 = _sample_t;
			}
		}
		var _refine_step = (2 * pi) / _sample_count;
		for (var _refine = 0; _refine < 6; _refine++) {
			var _refined_t = _g.sector_t0;
			for (var _offset = -1; _offset <= 1; _offset++) {
				var _candidate_t = _g.sector_t0 + _offset * _refine_step;
				var _candidate_s = __gm3d_ed_world_to_screen(
					_vp,
					__gm3d_ed_gizmo_ring_point(_pivot, _g.dir, _ring_ws, _candidate_t)
				);
				if (_candidate_s == undefined) {
					continue;
				}
				var _candidate_dx = _candidate_s[0] - _mx;
				var _candidate_dy = _candidate_s[1] - _my;
				var _candidate_d2 = _candidate_dx * _candidate_dx + _candidate_dy * _candidate_dy;
				if (_candidate_d2 < _best_d2) {
					_best_d2 = _candidate_d2;
					_refined_t = _candidate_t;
				}
			}
			_g.sector_t0 = _refined_t;
			_refine_step /= 3;
		}
		var _tangent_step = 0.01;
		var _tangent_a = __gm3d_ed_world_to_screen(
			_vp,
			__gm3d_ed_gizmo_ring_point(_pivot, _g.dir, _ring_ws, _g.sector_t0 - _tangent_step)
		);
		var _tangent_b = __gm3d_ed_world_to_screen(
			_vp,
			__gm3d_ed_gizmo_ring_point(_pivot, _g.dir, _ring_ws, _g.sector_t0 + _tangent_step)
		);
		if (_tangent_a != undefined && _tangent_b != undefined) {
			var _tangent_x = _tangent_b[0] - _tangent_a[0];
			var _tangent_y = _tangent_b[1] - _tangent_a[1];
			var _tangent_len = sqrt(_tangent_x * _tangent_x + _tangent_y * _tangent_y);
			if (_tangent_len > 0.0001) {
				_g.rot_tx = _tangent_x / _tangent_len;
				_g.rot_ty = _tangent_y / _tangent_len;
			}
		}
	}
}

// Routes active drag to translate, scale, or rotate.
function __gm3d_ed_gizmo_drag(_ed, _vp, _mx, _my) {
	var _g = _ed.giz;
	var _ray = __gm3d_ed_screen_ray(_vp, _mx, _my);
	if (_g.tool == Gm3dEdTool.Translate) {
		__gm3d_ed_gizmo_drag_translate(_ed, _g, _ray);
	} else if (_g.tool == Gm3dEdTool.Scale) {
		__gm3d_ed_gizmo_drag_scale(_ed, _g, _ray, _my);
	} else if (_g.tool == Gm3dEdTool.Rotate) {
		__gm3d_ed_gizmo_drag_rotate(_ed, _vp, _g, _mx, _my);
	}
}

// Moves selected nodes along axis or plane.
function __gm3d_ed_gizmo_drag_translate(_ed, _g, _ray) {
	var _hit = __gm3d_ed_ray_plane(_ray.origin, _ray.dir, _g.pivot, _g.plane_n);
	if (_hit == undefined) {
		return;
	}
	var _delta = new GM3D_Vec3();
	_delta.subVectors(_hit, _g.start_hit);
	if (_g.planar) {
		var _dn = _delta.dot(_g.dir);
		_delta.addScaledVector(_g.dir, -_dn);
	} else if (!_g.center) {
		var _d = _delta.dot(_g.dir);
		_delta = _g.dir.clone();
		_delta.multiplyScalar(_d);
	}
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		if (!__gm3d_ed_tool_allowed(_ed, _ed.sel[_i], Gm3dEdTool.Translate) || __gm3d_ed_hidden_get(_ed, _ed.sel[_i])) {
			continue;
		}
		var _local = __gm3d_ed_gizmo_world_delta_to_local(_ed.sel[_i], _delta);
		var _pos = _g.starts[_i].pos.clone();
		_pos.add(_local);
		var _sp = _ed.snap_on || keyboard_check(vk_control) ? _ed.snap_pos : 0;
		if (_sp > 0) {
			_pos.x = __gm3d_ed_snap(_pos.x, _sp);
			_pos.y = __gm3d_ed_snap(_pos.y, _sp);
			_pos.z = __gm3d_ed_snap(_pos.z, _sp);
		}
		_ed.sel[_i].setLocalPosition(_pos);
	}
}

// Scales selected nodes uniformly or along axis.
function __gm3d_ed_gizmo_drag_scale(_ed, _g, _ray, _my) {
	var _f = 1.0;
	if (_g.center) {

		_f = 1.0 + (_g.my0 - _my) / _g.size;
	} else {
		var _h2 = __gm3d_ed_ray_plane(_ray.origin, _ray.dir, _g.pivot, _g.plane_n);
		if (_h2 == undefined) {
			return;
		}
		var _dd = new GM3D_Vec3();
		_dd.subVectors(_h2, _g.start_hit);
		_f = 1.0 + _dd.dot(_g.dir) / max(_g.world_len, 0.0001);
	}
	_f = max(_f, 0.01);
	for (var _j = 0; _j < array_length(_ed.sel); _j++) {
		if (!__gm3d_ed_tool_allowed(_ed, _ed.sel[_j], Gm3dEdTool.Scale) || __gm3d_ed_hidden_get(_ed, _ed.sel[_j])) {
			continue;
		}
		var _s = _g.starts[_j].sca.clone();
		if (_g.center) {
			_s.x *= _f;
			_s.y *= _f;
			_s.z *= _f;
		} else if (_g.axis_idx == 0) {
			_s.x *= _f;
		} else if (_g.axis_idx == 1) {
			_s.y *= _f;
		} else {
			_s.z *= _f;
		}
		_s.x = max(_s.x, 0.01);
		_s.y = max(_s.y, 0.01);
		_s.z = max(_s.z, 0.01);
		_ed.sel[_j].setLocalScale(_s);
	}
}

// Rotates selected nodes via trackball or ring.
function __gm3d_ed_gizmo_drag_rotate(_ed, _vp, _g, _mx, _my) {
	if (_g.drag == 7 && variable_struct_exists(_g, "tb_mx") && variable_struct_exists(_g, "tb_my")) {

		var _dx7 = _mx - _g.tb_mx;
		var _dy7 = _my - _g.tb_my;
		_g.tb_mx = _mx;
		_g.tb_my = _my;
		var _mag7 = sqrt(_dx7 * _dx7 + _dy7 * _dy7);
		if (_mag7 > 0.0001 && _vp.camRight != undefined && _vp.camUp != undefined) {
			var _k7 = 0.01;
			var _rx7 = _vp.camRight;
			var _ru7 = _vp.camUp;
			var _axis7 = new GM3D_Vec3(
				_rx7.x * _dy7 + _ru7.x * _dx7,
				_rx7.y * _dy7 + _ru7.y * _dx7,
				_rx7.z * _dy7 + _ru7.z * _dx7,
			);
			_axis7.normalizeSafe(0.000001);
			var _qt7 = GM3D_Quaternion.fromAxisAngle(_axis7, _mag7 * _k7);
			for (var _k7i = 0; _k7i < array_length(_ed.sel); _k7i++) {
				if (!__gm3d_ed_tool_allowed(_ed, _ed.sel[_k7i], Gm3dEdTool.Rotate) || __gm3d_ed_hidden_get(_ed, _ed.sel[_k7i])) {
					continue;
				}
				var _qr7 = _qt7.clone();
				_qr7.multiply(_ed.sel[_k7i].getLocalRotation().clone());

				var _bad7 = false;
				try {
					_bad7 = is_nan(_qr7.x) || is_nan(_qr7.y) || is_nan(_qr7.z) || is_nan(_qr7.w);
				} catch (_eN) {
					_bad7 = true;
				}
				if (_bad7) {
					continue;
				}
				_ed.sel[_k7i].setLocalRotation(_qr7.normalizeSafe(0.000001));
			}
		}
	} else {
		var _rot_dx = _mx - _g.rot_mx;
		var _rot_dy = _my - _g.rot_my;
		_g.rot_mx = _mx;
		_g.rot_my = _my;
		var _dd = (_rot_dx * _g.rot_tx + _rot_dy * _g.rot_ty) * 0.01;
		var _ax2 = _g.center ? 1 : _g.axis_idx;

		var _axis = _g.dir;
		if (_g.drag != 6 && _ed.giz.orient == 1) {
			if (_ax2 == 2) {
				_axis = GM3D_Vec3.forward();
			} else if (_ax2 == 1) {
				_axis = GM3D_Vec3.up();
			} else {
				_axis = new GM3D_Vec3(1, 0, 0);
			}
		}
		_g.total_ang += _dd;
		var _deg = radtodeg(_g.total_ang);
		var _sr = _ed.snap_on || keyboard_check(vk_control) ? _ed.snap_rot : 0;
		if (_sr > 0) {
			_deg = __gm3d_ed_snap(_deg, _sr);
		}
		_g.display_ang = degtorad(_deg);
		for (var _k = 0; _k < array_length(_ed.sel); _k++) {
			if (!__gm3d_ed_tool_allowed(_ed, _ed.sel[_k], Gm3dEdTool.Rotate) || __gm3d_ed_hidden_get(_ed, _ed.sel[_k])) {
				continue;
			}
			var _q = GM3D_Quaternion.fromAxisAngle(_axis, degtorad(_deg));
			if (_ed.giz.orient == 1) {
				var _qs = _g.starts[_k].rot.clone();
				_qs.multiply(_q);
				_q = _qs;
			} else {
				_q.multiply(_g.starts[_k].rot);
			}
			_ed.sel[_k].setLocalRotation(_q.normalizeSafe(0.000001));
		}
	}
}

// Draws complete transform gizmo with handles.
function __gm3d_ed_gizmo_draw(_ed, _vp) {
	var _cols = [c_red, c_lime, c_blue];
	var _hls = [make_colour_rgb(255, 150, 60), make_colour_rgb(255, 255, 120), make_colour_rgb(110, 200, 255)];

	if (array_length(_ed.sel) == 0) {
		return;
	}
	if (!__gm3d_ed_gizmo_allowed(_ed)) {
		return;
	}
	var _pivot = __gm3d_ed_gizmo_pivot(_ed.sel);
	var _ps = __gm3d_ed_world_to_screen(_vp, _pivot);
	if (_ps == undefined) {
		return;
	}
	var _dirs = __gm3d_ed_gizmo_dirs(_ed);
	var _ws = __gm3d_ed_gizmo_len(_ed, _vp, _pivot);
	var _vf0 = __gm3d_ed_view_forward(_ed);
	var _look = new GM3D_Vec3(-_vf0.x, -_vf0.y, -_vf0.z);
	__gm3d_ed_gizmo_draw_translate_quads(_ed, _vp, _pivot, _dirs, _ws, _cols, _hls);
	__gm3d_ed_gizmo_draw_axes(_ed, _vp, _pivot, _ps, _dirs, _ws, _cols, _hls);
	__gm3d_ed_gizmo_draw_viewring(_ed, _vp, _pivot, _look, _ws);
	__gm3d_ed_gizmo_draw_center(_ed, _ps);
	if (_ed.giz.tool == Gm3dEdTool.Rotate && (_ed.giz.drag == 6 || (_ed.giz.drag >= 0 && _ed.giz.drag <= 2))) {
		__gm3d_ed_gizmo_draw_rotate_sweep(_ed, _vp, _pivot, _ps, _ws, _hls);
	} else if (_ed.giz.tool == Gm3dEdTool.Translate && _ed.giz.drag != -1) {
		__gm3d_ed_gizmo_draw_trail(_ed, _vp, _ps);
	}
}

// Draws selection bounding boxes for selected nodes.
function __gm3d_ed_gizmo_draw_selboxes(_ed, _vp) {
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		__gm3d_ed_draw_selbox(_ed.sel[_i], _vp, _ed);
	}
}

// Renders planar translation handle quads.
function __gm3d_ed_gizmo_draw_translate_quads(_ed, _vp, _pivot, _dirs, _ws, _cols, _hls) {
	if (_ed.giz.tool == Gm3dEdTool.Translate) {
		var _qview = __gm3d_ed_gizmo_cam_view(_vp, _pivot);
		for (var _qa = 0; _qa < 3; _qa++) {
			var _qp = __gm3d_ed_clip_screen_poly(_vp, __gm3d_ed_gizmo_quad(_pivot, _dirs, _qa, _ws * 0.3, _qview));
			if (array_length(_qp) < 3) {
				continue;
			}
			var _qh = (_ed.giz.hover == 3 + _qa && _ed.giz.drag == -1) || _ed.giz.drag == 3 + _qa;
			var _qcol = _qh ? _hls[_qa] : _cols[_qa];
			var _qal = _qh ? 0.55 : 0.3;
			if (_ed.giz.drag != -1 && _ed.giz.drag != 3 + _qa) {
				_qcol = merge_colour(_qcol, c_white, 0.6);
				_qal = 0.15;
			}
			draw_primitive_begin(pr_trianglefan);
			for (var _qv = 0; _qv < array_length(_qp); _qv++) {
				draw_vertex_colour(_qp[_qv][0], _qp[_qv][1], _qcol, _qal);
			}
			draw_primitive_end();
			draw_set_alpha(_qal <= 0.2 ? 0.35 : 0.8);
			for (var _qe = 0; _qe < array_length(_qp); _qe++) {
				var _qn = _qp[(_qe + 1) mod array_length(_qp)];
				__gm3d_ed_vp_line(_ed, _qp[_qe][0], _qp[_qe][1], _qn[0], _qn[1], 1, _qcol);
			}
			draw_set_alpha(1);
		}
	}
}

// Renders translate, scale, or rotate axis handles.
function __gm3d_ed_gizmo_draw_axes(_ed, _vp, _pivot, _ps, _dirs, _ws, _cols, _hls) {
	for (var _a = 0; _a < 3; _a++) {
		var _mine = _ed.giz.drag == _a;
		var _hov = (_ed.giz.hover == _a && _ed.giz.drag == -1) || _mine;
		var _bcol = _hov ? _hls[_a] : _cols[_a];
		var _al = 1;
		if (_ed.giz.drag != -1 && !_mine) {
			_bcol = merge_colour(_bcol, c_white, 0.6);
			_al = 0.2;
		}
		if (_ed.giz.tool == Gm3dEdTool.Translate) {
			var _e = __gm3d_ed_world_to_screen(
				_vp,
				new GM3D_Vec3(_pivot.x + _dirs[_a].x * _ws, _pivot.y + _dirs[_a].y * _ws, _pivot.z + _dirs[_a].z * _ws)
			);
			if (_e == undefined) {
				continue;
			}
			__gm3d_ed_gizmo_shaft(_ed, _ps[0], _ps[1], _e[0], _e[1], _bcol, _al);
			__gm3d_ed_arrow(_ps[0], _ps[1], _e[0], _e[1], _bcol, _hov ? 12 : 9, _al);
		} else if (_ed.giz.tool == Gm3dEdTool.Scale) {
			var _e2 = __gm3d_ed_world_to_screen(
				_vp,
				new GM3D_Vec3(_pivot.x + _dirs[_a].x * _ws, _pivot.y + _dirs[_a].y * _ws, _pivot.z + _dirs[_a].z * _ws)
			);
			if (_e2 == undefined) {
				continue;
			}
			__gm3d_ed_gizmo_shaft(_ed, _ps[0], _ps[1], _e2[0], _e2[1], _bcol, _al);
			draw_set_alpha(_al);
			draw_rectangle_color(_e2[0] - 5, _e2[1] - 5, _e2[0] + 5, _e2[1] + 5, _bcol, _bcol, _bcol, _bcol, false);
			draw_set_color(merge_colour(_bcol, c_white, 0.5));
			draw_line_width(_e2[0] - 5, _e2[1] - 5, _e2[0] + 5, _e2[1] - 5, 1);
			draw_set_color(merge_colour(_bcol, c_black, 0.3));
			draw_line_width(_e2[0] - 5, _e2[1] + 5, _e2[0] + 5, _e2[1] + 5, 1);
			draw_set_color(c_white);
			draw_set_alpha(1);
		} else if (_ed.giz.tool == Gm3dEdTool.Rotate) {
			var _pts = __gm3d_ed_gizmo_ring_front(_vp, _pivot, _dirs[_a], _ws);
			var _th = _ed.giz.hover == _a || _ed.giz.drag == _a ? 3 : 2;
			draw_set_alpha(_al);
			for (var _p = 0; _p < array_length(_pts) - 1; _p++) {
				if (_pts[_p].s == undefined || _pts[_p + 1].s == undefined || !_pts[_p].front || !_pts[_p + 1].front) {
					continue;
				}
				__gm3d_ed_vp_line(_ed, _pts[_p].s[0], _pts[_p].s[1], _pts[_p + 1].s[0], _pts[_p + 1].s[1], _th, _bcol);
			}
			draw_set_alpha(1);
		}
	}
}

// Draws camera-facing rotation ring and trackball disc.
function __gm3d_ed_gizmo_draw_viewring(_ed, _vp, _pivot, _look, _ws) {
	if (_ed.giz.tool == Gm3dEdTool.Rotate) {
		var _vpts = __gm3d_ed_gizmo_ring_pts(_vp, _pivot, _look, _ws);

		var _pc = __gm3d_ed_world_to_screen(_vp, _pivot);
		if (_pc != undefined && array_length(_vpts) > 0) {
			var _rr = 0;
			for (var _ri2 = 0; _ri2 < array_length(_vpts); _ri2++) {
				var _qx = _vpts[_ri2][0] - _pc[0];
				var _qy = _vpts[_ri2][1] - _pc[1];
				var _ql = _qx * _qx + _qy * _qy;
				if (_ql > _rr) {
					_rr = _ql;
				}
			}
			_rr = sqrt(_rr);
			if (_rr > 1) {
				var _dh = _ed.giz.hover == 7 || _ed.giz.drag == 7;
				var _dcol = _dh ? c_gray : c_white;
				draw_set_alpha(_dh ? 0.22 : 0.05);
				draw_circle_colour(_pc[0], _pc[1], _rr, _dcol, _dcol, false);
				draw_set_alpha(1);
			}
		}
		var _vh = _ed.giz.hover == 6 || _ed.giz.drag == 6;
		var _vth = _vh ? 3 : 2;
		var _vcol = _vh ? c_yellow : c_white;
		var _val = 1;
		if (_ed.giz.drag != -1 && _ed.giz.drag != 6) {
			_val = 0.2;
		}
		draw_set_alpha(_val);
		for (var _v = 0; _v < array_length(_vpts) - 1; _v++) {
			__gm3d_ed_vp_line(_ed, _vpts[_v][0], _vpts[_v][1], _vpts[_v + 1][0], _vpts[_v + 1][1], _vth, _vcol);
		}
		draw_set_alpha(1);
	}
}

// Draws central uniform transform handle circle.
function __gm3d_ed_gizmo_draw_center(_ed, _ps) {
	if (_ed.giz.tool == Gm3dEdTool.Translate || _ed.giz.tool == Gm3dEdTool.Scale) {
		var _bhov = _ed.giz.hover == -2 || _ed.giz.drag == -2;
		var _bcol = _bhov ? c_yellow : c_white;
		var _bal = 1;
		if (_ed.giz.drag != -1 && _ed.giz.drag != -2) {
			_bcol = make_colour_rgb(200, 200, 200);
			_bal = 0.2;
		}
		var _br = _bhov ? 6 : 4;
		var _brim = merge_colour(_bcol, c_black, 0.35);
		var _bn = 12;
		draw_set_alpha(_bal);
		draw_primitive_begin(pr_trianglefan);
		draw_vertex_colour(_ps[0] - 1, _ps[1] - 1, c_white, 1);
		for (var _bi = 0; _bi <= _bn; _bi++) {
			var _bt = (_bi / _bn) * 2 * pi;
			draw_vertex_colour(_ps[0] + cos(_bt) * _br, _ps[1] + sin(_bt) * _br, _bcol, 1);
		}
		draw_primitive_end();
		for (var _be = 0; _be < _bn; _be++) {
			var _bt0 = (_be / _bn) * 2 * pi;
			var _bt1 = ((_be + 1) / _bn) * 2 * pi;
			__gm3d_ed_vp_line(
				_ed,
				_ps[0] + cos(_bt0) * _br,
				_ps[1] + sin(_bt0) * _br,
				_ps[0] + cos(_bt1) * _br,
				_ps[1] + sin(_bt1) * _br,
				1,
				_brim
			);
		}
		draw_set_alpha(1);
	}
}

// Visualizes current rotation angle sweep arc.
function __gm3d_ed_gizmo_draw_rotate_sweep(_ed, _vp, _pivot, _ps, _ws, _hls) {
	var _sweep = _ed.giz.display_ang;
	if (abs(_sweep) <= 0.01) {
		return;
	}
	var _t0 = _ed.giz.sector_t0;
	var _draw_sweep = clamp(_sweep, -2 * pi, 2 * pi);
	var _steps = max(2, ceil(abs(_draw_sweep) / (2 * pi) * 72));
	var _arc = [];
	for (var _i = 0; _i <= _steps; _i++) {
		var _t = _t0 + _draw_sweep * (_i / _steps);
		var _sp = __gm3d_ed_world_to_screen(_vp, __gm3d_ed_gizmo_ring_point(_pivot, _ed.giz.dir, _ws, _t));
		if (_sp != undefined) {
			array_push(_arc, _sp);
		}
	}
	if (array_length(_arc) >= 2) {
		var _scol = _ed.giz.drag == 6 ? c_yellow : _hls[_ed.giz.drag];
		var _srim = merge_colour(_scol, c_white, 0.4);
		var _sfill = merge_colour(c_yellow, c_black, 0.25);
		var _laps = floor(abs(_sweep) / (2 * pi));
		var _boost = min(_laps, 4) * 0.12;
		draw_primitive_begin(pr_trianglefan);
		draw_vertex_colour(_ps[0], _ps[1], _sfill, min(0.3 + _boost, 0.85));
		for (var _f = 0; _f < array_length(_arc); _f++) {
			draw_vertex_colour(_arc[_f][0], _arc[_f][1], _sfill, min(0.3 + _boost, 0.85));
		}
		draw_primitive_end();
		draw_set_alpha(min(0.8 + _boost, 1.0));
		for (var _e = 0; _e < array_length(_arc) - 1; _e++) {
			__gm3d_ed_vp_line(_ed, _arc[_e][0], _arc[_e][1], _arc[_e + 1][0], _arc[_e + 1][1], 2, _scol);
		}
		var _start = __gm3d_ed_world_to_screen(_vp, __gm3d_ed_gizmo_ring_point(_pivot, _ed.giz.dir, _ws, _t0));
		var _current = __gm3d_ed_world_to_screen(_vp, __gm3d_ed_gizmo_ring_point(_pivot, _ed.giz.dir, _ws, _t0 + _sweep));
		if (_start != undefined) {
			__gm3d_ed_vp_line(_ed, _ps[0], _ps[1], _start[0], _start[1], 1, _srim);
		}
		if (_current != undefined) {
			__gm3d_ed_vp_line(_ed, _ps[0], _ps[1], _current[0], _current[1], 1, _srim);
		}
		draw_set_alpha(1);
	}
}

// Draws line from drag start to current pivot.
function __gm3d_ed_gizmo_draw_trail(_ed, _vp, _ps) {
	draw_set_alpha(0.7);
	__gm3d_ed_vp_line(_ed, _ed.giz.piv_sx, _ed.giz.piv_sy, _ps[0], _ps[1], 2, c_white);
	draw_set_alpha(1);
	draw_circle_color(_ed.giz.piv_sx, _ed.giz.piv_sy, 4, c_yellow, c_yellow, false);
}

// Draws 3D-style arrowhead at axis endpoint.
function __gm3d_ed_arrow(_x1, _y1, _x2, _y2, _col, _sz, _al) {
	var _dx = _x2 - _x1;
	var _dy = _y2 - _y1;
	var _l = sqrt(_dx * _dx + _dy * _dy);
	if (_l < 0.001) {
		return;
	}
	_dx /= _l;
	_dy /= _l;
	var _tx = _x2 + _dx * _sz;
	var _ty = _y2 + _dy * _sz;
	var _lx = _x2 - _dy * _sz * 0.6;
	var _ly = _y2 + _dx * _sz * 0.6;
	var _rx = _x2 + _dy * _sz * 0.6;
	var _ry = _y2 - _dx * _sz * 0.6;
	var _lc = merge_colour(_col, c_white, 0.35);
	var _dk = merge_colour(_col, c_black, 0.25);
	var _ax = _x2;
	var _ay = _y2;
	var _hx = _lx;
	var _hy = _ly;
	var _kx = _rx;
	var _ky = _ry;
	if (_ry < _ly) {
		_hx = _rx;
		_hy = _ry;
		_kx = _lx;
		_ky = _ly;
	}
	draw_set_alpha(_al);
	draw_primitive_begin(pr_trianglelist);
	draw_vertex_colour(_tx, _ty, _lc, 1);
	draw_vertex_colour(_ax, _ay, _lc, 1);
	draw_vertex_colour(_hx, _hy, _lc, 1);
	draw_vertex_colour(_tx, _ty, _dk, 1);
	draw_vertex_colour(_ax, _ay, _dk, 1);
	draw_vertex_colour(_kx, _ky, _dk, 1);
	draw_primitive_end();
	draw_set_alpha(1);
}

// Draws highlighted gizmo axis shaft line.
function __gm3d_ed_gizmo_shaft(_ed, _x1, _y1, _x2, _y2, _col, _al) {
	var _dx = _x2 - _x1;
	var _dy = _y2 - _y1;
	var _l = sqrt(_dx * _dx + _dy * _dy);
	draw_set_alpha(_al);
	__gm3d_ed_vp_line(_ed, _x1, _y1, _x2, _y2, 3, _col);
	if (_l > 0.001) {
		var _nx = -_dy / _l;
		var _ny = _dx / _l;
		if (_ny > 0) {
			_nx = -_nx;
			_ny = -_ny;
		}
		__gm3d_ed_vp_line(_ed, _x1 + _nx, _y1 + _ny, _x2 + _nx, _y2 + _ny, 1, merge_colour(_col, c_white, 0.35));
	}
	draw_set_alpha(1);
}

// Draws bounding box outline around single node.
function __gm3d_ed_draw_selbox(_node, _vp, _ed) {
	if (__gm3d_ed_hidden_get(_ed, _node)) {
		return;
	}
	var _box = __gm3d_ed_node_aabb(_node);
	if (!_box.valid) {
		return;
	}
	var _mn = _box.min;
	var _mx = _box.max;
	var _corners = [
		_mn.clone(),
		new GM3D_Vec3(_mx.x, _mn.y, _mn.z),
		new GM3D_Vec3(_mn.x, _mx.y, _mn.z),
		new GM3D_Vec3(_mx.x, _mx.y, _mn.z),
		new GM3D_Vec3(_mn.x, _mn.y, _mx.z),
		new GM3D_Vec3(_mx.x, _mn.y, _mx.z),
		new GM3D_Vec3(_mn.x, _mx.y, _mx.z),
		_mx.clone(),
	];
	var _scr = __gm3d_ed_world_corners_to_screen(_vp, _corners);
	var _edges = [
		[0, 1],
		[1, 3],
		[3, 2],
		[2, 0],
		[4, 5],
		[5, 7],
		[7, 6],
		[6, 4],
		[0, 4],
		[1, 5],
		[2, 6],
		[3, 7],
	];
	var _col = make_colour_rgb(255, 220, 80);
	draw_set_alpha(0.4);
	for (var _e = 0; _e < 12; _e++) {
		var _a = _scr[_edges[_e][0]];
		var _b = _scr[_edges[_e][1]];
		if (_a != undefined && _b != undefined) {
			__gm3d_ed_vp_line(_ed, _a[0], _a[1], _b[0], _b[1], 1.5, _col);
		}
	}
	draw_set_alpha(1);
}

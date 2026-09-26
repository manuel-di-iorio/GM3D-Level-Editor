/// @module gm3d_ed_gizmo
/// Translate/rotate/scale gizmo: hover, drag and draw.

/// World centroid of the selection, or undefined when empty.
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

/// Gizmo axes in world space, or active node frame in local mode.
function __gm3d_ed_gizmo_dirs(_ed) {
	if (_ed.giz.orient == 1 && array_length(_ed.sel) > 0) {
		return __gm3d_ed_quat_basis(_ed.sel[array_length(_ed.sel) - 1].getLocalRotation());
	}
	return [new GM3D_Vec3(1, 0, 0), GM3D_Vec3.up(), GM3D_Vec3.forward()];
}

/// World handle length for the current selection.
/// Recomputed every frame from the camera distance so the gizmo keeps a
/// constant screen size (ed.giz.size pixels): it never looks smaller from
/// far away or bigger from up close.
function __gm3d_ed_gizmo_len(_ed, _vp, _pivot) {
	return __gm3d_ed_gizmo_world_size(_vp, _pivot, _ed.giz.size);
}

/// World size matching a screen length in pixels.
function __gm3d_ed_gizmo_world_size(_vp, _pivot, _pixels) {
	var _a = __gm3d_ed_world_to_screen(_vp, _pivot);
	if (_a == undefined) {
		return 1;
	}
	var _b = __gm3d_ed_world_to_screen(
		_vp,
		new GM3D_Vec3(_pivot.x + _vp.camRight.x, _pivot.y + _vp.camRight.y, _pivot.z + _vp.camRight.z),
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

/// Converts a world-space delta to node local space.
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

/// Screen-space polyline of a rotation ring around _pivot on _axis.
function __gm3d_ed_gizmo_ring_pts(_vp, _pivot, _axis, _ws) {
	var _ref = GM3D_Vec3.up();
	if (abs(_axis.dot(_ref)) >= 0.99) {
		_ref = GM3D_Vec3.forward();
	}
	var _u = new GM3D_Vec3();
	_u.crossVectors(_axis, _ref);
	_u.normalizeSafe(0.000001);
	var _v = new GM3D_Vec3();
	_v.crossVectors(_axis, _u);
	var _world = [];
	var _seg = 36;
	for (var _i = 0; _i <= _seg; _i++) {
		var _t = (_i / _seg) * pi * 2;
		array_push(
			_world,
			new GM3D_Vec3(
				_pivot.x + (cos(_t) * _u.x + sin(_t) * _v.x) * _ws,
				_pivot.y + (cos(_t) * _u.y + sin(_t) * _v.y) * _ws,
				_pivot.z + (cos(_t) * _u.z + sin(_t) * _v.z) * _ws,
			),
		);
	}
	var _mapped = __gm3d_ed_world_corners_to_screen(_vp, _world);
	var _pts = [];
	for (var _j = 0; _j < array_length(_mapped); _j++) {
		if (_mapped[_j] != undefined) {
			array_push(_pts, _mapped[_j]);
		}
	}
	return _pts;
}

/// Normalized pivot-to-camera vector, or undefined when unavailable.
function __gm3d_ed_gizmo_cam_view(_vp, _pivot) {
	if (_vp == undefined || _vp.camNode == undefined || _pivot == undefined) {
		return undefined;
	}
	var _cp = _vp.camNode.getWorldPosition();
	var _view = new GM3D_Vec3(_cp.x - _pivot.x, _cp.y - _pivot.y, _cp.z - _pivot.z);
	_view.normalizeSafe(0.000001);
	return _view;
}

/// Quad corners of the translate plane opposite one axis.
/// Each span arm is flipped toward the camera (like UeTransformControls
/// _getAxisVector) so the quad always sits in the camera-facing octant.
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

/// Finds the gizmo handle under the mouse.
/// @return {Real} Axis 0-2, plane 3-5, view ring 6, -2 center, -1 none
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
		// Quad priority over axes: exact hits first (best = largest screen
		// area, i.e. most facing the camera), then a small padded border so
		// edge clicks near an axis shaft still grab the quad.
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
		// Padded border pass: still quad priority over the 20px axis grab.
		var _pad2 = 36.0; // 6px squared
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
	var _bestD = 400.0; // 20px squared axis grab distance
	for (var _a = 0; _a < 3; _a++) {
		var _d;
		if (_ed.giz.tool == Gm3dEdTool.Rotate) {
			_d = __gm3d_ed_point_polyline_dist2(_mx, _my, __gm3d_ed_gizmo_ring_pts(_vp, _pivot, _dirs[_a], _ws));
		} else {
			var _e = __gm3d_ed_world_to_screen(
				_vp,
				new GM3D_Vec3(_pivot.x + _dirs[_a].x * _ws, _pivot.y + _dirs[_a].y * _ws, _pivot.z + _dirs[_a].z * _ws),
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
		var _rd = __gm3d_ed_point_polyline_dist2(_mx, _my, __gm3d_ed_gizmo_ring_pts(_vp, _pivot, _look, _ws));
		if (_rd < _bestD) {
			_best = 6;
		}
	}
	return _best;
}

/// Captures drag state and history snapshot when a drag starts.
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
	if (_ps == undefined) {
		_ps = [_mx, _my];
	}
	_g.piv_sx = _ps[0];
	_g.piv_sy = _ps[1];
	_g.last_ang = arctan2(_my - _ps[1], _mx - _ps[0]);
	_g.total_ang = 0;
	_g.sector_a0 = _g.last_ang;
}

/// Applies the active gizmo drag (translate / scale / rotate) to the selection.
function __gm3d_ed_gizmo_drag(_ed, _vp, _mx, _my) {
	var _g = _ed.giz;
	var _ray = __gm3d_ed_screen_ray(_vp, _mx, _my);
	if (_g.tool == Gm3dEdTool.Translate) {
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
	} else if (_g.tool == Gm3dEdTool.Scale) {
		var _f = 1.0;
		if (_g.center) {
			var _dx0 = _g.mx0 - _g.piv_sx;
			var _dy0 = _g.my0 - _g.piv_sy;
			var _dx1 = _mx - _g.piv_sx;
			var _dy1 = _my - _g.piv_sy;
			_f = 1.0 + (sqrt(_dx1 * _dx1 + _dy1 * _dy1) - sqrt(_dx0 * _dx0 + _dy0 * _dy0)) / _g.size;
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
	} else if (_g.tool == Gm3dEdTool.Rotate) {
		var _ang = arctan2(_my - _g.piv_sy, _mx - _g.piv_sx);
		var _dd = _ang - _g.last_ang;
		_dd = arctan2(sin(_dd), cos(_dd));
		_g.total_ang -= _dd;
		_g.last_ang = _ang;
		var _deg = radtodeg(_g.total_ang);
		var _sr = _ed.snap_on || keyboard_check(vk_control) ? _ed.snap_rot : 0;
		if (_sr > 0) {
			_deg = __gm3d_ed_snap(_deg, _sr);
		}
		var _ax2 = _g.center ? 1 : _g.axis_idx;
		var _axis = _g.drag == 6 ? _g.dir : __gm3d_ed_gizmo_dirs(_ed)[_ax2];
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

/// Draws selection boxes plus the active tool gizmo (handles + center).
function __gm3d_ed_gizmo_draw(_ed, _vp) {
	var _cols = [c_red, c_lime, c_blue];
	var _hls = [make_colour_rgb(255, 150, 60), make_colour_rgb(255, 255, 120), make_colour_rgb(110, 200, 255)];
	__gm3d_ed_gizmo_draw_selboxes(_ed, _vp);
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

/// Draws selection boxes for all selected nodes.
function __gm3d_ed_gizmo_draw_selboxes(_ed, _vp) {
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		__gm3d_ed_draw_selbox(_ed.sel[_i], _vp, _ed);
	}
}

/// Draws translate plane quads.
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

/// Draws axes for translate/scale and rings for rotate.
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
				new GM3D_Vec3(_pivot.x + _dirs[_a].x * _ws, _pivot.y + _dirs[_a].y * _ws, _pivot.z + _dirs[_a].z * _ws),
			);
			if (_e == undefined) {
				continue;
			}
			__gm3d_ed_gizmo_shaft(_ed, _ps[0], _ps[1], _e[0], _e[1], _bcol, _al);
			__gm3d_ed_arrow(_ps[0], _ps[1], _e[0], _e[1], _bcol, _hov ? 12 : 9, _al);
		} else if (_ed.giz.tool == Gm3dEdTool.Scale) {
			var _e2 = __gm3d_ed_world_to_screen(
				_vp,
				new GM3D_Vec3(_pivot.x + _dirs[_a].x * _ws, _pivot.y + _dirs[_a].y * _ws, _pivot.z + _dirs[_a].z * _ws),
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
			var _pts = __gm3d_ed_gizmo_ring_pts(_vp, _pivot, _dirs[_a], _ws);
			var _th = _ed.giz.hover == _a || _ed.giz.drag == _a ? 3 : 2;
			draw_set_alpha(_al);
			for (var _p = 0; _p < array_length(_pts) - 1; _p++) {
				__gm3d_ed_vp_line(_ed, _pts[_p][0], _pts[_p][1], _pts[_p + 1][0], _pts[_p + 1][1], _th, _bcol);
			}
			draw_set_alpha(1);
		}
	}
}

/// Draws the view-plane ring for rotate.
function __gm3d_ed_gizmo_draw_viewring(_ed, _vp, _pivot, _look, _ws) {
	if (_ed.giz.tool == Gm3dEdTool.Rotate) {
		var _vpts = __gm3d_ed_gizmo_ring_pts(_vp, _pivot, _look, _ws);
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

/// Draws the center handle for translate/scale.
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
				_brim,
			);
		}
		draw_set_alpha(1);
	}
}

/// Draws the rotate-drag sweep sector.
function __gm3d_ed_gizmo_draw_rotate_sweep(_ed, _vp, _pivot, _ps, _ws, _hls) {
	// Screen atan2 is y-down, so the mouse sweeps a0 -> a0 - total while
	// the model takes +total: negate to follow the visible drag.
	var _sweep = -_ed.giz.total_ang;
	if (abs(_sweep) > 0.01) {
		var _spts = __gm3d_ed_gizmo_ring_pts(_vp, _pivot, _ed.giz.dir, _ws);
		var _a0 = _ed.giz.sector_a0;
		var _full = abs(_sweep) >= 2 * pi;
		var _in = [];
		for (var _si = 0; _si < array_length(_spts); _si++) {
			var _ang = arctan2(_spts[_si][1] - _ps[1], _spts[_si][0] - _ps[0]) - _a0;
			var _rel = arctan2(sin(_ang), cos(_ang));
			var _hit = _full;
			if (!_hit) {
				if (_sweep > 0) {
					_hit = (_rel >= 0 && _rel <= _sweep) || (_sweep > pi && _sweep < 2 * pi && _rel <= _sweep - 2 * pi);
				} else {
					_hit = (_rel <= 0 && _rel >= _sweep) || (_sweep < -pi && _sweep > -2 * pi && _rel >= _sweep + 2 * pi);
				}
			}
			if (_hit) {
				var _ord = _rel;
				if (_sweep > 0 && _rel < 0) {
					_ord = _rel + 2 * pi;
				} else if (_sweep < 0 && _rel > 0) {
					_ord = _rel - 2 * pi;
				}
				array_push(_in, { r: _ord, p: _spts[_si] });
			}
		}
		__gm3d_ed_sort_by_field(_in, "r", _sweep > 0);
		if (array_length(_in) >= 2) {
			var _scol = _ed.giz.drag == 6 ? c_yellow : _hls[_ed.giz.drag];
			draw_primitive_begin(pr_trianglefan);
			draw_vertex_colour(_ps[0], _ps[1], _scol, 0.3);
			for (var _f2 = 0; _f2 < array_length(_in); _f2++) {
				draw_vertex_colour(_in[_f2].p[0], _in[_f2].p[1], _scol, 0.3);
			}
			draw_primitive_end();
			draw_set_alpha(0.8);
			for (var _e2 = 0; _e2 < array_length(_in) - 1; _e2++) {
				__gm3d_ed_vp_line(_ed, _in[_e2].p[0], _in[_e2].p[1], _in[_e2 + 1].p[0], _in[_e2 + 1].p[1], 2, _scol);
			}
			draw_set_alpha(1);
			var _ph = floor(_ed.giz.total_ang / (pi / 12));
			for (var _e3 = 0; _e3 < array_length(_in) - 1; _e3++) {
				if ((((_e3 + _ph) mod 12) + 12) mod 12 < 6) {
					continue;
				}
				__gm3d_ed_vp_line(_ed, _in[_e3].p[0], _in[_e3].p[1], _in[_e3 + 1].p[0], _in[_e3 + 1].p[1], 2, c_white);
			}
			var _turns = floor(abs(_ed.giz.total_ang) / (2 * pi));
			if (_turns > 0) {
				var _dx0 = _in[0].p[0] - _ps[0];
				var _dy0 = _in[0].p[1] - _ps[1];
				var _dl = sqrt(_dx0 * _dx0 + _dy0 * _dy0);
				if (_dl > 1) {
					_dx0 /= _dl;
					_dy0 /= _dl;
					var _tn = min(_turns, 5);
					for (var _td = 1; _td <= _tn; _td++) {
						draw_circle_color(
							_ps[0] + _dx0 * (_dl + _td * 9),
							_ps[1] + _dy0 * (_dl + _td * 9),
							3,
							c_yellow,
							c_yellow,
							false,
						);
					}
				}
			}
		}
	}
}

/// Draws the translate-drag trail.
function __gm3d_ed_gizmo_draw_trail(_ed, _vp, _ps) {
	draw_set_alpha(0.7);
	__gm3d_ed_vp_line(_ed, _ed.giz.piv_sx, _ed.giz.piv_sy, _ps[0], _ps[1], 2, c_white);
	draw_set_alpha(1);
	draw_circle_color(_ed.giz.piv_sx, _ed.giz.piv_sy, 4, c_yellow, c_yellow, false);
}

/// Draws a translate-handle arrowhead.
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

/// Draws a gizmo axis shaft.
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

/// Draws the projected world-space bounding box of a selected node.
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

/// ---- Unity-style 2D overlay for lights / cameras / environment ----
/// Icons, direction arrows, range circles, spot cones and camera frustums are
/// projected with world_to_screen and drawn in Draw GUI over the scene, like
/// Unity does. Overdraw through models is accepted (editor convention).

/// Draws one world segment, clipped to the near plane and the screen rect so
/// its screen direction stays exact even when the ends leave the view.
function __gm3d_ed_overlay_seg(_ed, _vp, _a, _b, _wd, _col) {
	var _eps = 0.001;
	var _ca = new GM3D_Vec4(_a.x, _a.y, _a.z, 1.0);
	_ca.applyMatrix4(_vp.viewProj);
	var _cb = new GM3D_Vec4(_b.x, _b.y, _b.z, 1.0);
	_cb.applyMatrix4(_vp.viewProj);
	var _ain = _ca.w >= _eps;
	var _bin = _cb.w >= _eps;
	// Fully behind the camera: nothing correct to draw.
	if (!_ain && !_bin) {
		return;
	}
	var _pa = _a;
	var _pb = _b;
	if (!_ain || !_bin) {
		// Clip against the near plane: cross parameter from A toward B.
		var _t = (_eps - _ca.w) / (_cb.w - _ca.w);
		var _cross = new GM3D_Vec3(_a.x + (_b.x - _a.x) * _t, _a.y + (_b.y - _a.y) * _t, _a.z + (_b.z - _a.z) * _t);
		if (!_ain) {
			_pa = _cross;
		} else {
			_pb = _cross;
		}
	}
	var _sa = __gm3d_ed_overlay_project(_vp, _pa);
	var _sb = __gm3d_ed_overlay_project(_vp, _pb);
	if (_sa == undefined || _sb == undefined) {
		return;
	}
	var _cl = __gm3d_ed_clip_seg(_sa[0], _sa[1], _sb[0], _sb[1], _vp.winW, _vp.winH);
	if (_cl == undefined) {
		return;
	}
	__gm3d_ed_vp_line(_ed, _cl[0], _cl[1], _cl[2], _cl[3], _wd, _col);
}

/// Projects a world point to screen without frustum culling, so clipped lines
/// keep their true direction. Returns undefined only behind the camera.
function __gm3d_ed_overlay_project(_vp, _p) {
	var _v = new GM3D_Vec4(_p.x, _p.y, _p.z, 1.0);
	_v.applyMatrix4(_vp.viewProj);
	if (_v.w <= 0.0001) {
		return undefined;
	}
	var _nx = _v.x / _v.w;
	var _ny = _v.y / _v.w;
	var _sx = (_nx * 0.5 + 0.5) * _vp.winW;
	var _sy = 0;
	if (_vp.ndc_yup) {
		_sy = (1.0 - (_ny * 0.5 + 0.5)) * _vp.winH;
	} else {
		_sy = (_ny * 0.5 + 0.5) * _vp.winH;
	}
	return [_sx, _sy];
}

/// Outcode of a screen point against [0, _w] x [0, _h]: 1 left, 2 right,
//  4 top, 8 bottom.
function __gm3d_ed_outcode(_x, _y, _w, _h) {
	var _c = 0;
	if (_x < 0) {
		_c |= 1;
	} else if (_x > _w) {
		_c |= 2;
	}
	if (_y < 0) {
		_c |= 4;
	} else if (_y > _h) {
		_c |= 8;
	}
	return _c;
}

/// Cohen-Sutherland clip of a 2D segment against [0, _w] x [0, _h].
/// @return [x0, y0, x1, y1] or undefined when fully outside.
function __gm3d_ed_clip_seg(_x0, _y0, _x1, _y1, _w, _h) {
	var _c0 = __gm3d_ed_outcode(_x0, _y0, _w, _h);
	var _c1 = __gm3d_ed_outcode(_x1, _y1, _w, _h);
	var _guard = 0;
	while (_guard < 8) {
		_guard++;
		if ((_c0 | _c1) == 0) {
			return [_x0, _y0, _x1, _y1];
		}
		if ((_c0 & _c1) != 0) {
			return undefined;
		}
		var _cc = _c0;
		if (_cc == 0) {
			_cc = _c1;
		}
		var _cx = _x0;
		var _cy = _y0;
		if ((_cc & 1) != 0) {
			_cy = _y0 + (_y1 - _y0) * (0 - _x0) / (_x1 - _x0);
			_cx = 0;
		} else if ((_cc & 2) != 0) {
			_cy = _y0 + (_y1 - _y0) * (_w - _x0) / (_x1 - _x0);
			_cx = _w;
		} else if ((_cc & 4) != 0) {
			_cx = _x0 + (_x1 - _x0) * (0 - _y0) / (_y1 - _y0);
			_cy = 0;
		} else {
			_cx = _x0 + (_x1 - _x0) * (_h - _y0) / (_y1 - _y0);
			_cy = _h;
		}
		if (_cc == _c0) {
			_x0 = _cx;
			_y0 = _cy;
			_c0 = __gm3d_ed_outcode(_x0, _y0, _w, _h);
		} else {
			_x1 = _cx;
			_y1 = _cy;
			_c1 = __gm3d_ed_outcode(_x1, _y1, _w, _h);
		}
	}
	return [_x0, _y0, _x1, _y1];
}

/// Draws a diamond icon plus label for a prop node.
function __gm3d_ed_overlay_icon(_ed, _sp, _label, _col, _sel) {
	var _c = _sel ? make_colour_rgb(255, 220, 80) : _col;
	var _r = 9;
	if (_sel) {
		draw_primitive_begin(pr_trianglefan);
		draw_vertex_colour(_sp[0], _sp[1] - _r, _c, 0.85);
		draw_vertex_colour(_sp[0] + _r, _sp[1], _c, 0.85);
		draw_vertex_colour(_sp[0], _sp[1] + _r, _c, 0.85);
		draw_vertex_colour(_sp[0] - _r, _sp[1], _c, 0.85);
		draw_primitive_end();
	}
	draw_line_width_color(_sp[0], _sp[1] - _r, _sp[0] + _r, _sp[1], 2, _c, _c);
	draw_line_width_color(_sp[0] + _r, _sp[1], _sp[0], _sp[1] + _r, 2, _c, _c);
	draw_line_width_color(_sp[0], _sp[1] + _r, _sp[0] - _r, _sp[1], 2, _c, _c);
	draw_line_width_color(_sp[0] - _r, _sp[1], _sp[0], _sp[1] - _r, 2, _c, _c);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_color(c_black);
	draw_text(_sp[0] + 13, _sp[1] - 7, _label);
	draw_set_color(c_white);
	draw_text(_sp[0] + 12, _sp[1] - 8, _label);
}

/// Draws an arrowhead at screen tip _e along screen dir (_dx, _dy) normalized.
function __gm3d_ed_overlay_head(_e, _dx, _dy, _col) {
	var _hl = 10;
	var _cs = 0.906;
	var _sn = 0.423;
	var _lx = _e[0] - (_dx * _cs - _dy * _sn) * _hl;
	var _ly = _e[1] - (_dx * _sn + _dy * _cs) * _hl;
	var _rx = _e[0] - (_dx * _cs + _dy * _sn) * _hl;
	var _ry = _e[1] - (-_dx * _sn + _dy * _cs) * _hl;
	draw_line_width_color(_e[0], _e[1], _lx, _ly, 2, _col, _col);
	draw_line_width_color(_e[0], _e[1], _rx, _ry, 2, _col, _col);
}

/// Overlay pass for every tracked light, camera and environment node.
function __gm3d_ed_overlay_draw(_ed, _vp) {
	var _roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		var _nd = _roots[_i];
		var _kind = __gm3d_ed_kind_of(_ed, _nd);
		if (_kind != "light" && _kind != "camera" && _kind != "environment") {
			continue;
		}
		if (__gm3d_ed_hidden_get(_ed, _nd)) {
			continue;
		}
		var _wp = _nd.getWorldPosition();
		// The icon needs the center on screen, but the frustum/cone/box
		// edges clip on their own: draw them even when the center is out of
		// view (e.g. viewport camera right next to the node).
		var _sp = __gm3d_ed_world_to_screen(_vp, _wp);
		var _sel = __gm3d_ed_sel_has(_ed, _nd);
		var _en = __gm3d_ed_registry_find(_ed, _nd);
		var _lb = __gm3d_ed_label_get(_ed, _nd);
		if (_kind == "light") {
			__gm3d_ed_overlay_light(_ed, _vp, _nd, _en, _wp, _sp, _lb, _sel);
		} else if (_kind == "camera") {
			__gm3d_ed_overlay_camera(_ed, _vp, _nd, _en, _wp, _sp, _lb, _sel);
		} else {
			__gm3d_ed_overlay_env(_ed, _vp, _nd, _en, _wp, _sp, _lb, _sel);
		}
	}
	draw_set_alpha(1);
	draw_set_color(c_white);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}

/// Overlay for one light node: icon, direction arrow, range circle, spot cone.
/// GM3D lights emit along -Z of the node (opposite getWorldForward), so every
/// direction glyph extends along minus forward.
function __gm3d_ed_overlay_light(_ed, _vp, _nd, _en, _wp, _sp, _lb, _sel) {
	var _col = make_colour_rgb(255, 190, 80);
	if (_sel) {
		_col = make_colour_rgb(255, 220, 80);
	}
	var _d = (_en != undefined && is_struct(_en.data)) ? _en.data : __gm3d_ed_light_defaults();
	var _fw = _nd.getWorldForward();
	var _fl = sqrt(_fw.x * _fw.x + _fw.y * _fw.y + _fw.z * _fw.z);
	if (_fl > 0.0001) {
		_fw = new GM3D_Vec3(-_fw.x / _fl, -_fw.y / _fl, -_fw.z / _fl);
	} else {
		_fw = new GM3D_Vec3(0, 0, -1);
	}
	if (_d.type == "directional") {
		var _tip = new GM3D_Vec3(_wp.x + _fw.x * 1.5, _wp.y + _fw.y * 1.5, _wp.z + _fw.z * 1.5);
		__gm3d_ed_overlay_seg(_ed, _vp, _wp, _tip, 2, _col);
		var _se = __gm3d_ed_overlay_project(_vp, _tip);
		if (_se != undefined && _sp != undefined) {
			var _dx = _se[0] - _sp[0];
			var _dy = _se[1] - _sp[1];
			var _l = sqrt(_dx * _dx + _dy * _dy);
			if (_l > 4) {
				__gm3d_ed_overlay_head(_se, _dx / _l, _dy / _l, _col);
			}
		}
	} else {
		var _ws = __gm3d_ed_gizmo_world_size(_vp, _wp, 120);
		var _px = (_ws > 0.0001 ? _d.range / _ws : 0) * 120;
		if (_sp != undefined && _d.range > 0 && _px >= 4) {
			draw_set_alpha(0.7);
			draw_circle(_sp[0], _sp[1], min(_px, 600), true);
			draw_set_alpha(1);
		}
		if (_d.type == "spot") {
			var _len = max(_d.range, 0.5);
			var _ctr = new GM3D_Vec3(_wp.x + _fw.x * _len, _wp.y + _fw.y * _len, _wp.z + _fw.z * _len);
			var _rr = tan(degtorad(clamp(_d.outer, 1, 89))) * _len;
			var _up = GM3D_Vec3.up();
			var _u = new GM3D_Vec3();
			_u.crossVectors(_fw, _up);
			if (_u.x * _u.x + _u.y * _u.y + _u.z * _u.z < 0.000001) {
				_u = new GM3D_Vec3(1, 0, 0);
			} else {
				_u.normalizeSafe(0.000001);
			}
			var _v = new GM3D_Vec3();
			_v.crossVectors(_fw, _u);
			var _rim = [];
			for (var _k = 0; _k <= 12; _k++) {
				var _t = (_k / 12) * pi * 2;
				array_push(
					_rim,
					new GM3D_Vec3(
						_ctr.x + (cos(_t) * _u.x + sin(_t) * _v.x) * _rr,
						_ctr.y + (cos(_t) * _u.y + sin(_t) * _v.y) * _rr,
						_ctr.z + (cos(_t) * _u.z + sin(_t) * _v.z) * _rr,
					),
				);
			}
			for (var _e2 = 0; _e2 < 12; _e2++) {
				__gm3d_ed_overlay_seg(_ed, _vp, _rim[_e2], _rim[_e2 + 1], 1.5, _col);
			}
			var _spokes = [
				new GM3D_Vec3(_ctr.x + _u.x * _rr, _ctr.y + _u.y * _rr, _ctr.z + _u.z * _rr),
				new GM3D_Vec3(_ctr.x - _u.x * _rr, _ctr.y - _u.y * _rr, _ctr.z - _u.z * _rr),
				new GM3D_Vec3(_ctr.x + _v.x * _rr, _ctr.y + _v.y * _rr, _ctr.z + _v.z * _rr),
				new GM3D_Vec3(_ctr.x - _v.x * _rr, _ctr.y - _v.y * _rr, _ctr.z - _v.z * _rr),
			];
			for (var _q = 0; _q < 4; _q++) {
				__gm3d_ed_overlay_seg(_ed, _vp, _wp, _spokes[_q], 1.5, _col);
			}
		}
	}
	if (_sp != undefined) {
		__gm3d_ed_overlay_icon(_ed, _sp, _lb, _col, _sel);
	}
}

/// Overlay for one camera node: icon plus frustum wireframe.
/// GM3D cameras view along -Z of the node (opposite getWorldForward), like
/// the editor fly camera in __gm3d_ed_view_forward usage.
function __gm3d_ed_overlay_camera(_ed, _vp, _nd, _en, _wp, _sp, _lb, _sel) {
	var _col = make_colour_rgb(100, 220, 255);
	if (_sel) {
		_col = make_colour_rgb(255, 220, 80);
	}
	var _d = (_en != undefined && is_struct(_en.data)) ? _en.data : __gm3d_ed_camera_defaults();
	var _fw0 = _nd.getWorldForward();
	var _fl0 = sqrt(_fw0.x * _fw0.x + _fw0.y * _fw0.y + _fw0.z * _fw0.z);
	var _fw = new GM3D_Vec3(0, 0, -1);
	if (_fl0 > 0.0001) {
		_fw = new GM3D_Vec3(-_fw0.x / _fl0, -_fw0.y / _fl0, -_fw0.z / _fl0);
	}
	var _rt = _nd.getWorldRight();
	var _up = _nd.getWorldUp();
	var _nd0 = max(_d.near, 0.05);
	// Far plane drawn at the real far distance so the Inspector value is
	// visible: huge values just run the edges off-screen (clipped exactly).
	var _ld = max(_d.far, _nd0 + 0.01);
	var _hw0 = 0.5;
	var _hh0 = 0.5;
	var _hw1 = 1.0;
	var _hh1 = 1.0;
	if (_d.projection == "ortho") {
		_hw0 = max(_d.ow, 0.01) * 0.5;
		_hh0 = max(_d.oh, 0.01) * 0.5;
		_hw1 = _hw0;
		_hh1 = _hh0;
	} else {
		var _aspect = _vp.winW / max(_vp.winH, 1);
		var _t = tan(degtorad(clamp(_d.fov, 1, 179)) * 0.5);
		_hh0 = _t * _nd0;
		_hw0 = _hh0 * _aspect;
		_hh1 = _t * _ld;
		_hw1 = _hh1 * _aspect;
	}
	var _cn = new GM3D_Vec3(_wp.x + _fw.x * _nd0, _wp.y + _fw.y * _nd0, _wp.z + _fw.z * _nd0);
	var _cf = new GM3D_Vec3(_wp.x + _fw.x * _ld, _wp.y + _fw.y * _ld, _wp.z + _fw.z * _ld);
	var _corners = [];
	for (var _k = 0; _k < 8; _k++) {
		var _far = _k >= 4;
		var _sx = (_k mod 4 == 0 || _k mod 4 == 3) ? -1 : 1;
		var _sy = (_k mod 4 < 2) ? -1 : 1;
		var _base = _far ? _cf : _cn;
		var _hx = _far ? _hw1 : _hw0;
		var _hy = _far ? _hh1 : _hh0;
		array_push(
			_corners,
			new GM3D_Vec3(
				_base.x + _rt.x * _hx * _sx + _up.x * _hy * _sy,
				_base.y + _rt.y * _hx * _sx + _up.y * _hy * _sy,
				_base.z + _rt.z * _hx * _sx + _up.z * _hy * _sy,
			),
		);
	}
	var _edges = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]];
	for (var _e = 0; _e < 12; _e++) {
		__gm3d_ed_overlay_seg(_ed, _vp, _corners[_edges[_e][0]], _corners[_edges[_e][1]], 1.5, _col);
	}
	__gm3d_ed_overlay_seg(_ed, _vp, _wp, _cn, 1.5, _col);
	if (_sp != undefined) {
		__gm3d_ed_overlay_icon(_ed, _sp, _lb, _col, _sel);
	}
}

/// Overlay for the environment node: icon, plus size box when selected.
function __gm3d_ed_overlay_env(_ed, _vp, _nd, _en, _wp, _sp, _lb, _sel) {
	var _col = make_colour_rgb(150, 190, 150);
	if (_sel) {
		_col = make_colour_rgb(255, 220, 80);
	}
	if (_sel) {
		var _d = (_en != undefined && is_struct(_en.data)) ? _en.data : __gm3d_ed_env_defaults();
		var _hx = _d.size[0] * 0.5;
		var _hy = _d.size[1] * 0.5;
		var _hz = _d.size[2] * 0.5;
		var _corners = [
			new GM3D_Vec3(_wp.x - _hx, _wp.y - _hy, _wp.z - _hz),
			new GM3D_Vec3(_wp.x + _hx, _wp.y - _hy, _wp.z - _hz),
			new GM3D_Vec3(_wp.x - _hx, _wp.y + _hy, _wp.z - _hz),
			new GM3D_Vec3(_wp.x + _hx, _wp.y + _hy, _wp.z - _hz),
			new GM3D_Vec3(_wp.x - _hx, _wp.y - _hy, _wp.z + _hz),
			new GM3D_Vec3(_wp.x + _hx, _wp.y - _hy, _wp.z + _hz),
			new GM3D_Vec3(_wp.x - _hx, _wp.y + _hy, _wp.z + _hz),
			new GM3D_Vec3(_wp.x + _hx, _wp.y + _hy, _wp.z + _hz),
		];
		var _edges = [[0, 1], [1, 3], [3, 2], [2, 0], [4, 5], [5, 7], [7, 6], [6, 4], [0, 4], [1, 5], [2, 6], [3, 7]];
		draw_set_alpha(0.5);
		for (var _e = 0; _e < 12; _e++) {
			__gm3d_ed_overlay_seg(_ed, _vp, _corners[_edges[_e][0]], _corners[_edges[_e][1]], 1, _col);
		}
		draw_set_alpha(1);
	}
	if (_sp != undefined) {
		__gm3d_ed_overlay_icon(_ed, _sp, _lb, _col, _sel);
	}
}

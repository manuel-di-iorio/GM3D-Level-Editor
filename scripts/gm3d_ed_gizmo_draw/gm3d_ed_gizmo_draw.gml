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
		var _laps = floor(abs(_sweep) / (2 * pi));
		var _boost = min(_laps, 4) * 0.12;
		var _sfill_bg = merge_colour(c_yellow, c_black, min(0.25 + _laps * 0.1, 0.55));
		var _bg_al = min(0.3 + _boost * 0.5, 0.55);
		draw_primitive_begin(pr_trianglefan);
		draw_vertex_colour(_ps[0], _ps[1], _sfill_bg, _bg_al);
		for (var _f = 0; _f < array_length(_arc); _f++) {
			draw_vertex_colour(_arc[_f][0], _arc[_f][1], _sfill_bg, _bg_al);
		}
		draw_primitive_end();
		if (_laps >= 1) {
			var _sign = _sweep >= 0 ? 1 : -1;
			var _rem = _sweep - _sign * _laps * 2 * pi;
			if (abs(_rem) > 0.01) {
				var _sfill_tri = merge_colour(c_yellow, c_black, min(0.25 + _laps * 0.15, 0.7));
				var _tri_al = min(0.3 + _boost, 0.85);
				var _tsteps = max(2, ceil(abs(_rem) / (2 * pi) * 72));
				draw_primitive_begin(pr_trianglefan);
				draw_vertex_colour(_ps[0], _ps[1], _sfill_tri, _tri_al);
				for (var _ti = 0; _ti <= _tsteps; _ti++) {
					var _tt = _t0 + _rem * (_ti / _tsteps);
					var _tp = __gm3d_ed_world_to_screen(_vp, __gm3d_ed_gizmo_ring_point(_pivot, _ed.giz.dir, _ws, _tt));
					if (_tp != undefined) {
						draw_vertex_colour(_tp[0], _tp[1], _sfill_tri, _tri_al);
					}
				}
				draw_primitive_end();
			}
		}
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

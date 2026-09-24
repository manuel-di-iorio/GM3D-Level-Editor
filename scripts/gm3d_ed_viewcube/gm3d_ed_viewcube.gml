/// @module gm3d_ed_viewcube
/// Orientation cube: picking and drawing.

/// Builds orientation cube geometry in screen space.
function __gm3d_ed_viewcube(_ed) {
	if (_ed.rt == undefined || _ed.rt.cam == undefined) {
		return undefined;
	}
	if (_ed.gw <= 0 || _ed.gh <= 0) {
		return undefined;
	}
	var _cx = _ed.gw - _ed.cube_off[0];
	var _cy = _ed.cube_off[1];
	var _R = 10;
	var _qb = __gm3d_ed_quat_basis(_ed.rt.cam.getLocalRotation());
	var _rr = _qb[0];
	var _uu = _qb[1];
	var _f = __gm3d_ed_view_forward(_ed);
	var _axes = [
		[1, 0, 0],
		[0, 1, 0],
		[0, 0, 1],
	];
	var _ex = [];
	for (var _ea = 0; _ea < 3; _ea++) {
		var _ewa = _axes[_ea];
		array_push(_ex, [
			_ewa[0] * _rr.x + _ewa[1] * _rr.y + _ewa[2] * _rr.z,
			-(_ewa[0] * _uu.x + _ewa[1] * _uu.y + _ewa[2] * _uu.z),
		]);
	}
	var _corners = [];
	for (var _ci = 0; _ci < 8; _ci++) {
		var _sx = (_ci & 1) > 0 ? 1 : -1;
		var _sy = (_ci & 2) > 0 ? 1 : -1;
		var _sz = (_ci & 4) > 0 ? 1 : -1;
		array_push(_corners, [
			_cx + _R * (_sx * _ex[0][0] + _sy * _ex[1][0] + _sz * _ex[2][0]),
			_cy + _R * (_sx * _ex[0][1] + _sy * _ex[1][1] + _sz * _ex[2][1]),
		]);
	}
	var _faces = [];
	for (var _a = 0; _a < 3; _a++) {
		var _ax = _axes[_a];
		for (var _si = 0; _si < 2; _si++) {
			var _s = _si == 0 ? 1 : -1;
			var _ct;
			var _cb;
			if (_a == 1) {
				_ct = 245;
				_cb = _s > 0 ? 245 : 140;
			} else if (_a == 0) {
				_ct = _s > 0 ? 232 : 222;
				_cb = _s > 0 ? 162 : 152;
			} else {
				_ct = _s > 0 ? 200 : 190;
				_cb = _s > 0 ? 130 : 120;
			}
			array_push(_faces, {
				a: _a,
				s: _s,
				facing: _ax[0] * _s * _f.x + _ax[1] * _s * _f.y + _ax[2] * _s * _f.z,
				n: new GM3D_Vec3(_ax[0] * _s, _ax[1] * _s, _ax[2] * _s),
				idx: __gm3d_ed_cube_face_idx(_a, _s),
				ct: make_colour_rgb(_ct, _ct, _ct),
				cb: make_colour_rgb(_cb, _cb, _cb),
			});
		}
	}
	var _cone_lc = [make_colour_rgb(235, 90, 90), make_colour_rgb(110, 220, 110), make_colour_rgb(110, 150, 245)];
	var _cone_dk = [make_colour_rgb(150, 45, 45), make_colour_rgb(45, 140, 45), make_colour_rgb(45, 70, 160)];
	var _cone_len = 18;
	var _cone_rb = 6;
	var _cones = [];
	for (var _g = 0; _g < 3; _g++) {
		for (var _qi = 0; _qi < 2; _qi++) {
			var _q = _qi == 0 ? 1 : -1;
			var _gx = _axes[_g];
			var _px = _ex[_g][0] * _q;
			var _py = _ex[_g][1] * _q;
			var _cc = {
				a: _g,
				s: _q,
				facing: _gx[0] * _q * _f.x + _gx[1] * _q * _f.y + _gx[2] * _q * _f.z,
				front: false,
				disk: false,
				dx: 0,
				dy: 0,
				n: new GM3D_Vec3(_gx[0] * _q, _gx[1] * _q, _gx[2] * _q),
				lcol: _cone_lc[_g],
				dcol: _cone_dk[_g],
				r: _cone_rb,
			};
			_cc.front = _cc.facing > 0.08;
			var _pl = sqrt(_px * _px + _py * _py);
			if (_pl < 0.25) {
				_cc.disk = true;
				_cc.c = [_cx + (_R + _cone_len) * _px, _cy + (_R + _cone_len) * _py];
			} else {
				var _dx = _px / _pl;
				var _dy = _py / _pl;
				_cc.dx = _dx;
				_cc.dy = _dy;
				var _axx = _cx + _R * 0.9 * _px;
				var _ayy = _cy + _R * 0.9 * _py;
				_cc.apex = [_axx, _ayy];
				var _fx = _cx + (_R + _cone_len) * _px;
				var _fy = _cy + (_R + _cone_len) * _py;
				_cc.fc = [_fx, _fy];
				var _ux = -_dy;
				var _uy = _dx;
				var _aa = _cone_rb;
				var _bb = _cone_rb * abs(_cc.facing);
				var _t1x = _fx + _ux * _aa;
				var _t1y = _fy + _uy * _aa;
				var _t2x = _fx - _ux * _aa;
				var _t2y = _fy - _uy * _aa;
				if (_bb >= 1.5) {
					var _u0 = (_axx - _fx) * _ux + (_ayy - _fy) * _uy;
					var _v0 = (_axx - _fx) * _dx + (_ayy - _fy) * _dy;
					var _pp = _u0 / (_aa * _aa);
					var _qq = _v0 / (_bb * _bb);
					var _qa2 = 1 / (_aa * _aa) + (_pp * _pp) / (_qq * _qq * _bb * _bb);
					var _qb2 = (-2 * _pp) / (_qq * _qq * _bb * _bb);
					var _qc2 = 1 / (_qq * _qq * _bb * _bb) - 1;
					var _dd = _qb2 * _qb2 - 4 * _qa2 * _qc2;
					if (_dd > 0 && abs(_qq) > 0.000001) {
						var _sq = sqrt(_dd);
						var _ru1 = (-_qb2 + _sq) / (2 * _qa2);
						var _ru2 = (-_qb2 - _sq) / (2 * _qa2);
						var _rv1 = (1 - _pp * _ru1) / _qq;
						var _rv2 = (1 - _pp * _ru2) / _qq;
						_t1x = _fx + _ux * _ru1 + _dx * _rv1;
						_t1y = _fy + _uy * _ru1 + _dy * _rv1;
						_t2x = _fx + _ux * _ru2 + _dx * _rv2;
						_t2y = _fy + _uy * _ru2 + _dy * _rv2;
					}
				}
				if (_t1y <= _t2y) {
					_cc.lc = [_t1x, _t1y];
					_cc.dc = [_t2x, _t2y];
				} else {
					_cc.lc = [_t2x, _t2y];
					_cc.dc = [_t1x, _t1y];
				}
			}
			array_push(_cones, _cc);
		}
	}
	var _m = _R + _cone_len + 12;
	return {
		cx: _cx,
		cy: _cy,
		faces: _faces,
		cones: _cones,
		corners: _corners,
		box: [_cx - _m, _cy - _m, _cx + _m, _cy + _m],
	};
}

/// Finds the axis cone under a screen point.
/// @return {Array} [axis, sign], or undefined on miss
function __gm3d_ed_viewcube_cone_at(_vc, _mx, _my) {
	if (_vc == undefined) {
		return undefined;
	}
	for (var _i = 0; _i < array_length(_vc.cones); _i++) {
		var _c = _vc.cones[_i];
		if (_c.facing > 0.96) {
			continue;
		}
		if (_c.disk == true) {
			if (point_distance(_mx, _my, _c.c[0], _c.c[1]) <= 10) {
				return [_c.a, _c.s];
			}
			continue;
		}
		var _gx = (_c.apex[0] + _c.lc[0] + _c.dc[0]) / 3;
		var _gy = (_c.apex[1] + _c.lc[1] + _c.dc[1]) / 3;
		var _tx = _c.apex[0];
		var _ty = _c.apex[1];
		var _tl = sqrt((_tx - _gx) * (_tx - _gx) + (_ty - _gy) * (_ty - _gy));
		if (_tl > 0.001) {
			_tx = _tx + ((_tx - _gx) / _tl) * 3;
			_ty = _ty + ((_ty - _gy) / _tl) * 3;
		}
		var _lx = _c.lc[0];
		var _ly = _c.lc[1];
		var _ll = sqrt((_lx - _gx) * (_lx - _gx) + (_ly - _gy) * (_ly - _gy));
		if (_ll > 0.001) {
			_lx = _lx + ((_lx - _gx) / _ll) * 3;
			_ly = _ly + ((_ly - _gy) / _ll) * 3;
		}
		var _dx = _c.dc[0];
		var _dy = _c.dc[1];
		var _dl = sqrt((_dx - _gx) * (_dx - _gx) + (_dy - _gy) * (_dy - _gy));
		if (_dl > 0.001) {
			_dx = _dx + ((_dx - _gx) / _dl) * 3;
			_dy = _dy + ((_dy - _gy) / _dl) * 3;
		}
		if (__gm3d_ed_tri_hit(_mx, _my, _tx, _ty, _lx, _ly, _dx, _dy)) {
			return [_c.a, _c.s];
		}
	}
	return undefined;
}

/// True when a screen point is inside the cube bounds.
function __gm3d_ed_viewcube_box_at(_vc, _mx, _my) {
	if (_vc == undefined) {
		return false;
	}
	var _b = _vc.box;
	return _mx >= _b[0] && _mx <= _b[2] && _my >= _b[1] && _my <= _b[3];
}

/// Draws one axis cone.
function __gm3d_ed_viewcube_cone(_ed, _c, _hov) {
	var _al = _c.front ? 1 : _hov ? 0.75 : 0.35;
	var _lc = _hov ? merge_colour(_c.lcol, c_white, 0.45) : _c.lcol;
	var _dk = _hov ? _c.lcol : _c.dcol;
	if (_c.disk == true) {
		var _n = 10;
		var _rim = merge_colour(_lc, _dk, 0.45);
		draw_primitive_begin(pr_trianglefan);
		draw_vertex_colour(_c.c[0], _c.c[1], _lc, _al);
		for (var _k = 0; _k <= _n; _k++) {
			var _t = (_k / _n) * 2 * pi;
			draw_vertex_colour(_c.c[0] + cos(_t) * 6, _c.c[1] + sin(_t) * 6, _rim, _al);
		}
		draw_primitive_end();
		for (var _e = 0; _e < _n; _e++) {
			var _t0 = (_e / _n) * 2 * pi;
			var _t1 = ((_e + 1) / _n) * 2 * pi;
			__gm3d_ed_vp_line(
				_ed,
				_c.c[0] + cos(_t0) * 6,
				_c.c[1] + sin(_t0) * 6,
				_c.c[0] + cos(_t1) * 6,
				_c.c[1] + sin(_t1) * 6,
				1,
				_c.dcol,
			);
		}
		return;
	}
	var _strips = 5;
	var _open = _c.r * abs(_c.facing);
	if (_open >= 1.5) {
		var _ux = -_c.dy * _c.r;
		var _uy = _c.dx * _c.r;
		var _vx = _c.dx * _open;
		var _vy = _c.dy * _open;
		var _cap = merge_colour(_dk, c_black, 0.25);
		var _seg = 8;
		var _a1 = _c.facing > 0 ? 2 * pi : pi;
		draw_primitive_begin(pr_trianglefan);
		draw_vertex_colour(_c.fc[0], _c.fc[1], _cap, _al);
		for (var _h = 0; _h <= _seg; _h++) {
			var _ha = (_h / _seg) * _a1;
			draw_vertex_colour(
				_c.fc[0] + cos(_ha) * _ux + sin(_ha) * _vx,
				_c.fc[1] + cos(_ha) * _uy + sin(_ha) * _vy,
				_cap,
				_al,
			);
		}
		draw_primitive_end();
		var _qx = _c.fc[0] + _ux;
		var _qy = _c.fc[1] + _uy;
		for (var _j = 1; _j <= _seg; _j++) {
			var _ja = (_j / _seg) * _a1;
			var _nx = _c.fc[0] + cos(_ja) * _ux + sin(_ja) * _vx;
			var _ny = _c.fc[1] + cos(_ja) * _uy + sin(_ja) * _vy;
			__gm3d_ed_vp_line(_ed, _qx, _qy, _nx, _ny, 1, _c.dcol);
			_qx = _nx;
			_qy = _ny;
		}
	}
	draw_primitive_begin(pr_trianglelist);
	for (var _s = 0; _s < _strips; _s++) {
		var _t0 = _s / _strips;
		var _t1 = (_s + 1) / _strips;
		var _c0 = merge_colour(_lc, _dk, _t0);
		var _c1 = merge_colour(_lc, _dk, _t1);
		var _cm = merge_colour(_lc, _dk, (_t0 + _t1) * 0.5);
		var _ar = make_colour_rgb(colour_get_red(_cm) * 0.55, colour_get_green(_cm) * 0.55, colour_get_blue(_cm) * 0.55);
		var _p0x = _c.lc[0] + (_c.dc[0] - _c.lc[0]) * _t0;
		var _p0y = _c.lc[1] + (_c.dc[1] - _c.lc[1]) * _t0;
		var _p1x = _c.lc[0] + (_c.dc[0] - _c.lc[0]) * _t1;
		var _p1y = _c.lc[1] + (_c.dc[1] - _c.lc[1]) * _t1;
		draw_vertex_colour(_c.apex[0], _c.apex[1], _ar, _al);
		draw_vertex_colour(_p0x, _p0y, _c0, _al);
		draw_vertex_colour(_p1x, _p1y, _c1, _al);
	}
	draw_primitive_end();
	__gm3d_ed_vp_line(_ed, _c.apex[0], _c.apex[1], _c.lc[0], _c.lc[1], 2, merge_colour(_lc, c_white, 0.5));
	__gm3d_ed_vp_line(_ed, _c.apex[0], _c.apex[1], _c.dc[0], _c.dc[1], 1, _c.dcol);
}

/// Draws the orientation cube with axis cones.
function __gm3d_ed_viewcube_draw(_ed, _vp) {
	if (_ed.imgui == undefined || !_ed.imgui.win_cube.open) {
		return;
	}
	var _vc = __gm3d_ed_viewcube(_ed);
	if (_vc == undefined) {
		return;
	}
	var _labels = ["X", "Y", "Z"];
	draw_set_halign(fa_center);
	draw_set_valign(fa_middle);
	for (var _b = 0; _b < array_length(_vc.cones); _b++) {
		var _bc = _vc.cones[_b];
		if (_bc.front || _bc.facing > 0.93) {
			continue;
		}
		var _bh = _ed.cube_hover != undefined && _ed.cube_hover[0] == _bc.a && _ed.cube_hover[1] == _bc.s;
		__gm3d_ed_viewcube_cone(_ed, _bc, _bh);
	}
	var _fs = _vc.faces;
	__gm3d_ed_sort_by_field(_fs, "facing", true);
	for (var _k = 0; _k < array_length(_fs); _k++) {
		var _f = _fs[_k];
		if (abs(_f.facing) <= 0.02) {
			continue;
		}
		var _p = [];
		for (var _v = 0; _v < 4; _v++) {
			array_push(_p, _vc.corners[_f.idx[_v]]);
		}
		draw_primitive_begin(pr_trianglefan);
		for (var _w = 0; _w < 4; _w++) {
			var _kc = (_f.idx[_w] & 2) > 0 ? _f.ct : _f.cb;
			draw_vertex_colour(_p[_w][0], _p[_w][1], _kc, 1);
		}
		draw_primitive_end();
	}
	for (var _n = 0; _n < array_length(_vc.cones); _n++) {
		var _fc = _vc.cones[_n];
		if (!_fc.front || _fc.facing > 0.93) {
			continue;
		}
		var _hov = _ed.cube_hover != undefined && _ed.cube_hover[0] == _fc.a && _ed.cube_hover[1] == _fc.s;
		__gm3d_ed_viewcube_cone(_ed, _fc, _hov);
		if (!_fc.disk) {
			draw_set_color(c_white);
			draw_text(_fc.fc[0] + _fc.dx * 10, _fc.fc[1] + _fc.dy * 10, _labels[_fc.a]);
		}
	}
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_color(c_white);
}

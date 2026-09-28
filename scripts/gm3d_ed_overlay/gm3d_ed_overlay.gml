/// ---- 2D overlay for lights / cameras / environment ----

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

/// Draws a sprite billboard centered on _sp, tinted. Falls back gracefully.
/// @return True when drawn.
function __gm3d_ed_overlay_sprite(_sp, _sprname, _tint) {
	static _smap = {};
	if (!variable_struct_exists(_smap, _sprname)) {
		var _idx = -1;
		try {
			_idx = asset_get_index(_sprname);
		} catch (_e) {
			_idx = -1;
		}
		_smap[$ _sprname] = _idx;
	}
	var _spr = _smap[$ _sprname];
	if (_spr == -1) {
		return false;
	}
	// Center the sprite image on _sp for any origin at 1.5x scale: the drawn
	// rect spans [x-ox*s, x-ox*s+w*s], so x = _sp[0] + s*(ox-w/2).
	var _sc = 2.5;
	var _w = 0;
	var _h = 0;
	var _ox = 0;
	var _oy = 0;
	try {
		_w = sprite_get_width(_spr);
		_h = sprite_get_height(_spr);
		_ox = sprite_get_xoffset(_spr);
		_oy = sprite_get_yoffset(_spr);
	} catch (_e2) {
		return false;
	}
	try {
		draw_sprite_ext(_spr, 0, _sp[0] + _sc * (_ox - _w * 0.5), _sp[1] + _sc * (_oy - _h * 0.5), _sc, _sc, 0, _tint, 1);
	} catch (_e3) {
		return false;
	}
	return true;
}

/// Draws a sprite icon (or fallback diamond) for a prop node. No label: names
/// live in the Scene list.
/// @param _sprname sprite for the billboard, "" for the diamond.
function __gm3d_ed_overlay_icon(_ed, _sp, _label, _col, _sel, _sprname) {
	var _c = _sel ? make_colour_rgb(255, 220, 80) : _col;
	var _r = 9;
	var _drawn = false;
	if (_sprname != "") {
		_drawn = __gm3d_ed_overlay_sprite(_sp, _sprname, _c);
	}
	if (!_drawn) {
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
	}
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
	var _col = c_white;
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
		if (_sel) {
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
		}
	} else {
		var _ws = __gm3d_ed_gizmo_world_size(_vp, _wp, 120);
		var _px = (_ws > 0.0001 ? _d.range / _ws : 0) * 120;
		if (_sel && _sp != undefined && _d.range > 0 && _px >= 4) {
			draw_set_alpha(0.7);
			draw_circle(_sp[0], _sp[1], min(_px, 600), true);
			draw_set_alpha(1);
		}
		if (_sel && _d.type == "spot") {
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
		var _lspr = _d.type == "directional" ? "sprGM3DIconDirectionalLight" : "sprGM3DIconPointLight";
		__gm3d_ed_overlay_icon(_ed, _sp, _lb, _col, _sel, _lspr);
	}
}

/// Overlay for one camera node: icon plus frustum wireframe.
/// GM3D cameras view along -Z of the node (opposite getWorldForward), like
/// the editor fly camera in __gm3d_ed_view_forward usage.
function __gm3d_ed_overlay_camera(_ed, _vp, _nd, _en, _wp, _sp, _lb, _sel) {
	var _col = c_white;
	if (_sel) {
		_col = make_colour_rgb(255, 220, 80);
	}
	var _d = (_en != undefined && is_struct(_en.data)) ? _en.data : __gm3d_ed_camera_defaults();
	// Frustum and glyphs only for the selected camera; unselected nodes show
	// just the icon (click target).
	if (!_sel) {
		if (_sp != undefined) {
			__gm3d_ed_overlay_icon(_ed, _sp, _lb, _col, _sel, "sprGM3DIconCamera");
		}
		return;
	}
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
		__gm3d_ed_overlay_icon(_ed, _sp, _lb, _col, _sel, "sprGM3DIconCamera");
	}
}

/// Overlay for the environment node: icon, plus size box when selected.
function __gm3d_ed_overlay_env(_ed, _vp, _nd, _en, _wp, _sp, _lb, _sel) {
	var _col = c_white;
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
		__gm3d_ed_overlay_icon(_ed, _sp, _lb, _col, _sel, "sprGM3DIconPointLight");
	}
}

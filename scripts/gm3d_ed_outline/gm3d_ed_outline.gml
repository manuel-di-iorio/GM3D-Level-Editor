// Gets or creates outline state.
function __gm3d_ed_outline_cfg(_ed) {
	if (_ed == undefined) {
		return undefined;
	}
	if (!variable_struct_exists(_ed, "outline") || !is_struct(_ed.outline)) {
		_ed.outline = {
			mask: undefined,
			mw: 0,
			mh: 0,
			has: false,
			white: undefined,
			whiteSkin: undefined,
			mats_ok: undefined,
			warned: false,
		  warmed: false,
		  color: [1.0, 0.55, 0.1],
			thickness: 2.0,
			strength: 1.5,
			glow: 0.75,
			threshold: 0.9,
			sig: undefined,
		};
	}
	return _ed.outline;
}

// Logs outline warning once.
function __gm3d_ed_outline_warn(_ed, _o, _msg) {
	if (_o.warned) {
		return;
	}
	_o.warned = true;
	show_debug_message("[gm3d_ed_outline] disabled: " + string(_msg));
}

// Ensures outline mask materials exist.
function __gm3d_ed_outline_mats(_ed, _o) {
	if (_o.mats_ok == true && _o.white != undefined && _o.whiteSkin != undefined) {
		return true;
	}
	if (_o.mats_ok == false) {
		return false;
	}
	var _w = new GM3D_Material("gm3d_ed_mask");
	_w.setShader(GM3D_ERenderPass.Forward, shGM3DMask);
	var _ws = new GM3D_Material("gm3d_ed_mask_skin");
	_ws.setShader(GM3D_ERenderPass.Forward, shGM3DMaskSkin);
	_o.white = _w;
	_o.whiteSkin = _ws;
	_o.mats_ok = true;
	return true;
}

// Checks entry in selection list.
function __gm3d_ed_outline_is_sel(_entry, _selEntries) {
	if (_entry == undefined) {
		return false;
	}
	for (var _i = 0; _i < array_length(_selEntries); _i++) {
		if (_selEntries[_i] == _entry) {
			return true;
		}
	}
	return false;
}

// Ensures outline mask surface size.
function __gm3d_ed_outline_mask_surface(_o, _w, _h) {
	if (_w <= 0 || _h <= 0) {
		return false;
	}
	if (_o.mask != undefined && surface_exists(_o.mask) && _o.mw == _w && _o.mh == _h) {
		return true;
	}
	if (_o.mask != undefined && surface_exists(_o.mask)) {
		surface_free(_o.mask);
	}
	_o.mask = undefined;
	_o.mw = 0;
	_o.mh = 0;
	_o.mask = surface_create(_w, _h);
	_o.mw = _w;
	_o.mh = _h;
	if (!surface_exists(_o.mask)) {
		_o.mask = undefined;
		return false;
	}
	return true;
}

// Preinitializes outline materials and surface.
function __gm3d_ed_outline_warmup(_ed, _o) {
	if (variable_struct_exists(_o, "warmed") && _o.warmed == true) {
		return;
	}
	_o.warmed = true;
	if (!__gm3d_ed_outline_mats(_ed, _o)) {
		return;
	}
	var _app = undefined;
	_app = application_surface;
	if (_app == undefined || !surface_exists(_app)) {
		return;
	}
	__gm3d_ed_outline_mask_surface(_o, _ed.preview_w, _ed.preview_h);
}

// Builds cheap change signature for selection, camera and surface size.
// Returns undefined when it cannot be built reliably (forces recapture).
function __gm3d_ed_outline_sig(_ed) {
	if (_ed.rt == undefined || _ed.rt.scene == undefined || _ed.vp == undefined) {
		return undefined;
	}
	var _app = undefined;
	_app = application_surface;
	if (_app == undefined || !surface_exists(_app)) {
		return undefined;
	}
	var _sig = string(surface_get_width(_app)) + "x" + string(surface_get_height(_app));
	_sig += "|t" + string(is_array(_ed.tracked) ? array_length(_ed.tracked) : -1);
	var _vp = _ed.vp;
	if (_vp.camNode == undefined || _vp.camForward == undefined) {
		return undefined;
	}
	var _cp = _vp.camNode.getWorldPosition();
	if (_cp == undefined) {
		return undefined;
	}
	_sig += "|c" + string(_cp.x) + "," + string(_cp.y) + "," + string(_cp.z);
	_sig += "|f" + string(_vp.camForward.x) + "," + string(_vp.camForward.y) + "," + string(_vp.camForward.z);
	if (!is_array(_ed.sel)) {
		return _sig;
	}
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		var _nd = _ed.sel[_i];
		if (_nd == undefined) {
			_sig += "|x";
			continue;
		}
		var _wp = _nd.getWorldPosition();
		var _rq = _nd.getLocalRotation();
		var _sc = _nd.getLocalScale();
		if (_wp == undefined || _rq == undefined || _sc == undefined) {
			return undefined;
		}
		_sig += "|" + string(_nd.name) + "," + string(_wp.x) + "," + string(_wp.y) + "," + string(_wp.z);
		_sig += "," + string(_rq.x) + "," + string(_rq.y) + "," + string(_rq.z) + "," + string(_rq.w);
		_sig += "," + string(_sc.x) + "," + string(_sc.y) + "," + string(_sc.z);
		_sig += __gm3d_ed_hidden_get(_ed, _nd) ? ",h" : ",v";
	}
	return _sig;
}

// Renders selection mask for outline.
function __gm3d_ed_outline_capture(_ed) {
	if (_ed == undefined || _ed.active != true) {
		return;
	}
	if (!__gm3d_ed_preview_open(_ed)) {
		return;
	}
	var _o = __gm3d_ed_outline_cfg(_ed);
	if (_o == undefined) {
		return;
	}
	_o.has = false;
	if (_ed.rt == undefined || _ed.rt.scene == undefined || _ed.inst == undefined) {
		return;
	}
	var _renderer = undefined;
	_renderer = _ed.inst.renderer;
	if (_renderer == undefined) {
		return;
	}
	__gm3d_ed_outline_warmup(_ed, _o);

	var _selEntries = [];
	if (is_array(_ed.sel)) {
		for (var _i = 0; _i < array_length(_ed.sel); _i++) {
			var _nd = _ed.sel[_i];
			if (_nd == undefined || __gm3d_ed_hidden_get(_ed, _nd)) {
				continue;
			}
			if (__gm3d_ed_kind_of(_ed, _nd) != "asset") {
				continue;
			}
			var _en = __gm3d_ed_registry_find(_ed, _nd);
			if (_en != undefined && !__gm3d_ed_outline_is_sel(_en, _selEntries)) {
				array_push(_selEntries, _en);
			}
		}
	}
	if (array_length(_selEntries) == 0) {
		_o.sig = undefined;
		return;
	}
	var _sig = __gm3d_ed_outline_sig(_ed);
	var _old_sig = variable_struct_exists(_o, "sig") ? _o.sig : undefined;
	if (_sig != undefined && _sig == _old_sig && _o.has && _o.mask != undefined && surface_exists(_o.mask)) {
		return;
	}
	if (!__gm3d_ed_outline_mats(_ed, _o)) {
		return;
	}

	var _app = undefined;
	_app = application_surface;
	if (_app == undefined || !surface_exists(_app)) {
		return;
	}
	var _w = _ed.preview_w;
	var _h = _ed.preview_h;
	if (!(_w > 0) || !(_h > 0)) {
		return;
	}
	if (!__gm3d_ed_outline_mask_surface(_o, _w, _h)) {
		return;
	}

	var _grid = undefined;
	var _preview = undefined;
	if (variable_struct_exists(_ed, "grid_node")) {
		_grid = _ed.grid_node;
	}
	if (variable_struct_exists(_ed, "drag_preview")) {
		_preview = _ed.drag_preview;
	}

	var _swapped = [];
	var _muted = [];
	var _ok = true;
	var _nodes = _ed.rt.scene.getNodes();
	for (var _n = 0; _n < array_length(_nodes); _n++) {
		var _cur = _nodes[_n];
		if (_cur == undefined) {
			continue;
		}
		var _root = __gm3d_ed_walk_root(_cur);
		if ((_grid != undefined && _root == _grid) || (_preview != undefined && _root == _preview)) {
			__gm3d_ed_walk_mute_node(_cur, _muted);
			continue;
		}
		var _entry = undefined;
		_entry = __gm3d_ed_registry_find(_ed, _root);
		if (_entry != undefined && _entry.hidden == true) {
			continue;
		}
		if (!__gm3d_ed_outline_is_sel(_entry, _selEntries)) {
			__gm3d_ed_walk_mute_node(_cur, _muted);
			continue;
		}
		var _list = [];
		__gm3d_ed_walk_collect_comps(_cur, _list);
		for (var _c = 0; _c < array_length(_list); _c++) {
			var _comp = _list[_c].comp;
			var _orig = undefined;
			_orig = _comp.getMaterial();
			if (_orig == undefined || _orig == _o.white || _orig == _o.whiteSkin) {
				continue;
			}
			array_push(_swapped, { comp: _comp, orig: _orig });
			_comp.setMaterial(_list[_c].skinned ? _o.whiteSkin : _o.white);
		}
	}

	if (_ok) {
		surface_set_target(_o.mask);
		draw_clear(c_black);
		_renderer.render(_ed.rt.scene);
		surface_reset_target();
		_o.has = true;
		_o.sig = _sig;
	}

	__gm3d_ed_walk_restore(_swapped, _muted);
}

// Draws outline glow from mask.
function __gm3d_ed_outline_composite(_ed) {
	if (_ed == undefined || _ed.active != true) {
		return;
	}
	if (!variable_struct_exists(_ed, "outline") || !is_struct(_ed.outline)) {
		return;
	}
	var _o = _ed.outline;
	if (!_o.has || _o.mask == undefined || !surface_exists(_o.mask)) {
		return;
	}
	var _gw = _ed.preview_w;
	var _gh = _ed.preview_h;
	if (!(_gw > 0) || !(_gh > 0)) {
		return;
	}
	var _u_color = -1;
	var _u_texel = -1;
	var _u_thick = -1;
	var _u_strength = -1;
	var _u_glow = -1;
	var _u_thresh = -1;
	_u_color = shader_get_uniform(shGM3DOutline, "u_color");
	_u_texel = shader_get_uniform(shGM3DOutline, "u_texel");
	_u_thick = shader_get_uniform(shGM3DOutline, "u_thickness");
	_u_strength = shader_get_uniform(shGM3DOutline, "u_strength");
	_u_glow = shader_get_uniform(shGM3DOutline, "u_glow");
	_u_thresh = shader_get_uniform(shGM3DOutline, "u_threshold");
	var _was_blend = true;
	_was_blend = gpu_get_blendenable();
	shader_set(shGM3DOutline);
	if (_u_color != -1) {
		shader_set_uniform_f(_u_color, _o.color[0], _o.color[1], _o.color[2]);
	}
	if (_u_texel != -1 && _o.mw > 0 && _o.mh > 0) {
		shader_set_uniform_f(_u_texel, 1.0 / _o.mw, 1.0 / _o.mh);
	}
	if (_u_thick != -1) {
		shader_set_uniform_f(_u_thick, _o.thickness);
	}
	if (_u_strength != -1) {
		shader_set_uniform_f(_u_strength, _o.strength);
	}
	if (_u_glow != -1) {
		shader_set_uniform_f(_u_glow, _o.glow);
	}
	if (_u_thresh != -1) {
		shader_set_uniform_f(_u_thresh, _o.threshold);
	}
	gpu_set_blendenable(true);
	draw_surface_stretched(_o.mask, 0, 0, _gw, _gh);
	shader_reset();
	gpu_set_blendenable(_was_blend);
	draw_set_alpha(1);
	draw_set_color(c_white);
}

// Frees outline surfaces and materials.
function __gm3d_ed_outline_cleanup(_ed) {
	if (_ed == undefined || !variable_struct_exists(_ed, "outline") || !is_struct(_ed.outline)) {
		return;
	}
	var _o = _ed.outline;
	if (_o.mask != undefined && surface_exists(_o.mask)) {
		surface_free(_o.mask);
	}
	if (_o.white != undefined) {
		_o.white.destroy();
	}
	if (_o.whiteSkin != undefined) {
		_o.whiteSkin.destroy();
	}
	_ed.outline = undefined;
}

/// @module gm3d_ed_outline
/// Unique-style selection outline for models, GM3D-only (no vertex_* calls).
///
/// Pass 1 (Draw event, after the scene render): the selected asset subtrees get
/// shared solid-white materials (static + skinned variants so animated poses
/// are followed) while every other mesh component is temporarily disabled,
/// then the scene is rendered into a mask surface cleared to black. With no
/// occluders left, the mask always holds the full silhouette: the outline is
/// drawn always on top, with no depth test against other models.
/// Pass 2 (Draw GUI event, before the gizmo): a Sobel composite samples the
/// mask and draws a constant-pixel orange border. Non-edge pixels output
/// alpha 0, leaving the scene untouched. A border fade kills the false edge
/// where a silhouette is clipped by the viewport.

/// Lazily creates the outline state on the editor struct.
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
		};
	}
	return _ed.outline;
}

/// Debug helper: warns once when the GM3D material override path is missing.
function __gm3d_ed_outline_warn(_ed, _o, _msg) {
	if (_o.warned) {
		return;
	}
	_o.warned = true;
	try {
		show_debug_message("[gm3d_ed_outline] disabled: " + string(_msg));
	} catch (_e) {
	}
}

/// Lazily creates the shared solid-white mask materials (static + skinned).
/// Uses only GM3D material calls; any failure disables the outline and keeps
/// the legacy 2D selection box.
function __gm3d_ed_outline_mats(_ed, _o) {
	if (_o.mats_ok == true && _o.white != undefined && _o.whiteSkin != undefined) {
		return true;
	}
	if (_o.mats_ok == false) {
		return false;
	}
	try {
		var _w = new GM3D_Material("gm3d_ed_mask");
		_w.setShader(shGM3DMask);
		var _ws = new GM3D_Material("gm3d_ed_mask_skin");
		_ws.setShader(shGM3DMaskSkin);
		_o.white = _w;
		_o.whiteSkin = _ws;
		_o.mats_ok = true;
		return true;
	} catch (_e) {
		_o.mats_ok = false;
		_o.white = undefined;
		_o.whiteSkin = undefined;
		__gm3d_ed_outline_warn(_ed, _o, "GM3D_Material/setShader unavailable");
		return false;
	}
}

/// True when _entry is one of the selected entries (stable registry structs).
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

/// Pushes the mesh components of _node (no recursion, the scene walk covers
/// every node) as { comp, skinned } entries.
function __gm3d_ed_outline_collect_comps(_node, _out) {
	try {
		var _mc = _node.getMeshComponent();
		if (_mc != undefined) {
			array_push(_out, { comp: _mc, skinned: false });
		}
	} catch (_e) {
	}
	try {
		var _sk = _node.getSkinnedMeshComponent();
		if (_sk != undefined) {
			array_push(_out, { comp: _sk, skinned: true });
		}
	} catch (_e2) {
	}
}

/// Disables the mesh components of _node for the mask pass, recording their
/// previous enabled state in _muted as { comp, was } entries.
function __gm3d_ed_outline_mute_node(_node, _muted) {
	var _list = [];
	__gm3d_ed_outline_collect_comps(_node, _list);
	for (var _i = 0; _i < array_length(_list); _i++) {
		var _comp = _list[_i].comp;
		var _was = true;
		try {
			_was = _comp.getEnabled();
		} catch (_e) {
			_was = true;
		}
		if (_was) {
			try {
				_comp.setEnabled(false);
			} catch (_e2) {
			}
		}
		array_push(_muted, { comp: _comp, was: _was });
	}
}

/// Ensures the mask surface matches _w x _h. Returns true when ready.
function __gm3d_ed_outline_mask_surface(_o, _w, _h) {
	if (_w <= 0 || _h <= 0) {
		return false;
	}
	if (_o.mask != undefined && surface_exists(_o.mask) && _o.mw == _w && _o.mh == _h) {
		return true;
	}
	try {
		if (_o.mask != undefined && surface_exists(_o.mask)) {
			surface_free(_o.mask);
		}
	} catch (_eF) {
	}
	_o.mask = undefined;
	_o.mw = 0;
	_o.mh = 0;
	try {
		_o.mask = surface_create(_w, _h);
		_o.mw = _w;
		_o.mh = _h;
	} catch (_eC) {
		_o.mask = undefined;
		return false;
	}
	if (!surface_exists(_o.mask)) {
		_o.mask = undefined;
		return false;
	}
	return true;
}

/// One-time warmup: pre-creates the mask materials and the mask surface so the
/// first click on a model does not pay their allocation cost. Shader compile
/// is handled centrally by __gm3d_ed_shaders_warmup.
function __gm3d_ed_outline_warmup(_ed, _o) {
	if (variable_struct_exists(_o, "warmed") && _o.warmed == true) {
		return;
	}
	_o.warmed = true;
	if (!__gm3d_ed_outline_mats(_ed, _o)) {
		return;
	}
	var _app = undefined;
	try {
		_app = application_surface;
	} catch (_eA) {
		_app = undefined;
	}
	if (_app == undefined || !surface_exists(_app)) {
		return;
	}
	__gm3d_ed_outline_mask_surface(_o, surface_get_width(_app), surface_get_height(_app));
}
/// Pass 1: renders the selection mask. Call from the Draw event, right after
/// the scene render. Only the selected subtrees keep their components enabled
/// (reassigned to shared white materials); everything else — including the
/// grid and the drop preview — is muted for the mask pass and restored right
/// after, so the mask always holds the full silhouette with no depth test.
/// Hidden tracked subtrees are skipped so their disabled state is never
/// touched.
function __gm3d_ed_outline_capture(_ed) {
	if (_ed == undefined || _ed.active != true) {
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
	try {
		_renderer = _ed.inst.renderer;
	} catch (_eR) {
		_renderer = undefined;
	}
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
		return;
	}
	if (!__gm3d_ed_outline_mats(_ed, _o)) {
		return;
	}

	var _app = undefined;
	try {
		_app = application_surface;
	} catch (_eA) {
		_app = undefined;
	}
	if (_app == undefined || !surface_exists(_app)) {
		return;
	}
	var _w = surface_get_width(_app);
	var _h = surface_get_height(_app);
	if (!__gm3d_ed_outline_mask_surface(_o, _w, _h)) {
		return;
	}

	var _grid = undefined;
	var _preview = undefined;
	try {
		if (variable_struct_exists(_ed, "grid_node")) {
			_grid = _ed.grid_node;
		}
		if (variable_struct_exists(_ed, "drag_preview")) {
			_preview = _ed.drag_preview;
		}
	} catch (_eX) {
	}

	var _swapped = [];
	var _muted = [];
	var _ok = true;
	try {
		var _nodes = _ed.rt.scene.getNodes();
		for (var _n = 0; _n < array_length(_nodes); _n++) {
			var _cur = _nodes[_n];
			if (_cur == undefined) {
				continue;
			}
			var _root = _cur;
			var _guard = 0;
			try {
				while (_root.parent != undefined && _guard < 1024) {
					_root = _root.parent;
					_guard++;
				}
			} catch (_eP) {
			}
			if ((_grid != undefined && _root == _grid) || (_preview != undefined && _root == _preview)) {
				__gm3d_ed_outline_mute_node(_cur, _muted);
				continue;
			}
			var _entry = undefined;
			try {
				_entry = __gm3d_ed_registry_find(_ed, _root);
			} catch (_eF2) {
				_entry = undefined;
			}
			if (_entry != undefined && _entry.hidden == true) {
				continue;
			}
			if (!__gm3d_ed_outline_is_sel(_entry, _selEntries)) {
				__gm3d_ed_outline_mute_node(_cur, _muted);
				continue;
			}
			var _list = [];
			__gm3d_ed_outline_collect_comps(_cur, _list);
			for (var _c = 0; _c < array_length(_list); _c++) {
				var _comp = _list[_c].comp;
				var _orig = undefined;
				try {
					_orig = _comp.getMaterial();
				} catch (_eG) {
					_orig = undefined;
				}
				if (_orig == undefined || _orig == _o.white || _orig == _o.whiteSkin) {
					continue;
				}
				array_push(_swapped, { comp: _comp, orig: _orig });
				_comp.setMaterial(_list[_c].skinned ? _o.whiteSkin : _o.white);
			}
		}
	} catch (_eS) {
		_ok = false;
		__gm3d_ed_outline_warn(_ed, _o, "scene walk / setMaterial unavailable");
	}

	if (_ok) {
		try {
			surface_set_target(_o.mask);
			draw_clear(c_black);
			_renderer.render(_ed.rt.scene);
			surface_reset_target();
			_o.has = true;
		} catch (_eM) {
			try {
				surface_reset_target();
			} catch (_eR2) {
			}
			_o.has = false;
		}
	}

	try {
		for (var _s = 0; _s < array_length(_swapped); _s++) {
			_swapped[_s].comp.setMaterial(_swapped[_s].orig);
		}
		for (var _m = 0; _m < array_length(_muted); _m++) {
			if (_muted[_m].was) {
				_muted[_m].comp.setEnabled(true);
			}
		}
	} catch (_eB) {
	}
	try {
		_ed.rt.scene.update(0);
	} catch (_eU) {
	}
}

/// Pass 2: composites the outline over the viewport. Call from the Draw GUI
/// event, before the gizmo, so handles stay on top.
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
	var _gw = 0;
	var _gh = 0;
	try {
		_gw = display_get_gui_width();
		_gh = display_get_gui_height();
	} catch (_eG) {
		return;
	}
	if (_gw <= 0 || _gh <= 0) {
		return;
	}
	var _u_color = -1;
	var _u_texel = -1;
	var _u_thick = -1;
	var _u_strength = -1;
	var _u_glow = -1;
	var _u_thresh = -1;
	try {
		_u_color = shader_get_uniform(shGM3DOutline, "u_color");
		_u_texel = shader_get_uniform(shGM3DOutline, "u_texel");
		_u_thick = shader_get_uniform(shGM3DOutline, "u_thickness");
		_u_strength = shader_get_uniform(shGM3DOutline, "u_strength");
		_u_glow = shader_get_uniform(shGM3DOutline, "u_glow");
		_u_thresh = shader_get_uniform(shGM3DOutline, "u_threshold");
	} catch (_eU) {
		return;
	}
	var _was_blend = true;
	try {
		_was_blend = gpu_get_blendenable();
	} catch (_eB) {
		_was_blend = true;
	}
	try {
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
	} catch (_eD) {
	}
	try {
		shader_reset();
	} catch (_eR) {
	}
	try {
		gpu_set_blendenable(_was_blend);
	} catch (_eB2) {
	}
	draw_set_alpha(1);
	draw_set_color(c_white);
}

/// Frees outline resources. Call from editor cleanup.
function __gm3d_ed_outline_cleanup(_ed) {
	if (_ed == undefined || !variable_struct_exists(_ed, "outline") || !is_struct(_ed.outline)) {
		return;
	}
	var _o = _ed.outline;
	try {
		if (_o.mask != undefined && surface_exists(_o.mask)) {
			surface_free(_o.mask);
		}
	} catch (_e) {
	}
	try {
		if (_o.white != undefined) {
			_o.white.destroy();
		}
	} catch (_e2) {
	}
	try {
		if (_o.whiteSkin != undefined) {
			_o.whiteSkin.destroy();
		}
	} catch (_e3) {
	}
	_ed.outline = undefined;
}

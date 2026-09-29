/// @module gm3d_ed_gpu_pick
/// GPU ID picking: pickable roots are rendered with flat
/// ID colours into a dedicated surface (depth ON, occluders kept, unlike the
/// outline mask), then read back through a persistent buffer.
///
/// Cost model: exactly ONE render + ONE buffer_get_surface per gesture (click
/// or rect end), never per frame, never surface_getpixel in a loop. The
/// download helper is the single swap point if GameMaker ever exposes region
/// readback (copy 1px / rect instead of full surface).
///
/// ID encoding is R==B redundant (low byte in R and B, high byte in G), so
/// decode is immune to BGRA/RGBA readback order (G sits at offset 1 in both)
/// and to edge blending against the black background (R and B scale
/// together; a small tolerance absorbs rounding). Black (id 0) is miss.
///
/// Boundless tracked nodes (lights, cameras, environment) carry no mesh and
/// render nothing: they keep the CPU overlay-icon path (16px) in execute.

/// Lazily creates the gpu-pick state on the editor struct.
function __gm3d_ed_gpupick_cfg(_ed) {
	if (_ed == undefined) {
		return undefined;
	}
	if (!variable_struct_exists(_ed, "gpupick") || !is_struct(_ed.gpupick)) {
		_ed.gpupick = {
			surf: undefined,
			sw: 0,
			sh: 0,
			buf: undefined,
			bw: 0,
			bh: 0,
			mats: [],
			mats_ok: undefined,
			failed: false,
			failed_msg: "",
			pending: undefined,
			cycle_x: -10000,
			cycle_y: -10000,
			cycle_time: -10000,
			cycle_index: -1,
		};
	}
	return _ed.gpupick;
}

/// Marks the pass as failed with a visible error (no silent AABB fallback).
function __gm3d_ed_gpupick_fail(_ed, _g, _msg) {
	if (_g != undefined) {
		_g.failed = true;
		_g.failed_msg = _msg;
		_g.pending = undefined;
	}
	try {
		show_debug_message("[gm3d_ed_gpu_pick] disabled: " + string(_msg));
	} catch (_e) {
	}
}

/// Encodes a 1-based id (1..65025) as [r, g, b, a] floats for u_id.
function __gm3d_ed_gpupick_id_encode(_id) {
	var _lo = _id mod 255;
	var _hi = _id div 255;
	var _v = _lo / 255;
	return [_v, _hi / 255, _v, 1.0];
}

/// Decodes raw bytes to an id; 0 is miss (background or blended edge).
function __gm3d_ed_gpupick_id_decode(_b0, _b1, _b2) {
	var _d = _b0 - _b2;
	if (_d < 0) {
		_d = -_d;
	}
	if (_d > 2) {
		return 0;
	}
	var _lo = (_b0 + _b2) div 2;
	return _b1 * 255 + _lo;
}

/// Returns (creating on demand) the pooled flat material for _id.
/// @param _skinned false for static meshes, true for skinned meshes.
function __gm3d_ed_gpupick_mat(_ed, _g, _id, _skinned) {
	if (_g.mats_ok == false) {
		return undefined;
	}
	while (array_length(_g.mats) < _id) {
		array_push(_g.mats, { s: undefined, k: undefined });
	}
	var _en = _g.mats[_id - 1];
	var _key = _skinned ? "k" : "s";
	if (_en[$ _key] != undefined) {
		return _en[$ _key];
	}
	try {
		var _m = new GM3D_Material("gm3d_ed_pick_" + string(_id) + (_skinned ? "_k" : "_s"));
		_m.setShader(GM3D_ERenderPass.Forward, _skinned ? shGM3DIdSkin : shGM3DId);
		_m.setFloatArray("u_id", __gm3d_ed_gpupick_id_encode(_id));
		_en[$ _key] = _m;
		_g.mats_ok = true;
		return _m;
	} catch (_e) {
		_g.mats_ok = false;
		__gm3d_ed_gpupick_fail(_ed, _g, "GM3D_Material/setShader/setFloatArray unavailable");
		return undefined;
	}
}

/// Ensures the pick surface and the persistent readback buffer match _w x _h.
/// @return True when both are ready.
function __gm3d_ed_gpupick_surf(_ed, _g, _w, _h) {
	if (_w <= 0 || _h <= 0) {
		return false;
	}
	if (_g.surf != undefined && surface_exists(_g.surf) && _g.sw == _w && _g.sh == _h
	&& _g.buf != undefined && _g.bw == _w && _g.bh == _h) {
		return true;
	}
	try {
		if (_g.surf != undefined && surface_exists(_g.surf)) {
			surface_free(_g.surf);
		}
	} catch (_eF) {
	}
	try {
		if (_g.buf != undefined) {
			buffer_delete(_g.buf);
		}
	} catch (_eB) {
	}
	_g.surf = undefined;
	_g.buf = undefined;
	_g.sw = 0;
	_g.sh = 0;
	_g.bw = 0;
	_g.bh = 0;
	try {
		_g.surf = surface_create(_w, _h);
	} catch (_eC) {
		_g.surf = undefined;
	}
	if (_g.surf == undefined || !surface_exists(_g.surf)) {
		_g.surf = undefined;
		return false;
	}
	try {
		_g.buf = buffer_create(_w * _h * 4, buffer_fixed, 1);
	} catch (_eD) {
		_g.buf = undefined;
	}
	if (_g.buf == undefined) {
		try {
			if (surface_exists(_g.surf)) {
				surface_free(_g.surf);
			}
		} catch (_eF2) {
		}
		_g.surf = undefined;
		return false;
	}
	_g.sw = _w;
	_g.sh = _h;
	_g.bw = _w;
	_g.bh = _h;
	return true;
}

/// Paints one subtree with the flat materials of one id (or mutes it).
/// @param _mute True to disable comps (cycling ignore list) instead of painting.
function __gm3d_ed_gpupick_paint_tree(_ed, _g, _node, _id, _swapped, _muted, _mute) {
	if (_mute) {
		__gm3d_ed_walk_mute_node(_node, _muted);
	} else {
		var _list = [];
		__gm3d_ed_walk_collect_comps(_node, _list);
		for (var _c = 0; _c < array_length(_list); _c++) {
			var _comp = _list[_c].comp;
			var _mat = __gm3d_ed_gpupick_mat(_ed, _g, _id, _list[_c].skinned);
			if (_mat == undefined) {
				// Variant unavailable: mute so shaded pixels never leak
				// garbage ids into the pick surface.
				__gm3d_ed_walk_mute_node(_node, _muted);
				break;
			}
			var _orig = undefined;
			try {
				_orig = _comp.getMaterial();
			} catch (_eG) {
				_orig = undefined;
			}
			if (_orig == undefined) {
				__gm3d_ed_walk_mute_node(_node, _muted);
				break;
			}
			array_push(_swapped, { comp: _comp, orig: _orig });
			try {
				_comp.setMaterial(_mat);
			} catch (_eS) {
				array_pop(_swapped);
				__gm3d_ed_gpupick_fail(_ed, _g, "setMaterial unavailable");
				return;
			}
		}
	}
	var _kids = [];
	try {
		_kids = _node.getChildren();
	} catch (_eK) {
		_kids = [];
	}
	for (var _k = 0; _k < array_length(_kids); _k++) {
		if (_kids[_k] == undefined) {
			continue;
		}
		__gm3d_ed_gpupick_paint_tree(_ed, _g, _kids[_k], _id, _swapped, _muted, _mute);
	}
}

/// Renders all pickable roots with distinct ids (depth ON, occluders kept).
/// @param _all Live nodes from ONE getNodes() call shared by the whole stack
/// walk, so reference ignore (_ignore entries are roots from _all) stays
/// stable. getNodes() wrappers are NOT stable across calls: never match
/// ignore entries against a freshly fetched array.
/// @param _ignore Array of live roots from _all to mute, or undefined.
/// @return { nodes, w, h } with nodes[id-1] = root, or undefined on failure.
function __gm3d_ed_gpupick_render(_ed, _g, _all, _ignore) {
	var _renderer = undefined;
	try {
		_renderer = _ed.inst.renderer;
	} catch (_eR) {
		_renderer = undefined;
	}
	if (_renderer == undefined) {
		__gm3d_ed_gpupick_fail(_ed, _g, "renderer unavailable");
		return undefined;
	}
	var _cam = undefined;
	var _grid = undefined;
	var _preview = undefined;
	try {
		if (variable_struct_exists(_ed.rt, "cam")) {
			_cam = _ed.rt.cam;
		}
		if (variable_struct_exists(_ed, "grid_node")) {
			_grid = _ed.grid_node;
		}
		if (variable_struct_exists(_ed, "drag_preview")) {
			_preview = _ed.drag_preview;
		}
	} catch (_eX) {
	}
	var _roots = [];
	for (var _i = 0; _i < array_length(_all); _i++) {
		var _nd = _all[_i];
		if (_nd == undefined) {
			continue;
		}
		var _is_root = false;
		try {
			_is_root = _nd.parent == undefined;
		} catch (_eP) {
			continue;
		}
		if (!_is_root) {
			continue;
		}
		if ((_grid != undefined && _nd == _grid) || (_preview != undefined && _nd == _preview)
		|| (_cam != undefined && _nd == _cam) || __gm3d_ed_is_grid(_ed, _nd)) {
			continue;
		}
		if (__gm3d_ed_hidden_get(_ed, _nd)) {
			continue;
		}
		array_push(_roots, _nd);
	}
	var _swapped = [];
	var _muted = [];
	var _nodes = [];
	var _id = 0;
	try {
		for (var _r = 0; _r < array_length(_roots); _r++) {
			if (_id >= 65025) {
				__gm3d_ed_gpupick_fail(_ed, _g, "too many pickables (>65025)");
				__gm3d_ed_walk_restore(_swapped, _muted);
				return undefined;
			}
			var _skip = false;
			if (is_array(_ignore)) {
				for (var _q = 0; _q < array_length(_ignore); _q++) {
					if (_ignore[_q] == _roots[_r]) {
						_skip = true;
						break;
					}
				}
			}
			if (_skip) {
				__gm3d_ed_gpupick_paint_tree(_ed, _g, _roots[_r], 0, _swapped, _muted, true);
				continue;
			}
			_id++;
			array_push(_nodes, _roots[_r]);
			__gm3d_ed_gpupick_paint_tree(_ed, _g, _roots[_r], _id, _swapped, _muted, false);
			if (_g.failed) {
				__gm3d_ed_walk_restore(_swapped, _muted);
				return undefined;
			}
		}
		surface_set_target(_g.surf);
		draw_clear(c_black);
		_renderer.render(_ed.rt.scene);
		surface_reset_target();
	} catch (_eM) {
		try {
			surface_reset_target();
		} catch (_eT) {
		}
		__gm3d_ed_walk_restore(_swapped, _muted);
		__gm3d_ed_gpupick_fail(_ed, _g, "pick render failed");
		return undefined;
	}
	__gm3d_ed_walk_restore(_swapped, _muted);
	try {
		_ed.rt.scene.update(0);
	} catch (_eU) {
	}
	return { nodes: _nodes, w: _g.sw, h: _g.sh };
}

/// True when two live roots are the same placement (name + exact position).
/// Used only as a cycle-intent hint (did the click land on the selected
/// node?); nothing moves between clicks, so exact match is reliable without
/// wrapper identity. Never used to mute: muting uses reference ignore inside
/// one shared getNodes() array (see render).
function __gm3d_ed_gpupick_same_node(_a, _b) {
	if (_a == undefined || _b == undefined) {
		return false;
	}
	if (_a == _b) {
		return true;
	}
	var _na = undefined;
	var _nb = undefined;
	var _pa = undefined;
	var _pb = undefined;
	try {
		_na = _a.name;
		_nb = _b.name;
		_pa = _a.getLocalPosition();
		_pb = _b.getLocalPosition();
	} catch (_e) {
		return false;
	}
	if (_na != _nb) {
		return false;
	}
	var _dx = _pa.x - _pb.x;
	var _dy = _pa.y - _pb.y;
	var _dz = _pa.z - _pb.z;
	return _dx * _dx + _dy * _dy + _dz * _dz < 0.000001;
}

/// Ensures the pick surface + readback buffer and fetches ONE shared live
/// nodes array for the whole gesture (all probes of a stack walk reuse it).
/// @return Live nodes array, or undefined on failure.
function __gm3d_ed_gpupick_begin(_ed, _g) {
	var _aw = 0;
	var _ah = 0;
	try {
		_aw = surface_get_width(application_surface);
		_ah = surface_get_height(application_surface);
	} catch (_eA) {
		_aw = 0;
		_ah = 0;
	}
	if (!__gm3d_ed_gpupick_surf(_ed, _g, _aw, _ah)) {
		__gm3d_ed_gpupick_fail(_ed, _g, "pick surface unavailable");
		return undefined;
	}
	try {
		return _ed.rt.scene.getNodes();
	} catch (_eN) {
		__gm3d_ed_gpupick_fail(_ed, _g, "scene getNodes unavailable");
		return undefined;
	}
}

/// One probe: ID render (muting _ignore refs from _all) + one download +
/// one peek at surface pixel (_sx, _sy).
/// @return { node, nodes } (node undefined = miss), or undefined on failure.
function __gm3d_ed_gpupick_probe(_ed, _g, _all, _ignore, _sx, _sy) {
	var _pass = __gm3d_ed_gpupick_render(_ed, _g, _all, _ignore);
	if (_pass == undefined) {
		return undefined;
	}
	if (!__gm3d_ed_gpupick_download(_ed, _g)) {
		return undefined;
	}
	var _id = __gm3d_ed_gpupick_peek(_g, _sx, _sy);
	if (_id <= 0 || _id > array_length(_pass.nodes)) {
		return { node: undefined, nodes: _pass.nodes };
	}
	return { node: _pass.nodes[_id - 1], nodes: _pass.nodes };
}

/// Single download of the pick surface into the persistent buffer.
/// Swap point for a future region-readback API (copy 1px/rect instead).
/// @return True on success.
function __gm3d_ed_gpupick_download(_ed, _g) {
	try {
		buffer_get_surface(_g.buf, _g.surf, 0);
		return true;
	} catch (_e) {
		__gm3d_ed_gpupick_fail(_ed, _g, "buffer_get_surface unavailable");
		return false;
	}
}

/// Maps GUI coords to pick-surface pixels.
function __gm3d_ed_gpupick_to_surf(_ed, _g, _mx, _my) {
	var _gw = 0;
	var _gh = 0;
	try {
		_gw = display_get_gui_width();
		_gh = display_get_gui_height();
	} catch (_eG) {
		return undefined;
	}
	if (_gw <= 0 || _gh <= 0) {
		return undefined;
	}
	var _sx = clamp(floor(_mx * _g.sw / _gw), 0, _g.sw - 1);
	var _sy = clamp(floor(_my * _g.sh / _gh), 0, _g.sh - 1);
	return [_sx, _sy];
}

/// Peeks one downloaded pixel and decodes the id (0 = miss).
function __gm3d_ed_gpupick_peek(_g, _sx, _sy) {
	var _off = (_sy * _g.sw + _sx) * 4;
	var _b0 = 0;
	var _b1 = 0;
	var _b2 = 0;
	try {
		_b0 = buffer_peek(_g.buf, _off, buffer_u8);
		_b1 = buffer_peek(_g.buf, _off + 1, buffer_u8);
		_b2 = buffer_peek(_g.buf, _off + 2, buffer_u8);
	} catch (_e) {
		return 0;
	}
	return __gm3d_ed_gpupick_id_decode(_b0, _b1, _b2);
}

/// Single topmost pick: one ID render + one download + one peek.
/// @return Root node, undefined on miss OR failure (check _g.failed).
function __gm3d_ed_gpupick_click(_ed, _g, _mx, _my) {
	var _all = __gm3d_ed_gpupick_begin(_ed, _g);
	if (_all == undefined) {
		return undefined;
	}
	var _sp = __gm3d_ed_gpupick_to_surf(_ed, _g, _mx, _my);
	if (_sp == undefined) {
		return undefined;
	}
	var _res = __gm3d_ed_gpupick_probe(_ed, _g, _all, undefined, _sp[0], _sp[1]);
	if (_res == undefined) {
		return undefined;
	}
	return _res.node;
}

/// Full rect sequence: render + one download + region scan (deduped).
/// @param _r Normalized rect { x0, y0, x1, y1 } in GUI pixels.
/// @return Array of root nodes (mesh hits only; icons unioned by caller).
function __gm3d_ed_gpupick_rect(_ed, _g, _r) {
	var _all = __gm3d_ed_gpupick_begin(_ed, _g);
	if (_all == undefined) {
		return [];
	}
	var _pass = __gm3d_ed_gpupick_render(_ed, _g, _all, undefined);
	if (_pass == undefined) {
		return [];
	}
	if (!__gm3d_ed_gpupick_download(_ed, _g)) {
		return [];
	}
	var _gw = 0;
	var _gh = 0;
	try {
		_gw = display_get_gui_width();
		_gh = display_get_gui_height();
	} catch (_eG) {
		return [];
	}
	if (_gw <= 0 || _gh <= 0) {
		return [];
	}
	var _x0 = clamp(floor(_r.x0 * _g.sw / _gw), 0, _g.sw - 1);
	var _x1 = clamp(floor(_r.x1 * _g.sw / _gw), 0, _g.sw - 1);
	var _y0 = clamp(floor(_r.y0 * _g.sh / _gh), 0, _g.sh - 1);
	var _y1 = clamp(floor(_r.y1 * _g.sh / _gh), 0, _g.sh - 1);
	var _area = (_x1 - _x0 + 1) * (_y1 - _y0 + 1);
	var _step = 1;
	if (_area > 1280 * 720) {
		_step = 3;
	} else if (_area > 640 * 480) {
		_step = 2;
	}
	var _seen = [];
	var _out = [];
	for (var _yy = _y0; _yy <= _y1; _yy += _step) {
		for (var _xx = _x0; _xx <= _x1; _xx += _step) {
			var _id = __gm3d_ed_gpupick_peek(_g, _xx, _yy);
			if (_id <= 0 || _id > array_length(_pass.nodes)) {
				continue;
			}
			var _dup = false;
			for (var _s = 0; _s < array_length(_seen); _s++) {
				if (_seen[_s] == _id) {
					_dup = true;
					break;
				}
			}
			if (_dup) {
				continue;
			}
			array_push(_seen, _id);
			array_push(_out, _pass.nodes[_id - 1]);
		}
	}
	return _out;
}

/// Queues a click pick from Step input (executed in Draw, valid render context).
function __gm3d_ed_gpupick_request_click(_ed, _mx, _my, _shift) {
	var _g = __gm3d_ed_gpupick_cfg(_ed);
	if (_g == undefined || _g.failed) {
		return;
	}
	_g.pending = { kind: "click", x: _mx, y: _my, shift: _shift };
}

/// Queues a rect pick from Step input (executed in Draw, valid render context).
function __gm3d_ed_gpupick_request_rect(_ed, _r, _shift) {
	var _g = __gm3d_ed_gpupick_cfg(_ed);
	if (_g == undefined || _g.failed) {
		return;
	}
	_g.pending = { kind: "rect", x0: _r.x0, y0: _r.y0, x1: _r.x1, y1: _r.y1, shift: _shift };
}

/// CPU overlay-icon test for boundless tracked nodes (lights, cameras,
/// environment): screen-space 14-16px radius, nearest first. Unchanged
/// semantics from the old pick-all icon branch.
function __gm3d_ed_gpupick_icon_at(_ed, _vp, _mx, _my) {
	var _best = undefined;
	var _bestd = 16;
	var _nodes = [];
	try {
		_nodes = _ed.rt.scene.getNodes();
	} catch (_e) {
		return undefined;
	}
	for (var _i = 0; _i < array_length(_nodes); _i++) {
		var _node = _nodes[_i];
		if (_node == undefined) {
			continue;
		}
		var _is_root = false;
		try {
			_is_root = _node.parent == undefined;
		} catch (_eP) {
			continue;
		}
		if (!_is_root || __gm3d_ed_is_grid(_ed, _node) || __gm3d_ed_hidden_get(_ed, _node)) {
			continue;
		}
		var _box = __gm3d_ed_node_aabb(_node);
		if (_box.valid) {
			continue;
		}
		if (__gm3d_ed_registry_find(_ed, _node) == undefined) {
			continue;
		}
		var _c = __gm3d_ed_world_to_screen(_vp, _node.getWorldPosition());
		if (_c == undefined) {
			continue;
		}
		var _d = point_distance(_c[0], _c[1], _mx, _my);
		if (_d <= _bestd) {
			_bestd = _d;
			_best = _node;
		}
	}
	return _best;
}

/// CPU icon test for rect: boundless tracked centers inside the rect.
function __gm3d_ed_gpupick_icons_in_rect(_ed, _vp, _r) {
	var _out = [];
	var _nodes = [];
	try {
		_nodes = _ed.rt.scene.getNodes();
	} catch (_e) {
		return _out;
	}
	for (var _i = 0; _i < array_length(_nodes); _i++) {
		var _node = _nodes[_i];
		if (_node == undefined) {
			continue;
		}
		var _is_root = false;
		try {
			_is_root = _node.parent == undefined;
		} catch (_eP) {
			continue;
		}
		if (!_is_root || __gm3d_ed_is_grid(_ed, _node) || __gm3d_ed_hidden_get(_ed, _node)) {
			continue;
		}
		var _box = __gm3d_ed_node_aabb(_node);
		if (_box.valid) {
			continue;
		}
		if (__gm3d_ed_registry_find(_ed, _node) == undefined) {
			continue;
		}
		var _nc = __gm3d_ed_world_to_screen(_vp, _node.getWorldPosition());
		if (_nc != undefined && _nc[0] >= _r.x0 && _nc[0] <= _r.x1 && _nc[1] >= _r.y0 && _nc[1] <= _r.y1) {
			array_push(_out, _node);
		}
	}
	return _out;
}

/// Executes the queued pick in Draw (valid 3D render context, same frame as
/// the Step that queued it) and writes the selection with the old semantics:
/// click (icons win over mesh, shift-toggle, miss clears), cycling through
/// overlapping meshes on repeated clicks (ignore + re-render),
/// rect (replace vs shift-add, mesh GPU hits union boundless icon hits).
function __gm3d_ed_gpupick_execute(_ed) {
	if (_ed == undefined || _ed.active != true) {
		return;
	}
	var _g = __gm3d_ed_gpupick_cfg(_ed);
	if (_g == undefined || _g.pending == undefined || _g.failed) {
		return;
	}
	if (_ed.confirm != undefined) {
		_g.pending = undefined;
		return;
	}
	var _vp = __gm3d_ed_viewport(_ed);
	var _req = _g.pending;
	_g.pending = undefined;
	if (_req.kind == "click") {
		var _icon = __gm3d_ed_gpupick_icon_at(_ed, _vp, _req.x, _req.y);
		if (_req.shift) {
			var _top = _icon;
			if (_top == undefined) {
				_top = __gm3d_ed_gpupick_click(_ed, _g, _req.x, _req.y);
				if (_g.failed) {
					return;
				}
			}
			if (_top != undefined) {
				__gm3d_ed_sel_toggle(_ed, _top);
				__gm3d_ed_sel_apply_tool(_ed);
			}
			_g.cycle_x = _req.x;
			_g.cycle_y = _req.y;
			_g.cycle_time = current_time;
			_g.cycle_index = -1;
			return;
		}
		if (_icon != undefined) {
			_ed.sel = [_icon];
			_ed.giz.drag = -1;
			__gm3d_ed_sel_apply_tool(_ed);
			_g.cycle_x = _req.x;
			_g.cycle_y = _req.y;
			_g.cycle_time = current_time;
			_g.cycle_index = -1;
			return;
		}
		// Mesh path: one shared getNodes() array for the whole gesture, so
		// the cycling ignore list (live references) stays stable. A single
		// probe serves fresh clicks; repeated clicks on the same spot — or
		// on the already selected node — walk the full front-to-back stack
		// (ignore + re-render) and advance one step.
		var _all = __gm3d_ed_gpupick_begin(_ed, _g);
		if (_all == undefined) {
			return;
		}
		var _sp = __gm3d_ed_gpupick_to_surf(_ed, _g, _req.x, _req.y);
		if (_sp == undefined) {
			return;
		}
		var _first = __gm3d_ed_gpupick_probe(_ed, _g, _all, undefined, _sp[0], _sp[1]);
		if (_first == undefined) {
			return;
		}
		if (_first.node == undefined) {
			_g.cycle_x = -10000;
			_g.cycle_y = -10000;
			_g.cycle_time = -10000;
			_g.cycle_index = -1;
			__gm3d_ed_sel_clear(_ed);
			return;
		}
		var _same = point_distance(_g.cycle_x, _g.cycle_y, _req.x, _req.y) <= 10
			&& current_time - _g.cycle_time <= 700;
		var _on_sel = array_length(_ed.sel) == 1 && __gm3d_ed_gpupick_same_node(_ed.sel[0], _first.node);
		if (!_same && !_on_sel) {
			_ed.sel = [_first.node];
			_ed.giz.drag = -1;
			__gm3d_ed_sel_apply_tool(_ed);
			_g.cycle_x = _req.x;
			_g.cycle_y = _req.y;
			_g.cycle_time = current_time;
			_g.cycle_index = 0;
			return;
		}
		var _stack = [_first.node];
		var _ignore = [_first.node];
		for (var _w = 0; _w < 31; _w++) {
			var _res = __gm3d_ed_gpupick_probe(_ed, _g, _all, _ignore, _sp[0], _sp[1]);
			if (_res == undefined) {
				return;
			}
			if (_res.node == undefined) {
				break;
			}
			array_push(_stack, _res.node);
			array_push(_ignore, _res.node);
		}
		var _base = (_same && _g.cycle_index >= 0) ? _g.cycle_index : (_on_sel ? 0 : -1);
		var _idx = (_base + 1) mod array_length(_stack);
		_ed.sel = [_stack[_idx]];
		_ed.giz.drag = -1;
		__gm3d_ed_sel_apply_tool(_ed);
		_g.cycle_x = _req.x;
		_g.cycle_y = _req.y;
		_g.cycle_time = current_time;
		_g.cycle_index = _idx;
	} else if (_req.kind == "rect") {
		var _r = { x0: _req.x0, y0: _req.y0, x1: _req.x1, y1: _req.y1 };
		var _mesh = __gm3d_ed_gpupick_rect(_ed, _g, _r);
		if (_g.failed) {
			return;
		}
		var _icons = __gm3d_ed_gpupick_icons_in_rect(_ed, _vp, _r);
		var _hits = _icons;
		for (var _j = 0; _j < array_length(_mesh); _j++) {
			array_push(_hits, _mesh[_j]);
		}
		if (_req.shift) {
			for (var _i = 0; _i < array_length(_hits); _i++) {
				if (!__gm3d_ed_sel_has(_ed, _hits[_i])) {
					array_push(_ed.sel, _hits[_i]);
				}
			}
		} else {
			_ed.sel = _hits;
		}
		__gm3d_ed_sel_apply_tool(_ed);
	}
}

/// Draws the visible failure banner (no silent fallback by design).
function __gm3d_ed_gpupick_draw_fault(_ed) {
	if (_ed == undefined || !variable_struct_exists(_ed, "gpupick") || !is_struct(_ed.gpupick)) {
		return;
	}
	if (!_ed.gpupick.failed) {
		return;
	}
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_color(c_red);
	draw_text(16, 48, "GPU picking OFF: " + string(_ed.gpupick.failed_msg));
	draw_set_color(c_white);
}

/// Frees pick surface, readback buffer and pooled ID materials.
function __gm3d_ed_gpupick_cleanup(_ed) {
	if (_ed == undefined || !variable_struct_exists(_ed, "gpupick") || !is_struct(_ed.gpupick)) {
		return;
	}
	var _g = _ed.gpupick;
	try {
		if (_g.surf != undefined && surface_exists(_g.surf)) {
			surface_free(_g.surf);
		}
	} catch (_e) {
	}
	try {
		if (_g.buf != undefined) {
			buffer_delete(_g.buf);
		}
	} catch (_e2) {
	}
	if (is_array(_g.mats)) {
		for (var _i = 0; _i < array_length(_g.mats); _i++) {
			var _en = _g.mats[_i];
			if (!is_struct(_en)) {
				continue;
			}
			try {
				if (_en.s != undefined) {
					_en.s.destroy();
				}
			} catch (_e3) {
			}
			try {
				if (_en.k != undefined) {
					_en.k.destroy();
				}
			} catch (_e4) {
			}
		}
	}
	_ed.gpupick = undefined;
}

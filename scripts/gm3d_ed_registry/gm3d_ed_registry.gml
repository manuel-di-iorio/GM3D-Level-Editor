// Adds model asset to editor library.
function gm3d_editor_asset_add(_ed, _name, _model, _thumb = -1) {
	if (_ed == undefined) {
		return;
	}
	if (!variable_struct_exists(_ed, "assets") || !is_array(_ed.assets)) {
		_ed.assets = [];
	}
	if (_name == undefined || _name == "" || _model == undefined) {
		return;
	}
	var _entry = { name: _name, model: _model };
	try {
		if (_thumb != -1 && sprite_exists(_thumb)) {
			_entry.thumb = _thumb;
		}
	} catch (_e) {
	}
	array_push(_ed.assets, _entry);
}

// Clears all editor library assets.
function gm3d_editor_asset_clear(_ed) {
	if (_ed == undefined) {
		return;
	}
	__gm3d_ed_thumbs_free(_ed);
	_ed.assets = [];
}

// Frees editor-captured thumbnails, keeping caller-owned ones.
function __gm3d_ed_thumbs_free(_ed) {
	if (_ed == undefined || !is_array(_ed.assets)) {
		return;
	}
	for (var _i = 0; _i < array_length(_ed.assets); _i++) {
		var _a = _ed.assets[_i];
		if (!is_struct(_a) || !variable_struct_exists(_a, "thumb_owned") || _a.thumb_owned != true) {
			continue;
		}
		try {
			if (sprite_exists(_a.thumb)) {
				sprite_delete(_a.thumb);
			}
		} catch (_e) {
		}
		_a.thumb = -1;
		_a.thumb_owned = undefined;
	}
}

// Captures library thumbnails once at startup.
function gm3d_editor_capture_thumbnails(_ed) {
	if (_ed == undefined || _ed.thumbs_done == true) {
		return;
	}
	if (!is_array(_ed.assets) || array_length(_ed.assets) == 0) {
		return;
	}
	_ed.thumbs_done = true;
	var _size = 256;
	var _surf = undefined;
	try {
		_surf = surface_create(_size, _size);
	} catch (_eS) {
		_surf = undefined;
	}
	if (_surf == undefined || !surface_exists(_surf)) {
		return;
	}
	var _ts = undefined;
	try {
		_ts = GM3D_Scene.createEmpty();
	} catch (_eC) {
		_ts = undefined;
	}
	if (_ts == undefined) {
		surface_free(_surf);
		return;
	}
	var _renderer = undefined;
	try {
		_renderer = new GM3D_Renderer();
	} catch (_eR) {
		_renderer = undefined;
	}
	if (_renderer == undefined) {
		_ts.destroy();
		surface_free(_surf);
		return;
	}
	var _env = _ts.createNode("__thumb_env");
	var _envc = new GM3D_EnvironmentVolumeComponent();
	_env.addComponent(_envc);
	try {
		_envc.setSize(new GM3D_Vec3(20000, 20000, 20000));
		_envc.setAmbientColor(make_colour_rgb(70, 70, 85));
		_envc.setFogEnabled(false);
	} catch (_eE) {
		_ts.destroy();
		surface_free(_surf);
		return;
	}
	var _sun = _ts.createNode("__thumb_sun");
	var _sunc = new GM3D_LightComponent();
	_sun.addComponent(_sunc);
	try {
		_sunc.setType(GM3D_ELightType.Directional);
		_sunc.setColor(c_white);
		_sunc.setIntensity(1.0);
		_sunc.setShadowEnabled(true);
		_sunc.setShadowResolution(1024);
		_sunc.setShadowDistance(30.0);
		_sunc.setShadowNormalOffset(0.05);
	} catch (_eL) {
		_ts.destroy();
		surface_free(_surf);
		return;
	}
	var _cam = _ts.createNode("__thumb_cam");
	var _camc = new GM3D_CameraComponent();
	_cam.addComponent(_camc);
	try {
		_camc.setProjection(GM3D_ECameraProjection.Perspective);
		_camc.setFovY(degtorad(40));
		_camc.setNear(0.1);
		_camc.setFar(10000);
		_camc.setScreenRect([0.0, 0.0, 1.0, 1.0]);
		_camc.setEnabled(true);
	} catch (_eC2) {
		_ts.destroy();
		surface_free(_surf);
		return;
	}
	try {
			for (var _i = 0; _i < array_length(_ed.assets); _i++) {
			var _a = _ed.assets[_i];
			if (!is_struct(_a) || _a.model == undefined) {
				continue;
			}
			var _node = undefined;
			try {
				_node = _a.model.spawnInto(_ts, undefined);
			} catch (_eN) {
				_node = undefined;
			}
			if (_node == undefined) {
				continue;
			}
			_node.setLocalPosition(new GM3D_Vec3(0, 0, 0));
			_node.setLocalScale(new GM3D_Vec3(1, 1, 1));
			try {
				if (variable_struct_exists(_ed.rt, "on_spawn")) {
					_ed.rt.on_spawn(_ed.inst, _node, _a.name, _a.model);
				}
			} catch (_eO) {
			}
			__gm3d_ed_thumb_frame(_ed, _ts, _cam, _a.model);
			_ts.update(0);
			try {
				surface_set_target(_surf);
				draw_clear_alpha(c_black, 0);
				_renderer.render(_ts);
				surface_reset_target();
				var _spr = sprite_create_from_surface(_surf, 0, 0, _size, _size, false, true, 0, 0);
				if (sprite_exists(_spr)) {
					_a.thumb = _spr;
					_a.thumb_owned = true;
				}
			} catch (_eR2) {
				try {
					surface_reset_target();
				} catch (_eT) {
				}
			}
			__gm3d_ed_destroy_subtree(_node);
			_ts.update(0);
			}
	} catch (_eL) {
	}
	_ts.destroy();
	surface_free(_surf);
	_renderer = undefined;
}

// Frames a library model for thumbnail capture.
function __gm3d_ed_thumb_frame(_ed, _ts, _cam, _model) {
	var _ctr = new GM3D_Vec3(0, 1, 0);
	var _rad = 2.0;
	try {
		var _bs = _model.getBoundingSphere();
		if (is_struct(_bs) && variable_struct_exists(_bs, "origin") && variable_struct_exists(_bs, "radius")) {
			var _c = _bs.origin;
			_ctr = new GM3D_Vec3(_c.x, _c.y, _c.z);
			_rad = max(_bs.radius, 0.1);
		}
	} catch (_e) {
	}
	var _back = new GM3D_Vec3(1, 0.55, 1.25);
	_back.normalize();
	var _tan = max(tan(degtorad(20)), 0.001);
	var _dist = max(_rad * 1.15 * sqrt(1 + _tan * _tan) / _tan, 1.5);
	_cam.setLocalPosition(new GM3D_Vec3(_ctr.x + _back.x * _dist, _ctr.y + _back.y * _dist, _ctr.z + _back.z * _dist));
	var _cp = _cam.getLocalPosition();
	var _fwd = new GM3D_Vec3(_cp.x - _ctr.x, _cp.y - _ctr.y, _cp.z - _ctr.z);
	_fwd.normalize();
	var _up = GM3D_Vec3.up();
	if (abs(_fwd.dot(_up)) >= 0.999) {
		_up = GM3D_Vec3.forward();
	}
	var _rot = GM3D_Quaternion.fromLookRotation(_fwd, _up);
	_cam.setLocalRotation(_rot.normalizeSafe(0.000001));
}

// Clears current node selection.
function __gm3d_ed_sel_clear(_ed) {
	_ed.sel = [];
	_ed.giz.drag = -1;
	_ed.giz.hover = -1;
	if (variable_struct_exists(_ed, "scene_anchor")) {
		_ed.scene_anchor = undefined;
	}
}

// Checks if node is selected.
function __gm3d_ed_sel_has(_ed, _node) {
	if (_node == undefined) {
		return false;
	}
	var _en = __gm3d_ed_registry_find(_ed, _node);
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		if (_ed.sel[_i] == _node) {
			return true;
		}
		if (_en != undefined) {
			var _es = __gm3d_ed_registry_find(_ed, _ed.sel[_i]);
			if (_es == _en) {
				return true;
			}
		}
	}
	return false;
}

// Toggles node in selection set.
function __gm3d_ed_sel_toggle(_ed, _node) {
	if (_node == undefined) {
		return;
	}
	var _en = __gm3d_ed_registry_find(_ed, _node);
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		if (_ed.sel[_i] == _node) {
			array_delete(_ed.sel, _i, 1);
			return;
		}
		if (_en != undefined) {
			var _es = __gm3d_ed_registry_find(_ed, _ed.sel[_i]);
			if (_es == _en) {
				array_delete(_ed.sel, _i, 1);
				return;
			}
		}
	}
	array_push(_ed.sel, _node);
}

// Finds library model by name.
function __gm3d_ed_asset_find(_ed, _name) {
	var _lib = _ed.assets;
	if (!is_array(_lib)) {
		return undefined;
	}
	for (var _i = 0; _i < array_length(_lib); _i++) {
		if (_lib[_i].name == _name) {
			return _lib[_i].model;
		}
	}

	return undefined;
}

// Registers spawned asset node for tracking.
function __gm3d_ed_spawn_register(_ed, _node, _asset, _pos3, _label = undefined) {
	__gm3d_ed_kind_register(_ed, _node, "asset", _asset, _pos3, _label, __gm3d_ed_flags_read(_node));
}

// Registers node with kind and metadata.
function __gm3d_ed_kind_register(_ed, _node, _kind, _asset, _pos3, _label = undefined, _data = undefined) {
	if (_ed == undefined || _node == undefined) {
		return;
	}
	if (_kind == undefined || !is_string(_kind) || _kind == "") {
		_kind = "asset";
	}
	if (_kind == "asset" && (_asset == undefined || _asset == "")) {
		return;
	}
	if (!variable_struct_exists(_ed, "tracked") || !is_array(_ed.tracked)) {
		_ed.tracked = [];
	}
	var _nm = "node";
	_nm = _node.name;
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = _nm;
	}
	array_push(_ed.tracked, {
		kind: _kind,
		asset: _asset,
		name: _nm,
		label: _label,
		pos: _pos3 != undefined ? _pos3 : [0, 0, 0],
		data: _data,
		hidden: false,
	});
}

// Spawns model and registers it.
function __gm3d_ed_place(_ed, _asset, _model, _pos3, _rot, _scale3, _label = undefined) {
	if (_ed == undefined || _model == undefined) {
		return undefined;
	}
	var _node = _model.spawnInto(_ed.rt.scene, undefined);
	if (_node == undefined) {
		return undefined;
	}
	_node.setLocalPosition(new GM3D_Vec3(_pos3[0], _pos3[1], _pos3[2]));
	_node.setLocalScale(new GM3D_Vec3(_scale3[0], _scale3[1], _scale3[2]));
	if (_rot != undefined) {
		_node.setLocalRotation(_rot);
	}
	if (variable_struct_exists(_ed.rt, "on_spawn")) {
		_ed.rt.on_spawn(_ed.inst, _node, _asset, _model);
	}
	var _pp = _node.getLocalPosition();
	__gm3d_ed_spawn_register(_ed, _node, _asset, [_pp.x, _pp.y, _pp.z], _label);
	return _node;
}

// Tracks any node kind for editor editing.
function gm3d_editor_track(_ed, _kind, _asset, _node, _label = undefined) {
	if (_kind == "light") {
		return __gm3d_ed_track_light(_ed, _node, _label);
	}
	if (_kind == "camera") {
		return __gm3d_ed_track_camera(_ed, _node, _label);
	}
	if (_kind == "environment") {
		return __gm3d_ed_track_env(_ed, _node, _label);
	}
	if (_ed == undefined || _node == undefined) {
		return undefined;
	}
	var _pp = _node.getLocalPosition();
	__gm3d_ed_spawn_register(_ed, _node, _asset, [_pp.x, _pp.y, _pp.z], _label);
	return _node;
}

// Generates unique nonconflicting node label.
function __gm3d_ed_fresh_label(_ed, _base) {
	if (_base == undefined || !is_string(_base) || _base == "") {
		_base = "node";
	}
	var _reg = _ed.tracked;
	if (!is_array(_reg)) {
		return _base;
	}
	var _lbl = _base;
	var _n = 2;
	var _taken = true;
	while (_taken) {
		_taken = false;
		for (var _i = 0; _i < array_length(_reg); _i++) {
			if (_reg[_i].label == _lbl) {
				_taken = true;
				break;
			}
		}
		if (_taken) {
			_lbl = _base + " " + string(_n);
			_n++;
		}
	}
	return _lbl;
}

// Updates registry positions from scene nodes.
function __gm3d_ed_rows_follow(_ed, _nodes) {
	if (!is_array(_nodes)) {
		return;
	}
	var _claimed = [];
	for (var _i = 0; _i < array_length(_nodes); _i++) {
		var _nd = _nodes[_i];
		if (_nd == undefined) {
			continue;
		}
		var _nm = _nd.name;
		var _pp = undefined;
		try {
			_pp = _nd.getLocalPosition();
		} catch (_e) {
			continue;
		}
		var _reg = _ed.tracked;
		if (!is_array(_reg)) {
			continue;
		}
		var _best = undefined;
		var _bestd = 1000000000;
		for (var _j = 0; _j < array_length(_reg); _j++) {
			var _re = _reg[_j];
			if (_re.name != _nm) {
				continue;
			}
			var _taken = false;
			for (var _k = 0; _k < array_length(_claimed); _k++) {
				if (_claimed[_k] == _re) {
					_taken = true;
					break;
				}
			}
			if (_taken) {
				continue;
			}
			var _dx = _re.pos[0] - _pp.x;
			var _dy = _re.pos[1] - _pp.y;
			var _dz = _re.pos[2] - _pp.z;
			var _d = _dx * _dx + _dy * _dy + _dz * _dz;
			if (_d < _bestd) {
				_bestd = _d;
				_best = _re;
			}
		}
		if (_best == undefined) {
			continue;
		}
		_best.pos = [_pp.x, _pp.y, _pp.z];
		array_push(_claimed, _best);
	}
}

// Removes node from tracking registry.
function __gm3d_ed_spawn_unregister(_ed, _node) {
	var _reg = _ed.tracked;
	if (!is_array(_reg)) {
		return;
	}
	var _nm = _node.name;
	var _pp = _node.getLocalPosition();
	var _best = -1;
	var _bestd = 1000000000;
	for (var _k = 0; _k < array_length(_reg); _k++) {
		var _re = _reg[_k];
		if (_re.name != _nm) {
			continue;
		}
		var _d =
			(_re.pos[0] - _pp.x) * (_re.pos[0] - _pp.x) +
			(_re.pos[1] - _pp.y) * (_re.pos[1] - _pp.y) +
			(_re.pos[2] - _pp.z) * (_re.pos[2] - _pp.z);
		if (_d < _bestd) {
			_bestd = _d;
			_best = _k;
		}
	}
	if (_best >= 0) {
		array_delete(_reg, _best, 1);
	}
}

// Finds closest registry entry for node.
function __gm3d_ed_registry_find(_ed, _node) {
	var _reg = [];
	_reg = _ed.tracked;
	if (!is_array(_reg)) {
		return undefined;
	}
	var _nm = undefined;
	_nm = _node.name;
	var _pp = undefined;
	_pp = _node.getLocalPosition();
	var _best = undefined;
	var _bestd = 1000000000;
	for (var _j = 0; _j < array_length(_reg); _j++) {
		var _re = _reg[_j];
		if (_re.name != _nm) {
			continue;
		}
		var _dx = _re.pos[0] - _pp.x;
		var _dy = _re.pos[1] - _pp.y;
		var _dz = _re.pos[2] - _pp.z;
		var _d = _dx * _dx + _dy * _dy + _dz * _dz;
		if (_d < _bestd) {
			_bestd = _d;
			_best = _re;
		}
	}
	return _best;
}

// Returns asset name for node.
function __gm3d_ed_asset_name(_ed, _node) {
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en == undefined) {
		return undefined;
	}
	return _en.asset;
}

// Returns display label for node.
function __gm3d_ed_label_get(_ed, _node) {
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en != undefined && is_string(_en.label) && _en.label != "") {
		return _en.label;
	}
	var _nm = "node";
	_nm = _node.name;
	return _nm;
}

// Builds asset descriptor with transform.
function __gm3d_ed_asset_desc(_ed, _node) {
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en == undefined) {
		return undefined;
	}
	var _label = _en.label;
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = _node.name;
	}
	var _p = _node.getLocalPosition();
	var _q = _node.getLocalRotation();
	var _s = _node.getLocalScale();
	var _fc = true;
	var _fr = true;
	if (is_struct(_en.data)) {
		_fc = _en.data.castShadows == true;
		_fr = _en.data.receiveShadows == true;
	}
	return {
		asset: _en.asset,
		name: _label,
		position: [_p.x, _p.y, _p.z],
		rotation: [_q.x, _q.y, _q.z, _q.w],
		scale: [_s.x, _s.y, _s.z],
		flags: { castShadows: _fc, receiveShadows: _fr },
	};
}

// Lists tracked root scene nodes.
function __gm3d_ed_root_tracked(_ed) {
	var _out = [];
	var _roots = _ed.rt.scene.getNodes();
	for (var _i = 0; _i < array_length(_roots); _i++) {
		var _nd = _roots[_i];
		if (_nd.parent != undefined) {
			continue;
		}

		if (_ed != undefined && variable_struct_exists(_ed, "rt") && is_struct(_ed.rt)) {
			if (variable_struct_exists(_ed.rt, "cam") && _nd == _ed.rt.cam) {
				continue;
			}
		}
		if (__gm3d_ed_registry_find(_ed, _nd) == undefined) {
			continue;
		}
		array_push(_out, _nd);
	}
	return _out;
}

// Resolves registry entries to scene nodes.
function __gm3d_ed_tracked_nodes(_ed) {
	var _out = [];
	if (_ed == undefined || _ed.rt == undefined || _ed.rt.scene == undefined) {
		return _out;
	}
	if (!is_array(_ed.tracked)) {
		return _out;
	}
	var _roots = _ed.rt.scene.getNodes();
	var _used = [];
	for (var _u = 0; _u < array_length(_roots); _u++) {
		array_push(_used, false);
	}
	for (var _i = 0; _i < array_length(_ed.tracked); _i++) {
		var _en = _ed.tracked[_i];
		if (!is_struct(_en) || !is_string(_en.name) || !is_array(_en.pos) || array_length(_en.pos) != 3) {
			continue;
		}
		var _best = -1;
		var _bestd = 1000000000;
		for (var _j = 0; _j < array_length(_roots); _j++) {
			if (_used[_j]) {
				continue;
			}
			var _nd = _roots[_j];
			if (_nd == undefined || _nd.parent != undefined) {
				continue;
			}
			if (__gm3d_ed_is_grid(_ed, _nd)) {
				continue;
			}
			if (variable_struct_exists(_ed.rt, "cam") && _nd == _ed.rt.cam) {
				continue;
			}
			if (variable_struct_exists(_ed, "drag_preview") && _nd == _ed.drag_preview) {
				continue;
			}
			if (_nd.name != _en.name) {
				continue;
			}
			var _pp = _nd.getLocalPosition();
			var _dx = _en.pos[0] - _pp.x;
			var _dy = _en.pos[1] - _pp.y;
			var _dz = _en.pos[2] - _pp.z;
			var _d = _dx * _dx + _dy * _dy + _dz * _dz;
			if (_d < _bestd) {
				_bestd = _d;
				_best = _j;
			}
		}
		if (_best >= 0) {
			_used[_best] = true;
			array_push(_out, _roots[_best]);
		}
	}
	return _out;
}

// Returns default light property values.
function __gm3d_ed_light_defaults() {
	return { type: "directional", color: [255, 255, 255], intensity: 1.0, range: 50.0, inner: 30.0, outer: 45.0, enabled: true, shadow: false, shadowRes: 2048, shadowDist: 20.0, shadowNormal: 0.05 };
}

// Returns default camera property values.
function __gm3d_ed_camera_defaults() {
	return { projection: "perspective", fov: 60.0, ow: 10.0, oh: 10.0, near: 0.1, far: 500.0, enabled: true };
}

// Returns default environment property values.
function __gm3d_ed_env_defaults() {
	return {
		size: [20000.0, 20000.0, 20000.0],
		ambient: [70, 70, 85],
		fog: false,
		fogcolor: [192, 192, 192],
		fogstart: 20.0,
		fogend: 100.0,
		enabled: true,
	};
}

// Safely calls bound component getter with fallback.
function __gm3d_ed_comp_get(_comp, _m, _fb) {
	if (_comp == undefined || !is_string(_m) || _m == "") {
		return _fb;
	}
	try {
		var _f = _comp[$ _m];
		if (_f == undefined) {
			return _fb;
		}
		return method(_comp, _f)();
	} catch (_e) {
		return _fb;
	}
}

// Converts light enum to string.
function __gm3d_ed_light_type_to_str(_v) {
	try {
		if (_v == GM3D_ELightType.Point) {
			return "point";
		}
		if (_v == GM3D_ELightType.Spot) {
			return "spot";
		}
		if (_v == GM3D_ELightType.Directional) {
			return "directional";
		}
	} catch (_e) {
	}
	return undefined;
}

// Converts light string to enum.
function __gm3d_ed_light_type_to_enum(_s) {
	if (_s == "point") {
		return GM3D_ELightType.Point;
	}
	if (_s == "spot") {
		return GM3D_ELightType.Spot;
	}
	return GM3D_ELightType.Directional;
}

// Converts projection enum to string.
function __gm3d_ed_cam_proj_to_str(_v) {
	try {
		if (_v == GM3D_ECameraProjection.Orthographic) {
			return "ortho";
		}
		if (_v == GM3D_ECameraProjection.Perspective) {
			return "perspective";
		}
	} catch (_e) {
	}
	return undefined;
}

// Converts projection string to enum.
function __gm3d_ed_cam_proj_to_enum(_s) {
	if (_s == "ortho") {
		return GM3D_ECameraProjection.Orthographic;
	}
	return GM3D_ECameraProjection.Perspective;
}

// Reads light properties from node.
function __gm3d_ed_light_read(_node) {
	var _d = __gm3d_ed_light_defaults();
	var _lc = undefined;
	try {
		_lc = _node.getLightComponent();
	} catch (_e) {
		return _d;
	}
	if (_lc == undefined) {
		return _d;
	}
	var _t = __gm3d_ed_light_type_to_str(__gm3d_ed_comp_get(_lc, "getType", undefined));
	if (_t != undefined) {
		_d.type = _t;
	}
	var _c = __gm3d_ed_comp_get(_lc, "getColor", undefined);
	if (is_real(_c)) {
		_d.color = [colour_get_red(_c), colour_get_green(_c), colour_get_blue(_c)];
	}
	var _v = __gm3d_ed_comp_get(_lc, "getIntensity", undefined);
	if (is_real(_v)) {
		_d.intensity = _v;
	}
	_v = __gm3d_ed_comp_get(_lc, "getRange", undefined);
	if (is_real(_v) && _v > 0) {
		_d.range = _v;
	}
	_v = __gm3d_ed_comp_get(_lc, "getInnerConeAngle", undefined);
	if (is_real(_v)) {
		_d.inner = radtodeg(_v);
	}
	_v = __gm3d_ed_comp_get(_lc, "getOuterConeAngle", undefined);
	if (is_real(_v)) {
		_d.outer = radtodeg(_v);
	}
	_v = __gm3d_ed_comp_get(_lc, "getEnabled", undefined);
	if (_v != undefined) {
		_d.enabled = (_v == true || _v == 1);
	}
	_v = __gm3d_ed_comp_get(_lc, "getShadowEnabled", undefined);
	if (_v != undefined) {
		_d.shadow = (_v == true || _v == 1);
	}
	_v = __gm3d_ed_comp_get(_lc, "getShadowResolution", undefined);
	if (is_real(_v) && _v > 0) {
		_d.shadowRes = _v;
	}
	_v = __gm3d_ed_comp_get(_lc, "getShadowDistance", undefined);
	if (is_real(_v) && _v > 0) {
		_d.shadowDist = _v;
	}
	_v = __gm3d_ed_comp_get(_lc, "getShadowNormalOffset", undefined);
	if (is_real(_v) && _v >= 0) {
		_d.shadowNormal = _v;
	}
	return _d;
}

// Applies light properties to node.
function __gm3d_ed_light_apply(_node, _d) {
	if (_node == undefined || _d == undefined) {
		return;
	}
	var _lc = undefined;
	try {
		_lc = _node.getLightComponent();
	} catch (_e) {
		return;
	}
	if (_lc == undefined) {
		return;
	}
	try {
		_lc.setType(__gm3d_ed_light_type_to_enum(_d.type));
	} catch (_e) {
	}
	try {
		var _cc = _d.color;
		_lc.setColor(make_colour_rgb(clamp(_cc[0], 0, 255), clamp(_cc[1], 0, 255), clamp(_cc[2], 0, 255)));
	} catch (_e) {
	}
	try {
		_lc.setIntensity(max(_d.intensity, 0));
	} catch (_e) {
	}
	if (_d.type != "directional") {
		try {
			_lc.setRange(max(_d.range, 0.01));
		} catch (_e) {
		}
	}
	if (_d.type == "spot") {
		try {
			_lc.setInnerConeAngle(degtorad(clamp(_d.inner, 0, 89)));
		} catch (_e) {
		}
		try {
			_lc.setOuterConeAngle(degtorad(clamp(_d.outer, 1, 89)));
		} catch (_e) {
		}
	}
	try {
		_lc.setEnabled(_d.enabled == true);
	} catch (_e) {
	}
	if (_d.type == "directional") {
		try {
			_lc.setShadowEnabled(_d.shadow == true);
		} catch (_e) {
			__gm3d_ed_shadow_warn();
		}
		try {
			_lc.setShadowResolution(clamp(round(_d.shadowRes), 128, 4096));
		} catch (_e) {
			__gm3d_ed_shadow_warn();
		}
		try {
			_lc.setShadowDistance(max(_d.shadowDist, 1));
		} catch (_e) {
			__gm3d_ed_shadow_warn();
		}
		try {
			_lc.setShadowNormalOffset(clamp(_d.shadowNormal, 0, 1));
		} catch (_e) {
			__gm3d_ed_shadow_warn();
		}
	}
	var _pv = gm3d_editor_inst();
	if (_pv != undefined && _pv.show_shadows == false) {
		try {
			_lc.setShadowEnabled(false);
		} catch (_e) {
		}
	}
}

// Warns once when the runtime shadow API is missing.
function __gm3d_ed_shadow_warn() {
	if (variable_global_exists("gm3d_ed_shadow_warned") && global.gm3d_ed_shadow_warned == true) {
		return;
	}
	global.gm3d_ed_shadow_warned = true;
	try {
		show_debug_message("[gm3d_editor] shadow API unavailable on GM3D_LightComponent");
	} catch (_e) {
	}
}

// Applies shadow preview override to tracked directionals.
function __gm3d_ed_shadowpreview_apply(_ed) {
	if (_ed == undefined) {
		return;
	}
	var _roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		if (__gm3d_ed_kind_of(_ed, _roots[_i]) != "light") {
			continue;
		}
		var _en = __gm3d_ed_registry_find(_ed, _roots[_i]);
		if (_en == undefined || !is_struct(_en.data) || _en.data.type != "directional") {
			continue;
		}
		try {
			var _lc = _roots[_i].getLightComponent();
			if (_lc == undefined) {
				continue;
			}
			_lc.setShadowEnabled(_ed.show_shadows != false && _en.data.shadow == true);
		} catch (_e) {
		}
	}
}

// Reads camera properties from node.
function __gm3d_ed_camera_read(_node) {
	var _d = __gm3d_ed_camera_defaults();
	var _cc = undefined;
	try {
		_cc = _node.getCameraComponent();
	} catch (_e) {
		return _d;
	}
	if (_cc == undefined) {
		return _d;
	}
	var _p = __gm3d_ed_cam_proj_to_str(__gm3d_ed_comp_get(_cc, "getProjection", undefined));
	if (_p != undefined) {
		_d.projection = _p;
	}
	var _v = __gm3d_ed_comp_get(_cc, "getFovY", undefined);
	if (is_real(_v) && _v > 0) {
		_d.fov = radtodeg(_v);
	}
	_v = __gm3d_ed_comp_get(_cc, "getOrthoWidth", undefined);
	if (is_real(_v) && _v > 0) {
		_d.ow = _v;
	}
	_v = __gm3d_ed_comp_get(_cc, "getOrthoHeight", undefined);
	if (is_real(_v) && _v > 0) {
		_d.oh = _v;
	}
	_v = __gm3d_ed_comp_get(_cc, "getNear", undefined);
	if (is_real(_v) && _v > 0) {
		_d.near = _v;
	}
	_v = __gm3d_ed_comp_get(_cc, "getFar", undefined);
	if (is_real(_v) && _v > _d.near) {
		_d.far = _v;
	}
	_v = __gm3d_ed_comp_get(_cc, "getEnabled", undefined);
	if (_v != undefined) {
		_d.enabled = (_v == true || _v == 1);
	}
	return _d;
}

// Applies camera properties to node.
function __gm3d_ed_camera_apply(_node, _d) {
	if (_node == undefined || _d == undefined) {
		return;
	}
	var _cc = undefined;
	try {
		_cc = _node.getCameraComponent();
	} catch (_e) {
		return;
	}
	if (_cc == undefined) {
		return;
	}
	try {
		_cc.setProjection(__gm3d_ed_cam_proj_to_enum(_d.projection));
	} catch (_e) {
	}
	if (_d.projection == "ortho") {
		try {
			_cc.setOrthoWidth(max(_d.ow, 0.01));
		} catch (_e) {
		}
		try {
			_cc.setOrthoHeight(max(_d.oh, 0.01));
		} catch (_e) {
		}
	} else {
		try {
			_cc.setFovY(degtorad(clamp(_d.fov, 1, 179)));
		} catch (_e) {
		}
	}
	try {
		_cc.setNear(max(_d.near, 0.01));
	} catch (_e) {
	}
	try {
		_cc.setFar(max(_d.far, _d.near + 0.01));
	} catch (_e) {
	}
	try {
		_cc.setEnabled(_d.enabled == true);
	} catch (_e) {
	}
}

// Reads environment properties from node.
function __gm3d_ed_env_read(_node) {
	var _d = __gm3d_ed_env_defaults();
	var _ec = undefined;
	try {
		_ec = _node.getEnvironmentVolumeComponent();
	} catch (_e) {
		return _d;
	}
	if (_ec == undefined) {
		return _d;
	}
	var _s = __gm3d_ed_comp_get(_ec, "getSize", undefined);
	if (is_array(_s) && array_length(_s) == 3) {
		_d.size = [max(_s[0], 0.01), max(_s[1], 0.01), max(_s[2], 0.01)];
	} else if (is_struct(_s) && variable_struct_exists(_s, "x")) {
		_d.size = [max(_s.x, 0.01), max(_s.y, 0.01), max(_s.z, 0.01)];
	}
	var _c = __gm3d_ed_comp_get(_ec, "getAmbientColor", undefined);
	if (is_real(_c)) {
		_d.ambient = [colour_get_red(_c), colour_get_green(_c), colour_get_blue(_c)];
	}
	var 	_v = __gm3d_ed_comp_get(_ec, "getFogEnabled", undefined);
	if (_v != undefined) {
		_d.fog = (_v == true || _v == 1);
	}
	_c = __gm3d_ed_comp_get(_ec, "getFogColor", undefined);
	if (is_real(_c)) {
		_d.fogcolor = [colour_get_red(_c), colour_get_green(_c), colour_get_blue(_c)];
	}
	_v = __gm3d_ed_comp_get(_ec, "getFogStart", undefined);
	if (is_real(_v)) {
		_d.fogstart = _v;
	}
	_v = __gm3d_ed_comp_get(_ec, "getFogEnd", undefined);
	if (is_real(_v)) {
		_d.fogend = _v;
	}
	_v = __gm3d_ed_comp_get(_ec, "getEnabled", undefined);
	if (_v != undefined) {
		_d.enabled = (_v == true || _v == 1);
	}
	return _d;
}

// Applies environment properties to node.
function __gm3d_ed_env_apply(_node, _d) {
	if (_node == undefined || _d == undefined) {
		return;
	}
	var _ec = undefined;
	try {
		_ec = _node.getEnvironmentVolumeComponent();
	} catch (_e) {
		return;
	}
	if (_ec == undefined) {
		return;
	}
	try {
		_ec.setSize(new GM3D_Vec3(max(_d.size[0], 0.01), max(_d.size[1], 0.01), max(_d.size[2], 0.01)));
	} catch (_e) {
	}
	try {
		var _ac = _d.ambient;
		_ec.setAmbientColor(make_colour_rgb(clamp(_ac[0], 0, 255), clamp(_ac[1], 0, 255), clamp(_ac[2], 0, 255)));
	} catch (_e) {
	}
	try {
		_ec.setFogEnabled(_d.fog == true);
	} catch (_e) {
	}
	try {
		var _fc = _d.fogcolor;
		_ec.setFogColor(make_colour_rgb(clamp(_fc[0], 0, 255), clamp(_fc[1], 0, 255), clamp(_fc[2], 0, 255)));
	} catch (_e) {
	}
	try {
		_ec.setFogStart(_d.fogstart);
	} catch (_e) {
	}
	try {
		_ec.setFogEnd(max(_d.fogend, _d.fogstart + 0.01));
	} catch (_e) {
	}
	try {
		_ec.setEnabled(_d.enabled == true);
	} catch (_e) {
	}
}

// Determines node kind from registry.
function __gm3d_ed_kind_of(_ed, _node) {
	if (_node == undefined) {
		return undefined;
	}
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en != undefined && is_string(_en.kind) && _en.kind != "") {
		return _en.kind;
	}
	try {
		if (_node.getLightComponent() != undefined) {
			return "light";
		}
	} catch (_e) {
	}
	try {
		if (_node.getCameraComponent() != undefined) {
			return "camera";
		}
	} catch (_e) {
	}
	try {
		if (_node.getEnvironmentVolumeComponent() != undefined) {
			return "environment";
		}
	} catch (_e) {
	}
	if (_en != undefined) {
		return "asset";
	}
	return undefined;
}

// Registers existing light node for editing.
function __gm3d_ed_track_light(_ed, _node, _label = undefined) {
	if (_ed == undefined || _node == undefined) {
		return undefined;
	}
	var _d = __gm3d_ed_light_read(_node);
	var _pp = _node.getLocalPosition();
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = __gm3d_ed_fresh_label(_ed, _node.name);
	}
	__gm3d_ed_kind_register(_ed, _node, "light", "", [_pp.x, _pp.y, _pp.z], _label, _d);
	if (_d.type == "directional") {
		__gm3d_ed_hidden_set(_ed, _node, true);
	}
	return _node;
}

// Registers existing camera node for editing.
function __gm3d_ed_track_camera(_ed, _node, _label = undefined) {
	if (_ed == undefined || _node == undefined) {
		return undefined;
	}
	var _d = __gm3d_ed_camera_read(_node);
	var _pp = _node.getLocalPosition();
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = __gm3d_ed_fresh_label(_ed, _node.name);
	}
	__gm3d_ed_kind_register(_ed, _node, "camera", "", [_pp.x, _pp.y, _pp.z], _label, _d);
	__gm3d_ed_cameras_mute(_ed);
	return _node;
}

// Registers existing environment node for editing.
function __gm3d_ed_track_env(_ed, _node, _label = undefined) {
	if (_ed == undefined || _node == undefined) {
		return undefined;
	}
	var _d = __gm3d_ed_env_read(_node);
	var _pp = _node.getLocalPosition();
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = __gm3d_ed_fresh_label(_ed, _node.name);
	}
	__gm3d_ed_kind_register(_ed, _node, "environment", "", [_pp.x, _pp.y, _pp.z], _label, _d);
	__gm3d_ed_hidden_set(_ed, _node, true);
	return _node;
}

// Creates new light node in scene.
function __gm3d_ed_create_light(_ed, _type) {
	if (_ed == undefined || _ed.rt == undefined) {
		return undefined;
	}
	if (_type != "point" && _type != "spot") {
		_type = "directional";
	}
	var _hb = __gm3d_ed_history_snap(_ed);
	var _base = _type == "point" ? "Point" : _type == "spot" ? "Spot" : "Directional";
	var _lbl = __gm3d_ed_fresh_label(_ed, _base);
	var _node = _ed.rt.scene.createNode(_lbl);
	if (_node == undefined) {
		return undefined;
	}
	var _lc = new GM3D_LightComponent();
	_node.addComponent(_lc);
	if (_type == "directional") {
		_node.setLocalPosition(new GM3D_Vec3(0, 3, 0));
		_node.setLocalRotation(__gm3d_ed_euler_to_quat(degtorad(-50), 0, 0));
	} else {
		_node.setLocalPosition(new GM3D_Vec3(0, 2, 0));
	}
	var _d = __gm3d_ed_light_defaults();
	_d.type = _type;
	__gm3d_ed_light_apply(_node, _d);
	_ed.rt.scene.update(0);
	var _pp = _node.getLocalPosition();
	__gm3d_ed_kind_register(_ed, _node, "light", "", [_pp.x, _pp.y, _pp.z], _lbl, _d);
	if (_d.type == "directional") {
		__gm3d_ed_hidden_set(_ed, _node, true);
	}
	_ed.sel = [_node];
	_ed.giz.drag = -1;
	__gm3d_ed_sel_apply_tool(_ed);
	__gm3d_ed_history_commit(_ed, _hb);
	return _node;
}

// Creates new camera node in scene.
function __gm3d_ed_create_camera(_ed, _proj) {
	if (_ed == undefined || _ed.rt == undefined) {
		return undefined;
	}
	if (_proj != "ortho") {
		_proj = "perspective";
	}
	var _hb = __gm3d_ed_history_snap(_ed);
	var _lbl = __gm3d_ed_fresh_label(_ed, _proj == "ortho" ? "OrthoCam" : "Camera");
	var _node = _ed.rt.scene.createNode(_lbl);
	if (_node == undefined) {
		return undefined;
	}
	var _cc = new GM3D_CameraComponent();
	_node.addComponent(_cc);
	_node.setLocalPosition(new GM3D_Vec3(0, 2, 5));
	var _d = __gm3d_ed_camera_defaults();
	_d.projection = _proj;
	__gm3d_ed_camera_apply(_node, _d);
	_ed.rt.scene.update(0);
	var _pp = _node.getLocalPosition();
	__gm3d_ed_kind_register(_ed, _node, "camera", "", [_pp.x, _pp.y, _pp.z], _lbl, _d);
	_ed.sel = [_node];
	_ed.giz.drag = -1;
	__gm3d_ed_history_commit(_ed, _hb);
	__gm3d_ed_cameras_mute(_ed);
	return _node;
}

// Creates new environment node in scene.
function __gm3d_ed_create_env(_ed) {
	if (_ed == undefined || _ed.rt == undefined) {
		return undefined;
	}
	if (__gm3d_ed_env_node(_ed) != undefined) {
		return undefined;
	}
	var _hb = __gm3d_ed_history_snap(_ed);
	var _lbl = __gm3d_ed_fresh_label(_ed, "Environment");
	var _node = _ed.rt.scene.createNode(_lbl);
	if (_node == undefined) {
		return undefined;
	}
	var _ec = new GM3D_EnvironmentVolumeComponent();
	_node.addComponent(_ec);
	var _d = __gm3d_ed_env_defaults();
	__gm3d_ed_env_apply(_node, _d);
	_ed.rt.scene.update(0);
	__gm3d_ed_kind_register(_ed, _node, "environment", "", [0, 0, 0], _lbl, _d);
	__gm3d_ed_hidden_set(_ed, _node, true);
	_ed.sel = [_node];
	_ed.giz.drag = -1;
	__gm3d_ed_history_commit(_ed, _hb);
	return _node;
}

// Finds tracked environment node.
function __gm3d_ed_env_node(_ed) {
	var _roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		if (__gm3d_ed_kind_of(_ed, _roots[_i]) == "environment") {
			return _roots[_i];
		}
	}
	return undefined;
}

// Disables all tracked scene cameras.
function __gm3d_ed_cameras_mute(_ed) {
	if (_ed == undefined || _ed.rt == undefined) {
		return;
	}
	var _roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		if (__gm3d_ed_kind_of(_ed, _roots[_i]) != "camera") {
			continue;
		}
		try {
			var _cc = _roots[_i].getCameraComponent();
			if (_cc != undefined) {
				_cc.setEnabled(false);
			}
		} catch (_e) {
		}
	}
}

// Restores tracked cameras enabled state.
function __gm3d_ed_cameras_restore(_ed) {
	if (_ed == undefined || _ed.rt == undefined) {
		return;
	}
	var _roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		var _en = __gm3d_ed_registry_find(_ed, _roots[_i]);
		if (_en == undefined || !is_struct(_en.data)) {
			continue;
		}
		if (__gm3d_ed_kind_of(_ed, _roots[_i]) != "camera") {
			continue;
		}
		try {
			var _cc = _roots[_i].getCameraComponent();
			if (_cc != undefined) {
				_cc.setEnabled(_en.data.enabled == true);
			}
		} catch (_e) {
		}
	}
}

// Checks if gizmo tool applies.
function __gm3d_ed_tool_allowed(_ed, _node, _tool) {
	if (_node == undefined) {
		return false;
	}
	var _kind = __gm3d_ed_kind_of(_ed, _node);
	if (_kind == undefined || _kind == "asset") {
		return true;
	}
	if (_kind == "environment") {
		return false;
	}
	if (_tool == Gm3dEdTool.Scale) {
		return false;
	}
	if (_kind == "camera") {
		return true;
	}
	var _type = "directional";
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en != undefined && is_struct(_en.data) && is_string(_en.data.type)) {
		_type = _en.data.type;
	}
	if (_tool == Gm3dEdTool.Translate) {
		return true;
	}
	if (_tool == Gm3dEdTool.Rotate) {
		return _type != "point";
	}
	return true;
}

// Checks if gizmo can manipulate selection.
function __gm3d_ed_gizmo_allowed(_ed) {
	if (_ed == undefined || !is_array(_ed.sel) || array_length(_ed.sel) == 0) {
		return false;
	}
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		var _sn = _ed.sel[_i];
		if (__gm3d_ed_hidden_get(_ed, _sn)) {
			continue;
		}
		if (__gm3d_ed_tool_allowed(_ed, _sn, _ed.giz.tool)) {
			return true;
		}
	}
	return false;
}

// Auto selects gizmo tool for light.
function __gm3d_ed_sel_apply_tool(_ed) {
	if (_ed == undefined || !is_array(_ed.sel) || array_length(_ed.sel) != 1) {
		return;
	}
	var _node = _ed.sel[0];
	if (__gm3d_ed_kind_of(_ed, _node) != "light") {
		return;
	}
	var _type = "directional";
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en != undefined && is_struct(_en.data) && is_string(_en.data.type)) {
		_type = _en.data.type;
	}
	if (_type == "directional") {
		_ed.giz.tool = Gm3dEdTool.Rotate;
	} else if (_type == "point") {
		_ed.giz.tool = Gm3dEdTool.Translate;
	}
}

// Checks if node is hidden.
function __gm3d_ed_hidden_get(_ed, _node) {
	if (_ed == undefined || _node == undefined) {
		return false;
	}
	var _en = __gm3d_ed_registry_find(_ed, _node);
	return _en != undefined && _en.hidden == true;
}

// Hides or unhides node meshes.
function __gm3d_ed_hidden_set(_ed, _node, _hide) {
	if (_ed == undefined || _node == undefined) {
		return false;
	}
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en == undefined) {
		return false;
	}
	_en.hidden = (_hide == true);
	var _stack = [_node];
	while (array_length(_stack) > 0) {
		var _cur = array_pop(_stack);
		try {
			var _mc = _cur.getMeshComponent();
			if (_mc != undefined) {
				_mc.setEnabled(!_en.hidden);
			}
		} catch (_e) {
		}
		try {
			var _sk = _cur.getSkinnedMeshComponent();
			if (_sk != undefined) {
				_sk.setEnabled(!_en.hidden);
			}
		} catch (_e) {
		}
		var _kids = _cur.getChildren();
		for (var _k = 0; _k < array_length(_kids); _k++) {
			array_push(_stack, _kids[_k]);
		}
	}
	if (_ed.rt != undefined && _ed.rt.scene != undefined) {
		_ed.rt.scene.update(0);
	}
	return true;
}

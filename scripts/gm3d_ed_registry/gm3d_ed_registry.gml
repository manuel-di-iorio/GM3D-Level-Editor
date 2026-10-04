// Adds model asset to editor library.
function gm3d_editor_asset_add(_name, _model, _thumb = -1) {
	var _ed = gm3d_editor_inst();
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
	if (_thumb != -1 && sprite_exists(_thumb)) {
		_entry.thumb = _thumb;
	}
	array_push(_ed.assets, _entry);
}

// Clears all editor library assets.
function gm3d_editor_asset_clear() {
	var _ed = gm3d_editor_inst();
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
		if (sprite_exists(_a.thumb)) {
			sprite_delete(_a.thumb);
		}
		_a.thumb = -1;
		_a.thumb_owned = undefined;
	}
}

// Captures library thumbnails once at startup.
function gm3d_editor_capture_thumbnails() {
	var _ed = gm3d_editor_inst();
	if (_ed == undefined || _ed.thumbs_done == true) {
		return;
	}
	if (!is_array(_ed.assets) || array_length(_ed.assets) == 0) {
		return;
	}
	_ed.thumbs_done = true;
	var _size = 256;
	var _surf = undefined;
	_surf = surface_create(_size, _size);
	if (_surf == undefined || !surface_exists(_surf)) {
		return;
	}
	var _ts = undefined;
	_ts = GM3D_Scene.createEmpty();
	if (_ts == undefined) {
		surface_free(_surf);
		return;
	}
	var _renderer = undefined;
	_renderer = new GM3D_Renderer();
	if (_renderer == undefined) {
		_ts.destroy();
		surface_free(_surf);
		return;
	}
	var _env = _ts.createNode("__thumb_env");
	var _envc = new GM3D_EnvironmentVolumeComponent();
	_env.addComponent(_envc);
	_envc.setSize(new GM3D_Vec3(20000, 20000, 20000));
	_envc.setAmbientColor(make_colour_rgb(70, 70, 85));
	_envc.setFogEnabled(false);
	var _sun = _ts.createNode("__thumb_sun");
	var _sunc = new GM3D_LightComponent();
	_sun.addComponent(_sunc);
	_sunc.setType(GM3D_ELightType.Directional);
	_sunc.setColor(c_white);
	_sunc.setIntensity(1.0);
	_sunc.setShadowEnabled(true);
	_sunc.setShadowResolution(1024);
	_sunc.setShadowDistance(30.0);
	_sunc.setShadowNormalOffset(0.05);
	var _cam = _ts.createNode("__thumb_cam");
	var _camc = new GM3D_CameraComponent();
	_cam.addComponent(_camc);
	_camc.setProjection(GM3D_ECameraProjection.Perspective);
	_camc.setFovY(degtorad(40));
	_camc.setNear(0.1);
	_camc.setFar(10000);
	_camc.setScreenRect([0.0, 0.0, 1.0, 1.0]);
	_camc.setEnabled(true);
		for (var _i = 0; _i < array_length(_ed.assets); _i++) {
		var _a = _ed.assets[_i];
		if (!is_struct(_a) || _a.model == undefined) {
			continue;
		}
		var _node = undefined;
		_node = _a.model.spawnInto(_ts, undefined);
		if (_node == undefined) {
			continue;
		}
		_node.setLocalPosition(new GM3D_Vec3(0, 0, 0));
		_node.setLocalScale(new GM3D_Vec3(1, 1, 1));
		__gm3d_ed_magenta_fix(_ed, _node);
		if (variable_struct_exists(_ed.rt, "on_spawn")) {
			_ed.rt.on_spawn(_ed.inst, _node, _a.name, _a.model);
		}
		__gm3d_ed_thumb_frame(_ed, _ts, _cam, _a.model);
		_ts.update(0);
		surface_set_target(_surf);
		draw_clear_alpha(c_black, 0);
		_renderer.render(_ts);
		surface_reset_target();
		var _spr = sprite_create_from_surface(_surf, 0, 0, _size, _size, false, true, 0, 0);
		if (sprite_exists(_spr)) {
			_a.thumb = _spr;
			_a.thumb_owned = true;
		}
		__gm3d_ed_destroy_subtree(_node);
		_ts.update(0);
		}
	_ts.destroy();
	surface_free(_surf);
	_renderer = undefined;
}

// Frames a library model for thumbnail capture.
function __gm3d_ed_thumb_frame(_ed, _ts, _cam, _model) {
	var _ctr = new GM3D_Vec3(0, 1, 0);
	var _rad = 2.0;
	var _bs = _model.getBoundingSphere();
	if (is_struct(_bs) && variable_struct_exists(_bs, "origin") && variable_struct_exists(_bs, "radius")) {
		var _c = _bs.origin;
		_ctr = new GM3D_Vec3(_c.x, _c.y, _c.z);
		_rad = max(_bs.radius, 0.1);
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
	if (__gm3d_ed_locked_get(_ed, _node)) {
		return;
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
	if (!variable_struct_exists(_ed, "reg_by_name") || !is_struct(_ed.reg_by_name)) {
		_ed.reg_by_name = {};
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
		locked: false,
	});
	__gm3d_ed_reg_index_add(_ed, _nm);
	if (_ed.unlit_quiet != true) {
		__gm3d_ed_unlit_apply(_ed);
	}
}

// Adds newest tracked entry to name index.
function __gm3d_ed_reg_index_add(_ed, _name) {
	if (_ed == undefined || !is_string(_name) || !is_array(_ed.tracked) || array_length(_ed.tracked) == 0) {
		return;
	}
	if (!variable_struct_exists(_ed, "reg_by_name") || !is_struct(_ed.reg_by_name)) {
		_ed.reg_by_name = {};
	}
	var _en = _ed.tracked[array_length(_ed.tracked) - 1];
	var _b = undefined;
	if (variable_struct_exists(_ed.reg_by_name, _name)) {
		_b = _ed.reg_by_name[$ _name];
	}
	if (!is_array(_b)) {
		_b = [];
		_ed.reg_by_name[$ _name] = _b;
	}
	array_push(_b, _en);
}

// Rebuilds one name bucket from tracked array.
function __gm3d_ed_reg_index_sync(_ed, _name) {
	if (_ed == undefined || !is_string(_name)) {
		return;
	}
	if (!variable_struct_exists(_ed, "reg_by_name") || !is_struct(_ed.reg_by_name)) {
		_ed.reg_by_name = {};
	}
	var _b = [];
	if (is_array(_ed.tracked)) {
		for (var _i = 0; _i < array_length(_ed.tracked); _i++) {
			var _re = _ed.tracked[_i];
			var _rn = undefined;
			_rn = _re.name;
			if (_rn == _name) {
				array_push(_b, _re);
			}
		}
	}
	if (array_length(_b) > 0) {
		_ed.reg_by_name[$ _name] = _b;
	} else {
		if (variable_struct_exists(_ed.reg_by_name, _name)) {
			variable_struct_remove(_ed.reg_by_name, _name);
		}
	}
}

// Lazily builds full name index from tracked array.
function __gm3d_ed_reg_index_ensure(_ed) {
	if (_ed == undefined) {
		return;
	}
	if (variable_struct_exists(_ed, "reg_by_name") && is_struct(_ed.reg_by_name)) {
		return;
	}
	_ed.reg_by_name = {};
	if (!is_array(_ed.tracked)) {
		return;
	}
	for (var _i = 0; _i < array_length(_ed.tracked); _i++) {
		var _re = _ed.tracked[_i];
		var _rn = undefined;
		_rn = _re.name;
		if (!is_string(_rn)) {
			continue;
		}
		var _b = undefined;
		if (variable_struct_exists(_ed.reg_by_name, _rn)) {
			_b = _ed.reg_by_name[$ _rn];
		}
		if (!is_array(_b)) {
			_b = [];
			_ed.reg_by_name[$ _rn] = _b;
		}
		array_push(_b, _re);
	}
}
function __gm3d_ed_place(_ed, _asset, _model, _pos3, _rot, _scale3, _label = undefined) {
	if (_ed == undefined || _model == undefined) {
		return undefined;
	}
	var _node = _model.spawnInto(_ed.rt.scene, undefined);
	if (_node == undefined) {
		return undefined;
	}
	__gm3d_ed_magenta_fix(_ed, _node);
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
function gm3d_editor_track(_kind, _asset, _node, _label = undefined) {
	var _ed = gm3d_editor_inst();
	if (_ed == undefined) {
		return undefined;
	}
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
		_pp = _nd.getLocalPosition();
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
		__gm3d_ed_reg_index_sync(_ed, _nm);
	}
}

// Finds closest registry entry for node.
function __gm3d_ed_registry_find(_ed, _node) {
	if (_ed == undefined || _node == undefined) {
		return undefined;
	}
	var _nm = undefined;
	var _pp = undefined;
	_nm = _node.name;
	_pp = _node.getLocalPosition();
	if (!is_string(_nm) || _pp == undefined) {
		return undefined;
	}
	__gm3d_ed_reg_index_ensure(_ed);
	var _bucket = undefined;
	if (variable_struct_exists(_ed.reg_by_name, _nm)) {
		_bucket = _ed.reg_by_name[$ _nm];
	}
	if (is_array(_bucket)) {
		var _best = undefined;
		var _bestd = 1000000000;
		for (var _j = 0; _j < array_length(_bucket); _j++) {
			var _re = _bucket[_j];
			var _dx = _re.pos[0] - _pp.x;
			var _dy = _re.pos[1] - _pp.y;
			var _dz = _re.pos[2] - _pp.z;
			var _d = _dx * _dx + _dy * _dy + _dz * _dz;
			if (_d < _bestd) {
				_bestd = _d;
				_best = _re;
			}
		}
		if (_best != undefined) {
			return _best;
		}
	}
	var _reg = [];
	_reg = _ed.tracked;
	if (!is_array(_reg)) {
		return undefined;
	}
	var _bf = undefined;
	var _bd = 1000000000;
	for (var _k = 0; _k < array_length(_reg); _k++) {
		var _rf = _reg[_k];
		if (_rf.name != _nm) {
			continue;
		}
		var _ex = _rf.pos[0] - _pp.x;
		var _ey = _rf.pos[1] - _pp.y;
		var _ez = _rf.pos[2] - _pp.z;
		var _dd = _ex * _ex + _ey * _ey + _ez * _ez;
		if (_dd < _bd) {
			_bd = _dd;
			_bf = _rf;
		}
	}
	return _bf;
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
	var _roots = [];
	_roots = _ed.rt.scene.getNodes();
	var _used = [];
	var _by_name = {};
	for (var _u = 0; _u < array_length(_roots); _u++) {
		array_push(_used, false);
		var _rn = undefined;
		_rn = _roots[_u].name;
		if (!is_string(_rn)) {
			continue;
		}
		var _rb = undefined;
		if (variable_struct_exists(_by_name, _rn)) {
			_rb = _by_name[$ _rn];
		}
		if (!is_array(_rb)) {
			_rb = [];
			_by_name[$ _rn] = _rb;
		}
		array_push(_rb, _u);
	}
	for (var _i = 0; _i < array_length(_ed.tracked); _i++) {
		var _en = _ed.tracked[_i];
		if (!is_struct(_en) || !is_string(_en.name) || !is_array(_en.pos) || array_length(_en.pos) != 3) {
			continue;
		}
		var _bucket = undefined;
		if (variable_struct_exists(_by_name, _en.name)) {
			_bucket = _by_name[$ _en.name];
		}
		if (!is_array(_bucket)) {
			continue;
		}
		var _best = -1;
		var _bestd = 1000000000;
		for (var _b2 = 0; _b2 < array_length(_bucket); _b2++) {
			var _j = _bucket[_b2];
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

















// Determines node kind from registry.
function __gm3d_ed_kind_of(_ed, _node) {
	if (_node == undefined) {
		return undefined;
	}
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en != undefined && is_string(_en.kind) && _en.kind != "") {
		return _en.kind;
	}
	if (_node.getLightComponent() != undefined) {
		return "light";
	}
	if (_node.getCameraComponent() != undefined) {
		return "camera";
	}
	if (_node.getEnvironmentVolumeComponent() != undefined) {
		return "environment";
	}
	if (_en != undefined) {
		return "asset";
	}
	return undefined;
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
	if (_ed == undefined || _ed.giz.tool == Gm3dEdTool.View || !is_array(_ed.sel) || array_length(_ed.sel) == 0) {
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
		var _mc = _cur.getMeshComponent();
		if (_mc != undefined) {
			_mc.setEnabled(!_en.hidden);
		}
		var _sk = _cur.getSkinnedMeshComponent();
		if (_sk != undefined) {
			_sk.setEnabled(!_en.hidden);
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

// Checks if node selection is disabled (locked).
function __gm3d_ed_locked_get(_ed, _node) {
	if (_ed == undefined || _node == undefined) {
		return false;
	}
	var _en = __gm3d_ed_registry_find(_ed, _node);
	return _en != undefined && _en.locked == true;
}

// Locks or unlocks node selection (locked = cannot be selected).
function __gm3d_ed_locked_set(_ed, _node, _lock) {
	if (_ed == undefined || _node == undefined) {
		return false;
	}
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en == undefined) {
		return false;
	}
	_en.locked = (_lock == true);
	// If node got locked and it was selected, remove it from selection.
	if (_en.locked && is_array(_ed.sel)) {
		var _ns = [];
		for (var _i = 0; _i < array_length(_ed.sel); _i++) {
			if (_ed.sel[_i] != _node) {
				array_push(_ns, _ed.sel[_i]);
			}
		}
		_ed.sel = _ns;
		_ed.giz.drag = -1;
		__gm3d_ed_sel_apply_tool(_ed);
	}
	return true;
}

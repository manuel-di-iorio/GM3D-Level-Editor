// Resolves scene path to absolute path.
function __gm3d_ed_scene_path(_ed) {
	var _f = _ed.scene_file;
	if (_f == undefined || _f == "") {
		return "";
	}
	if (string_pos(":", _f) > 0 || string_copy(_f, 1, 2) == "\\\\" || string_copy(_f, 1, 1) == "/") {
		return _f;
	}
	return working_directory + _f;
}

// Converts node to serializable descriptor skipping system.
function __gm3d_ed_node_to_descriptor(_ed, _node) {
	if (__gm3d_ed_is_grid(_ed, _node)) {
		return undefined;
	}

	if (_ed != undefined && variable_struct_exists(_ed, "rt") && is_struct(_ed.rt)) {
		if (variable_struct_exists(_ed.rt, "cam") && _node == _ed.rt.cam) {
			return undefined;
		}
	}
	if (_ed != undefined && variable_struct_exists(_ed, "drag_preview") && _node == _ed.drag_preview) {
		return undefined;
	}
	return __gm3d_ed_node_desc(_ed, _node);
}

// Converts tracked node to descriptor.
function __gm3d_ed_node_desc(_ed, _node) {

	if (__gm3d_ed_registry_find(_ed, _node) == undefined) {
		return undefined;
	}
	var _kind = __gm3d_ed_kind_of(_ed, _node);
	if (_kind == undefined) {
		return undefined;
	}
	if (_kind == "light" || _kind == "camera" || _kind == "environment") {
		return __gm3d_ed_prop_desc(_ed, _node, _kind);
	}
	var _ad = __gm3d_ed_asset_desc(_ed, _node);
	if (_ad != undefined) {
		return {
			kind: "asset",
			asset: _ad.asset,
			name: _ad.name,
			position: _ad.position,
			rotation: _ad.rotation,
			scale: _ad.scale,
		};
	}

	return undefined;
}

// Builds light camera environment descriptor.
function __gm3d_ed_prop_desc(_ed, _node, _kind) {
	var _en = __gm3d_ed_registry_find(_ed, _node);
	var _label = undefined;
	if (_en != undefined && is_string(_en.label) && _en.label != "") {
		_label = _en.label;
	} else {
		_label = _node.name;
	}
	var _p = _node.getLocalPosition();
	var _q = _node.getLocalRotation();
	var _s = _node.getLocalScale();
	var _d = {
		kind: _kind,
		name: _label,
		position: [_p.x, _p.y, _p.z],
		rotation: [_q.x, _q.y, _q.z, _q.w],
		scale: [_s.x, _s.y, _s.z],
	};
	var _pd = undefined;
	if (_en != undefined && is_struct(_en.data)) {
		_pd = _en.data;
	} else if (_kind == "light") {
		_pd = __gm3d_ed_light_read(_node);
	} else if (_kind == "camera") {
		_pd = __gm3d_ed_camera_read(_node);
	} else {
		_pd = __gm3d_ed_env_read(_node);
	}
	if (_kind == "light") {
		_d.light = {
			type: _pd.type,
			color: [_pd.color[0], _pd.color[1], _pd.color[2]],
			intensity: _pd.intensity,
			range: _pd.range,
			innerCone: _pd.inner,
			outerCone: _pd.outer,
			enabled: _pd.enabled == true,
		};
	} else if (_kind == "camera") {
		_d.camera = {
			projection: _pd.projection,
			fovY: _pd.fov,
			orthoWidth: _pd.ow,
			orthoHeight: _pd.oh,
			near: _pd.near,
			far: _pd.far,
			enabled: _pd.enabled == true,
		};
	} else {
		_d.environment = {
			size: [_pd.size[0], _pd.size[1], _pd.size[2]],
			ambient: [_pd.ambient[0], _pd.ambient[1], _pd.ambient[2]],
			fogEnabled: _pd.fog == true,
			fogColor: [_pd.fogcolor[0], _pd.fogcolor[1], _pd.fogcolor[2]],
			fogStart: _pd.fogstart,
			fogEnd: _pd.fogend,
			enabled: _pd.enabled == true,
		};
	}
	return _d;
}

// Serializes tracked nodes to descriptor array.
function __gm3d_ed_serialize_scene(_ed) {
	var _nodes = __gm3d_ed_tracked_nodes(_ed);
	var _out = [];
	for (var i = 0; i < array_length(_nodes); ++i) {
		var _d = __gm3d_ed_node_to_descriptor(_ed, _nodes[i]);
		if (_d != undefined) {
			array_push(_out, _d);
		}
	}
	return _out;
}

// Creates parent directory for path.
function __gm3d_ed_ensure_dir(_path) {
	var _bs = string_last_pos("\\", _path);
	var _fs = string_last_pos("/", _path);
	var _p = max(_bs, _fs);
	if (_p > 1) {
		directory_create(string_copy(_path, 1, _p - 1));
	}
}

// Writes serialized scene to JSON file.
function __gm3d_ed_save_scene(_ed) {
	var _nodes = __gm3d_ed_serialize_scene(_ed);
	var _json = json_stringify({ version: 1, nodes: _nodes });
	var _path = __gm3d_ed_scene_path(_ed);
	if (_path == "") {
		return false;
	}
	__gm3d_ed_ensure_dir(_path);
	if (!__gm3d_ed_write_text_file_atomic(_path, _json)) {
		return false;
	}
	_ed.dirty = false;
	return true;
}

// Validates scene descriptor array structure.
function __gm3d_ed_validate_descs(_nodes) {
	if (!is_array(_nodes)) {
		return false;
	}
	for (var _i = 0; _i < array_length(_nodes); ++_i) {
		var _d = _nodes[_i];
		if (!is_struct(_d)) {
			return false;
		}
		if (!variable_struct_exists(_d, "name") || !is_string(_d.name)) {
			return false;
		}
		var _kind = "asset";
		if (variable_struct_exists(_d, "kind")) {
			if (!is_string(_d.kind)) {
				return false;
			}
			_kind = _d.kind;
		}
		if (!__gm3d_ed_is_num3(_d, "position") || !__gm3d_ed_is_num4(_d, "rotation") || !__gm3d_ed_is_num3(_d, "scale")) {
			return false;
		}
		if (_kind == "asset") {
			if (variable_struct_exists(_d, "asset") && !is_string(_d.asset)) {
				return false;
			}
		} else if (_kind == "light") {
			if (!__gm3d_ed_is_light_struct(_d)) {
				return false;
			}
		} else if (_kind == "camera") {
			if (!__gm3d_ed_is_camera_struct(_d)) {
				return false;
			}
		} else if (_kind == "environment") {
			if (!__gm3d_ed_is_env_struct(_d)) {
				return false;
			}
		} else {
			return false;
		}
	}
	return true;
}

// Validates light descriptor structure.
function __gm3d_ed_is_light_struct(_d) {
	if (!variable_struct_exists(_d, "light") || !is_struct(_d.light)) {
		return false;
	}
	var _l = _d.light;
	if (!variable_struct_exists(_l, "type") || !is_string(_l.type)) {
		return false;
	}
	if (_l.type != "directional" && _l.type != "point" && _l.type != "spot") {
		return false;
	}
	if (!variable_struct_exists(_l, "color") || !is_array(_l.color) || array_length(_l.color) != 3) {
		return false;
	}
	if (!variable_struct_exists(_l, "intensity") || !is_real(_l.intensity)) {
		return false;
	}
	if (!variable_struct_exists(_l, "range") || !is_real(_l.range)) {
		return false;
	}
	if (!variable_struct_exists(_l, "innerCone") || !is_real(_l.innerCone)) {
		return false;
	}
	if (!variable_struct_exists(_l, "outerCone") || !is_real(_l.outerCone)) {
		return false;
	}
	return true;
}

// Validates camera descriptor structure.
function __gm3d_ed_is_camera_struct(_d) {
	if (!variable_struct_exists(_d, "camera") || !is_struct(_d.camera)) {
		return false;
	}
	var _c = _d.camera;
	if (!variable_struct_exists(_c, "projection") || !is_string(_c.projection)) {
		return false;
	}
	if (_c.projection != "perspective" && _c.projection != "ortho") {
		return false;
	}
	if (!variable_struct_exists(_c, "fovY") || !is_real(_c.fovY)) {
		return false;
	}
	if (!variable_struct_exists(_c, "orthoWidth") || !is_real(_c.orthoWidth)) {
		return false;
	}
	if (!variable_struct_exists(_c, "orthoHeight") || !is_real(_c.orthoHeight)) {
		return false;
	}
	if (!variable_struct_exists(_c, "near") || !is_real(_c.near)) {
		return false;
	}
	if (!variable_struct_exists(_c, "far") || !is_real(_c.far)) {
		return false;
	}
	return true;
}

// Validates environment descriptor structure.
function __gm3d_ed_is_env_struct(_d) {
	if (!variable_struct_exists(_d, "environment") || !is_struct(_d.environment)) {
		return false;
	}
	var _e = _d.environment;
	if (!variable_struct_exists(_e, "size") || !is_array(_e.size) || array_length(_e.size) != 3) {
		return false;
	}
	if (!variable_struct_exists(_e, "ambient") || !is_array(_e.ambient) || array_length(_e.ambient) != 3) {
		return false;
	}
	if (!variable_struct_exists(_e, "fogColor") || !is_array(_e.fogColor) || array_length(_e.fogColor) != 3) {
		return false;
	}
	if (!variable_struct_exists(_e, "fogStart") || !is_real(_e.fogStart)) {
		return false;
	}
	if (!variable_struct_exists(_e, "fogEnd") || !is_real(_e.fogEnd)) {
		return false;
	}
	return true;
}

// Checks for three number array.
function __gm3d_ed_is_num3(_d, _key) {
	if (!variable_struct_exists(_d, _key)) {
		return false;
	}
	var _a = _d[$ _key];
	return is_array(_a) && array_length(_a) == 3 && is_real(_a[0]) && is_real(_a[1]) && is_real(_a[2]);
}

// Checks for four number array.
function __gm3d_ed_is_num4(_d, _key) {
	if (!variable_struct_exists(_d, _key)) {
		return false;
	}
	var _a = _d[$ _key];
	return is_array(_a) && array_length(_a) == 4 && is_real(_a[0]) && is_real(_a[1]) && is_real(_a[2]) && is_real(_a[3]);
}

// Clears scene and rebuilds from descriptors.
function __gm3d_ed_rebuild(_ed, _nodes) {
	var _rep = { placed: 0, failed: 0, err: "" };
	if (!is_array(_nodes)) {
		_nodes = [];
	}
	if (!__gm3d_ed_validate_descs(_nodes)) {
		throw "invalid descriptors";
	}

	__gm3d_ed_drop_preview_clear(_ed);
	var _tracked = __gm3d_ed_root_tracked(_ed);

	var _hidden_labels = [];
	for (var _i = 0; _i < array_length(_tracked); _i++) {
		var _he = __gm3d_ed_registry_find(_ed, _tracked[_i]);
		if (_he != undefined && _he.hidden == true && is_string(_he.label)) {
			array_push(_hidden_labels, _he.label);
		}
		__gm3d_ed_destroy_subtree(_tracked[_i]);
	}
	_ed.rt.scene.update(0);
	_ed.tracked = [];
	var _placementData = [];
	for (var _i = 0; _i < array_length(_nodes); ++_i) {
		var _d = _nodes[_i];
		if (!is_struct(_d)) {
			continue;
		}
		array_push(_placementData, _d);
	}
	for (var _i = 0; _i < array_length(_placementData); ++_i) {
		var _p = _placementData[_i];

		var _kind = "asset";
		if (variable_struct_exists(_p, "kind")) {
			_kind = _p.kind;
		}
		if (_kind == "light" || _kind == "camera" || _kind == "environment") {
			if (__gm3d_ed_rebuild_prop(_ed, _p, _kind) == undefined) {
				throw "place failed for '" + string(_p.name) + "'";
			}
			_rep.placed++;
			continue;
		}
		if (_kind != "asset") {
			throw "unknown kind '" + string(_kind) + "'";
		}
		var _akey = _p.name;
		if (variable_struct_exists(_p, "asset") && _p.asset != undefined) {
			_akey = _p.asset;
		}
		var _model = __gm3d_ed_asset_find(_ed, _akey);
		if (_model == undefined) {
			throw "unknown model '" + string(_akey) + "'";
		}
		var _rq = __gm3d_ed_quat_from_array(_p.rotation);
		var _root = __gm3d_ed_place(
			_ed,
			_akey,
			_model,
			_p.position,
			_rq.normalizeSafe(0.000001),
			_p.scale,
			_p.name,
		);
		if (_root == undefined) {
			throw "place failed for '" + string(_akey) + "'";
		}
		_rep.placed++;
	}
	_ed.rt.scene.update(0);
	__gm3d_ed_cameras_mute(_ed);
	var _rt2 = __gm3d_ed_root_tracked(_ed);
	for (var _h = 0; _h < array_length(_rt2); _h++) {
		var _en2 = __gm3d_ed_registry_find(_ed, _rt2[_h]);
		if (_en2 == undefined || !is_string(_en2.label)) {
			continue;
		}
		for (var _q = 0; _q < array_length(_hidden_labels); _q++) {
			if (_en2.label == _hidden_labels[_q]) {
				__gm3d_ed_hidden_set(_ed, _rt2[_h], true);
				break;
			}
		}
	}
	return _rep;
}

// Rebuilds light camera environment node.
function __gm3d_ed_rebuild_prop(_ed, _p, _kind) {
	var _rq = __gm3d_ed_quat_from_array(_p.rotation);
	var _node = _ed.rt.scene.createNode(_p.name);
	if (_node == undefined) {
		return undefined;
	}
	_node.setLocalPosition(new GM3D_Vec3(_p.position[0], _p.position[1], _p.position[2]));
	_node.setLocalScale(new GM3D_Vec3(_p.scale[0], _p.scale[1], _p.scale[2]));
	_node.setLocalRotation(_rq.normalizeSafe(0.000001));
	var _data = undefined;
	if (_kind == "light") {
		var _lc = new GM3D_LightComponent();
		_node.addComponent(_lc);
		_data = __gm3d_ed_light_defaults();
		var _l = _p.light;
		_data.type = _l.type;
		_data.color = [_l.color[0], _l.color[1], _l.color[2]];
		_data.intensity = _l.intensity;
		_data.range = _l.range;
		_data.inner = _l.innerCone;
		_data.outer = _l.outerCone;
		_data.enabled = variable_struct_exists(_l, "enabled") ? _l.enabled == true : true;
		__gm3d_ed_light_apply(_node, _data);
	} else if (_kind == "camera") {
		var _cc = new GM3D_CameraComponent();
		_node.addComponent(_cc);
		_data = __gm3d_ed_camera_defaults();
		var _c = _p.camera;
		_data.projection = _c.projection;
		_data.fov = _c.fovY;
		_data.ow = _c.orthoWidth;
		_data.oh = _c.orthoHeight;
		_data.near = _c.near;
		_data.far = _c.far;
		_data.enabled = variable_struct_exists(_c, "enabled") ? _c.enabled == true : true;
		__gm3d_ed_camera_apply(_node, _data);
	} else {
		var _ec = new GM3D_EnvironmentVolumeComponent();
		_node.addComponent(_ec);
		_data = __gm3d_ed_env_defaults();
		var _e = _p.environment;
		_data.size = [_e.size[0], _e.size[1], _e.size[2]];
		_data.ambient = [_e.ambient[0], _e.ambient[1], _e.ambient[2]];
		_data.fog = variable_struct_exists(_e, "fogEnabled") ? _e.fogEnabled == true : false;
		_data.fogcolor = [_e.fogColor[0], _e.fogColor[1], _e.fogColor[2]];
		_data.fogstart = _e.fogStart;
		_data.fogend = _e.fogEnd;
		_data.enabled = variable_struct_exists(_e, "enabled") ? _e.enabled == true : true;
		__gm3d_ed_env_apply(_node, _data);
	}
	_ed.rt.scene.update(0);
	var _pp = _node.getLocalPosition();
	__gm3d_ed_kind_register(_ed, _node, _kind, "", [_pp.x, _pp.y, _pp.z], _p.name, _data);
	if (_kind == "environment") {
		__gm3d_ed_hidden_set(_ed, _node, true);
	}
	if (_kind == "light" && is_struct(_data) && variable_struct_exists(_data, "type") && _data.type == "directional") {
		__gm3d_ed_hidden_set(_ed, _node, true);
	}
	return _node;
}

// Loads scene JSON into editor.
function __gm3d_ed_load_scene(_ed) {
	var _path = __gm3d_ed_scene_path(_ed);
	if (_path == "") {
		return false;
	}
	if (!file_exists(_path)) {
		return false;
	}
	var _json = __gm3d_ed_read_text_file(_path);
	if (_json == "") {
		return false;
	}
	var _data = json_parse(_json);
	var _ok_data =
		is_struct(_data) && _data.version == 1 && variable_struct_exists(_data, "nodes") && is_array(_data.nodes);
	if (!_ok_data) {
		return false;
	}
	__gm3d_ed_rebuild(_ed, _data.nodes);
	_ed.sel = [];
	_ed.giz.drag = -1;
	_ed.giz.hover = -1;
	__gm3d_ed_history_clear(_ed);
	_ed.dirty = false;
	return true;
}

// Reads whole text file contents.
function __gm3d_ed_read_text_file(_path) {
	if (_path == "" || !file_exists(_path)) {
		return "";
	}
	var _f = file_text_open_read(_path);
	if (_f < 0) {
		return "";
	}
	var _out = "";
	while (!file_text_eof(_f)) {
		_out += file_text_read_string(_f);
		file_text_readln(_f);
	}
	file_text_close(_f);
	return _out;
}

// Writes text to file.
function __gm3d_ed_write_text_file(_path, _txt) {
	var _f = file_text_open_write(_path);
	if (_f < 0) {
		return false;
	}
	file_text_write_string(_f, _txt);
	file_text_close(_f);
	return file_exists(_path);
}

// Atomically writes text via temporary file.
function __gm3d_ed_write_text_file_atomic(_path, _txt) {
	var _tmp = _path + ".tmp";
	if (!__gm3d_ed_write_text_file(_tmp, _txt)) {
		return false;
	}
	if (!file_exists(_tmp)) {
		return false;
	}
	if (file_exists(_path)) {
		file_delete(_path);
	}
	file_rename(_tmp, _path);
	return file_exists(_path);
}

// Loads scene file into runtime scene.
function gm3d_load(_scene, _fname, _models) {
	var _rep = { placed: 0, failed: 0 };
	if (_scene == undefined || _fname == undefined || _fname == "" || !is_struct(_models)) {
		return _rep;
	}
	if (!file_exists(_fname)) {
		return _rep;
	}
	var _json = "";
	var _f = file_text_open_read(_fname);
	if (_f < 0) {
		return _rep;
	}
	while (!file_text_eof(_f)) {
		_json += file_text_read_string(_f);
		file_text_readln(_f);
	}
	file_text_close(_f);
	if (_json == "") {
		return _rep;
	}
	var _data = undefined;
	try {
		_data = json_parse(_json);
	} catch (_e) {
		return _rep;
	}
	if (!is_struct(_data) || !variable_struct_exists(_data, "nodes") || !is_array(_data.nodes)) {
		return _rep;
	}
	var _nodes = _data.nodes;
	for (var _i = 0; _i < array_length(_nodes); ++_i) {
		var _ok = false;
		try {
			_ok = __gm3d_load_node(_scene, _models, _nodes[_i]) != undefined;
		} catch (_e2) {
			_ok = false;
		}
		if (_ok) {
			_rep.placed++;
		} else {
			_rep.failed++;
		}
	}
	try {
		_scene.update(0);
	} catch (_e3) {
	}
	return _rep;
}

// Spawns single node from descriptor.
function __gm3d_load_node(_scene, _models, _p) {
	if (_scene == undefined || !is_struct(_p)) {
		return undefined;
	}
	var _kind = undefined;
	if (variable_struct_exists(_p, "kind") && is_string(_p.kind) && _p.kind != "") {
		_kind = _p.kind;
	}
	var _name = "node";
	if (variable_struct_exists(_p, "name") && is_string(_p.name) && _p.name != "") {
		_name = _p.name;
	}
	if (_kind == "light" || _kind == "camera" || _kind == "environment") {
		return __gm3d_load_prop(_scene, _p, _kind, _name);
	}
	if (_kind != "asset") {
		return undefined;
	}
	if (!variable_struct_exists(_p, "asset") || !is_string(_p.asset) || _p.asset == "") {
		return undefined;
	}
	var _akey = _p.asset;
	if (!variable_struct_exists(_models, _akey)) {
		return undefined;
	}
	var _model = _models[$ _akey];
	if (_model == undefined) {
		return undefined;
	}
	var _node = _model.spawnInto(_scene, undefined);
	if (_node == undefined) {
		return undefined;
	}
	_node.setLocalPosition(__gm3d_load_vec3(_p, "position", 0, 0, 0));
	_node.setLocalScale(__gm3d_load_vec3(_p, "scale", 1, 1, 1));
	_node.setLocalRotation(__gm3d_load_quat(_p));
	return _node;
}

// Creates light camera environment from descriptor.
function __gm3d_load_prop(_scene, _p, _kind, _name) {
	var _node = _scene.createNode(_name);
	if (_node == undefined) {
		return undefined;
	}
	_node.setLocalPosition(__gm3d_load_vec3(_p, "position", 0, 0, 0));
	_node.setLocalScale(__gm3d_load_vec3(_p, "scale", 1, 1, 1));
	_node.setLocalRotation(__gm3d_load_quat(_p));
	if (_kind == "light" && is_struct(_p.light)) {
		var _lc = new GM3D_LightComponent();
		_node.addComponent(_lc);
		var _l = _p.light;
		try {
			_lc.setType(_l.type == "point" ? GM3D_ELightType.Point : _l.type == "spot" ? GM3D_ELightType.Spot : GM3D_ELightType.Directional);
		} catch (_e) {
		}
		if (is_array(_l.color) && array_length(_l.color) == 3) {
			try {
				_lc.setColor(make_colour_rgb(clamp(_l.color[0], 0, 255), clamp(_l.color[1], 0, 255), clamp(_l.color[2], 0, 255)));
			} catch (_e2) {
			}
		}
		if (is_real(_l.intensity)) {
			try {
				_lc.setIntensity(max(_l.intensity, 0));
			} catch (_e3) {
			}
		}
		if (is_real(_l.range) && _l.range > 0) {
			try {
				_lc.setRange(_l.range);
			} catch (_e4) {
			}
		}
		if (is_real(_l.innerCone)) {
			try {
				_lc.setInnerConeAngle(degtorad(clamp(_l.innerCone, 0, 89)));
			} catch (_e5) {
			}
		}
		if (is_real(_l.outerCone)) {
			try {
				_lc.setOuterConeAngle(degtorad(clamp(_l.outerCone, 1, 89)));
			} catch (_e6) {
			}
		}
		try {
			_lc.setEnabled(!variable_struct_exists(_l, "enabled") || _l.enabled == true);
		} catch (_e7) {
		}
	} else if (_kind == "camera" && is_struct(_p.camera)) {
		var _cc = new GM3D_CameraComponent();
		_node.addComponent(_cc);
		var _c = _p.camera;
		try {
			_cc.setProjection(_c.projection == "ortho" ? GM3D_ECameraProjection.Orthographic : GM3D_ECameraProjection.Perspective);
		} catch (_e8) {
		}
		if (_c.projection == "ortho") {
			if (is_real(_c.orthoWidth) && _c.orthoWidth > 0) {
				try {
					_cc.setOrthoWidth(_c.orthoWidth);
				} catch (_e9) {
				}
			}
			if (is_real(_c.orthoHeight) && _c.orthoHeight > 0) {
				try {
					_cc.setOrthoHeight(_c.orthoHeight);
				} catch (_e10) {
				}
			}
		} else if (is_real(_c.fovY) && _c.fovY > 0) {
			try {
				_cc.setFovY(degtorad(clamp(_c.fovY, 1, 179)));
			} catch (_e11) {
			}
		}
		if (is_real(_c.near) && _c.near > 0) {
			try {
				_cc.setNear(_c.near);
			} catch (_e12) {
			}
		}
		if (is_real(_c.far) && _c.far > 0) {
			try {
				_cc.setFar(_c.far);
			} catch (_e13) {
			}
		}
		try {
			_cc.setEnabled(!variable_struct_exists(_c, "enabled") || _c.enabled == true);
		} catch (_e14) {
		}
	} else if (_kind == "environment" && is_struct(_p.environment)) {
		var _ec = new GM3D_EnvironmentVolumeComponent();
		_node.addComponent(_ec);
		var _e = _p.environment;
		if (is_array(_e.size) && array_length(_e.size) == 3) {
			try {
				_ec.setSize(new GM3D_Vec3(max(_e.size[0], 0.01), max(_e.size[1], 0.01), max(_e.size[2], 0.01)));
			} catch (_e15) {
			}
		}
		if (is_array(_e.ambient) && array_length(_e.ambient) == 3) {
			try {
				_ec.setAmbientColor(make_colour_rgb(clamp(_e.ambient[0], 0, 255), clamp(_e.ambient[1], 0, 255), clamp(_e.ambient[2], 0, 255)));
			} catch (_e16) {
			}
		}
		try {
			_ec.setFogEnabled(variable_struct_exists(_e, "fogEnabled") && _e.fogEnabled == true);
		} catch (_e17) {
		}
		if (is_array(_e.fogColor) && array_length(_e.fogColor) == 3) {
			try {
				_ec.setFogColor(make_colour_rgb(clamp(_e.fogColor[0], 0, 255), clamp(_e.fogColor[1], 0, 255), clamp(_e.fogColor[2], 0, 255)));
			} catch (_e18) {
			}
		}
		if (is_real(_e.fogStart)) {
			try {
				_ec.setFogStart(_e.fogStart);
			} catch (_e19) {
			}
		}
		if (is_real(_e.fogEnd)) {
			try {
				_ec.setFogEnd(_e.fogEnd);
			} catch (_e20) {
			}
		}
		try {
			_ec.setEnabled(!variable_struct_exists(_e, "enabled") || _e.enabled == true);
		} catch (_e21) {
		}
	} else {
		_node.destroy();
		return undefined;
	}
	return _node;
}

// Parses vector from descriptor with fallback.
function __gm3d_load_vec3(_p, _field, _fx, _fy, _fz) {
	try {
		var _a = _p[$ _field];
		if (is_array(_a) && array_length(_a) == 3 && is_real(_a[0]) && is_real(_a[1]) && is_real(_a[2])) {
			return new GM3D_Vec3(_a[0], _a[1], _a[2]);
		}
	} catch (_e) {
	}
	return new GM3D_Vec3(_fx, _fy, _fz);
}

// Parses quaternion from descriptor with fallback.
function __gm3d_load_quat(_p) {
	try {
		var _a = _p.rotation;
		if (is_array(_a) && array_length(_a) == 4 && is_real(_a[0]) && is_real(_a[1]) && is_real(_a[2]) && is_real(_a[3])) {
			var _q = new GM3D_Quaternion();
			_q.x = _a[0];
			_q.y = _a[1];
			_q.z = _a[2];
			_q.w = _a[3];
			return _q.normalizeSafe(0.000001);
		}
	} catch (_e) {
	}
	var _q0 = new GM3D_Quaternion();
	return _q0;
}

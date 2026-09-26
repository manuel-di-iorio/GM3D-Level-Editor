/// @module gm3d_ed_serialize
/// Scene JSON save/load, rebuild and descriptor validation.

/// Resolves the scene file path against working_directory when relative.
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

/// Converts a live tracked node to a descriptor, or undefined for structural nodes.
function __gm3d_ed_node_to_descriptor(_ed, _node) {
	if (__gm3d_ed_is_grid(_ed, _node)) {
		return undefined;
	}
	return __gm3d_ed_node_desc(_ed, _node);
}

/// Builds a serializable descriptor for any tracked live node.
/// @return Descriptor with kind, or undefined when untracked.
function __gm3d_ed_node_desc(_ed, _node) {
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

/// Builds a light/camera/environment descriptor from live TRS plus tracked props.
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

/// Serializes the live scene into a descriptor list.
function __gm3d_ed_serialize_scene(_ed) {
	var _roots = [];
	_roots = _ed.rt.scene.getNodes();
	var _out = [];
	for (var i = 0; i < array_length(_roots); ++i) {
		if (_roots[i].parent != undefined) {
			continue;
		}
		var _d = __gm3d_ed_node_to_descriptor(_ed, _roots[i]);
		if (_d != undefined) {
			array_push(_out, _d);
		}
	}
	return _out;
}

/// Creates the parent folder of _path when missing (best effort).
function __gm3d_ed_ensure_dir(_path) {
	var _bs = string_last_pos("\\", _path);
	var _fs = string_last_pos("/", _path);
	var _p = max(_bs, _fs);
	if (_p > 1) {
		directory_create(string_copy(_path, 1, _p - 1));
	}
}

/// Saves the current scene to disk as JSON via a temp file and rename.
/// @return True on success.
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

/// Validates a descriptor list without touching the live scene.
/// Missing kind means legacy asset descriptor. Only "asset" is rejected when
/// unknown: light/camera/environment entries are validated structurally.
/// @return True when every entry is usable.
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

/// True when _d.light holds a usable light struct.
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

/// True when _d.camera holds a usable camera struct.
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

/// True when _d.environment holds a usable environment struct.
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

/// True when _d[_key] is a numeric 3-array.
function __gm3d_ed_is_num3(_d, _key) {
	if (!variable_struct_exists(_d, _key)) {
		return false;
	}
	var _a = _d[$ _key];
	return is_array(_a) && array_length(_a) == 3 && is_real(_a[0]) && is_real(_a[1]) && is_real(_a[2]);
}

/// True when _d[_key] is a numeric 4-array.
function __gm3d_ed_is_num4(_d, _key) {
	if (!variable_struct_exists(_d, _key)) {
		return false;
	}
	var _a = _d[$ _key];
	return is_array(_a) && array_length(_a) == 4 && is_real(_a[0]) && is_real(_a[1]) && is_real(_a[2]) && is_real(_a[3]);
}

/// Rebuilds asset placements from a descriptor list.
/// @return Placement report { placed, failed, err }.
function __gm3d_ed_rebuild(_ed, _nodes) {
	var _rep = { placed: 0, failed: 0, err: "" };
	if (!is_array(_nodes)) {
		_nodes = [];
	}
	if (!__gm3d_ed_validate_descs(_nodes)) {
		throw "invalid descriptors";
	}

	var _tracked = __gm3d_ed_root_tracked(_ed);
	// Editor-only hidden flags are never serialized: carry them over by label
	// so load/undo keep the viewport state of same-named nodes.
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
		// Legacy files have no kind: treat missing kind as "asset".
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

/// Rebuilds one light/camera/environment node from a descriptor.
/// @return New node or undefined.
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
	return _node;
}

/// Loads a scene JSON file and rebuilds the runtime scene.
/// @return True on success.
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

/// Reads a whole text file, including multi-line JSON.
/// @return File text or "" when missing or unreadable.
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

/// Writes text to a file.
/// @return False when writing fails.
function __gm3d_ed_write_text_file(_path, _txt) {
	var _f = file_text_open_write(_path);
	if (_f < 0) {
		return false;
	}
	file_text_write_string(_f, _txt);
	file_text_close(_f);
	return file_exists(_path);
}

/// Writes text atomically via temp file and rename.
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

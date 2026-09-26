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

/// Converts a live asset node to a descriptor, or undefined for structural nodes.
function __gm3d_ed_node_to_descriptor(_ed, _node) {
	if (__gm3d_ed_is_grid(_ed, _node)) {
		return undefined;
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
		// kind is new: missing means legacy asset descriptor (version 1 files
		// written before kind existed). When present it must be "asset" until
		// light/camera/environment kinds land (see docs/plans).
		if (variable_struct_exists(_d, "kind")) {
			if (!is_string(_d.kind) || _d.kind != "asset") {
				return false;
			}
		}
		if (!__gm3d_ed_is_num3(_d, "position") || !__gm3d_ed_is_num4(_d, "rotation") || !__gm3d_ed_is_num3(_d, "scale")) {
			return false;
		}
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
	for (var _i = 0; _i < array_length(_tracked); _i++) {
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
		if (_kind != "asset") {
			throw "unknown kind '" + string(_kind) + "'";
		}
		var _akey = _p.name;
		if (_p.asset != undefined) {
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
	return _rep;
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

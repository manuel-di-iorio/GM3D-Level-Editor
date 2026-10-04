// Folder (relative to working_directory) holding editor scene files.
function __gm3d_ed_scenes_dir() {
	return working_directory + "__gm3dEditor/scenes/";
}

// Prompts scene name and saves scene.
function __gm3d_ed_save_as(_ed, _after = undefined) {
	if (_ed == undefined || _ed.scene_dlg != undefined) {
		return false;
	}
	_ed.scene_dlg = {
		mode: "save",
		name: __gm3d_ed_scene_name(_ed),
		error: "",
		err_name: "",
		open: true,
		after: _after,
		list: __gm3d_ed_scene_list(),
	};
	return false;
}

// Saves scene or prompts for name.
function __gm3d_ed_save_or_ask(_ed, _after = undefined) {
	if (_ed.scene_file == undefined || _ed.scene_file == "") {
		return __gm3d_ed_save_as(_ed, _after);
	}
	var _ok = __gm3d_ed_save_scene(_ed);
	return _ok;
}

// Shows confirmation dialog if dirty.
function __gm3d_ed_confirm_ask(_ed, _action) {
	var _dirty = false;
	_dirty = _ed.dirty == true;
	if (!_dirty) {
		__gm3d_ed_confirm_do(_ed, _action);
		return;
	}
	_ed.confirm = { action: _action, open: true };
}

// Executes confirmed new load close action.
function __gm3d_ed_confirm_do(_ed, _action) {
	if (_action == "new") {
		__gm3d_ed_new_scene(_ed);
	} else if (_action == "load") {
		__gm3d_ed_load_ask(_ed);
	} else if (_action == "close") {
		__gm3d_ed_set_active(_ed, false);
	}
}

// Opens load dialog for scenes folder.
function __gm3d_ed_load_ask(_ed) {
	if (_ed == undefined || _ed.scene_dlg != undefined) {
		return false;
	}
	_ed.scene_dlg = {
		mode: "load",
		name: __gm3d_ed_scene_name(_ed),
		error: "",
		err_name: "",
		open: true,
		after: undefined,
		list: __gm3d_ed_scene_list(),
	};
	return false;
}

// Derives scene name from current file.
function __gm3d_ed_scene_name(_ed) {
	var _f = "";
	if (_ed != undefined && is_string(_ed.scene_file)) {
		_f = _ed.scene_file;
	}
	var _p = max(string_last_pos("/", _f), string_last_pos("\\", _f));
	if (_p > 0) {
		_f = string_copy(_f, _p + 1, string_length(_f) - _p);
	}
	if (string_length(_f) > 5 && string_lower(string_copy(_f, string_length(_f) - 4, 5)) == ".json") {
		_f = string_copy(_f, 1, string_length(_f) - 5);
	}
	_f = string_trim(_f);
	if (_f == "") {
		_f = "scene";
	}
	return _f;
}

// Sanitizes scene name for file use.
function __gm3d_ed_sanitize_scene_name(_name) {
	if (!is_string(_name)) {
		return "";
	}
	var _s = string_trim(_name);
	var _out = "";
	for (var _i = 1; _i <= string_length(_s); _i++) {
		var _ch = string_char_at(_s, _i);
		if (_ch == "/" || _ch == "\\" || _ch == ":" || _ch == "*" || _ch == "?" || _ch == "\"" || _ch == "<" || _ch == ">" || _ch == "|") {
			continue;
		}
		if (ord(_ch) < 32) {
			continue;
		}
		_out += _ch;
	}
	_out = string_trim(_out);
	while (string_length(_out) > 0) {
		var _last = string_char_at(_out, string_length(_out));
		if (_last != "." && _last != " ") {
			break;
		}
		_out = string_copy(_out, 1, string_length(_out) - 1);
	}
	if (string_length(_out) > 64) {
		_out = string_copy(_out, 1, 64);
	}
	return _out;
}

// Builds relative scene file path for name.
function __gm3d_ed_scene_file_for(_name) {
	return "__gm3dEditor/scenes/" + _name + ".json";
}

// Lists saved scene names.
function __gm3d_ed_scene_list() {
	var _out = [];
	var _f = file_find_first(__gm3d_ed_scenes_dir() + "*.json", 0);
	var _guard = 0;
	while (_f != "" && _guard < 500) {
		_guard++;
		var _n = _f;
		var _p = max(string_last_pos("/", _n), string_last_pos("\\", _n));
		if (_p > 0) {
			_n = string_copy(_n, _p + 1, string_length(_n) - _p);
		}
		if (string_length(_n) > 5 && string_lower(string_copy(_n, string_length(_n) - 4, 5)) == ".json") {
			_n = string_copy(_n, 1, string_length(_n) - 5);
		}
		if (_n != "") {
			array_push(_out, _n);
		}
		_f = file_find_next();
	}
	file_find_close();
	for (var _a = 1; _a < array_length(_out); _a++) {
		var _it = _out[_a];
		var _b = _a - 1;
		while (_b >= 0 && string_lower(_out[_b]) > string_lower(_it)) {
			_out[_b + 1] = _out[_b];
			_b--;
		}
		_out[_b + 1] = _it;
	}
	return _out;
}

// Saves scene under given name.
function __gm3d_ed_save_named(_ed, _name) {
	var _clean = __gm3d_ed_sanitize_scene_name(_name);
	if (_clean == "") {
		return false;
	}
	_ed.scene_file = __gm3d_ed_scene_file_for(_clean);
	return __gm3d_ed_save_scene(_ed);
}

// Loads scene by name.
function __gm3d_ed_load_named(_ed, _name) {
	var _clean = __gm3d_ed_sanitize_scene_name(_name);
	if (_clean == "") {
		return false;
	}
	var _old = _ed.scene_file;
	_ed.scene_file = __gm3d_ed_scene_file_for(_clean);
	if (__gm3d_ed_load_scene(_ed)) {
		return true;
	}
	_ed.scene_file = _old;
	return false;
}

// Deletes a saved scene file by name. Returns true on success.
function __gm3d_ed_delete_scene_named(_name) {
	var _clean = __gm3d_ed_sanitize_scene_name(_name);
	if (_clean == "") {
		return false;
	}
	var _path = __gm3d_ed_scenes_dir() + _clean + ".json";
	if (!file_exists(_path)) {
		return false;
	}
	file_delete(_path);
	return true;
}

// Confirms save dialog.
function __gm3d_ed_scene_dlg_do_save(_ed) {
	var _dlg = _ed.scene_dlg;
	if (_dlg == undefined) {
		return;
	}
	var _clean = __gm3d_ed_sanitize_scene_name(_dlg.name);
	if (_clean == "") {
		_dlg.error = "Type a valid scene name.";
		_dlg.err_name = _dlg.name;
		return;
	}
	_dlg.name = _clean;
	if (!__gm3d_ed_save_named(_ed, _clean)) {
		_dlg.error = "Could not write file.";
		_dlg.err_name = _dlg.name;
		return;
	}
	var _after = _dlg.after;
	_ed.scene_dlg = undefined;
	if (_after != undefined && _after != "") {
		__gm3d_ed_confirm_do(_ed, _after);
	}
}

// Confirms load dialog.
function __gm3d_ed_scene_dlg_do_load(_ed) {
	var _dlg = _ed.scene_dlg;
	if (_dlg == undefined) {
		return;
	}
	var _clean = __gm3d_ed_sanitize_scene_name(_dlg.name);
	if (_clean == "") {
		_dlg.error = "Type a valid scene name.";
		_dlg.err_name = _dlg.name;
		return;
	}
	_dlg.name = _clean;
	if (!__gm3d_ed_load_named(_ed, _clean)) {
		_dlg.error = "Scene not found or invalid.";
		_dlg.err_name = _dlg.name;
		return;
	}
	_ed.scene_dlg = undefined;
}

// Creates new empty scene.
function gm3d_editor_new_scene() {
	var _e = gm3d_editor_inst();
	if (_e == undefined) {
		return;
	}
	__gm3d_ed_new_scene(_e);
}

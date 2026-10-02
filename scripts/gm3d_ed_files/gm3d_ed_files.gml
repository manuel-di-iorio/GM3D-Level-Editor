// Prompts filename and saves scene.
function __gm3d_ed_save_as(_ed) {
	var _f = "";
	_f = get_save_filename("Scene JSON (*.json)|*.json", _ed.scene_file != "" ? _ed.scene_file : "scene.json");
	if (_f == "") {
		return false;
	}
	_ed.scene_file = _f;
	var _ok = __gm3d_ed_save_scene(_ed);
	return _ok;
}

// Saves scene or prompts for path.
function __gm3d_ed_save_or_ask(_ed) {
	if (_ed.scene_file == undefined || _ed.scene_file == "") {
		return __gm3d_ed_save_as(_ed);
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

// Loads scene through OS dialog.
function __gm3d_ed_load_ask(_ed) {
	var _f = get_open_filename("Scene JSON (*.json)|*.json", "scene.json");
	if (_f == "") {
		return false;
	}
	var _old = _ed.scene_file;
	_ed.scene_file = _f;
	if (__gm3d_ed_load_scene(_ed)) {
		return true;
	}
	_ed.scene_file = _old;
	return false;
}

// Creates new empty scene.
function gm3d_editor_new_scene() {
	var _e = gm3d_editor_inst();
	if (_e == undefined) {
		return;
	}
	__gm3d_ed_new_scene(_e);
}

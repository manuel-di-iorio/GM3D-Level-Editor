/// @module gm3d_ed_history
/// Undo/redo via JSON snapshots with selection restore.

/// Clears both undo and redo stacks (new scene, load).
function __gm3d_ed_history_clear(_ed) {
	if (_ed == undefined) {
		return;
	}
	_ed.undo = [];
	_ed.redo = [];
}

/// Captures a full scene plus selection snapshot.
/// @return { json, sel } snapshot data.
function __gm3d_ed_history_snap(_ed) {
	var _nodes = __gm3d_ed_serialize_scene(_ed);
	var _sel = [];
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		var _d = __gm3d_ed_node_desc(_ed, _ed.sel[_i]);
		if (_d != undefined) {
			array_push(_sel, _d);
		}
	}
	return { json: json_stringify(_nodes), sel: _sel };
}

/// Commits a before-snapshot after a gesture; no-op when unchanged.
function __gm3d_ed_history_commit(_ed, _before) {
	var _cur = undefined;
	_cur = __gm3d_ed_history_snap(_ed);
	if (_cur.json == _before.json) {
		return;
	}
	if (!is_array(_ed.undo)) {
		_ed.undo = [];
	}
	if (!is_array(_ed.redo)) {
		_ed.redo = [];
	}
	array_push(_ed.undo, _before);
	_ed.redo = [];
	while (array_length(_ed.undo) > 100) {
		array_delete(_ed.undo, 0, 1);
	}
	_ed.dirty = true;
}

/// True when two placement descriptors match within float tolerance.
function __gm3d_ed_desc_match(_a, _b) {
	var _ka = variable_struct_exists(_a, "kind") ? _a.kind : "asset";
	var _kb = variable_struct_exists(_b, "kind") ? _b.kind : "asset";
	if (_ka != _kb) {
		return false;
	}
	if (_ka == "asset") {
		var _aa = variable_struct_exists(_a, "asset") ? _a.asset : _a.name;
		var _ab = variable_struct_exists(_b, "asset") ? _b.asset : _b.name;
		if (_aa != _ab) {
			return false;
		}
	}
	if (_a.name != _b.name) {
		return false;
	}
	var _t = 0.0001;
	var _pa = _a.position;
	var _pb = _b.position;
	var _sa = _a.scale;
	var _sb = _b.scale;
	var _ra = _a.rotation;
	var _rb = _b.rotation;
	for (var _i = 0; _i < 3; _i++) {
		if (abs(_pa[_i] - _pb[_i]) > _t) {
			return false;
		}
		if (abs(_sa[_i] - _sb[_i]) > _t) {
			return false;
		}
	}
	for (var _j = 0; _j < 4; _j++) {
		if (abs(_ra[_j] - _rb[_j]) > _t) {
			return false;
		}
	}
	return true;
}

/// Restores selection by descriptor match over the fresh scene.
/// @param _sel_descs selection descriptors.
function __gm3d_ed_history_restore_sel(_ed, _sel_descs) {
	var _out = [];
	if (is_array(_sel_descs) && array_length(_sel_descs) > 0) {
		var _roots = [];
		_roots = _ed.rt.scene.getNodes();
		var _used = [];
		for (var _u = 0; _u < array_length(_roots); _u++) {
			array_push(_used, false);
		}
		for (var _i = 0; _i < array_length(_sel_descs); _i++) {
			for (var _j = 0; _j < array_length(_roots); _j++) {
				if (_used[_j]) {
					continue;
				}
				var _d = __gm3d_ed_node_desc(_ed, _roots[_j]);
				if (_d == undefined) {
					continue;
				}
				if (__gm3d_ed_desc_match(_sel_descs[_i], _d)) {
					array_push(_out, _roots[_j]);
					_used[_j] = true;
					break;
				}
			}
		}
	}
	_ed.sel = _out;
	_ed.giz.drag = -1;
}

/// Undoes one snapshot via full scene rebuild.
function __gm3d_ed_history_undo(_ed) {
	if (!is_array(_ed.undo) || array_length(_ed.undo) == 0) {
		return false;
	}
	if (!is_array(_ed.redo)) {
		_ed.redo = [];
	}
	var _en = _ed.undo[array_length(_ed.undo) - 1];
	var _data = json_parse(_en.json);
	if (!is_array(_data)) {
		return false;
	}
	var _cur = undefined;
	_cur = __gm3d_ed_history_snap(_ed);
	array_pop(_ed.undo);
	array_push(_ed.redo, _cur);
	__gm3d_ed_rebuild(_ed, _data);
	__gm3d_ed_history_restore_sel(_ed, _en.sel);
	return true;
}

/// Redoes one snapshot via full scene rebuild.
function __gm3d_ed_history_redo(_ed) {
	if (!is_array(_ed.redo) || array_length(_ed.redo) == 0) {
		return false;
	}
	if (!is_array(_ed.undo)) {
		_ed.undo = [];
	}
	var _en = _ed.redo[array_length(_ed.redo) - 1];
	var _data = json_parse(_en.json);
	if (!is_array(_data)) {
		return false;
	}
	var _cur = undefined;
	_cur = __gm3d_ed_history_snap(_ed);
	array_pop(_ed.redo);
	array_push(_ed.undo, _cur);
	__gm3d_ed_rebuild(_ed, _data);
	__gm3d_ed_history_restore_sel(_ed, _en.sel);
	return true;
}

/// Undoes the last editor gesture (Ctrl+Z).
function gm3d_editor_undo() {
	var _e = gm3d_editor_inst();
	if (_e == undefined) {
		return false;
	}
	return __gm3d_ed_history_undo(_e);
}

/// Redoes the last undone gesture (Ctrl+Y).
function gm3d_editor_redo() {
	var _e = gm3d_editor_inst();
	if (_e == undefined) {
		return false;
	}
	return __gm3d_ed_history_redo(_e);
}

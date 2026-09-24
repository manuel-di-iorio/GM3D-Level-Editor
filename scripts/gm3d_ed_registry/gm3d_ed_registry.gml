/// @module gm3d_ed_registry
/// Asset library, tracked placements, selection and labels.

/// Adds a loaded model handle to the Models library.
/// @param _model loaded handle spawned by the editor via spawnInto (caller owns loading)
function gm3d_editor_asset_add(_ed, _name, _model) {
	if (_ed == undefined) {
		return;
	}
	if (!variable_struct_exists(_ed, "assets") || !is_array(_ed.assets)) {
		_ed.assets = [];
	}
	if (_name == undefined || _name == "" || _model == undefined) {
		return;
	}
	array_push(_ed.assets, { name: _name, model: _model });
}

/// Clears the Models library.
function gm3d_editor_asset_clear(_ed) {
	if (_ed == undefined) {
		return;
	}
	_ed.assets = [];
}

/// Clears the selection and any gizmo hover/drag state.
function __gm3d_ed_sel_clear(_ed) {
	_ed.sel = [];
	_ed.giz.drag = -1;
	_ed.giz.hover = -1;
}

/// True when _node is in the current selection.
function __gm3d_ed_sel_has(_ed, _node) {
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		if (_ed.sel[_i] == _node) {
			return true;
		}
	}
	return false;
}

/// Adds _node to the selection, or removes it when already selected.
function __gm3d_ed_sel_toggle(_ed, _node) {
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		if (_ed.sel[_i] == _node) {
			array_delete(_ed.sel, _i, 1);
			return;
		}
	}
	array_push(_ed.sel, _node);
}

/// Finds a library model by name.
/// @return Model handle or undefined when missing.
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

/// Records a spawned placement by live name and position.
/// @param _pos3 [x, y, z] spawn position used for matching.
/// @param _label Display name, defaults to the live node name.
function __gm3d_ed_spawn_register(_ed, _node, _asset, _pos3, _label = undefined) {
	if (_ed == undefined || _node == undefined || _asset == undefined || _asset == "") {
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
		asset: _asset,
		name: _nm,
		label: _label,
		pos: _pos3 != undefined ? _pos3 : [0, 0, 0],
	});
}

/// Spawns one library model into the live scene and tracks the placement.
/// Single funnel for every editor creation path (drop, duplicate, load):
/// the editor owns placement (spawnInto, TRS, registry entry). When the
/// adapter defines on_spawn(inst, node, asset, model), it runs after TRS so
/// the game can finish the instance (animation state, AI, ...) without
/// owning placement.
/// @param _asset library name for tracking.
/// @param _model loaded handle from gm3d_editor_asset_add.
/// @param _pos3 [x, y, z] spawn position.
/// @param _rot rotation quat or undefined for the spawn default.
/// @param _scale3 [sx, sy, sz] spawn scale.
/// @param _label display name, defaults to the live node name.
/// @return Spawned root node or undefined.
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

/// Tracks a game-spawned node so it appears in Scene, Inspector, save and undo.
function gm3d_editor_track_node(_ed, _asset, _node, _label = undefined) {
	if (_ed == undefined || _node == undefined) {
		return;
	}
	var _pp = _node.getLocalPosition();
	__gm3d_ed_spawn_register(_ed, _node, _asset, [_pp.x, _pp.y, _pp.z], _label);
}

/// Returns a unique display label based on _base.
/// @return Free label (appends " 2", " 3", ...).
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

/// Re-points tracked rows at the live positions of moved nodes.
function __gm3d_ed_rows_follow(_ed, _nodes) {
	if (!is_array(_nodes)) {
		return;
	}
	for (var _i = 0; _i < array_length(_nodes); _i++) {
		var _en = __gm3d_ed_registry_find(_ed, _nodes[_i]);
		if (_en == undefined) {
			continue;
		}
		var _pp = _nodes[_i].getLocalPosition();
		_en.pos = [_pp.x, _pp.y, _pp.z];
	}
}

/// Drops the tracked entry nearest to a node.
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

/// Finds the tracked entry for a node by live name and nearest position.
/// @return Tracked entry or undefined.
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

/// Returns the library name for a node.
function __gm3d_ed_asset_name(_ed, _node) {
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en == undefined) {
		return undefined;
	}
	return _en.asset;
}

/// Returns the display label for a node, or the live node name when untracked.
function __gm3d_ed_label_get(_ed, _node) {
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en != undefined && is_string(_en.label) && _en.label != "") {
		return _en.label;
	}
	var _nm = "node";
	_nm = _node.name;
	return _nm;
}

/// Builds a serializable asset descriptor for a live node.
/// @return Descriptor or undefined when the library entry is missing.
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
	return {
		asset: _en.asset,
		name: _label,
		position: [_p.x, _p.y, _p.z],
		rotation: [_q.x, _q.y, _q.z, _q.w],
		scale: [_s.x, _s.y, _s.z],
	};
}

/// Returns root nodes that have a tracked registry entry.
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

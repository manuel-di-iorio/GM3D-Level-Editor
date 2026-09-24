/// @module gm3d_ed_scene_ops
/// Scene operations: new, delete, duplicate, focus and drop point.

/// Ground-plane drop point for the mouse (exact raycast, never 2D approx).
function __gm3d_ed_drop_point(_ed, _vp, _mx, _my) {
	var _ray = __gm3d_ed_screen_ray(_vp, _mx, _my);
	var _hit = __gm3d_ed_ray_plane(_ray.origin, _ray.dir, new GM3D_Vec3(0, 0, 0), new GM3D_Vec3(0, 1, 0));
	if (_hit != undefined) {
		return _hit;
	}
	var _pp = _ed.rt.cam.getLocalPosition();
	var _f = __gm3d_ed_view_forward(_ed);
	return new GM3D_Vec3(_pp.x - _f.x * 6, 0, _pp.z - _f.z * 6);
}

/// Normalizes a drag rectangle to { x0, y0, x1, y1 } (top-left to bottom-right).
function __gm3d_ed_rect_norm(_r) {
	return {
		x0: min(_r.x0, _r.x1),
		y0: min(_r.y0, _r.y1),
		x1: max(_r.x0, _r.x1),
		y1: max(_r.y0, _r.y1),
	};
}

/// Destroys a node and its whole subtree, deepest first.
function __gm3d_ed_destroy_subtree(_node) {
	if (_node == undefined) {
		return;
	}
	var _kids = _node.getChildren();
	for (var _i = 0; _i < array_length(_kids); _i++) {
		__gm3d_ed_destroy_subtree(_kids[_i]);
	}
	_node.destroy();
}

/// Clears all tracked placements to start a new empty scene.
function __gm3d_ed_new_scene(_ed) {
	var _tracked = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_tracked); _i++) {
		__gm3d_ed_destroy_subtree(_tracked[_i]);
	}
	_ed.rt.scene.update(0);
	_ed.tracked = [];
	__gm3d_ed_sel_clear(_ed);
	__gm3d_ed_history_clear(_ed);
	_ed.dirty = false;
	_ed.drag_lib = undefined;
	_ed.drag_moved = false;
	_ed.rect = undefined;
	_ed.press_vp = false;
	_ed.scene_file = "";
}

/// Deletes the current selection; undoable.
function __gm3d_ed_delete_sel(_ed) {
	if (array_length(_ed.sel) == 0) {
		return;
	}
	var _victims = [];
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		array_push(_victims, _ed.sel[_i]);
	}
	if (array_length(_victims) == 0) {
		return;
	}
	var _before = undefined;
	_before = __gm3d_ed_history_snap(_ed);
	for (var _j = 0; _j < array_length(_victims); _j++) {
		__gm3d_ed_spawn_unregister(_ed, _victims[_j]);
		__gm3d_ed_destroy_subtree(_victims[_j]);
	}
	_ed.rt.scene.update(0);
	__gm3d_ed_sel_clear(_ed);
	if (_before != undefined) {
		__gm3d_ed_history_commit(_ed, _before);
	}
}

/// Duplicates the current selection with an offset, selects the copies; undoable.
function __gm3d_ed_duplicate_sel(_ed) {
	var _n = array_length(_ed.sel);
	if (_n == 0) {
		return;
	}

	var _before = undefined;
	_before = __gm3d_ed_history_snap(_ed);
	var _out = [];
	var _off = _ed.cfg.duplicate_offset;
	for (var _i = 0; _i < _n; _i++) {
		var _s = _ed.sel[_i];
		var _aname = __gm3d_ed_asset_name(_ed, _s);
		if (_aname == undefined) {
			continue;
		}
		var _model = __gm3d_ed_asset_find(_ed, _aname);
		if (_model == undefined) {
			continue;
		}
		var _sp = _s.getLocalPosition();
		var _ss = _s.getLocalScale();
		var _nx = _sp.x + _off;
		var _nz = _sp.z + _off;
		var _c = __gm3d_ed_place(
			_ed,
			_aname,
			_model,
			[_nx, _sp.y, _nz],
			_s.getLocalRotation().clone(),
			[_ss.x, _ss.y, _ss.z],
			__gm3d_ed_fresh_label(_ed, __gm3d_ed_label_get(_ed, _s)),
		);
		if (_c == undefined) {
			continue;
		}
		array_push(_out, _c);
	}
	if (array_length(_out) > 0) {
		_ed.sel = _out;
	}
	if (_before != undefined) {
		__gm3d_ed_history_commit(_ed, _before);
	}
}

/// Returns the focus target for the current selection.
function __gm3d_ed_focus_target(_ed) {
	var _n = array_length(_ed.sel);
	if (_n == 0) {
		return undefined;
	}
	var _mn = undefined;
	var _mx = undefined;
	for (var _i = 0; _i < _n; _i++) {
		var _box = undefined;
		_box = __gm3d_ed_node_aabb(_ed.sel[_i]);
		if (_box == undefined || !_box.valid) {
			continue;
		}
		if (_mn == undefined) {
			_mn = _box.min.clone();
			_mx = _box.max.clone();
		} else {
			_mn.x = min(_mn.x, _box.min.x);
			_mn.y = min(_mn.y, _box.min.y);
			_mn.z = min(_mn.z, _box.min.z);
			_mx.x = max(_mx.x, _box.max.x);
			_mx.y = max(_mx.y, _box.max.y);
			_mx.z = max(_mx.z, _box.max.z);
		}
	}
	if (_mn != undefined) {
		var _cx = (_mn.x + _mx.x) * 0.5;
		var _cy = (_mn.y + _mx.y) * 0.5;
		var _cz = (_mn.z + _mx.z) * 0.5;
		return {
			center: new GM3D_Vec3(_cx, _cy, _cz),
			mn: _mn,
			mx: _mx,
			radius: 1.0,
		};
	}
	var _p = __gm3d_ed_gizmo_pivot(_ed.sel);
	if (_p == undefined) {
		return undefined;
	}
	return { center: _p, radius: 1.0 };
}

/// Moves the camera to frame the current selection.
/// @return True when a selection was focused.
function __gm3d_ed_focus_selection(_ed) {
	var _t = __gm3d_ed_focus_target(_ed);
	if (_t == undefined) {
		return false;
	}
	if (_ed.rt == undefined) {
		return false;
	}
	var _vp = __gm3d_ed_viewport(_ed);
	var _fwd = __gm3d_ed_view_forward(_ed);
	var _fov = clamp(_vp.fovY, 0.05, 3.1);
	var _dist = 5.0;
	if (variable_struct_exists(_t, "mn")) {
		var _vx = -_fwd.x;
		var _vy = -_fwd.y;
		var _vz = -_fwd.z;
		var _rx = -_vz;
		var _ry = 0.0;
		var _rz = _vx;
		var _rl = sqrt(_rx * _rx + _rz * _rz);
		if (_rl < 0.0001) {
			_rx = 1.0;
			_ry = 0.0;
			_rz = 0.0;
		} else {
			_rx /= _rl;
			_rz /= _rl;
		}
		var _ux = _ry * _vz - _rz * _vy;
		var _uy = _rz * _vx - _rx * _vz;
		var _uz = _rx * _vy - _ry * _vx;
		var _ex = (_t.mx.x - _t.mn.x) * 0.5;
		var _ey = (_t.mx.y - _t.mn.y) * 0.5;
		var _ez = (_t.mx.z - _t.mn.z) * 0.5;
		var _ax = abs(_ux);
		var _ay = abs(_uy);
		var _az = abs(_uz);
		var _h = _ex * _ax + _ey * _ay + _ez * _az;
		var _w = _ex * abs(_rx) + _ey * abs(_ry) + _ez * abs(_rz);
		var _d = _ex * abs(_vx) + _ey * abs(_vy) + _ez * abs(_vz);
		var _tanY = max(tan(_fov * 0.5), 0.05);
		var _aspect = 16.0 / 9.0;
		if (_ed.gw > 0 && _ed.gh > 0) {
			_aspect = _ed.gw / _ed.gh;
		}
		var _tanX = _tanY * max(_aspect, 0.1);
		_dist = max(_h / _tanY, _w / _tanX) * 1.2 + _d + 0.3;
	} else {
		var _fit = _t.radius / max(sin(_fov * 0.5), 0.1);
		_dist = _fit * 1.2 + 0.3;
	}
	_dist = clamp(_dist, 1.5, 150.0);
	_ed.rt.cam.setLocalPosition(
		new GM3D_Vec3(_t.center.x + _fwd.x * _dist, _t.center.y + _fwd.y * _dist, _t.center.z + _fwd.z * _dist),
	);
	return true;
}

/// Selects a node and moves the camera to frame it.
/// @return True on success.
function __gm3d_ed_focus_node(_ed, _node) {
	if (_node == undefined) {
		return false;
	}
	_ed.sel = [_node];
	_ed.giz.drag = -1;
	return __gm3d_ed_focus_selection(_ed);
}

/// Selects exactly one node, clearing the previous selection.
function __gm3d_ed_scene_select(_ed, _node) {
	_ed.sel = [_node];
	_ed.giz.drag = -1;
}

/// Handles outliner row clicks: select on single click, focus on double click.
function __gm3d_ed_scene_click(_ed, _nd, _row) {
	var _now = current_time;
	if (_ed.scene_click_idx == _row && _now - _ed.scene_click_time <= 400) {
		__gm3d_ed_scene_select(_ed, _nd);
		__gm3d_ed_focus_node(_ed, _nd);
		_ed.scene_click_idx = -1;
		_ed.scene_click_time = -10000;
	} else {
		__gm3d_ed_scene_select(_ed, _nd);
		_ed.scene_click_idx = _row;
		_ed.scene_click_time = _now;
	}
}

/// Renames a node label; undoable.
function __gm3d_ed_scene_commit_rename(_ed, _node, _new_label) {
	var _hb = __gm3d_ed_history_snap(_ed);
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en != undefined) {
		_en.label = _new_label;
	}
	if (_hb != undefined) {
		__gm3d_ed_history_commit(_ed, _hb);
	}
}

/// Applies a deferred outliner context-menu action.
function __gm3d_ed_scene_list_commit(_ed, _ren, _foc, _dup, _del) {
	if (_ren != undefined) {
		__gm3d_ed_scene_select(_ed, _ren);
		__gm3d_ed_rename_begin(_ed, _ren);
	}
	if (_foc != undefined) {
		__gm3d_ed_focus_node(_ed, _foc);
	}
	if (_dup != undefined) {
		__gm3d_ed_scene_select(_ed, _dup);
		__gm3d_ed_duplicate_sel(_ed);
	}
	if (_del != undefined) {
		__gm3d_ed_scene_select(_ed, _del);
		__gm3d_ed_delete_sel(_ed);
	}
}

/// Applies an inspector axis edit to the selection; undoable.
/// @param _mode 0 position, 1 rotation, 2 scale (clamped).
function __gm3d_ed_inspector_apply(_ed, _mode, _idx, _v) {
	var _vv = _v;
	if (_mode == 2) {
		_vv = max(_vv, 0.01);
	}
	var _hsnap = __gm3d_ed_history_snap(_ed);
	__gm3d_ed_apply_axis(_ed, _mode, _idx, _vv);
	__gm3d_ed_rows_follow(_ed, _ed.sel);
	if (_hsnap != undefined) {
		__gm3d_ed_history_commit(_ed, _hsnap);
	}
}

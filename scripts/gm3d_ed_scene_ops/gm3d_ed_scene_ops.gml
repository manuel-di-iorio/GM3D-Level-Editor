// Checks if node is editor grid.
function __gm3d_ed_is_grid(_ed, _node) {
	if (_node == undefined) {
		return false;
	}
	if (_ed != undefined && variable_struct_exists(_ed, "grid_node") && _ed.grid_node != undefined) {
		if (_node == _ed.grid_node) {
			return true;
		}
	}
	if (is_string(_node.name) && _node.name == "__editor_grid") {
		return true;
	}
	return false;
}

// Creates editor grid if enabled.
function __gm3d_ed_grid_ensure(_ed) {
	if (_ed == undefined || _ed.rt == undefined || _ed.rt.scene == undefined) {
		return;
	}
	if (!variable_struct_exists(_ed, "grid_node")) {
		_ed.grid_node = undefined;
	}
	if (!variable_struct_exists(_ed, "grid_src")) {
		_ed.grid_src = undefined;
	}
	if (!variable_struct_exists(_ed, "grid_mat")) {
		_ed.grid_mat = undefined;
	}
	if (!variable_struct_exists(_ed, "grid_step") || !is_real(_ed.grid_step)) {
		_ed.grid_step = 1;
	}
	if (!variable_struct_exists(_ed, "show_grid") || !_ed.show_grid) {
		__gm3d_ed_grid_remove(_ed);
		return;
	}
	if (_ed.grid_node != undefined) {
		return;
	}
	if (_ed.grid_src == undefined) {
		var _path = working_directory + "__gm3dEditorGrid.glb";
		if (!file_exists(_path)) {
			return;
		}
		var _src = GM3D_Scene.loadGltf(_path);
		if (_src == undefined) {
			return;
		}
		var _mats = _src.getMaterials();
		for (var _i = 0; _i < array_length(_mats); ++_i) {

			_mats[_i].setShader(GM3D_ERenderPass.Forward, shGM3DGrid);
		}
		_src.freeze();
		_ed.grid_src = _src;
	}
	var _n = _ed.grid_src.spawnInto(_ed.rt.scene, undefined);
	if (_n == undefined) {
		return;
	}
	_ed.grid_node = _n;
	var _gmats = _ed.grid_src.getMaterials();
	_ed.grid_mat = array_length(_gmats) > 0 ? _gmats[0] : undefined;
	__gm3d_ed_grid_bg_sync(_ed);
	__gm3d_ed_grid_step_sync(_ed);
	_ed.rt.scene.update(0);
}

// Updates grid shader step size.
function __gm3d_ed_grid_step_sync(_ed) {
	if (_ed == undefined) {
		return;
	}
	var _s = 1;
	if (variable_struct_exists(_ed, "grid_step") && is_real(_ed.grid_step)) {
		_s = clamp(_ed.grid_step, 0.1, 8);
	}
	var _mats = [];
	if (variable_struct_exists(_ed, "grid_src") && _ed.grid_src != undefined) {
		try {
			_mats = _ed.grid_src.getMaterials();
		} catch (_e) {
			_mats = [];
		}
	}
	if (!is_array(_mats) || array_length(_mats) == 0) {
		if (variable_struct_exists(_ed, "grid_mat") && _ed.grid_mat != undefined) {
			_mats = [_ed.grid_mat];
		}
	}
	for (var _i = 0; _i < array_length(_mats); ++_i) {
		try {
			_mats[_i].setFloat("u_grid_step", _s);
		} catch (_e2) {
		}
	}
}

// Sets grid step and refreshes.
function __gm3d_ed_grid_set_step(_ed, _v) {
	if (_ed == undefined || !is_real(_v)) {
		return;
	}
	_ed.grid_step = clamp(_v, 0.1, 8);
	__gm3d_ed_grid_step_sync(_ed);
	if (_ed.rt != undefined && _ed.rt.scene != undefined && variable_struct_exists(_ed, "grid_node") && _ed.grid_node != undefined) {
		try {
			_ed.rt.scene.update(0);
		} catch (_e2) {
		}
	}
}

// Syncs grid background color.
function __gm3d_ed_grid_bg_sync(_ed) {
	if (_ed == undefined || !variable_struct_exists(_ed, "grid_mat") || _ed.grid_mat == undefined) {
		return;
	}
	var _c = window_get_colour();
	_ed.grid_mat.setFloatArray("u_grid_bg", [colour_get_red(_c) / 255, colour_get_green(_c) / 255, colour_get_blue(_c) / 255]);
}

// Removes editor grid node.
function __gm3d_ed_grid_remove(_ed) {
	if (_ed == undefined || !variable_struct_exists(_ed, "grid_node")) {
		return;
	}
	if (_ed.grid_node != undefined) {
		_ed.grid_node.destroy();
		_ed.grid_node = undefined;
		if (_ed.rt != undefined && _ed.rt.scene != undefined) {
			_ed.rt.scene.update(0);
		}
	}
}

// Computes ground plane drop point.
function __gm3d_ed_drop_point(_ed, _vp, _mx, _my) {
	var _ray = __gm3d_ed_screen_ray(_vp, _mx, _my);
	return __gm3d_ed_ray_plane(_ray.origin, _ray.dir, new GM3D_Vec3(0, 0, 0), new GM3D_Vec3(0, 1, 0));
}

// Normalizes rectangle corner coordinates.
function __gm3d_ed_rect_norm(_r) {
	return {
		x0: min(_r.x0, _r.x1),
		y0: min(_r.y0, _r.y1),
		x1: max(_r.x0, _r.x1),
		y1: max(_r.y0, _r.y1),
	};
}

// Destroys node and all children.
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

// Clears scene to empty state.
function __gm3d_ed_new_scene(_ed) {
	__gm3d_ed_drop_preview_clear(_ed);
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

// Reloads file or clears scene.
function __gm3d_ed_discard_changes(_ed) {
	var _path = __gm3d_ed_scene_path(_ed);
	if (_path != "" && file_exists(_path)) {
		if (__gm3d_ed_load_scene(_ed)) {
			__gm3d_ed_sel_clear(_ed);
			__gm3d_ed_history_clear(_ed);
		}
		return;
	}
	__gm3d_ed_new_scene(_ed);
}

// Deletes selected nodes with undo.
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

// Duplicates selected nodes with offset.
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
		var _kind = __gm3d_ed_kind_of(_ed, _s);
		if (_kind == "light" || _kind == "camera" || _kind == "environment") {
			var _c = __gm3d_ed_duplicate_prop(_ed, _s, _kind, _off);
			if (_c != undefined) {
				array_push(_out, _c);
			}
			continue;
		}
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

// Duplicates light camera environment node.
function __gm3d_ed_duplicate_prop(_ed, _src, _kind, _off) {
	var _en = __gm3d_ed_registry_find(_ed, _src);
	if (_en == undefined || !is_struct(_en.data)) {
		return undefined;
	}
	var _lbl = __gm3d_ed_fresh_label(_ed, __gm3d_ed_label_get(_ed, _src));
	var _node = _ed.rt.scene.createNode(_lbl);
	if (_node == undefined) {
		return undefined;
	}
	var _sp = _src.getLocalPosition();
	_node.setLocalPosition(new GM3D_Vec3(_sp.x + _off, _sp.y, _sp.z + _off));
	_node.setLocalScale(_src.getLocalScale().clone());
	_node.setLocalRotation(_src.getLocalRotation().clone());
	var _data = undefined;
	if (_kind == "light") {
		var _lc = new GM3D_LightComponent();
		_node.addComponent(_lc);
		_data = {
			type: _en.data.type,
			color: [_en.data.color[0], _en.data.color[1], _en.data.color[2]],
			intensity: _en.data.intensity,
			range: _en.data.range,
			inner: _en.data.inner,
			outer: _en.data.outer,
			enabled: _en.data.enabled == true,
		};
		__gm3d_ed_light_apply(_node, _data);
	} else if (_kind == "camera") {
		var _cc = new GM3D_CameraComponent();
		_node.addComponent(_cc);
		_data = {
			projection: _en.data.projection,
			fov: _en.data.fov,
			ow: _en.data.ow,
			oh: _en.data.oh,
			near: _en.data.near,
			far: _en.data.far,
			enabled: _en.data.enabled == true,
		};
		__gm3d_ed_camera_apply(_node, _data);
	} else {
		var _ec = new GM3D_EnvironmentVolumeComponent();
		_node.addComponent(_ec);
		_data = {
			size: [_en.data.size[0], _en.data.size[1], _en.data.size[2]],
			ambient: [_en.data.ambient[0], _en.data.ambient[1], _en.data.ambient[2]],
			fog: _en.data.fog == true,
			fogcolor: [_en.data.fogcolor[0], _en.data.fogcolor[1], _en.data.fogcolor[2]],
			fogstart: _en.data.fogstart,
			fogend: _en.data.fogend,
			enabled: _en.data.enabled == true,
		};
		__gm3d_ed_env_apply(_node, _data);
	}
	_ed.rt.scene.update(0);
	var _pp = _node.getLocalPosition();
	__gm3d_ed_kind_register(_ed, _node, _kind, "", [_pp.x, _pp.y, _pp.z], _lbl, _data);
	if (__gm3d_ed_hidden_get(_ed, _src)) {
		__gm3d_ed_hidden_set(_ed, _node, true);
	}
	__gm3d_ed_cameras_mute(_ed);
	return _node;
}

// Computes focus center from selection.
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

// Moves camera to frame selection.
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

// Selects and focuses single node.
function __gm3d_ed_focus_node(_ed, _node) {
	if (_node == undefined) {
		return false;
	}
	_ed.sel = [_node];
	_ed.giz.drag = -1;
	__gm3d_ed_sel_apply_tool(_ed);
	return __gm3d_ed_focus_selection(_ed);
}

// Selects single scene node.
function __gm3d_ed_scene_select(_ed, _node) {
	_ed.sel = [_node];
	_ed.giz.drag = -1;
	__gm3d_ed_sel_apply_tool(_ed);
}

// Handles scene list click and doubleclick.
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

// Commits renamed node label with undo.
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

// Applies pending scene list actions.
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

// Applies position rotation scale axis edit.
function __gm3d_ed_apply_axis(_ed, _mode, _idx, _v) {
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		var _n = _ed.sel[_i];
		if (_mode == 0) {
			var _p = _n.getLocalPosition().clone();
			if (_idx == 0) {
				_p.x = _v;
			} else if (_idx == 1) {
				_p.y = _v;
			} else {
				_p.z = _v;
			}
			_n.setLocalPosition(_p);
		} else if (_mode == 1) {
			var _e = __gm3d_ed_quat_to_euler(_n.getLocalRotation());
			_e[_idx] = degtorad(_v);
			_n.setLocalRotation(__gm3d_ed_euler_to_quat(_e[0], _e[1], _e[2]));
		} else {
			var _s = _n.getLocalScale().clone();
			if (_idx == 0) {
				_s.x = max(_v, 0.01);
			} else if (_idx == 1) {
				_s.y = max(_v, 0.01);
			} else {
				_s.z = max(_v, 0.01);
			}
			_n.setLocalScale(_s);
		}
	}
}

// Applies inspector edit with history.
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

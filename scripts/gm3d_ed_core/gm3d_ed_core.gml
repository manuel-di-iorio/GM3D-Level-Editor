/// @module gm3d_ed_core
/// Boot, loop, public API, central state and input orchestration.
/// NOTE: scene nodes have no stable identity; tracked placements match by live name + nearest recorded position.
enum Gm3dEdTool {
	Translate = 1,
	Rotate = 2,
	Scale = 3,
}

/// Public API: boot + loop
/// Creates editor state over a game runtime adapter.
function gm3d_editor_init(_self, _rt) {
	global.gm3d_editor_active = true;
	var _ed = __gm3d_ed_create(_self, _rt);
	__gm3d_ed_cam_remember(_ed);
	__gm3d_ed_ui_load(_ed);
	global.gm3d_editor_active = _ed.active;
	global.gm3d_editor_inst = _ed;
	return _ed;
}

/// Advances the frozen scene and editor input; call from Step event.
function gm3d_editor_step(_ed) {
	if (_ed == undefined || _ed.rt == undefined) {
		return;
	}
	if (_ed.active) {
		_ed.rt.scene.update(0);
	}
	var _dt = delta_time * 0.000001;
	__gm3d_ed_step(_ed, _dt);
	__gm3d_ed_imgui_draw(_ed);
}

/// Draws the 3D overlay; call from Draw GUI event.
function gm3d_editor_draw(_ed) {
	// Fresh viewport: the Step copy is stale after fly and gizmo moves.
	var _vp = undefined;
	if (_ed.rt != undefined) {
		_vp = __gm3d_ed_viewport(_ed);
	}
	var _modal = false;
	_modal = _ed.confirm != undefined;
	if (_modal) {
		draw_set_alpha(0.55);
		draw_set_color(c_black);
		draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
		draw_set_color(c_white);
		draw_set_alpha(1);
		draw_set_halign(fa_left);
		draw_set_valign(fa_top);
		return;
	}
	if (_ed.active && _vp != undefined) {
		if (_ed.rect != undefined && _ed.rect.on) {
			var _r = __gm3d_ed_rect_norm(_ed.rect);
			draw_set_alpha(0.15);
			draw_set_color(make_colour_rgb(90, 140, 250));
			draw_rectangle(_r.x0, _r.y0, _r.x1, _r.y1, false);
			draw_set_alpha(1);
			draw_rectangle(_r.x0, _r.y0, _r.x1, _r.y1, true);
		}
		if (_ed.drag_lib != undefined && _ed.drag_moved) {
			var _mx = device_mouse_x_to_gui(0);
			var _my = device_mouse_y_to_gui(0);
			if (__gm3d_ed_in_viewport(_ed, _mx, _my)) {
				draw_set_color(c_white);
				draw_set_halign(fa_center);
				draw_text(_mx, _my - 14, _ed.drag_lib.asset.name);
				draw_set_halign(fa_left);
				var _dp = __gm3d_ed_drop_point(_ed, _vp, _mx, _my);
				var _sp = __gm3d_ed_world_to_screen(_vp, _dp);
				if (_sp != undefined) {
					draw_set_color(make_colour_rgb(90, 140, 250));
					draw_circle(_sp[0], _sp[1], 10, true);
					draw_circle(_sp[0], _sp[1], 3, false);
					draw_set_color(c_white);
				}
			} else {
				draw_set_color(make_colour_rgb(90, 140, 250));
				draw_rectangle(_mx + 14, _my + 10, _mx + 150, _my + 32, false);
				draw_set_color(c_white);
				draw_set_valign(fa_middle);
				draw_text(_mx + 22, _my + 21, _ed.drag_lib.asset.name);
				draw_set_valign(fa_top);
			}
		}
		__gm3d_ed_gizmo_draw(_ed, _vp);
		__gm3d_ed_viewcube_draw(_ed, _vp);
	}
	if (!_ed.active) {
		draw_set_halign(fa_center);
		draw_set_color(c_white);
		draw_text(display_get_gui_width() * 0.5, 24, "Press F1 for the 3D in-game editor");
		draw_set_halign(fa_left);
	}
	draw_set_color(c_white);
	draw_set_alpha(1);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}

/// Unregisters the editor instance; call from CleanUp event.
function gm3d_editor_cleanup(_ed) {
	__gm3d_ed_ui_save(_ed);
	if (_ed != undefined && variable_global_exists("gm3d_editor_inst") && global.gm3d_editor_inst == _ed) {
		global.gm3d_editor_inst = undefined;
	}

	if (variable_global_exists("gm3d_editor_active")) {
		global.gm3d_editor_active = false;
	}
}

/// Returns the live editor state, or undefined when destroyed.
function gm3d_editor_inst() {
	var _st = undefined;

	if (!variable_global_exists("gm3d_editor_inst")) {
		return undefined;
	}
	_st = global.gm3d_editor_inst;

	if (_st == undefined) {
		return undefined;
	}

	if (_st.inst == undefined || _st.inst == noone || !instance_exists(_st.inst)) {
		return undefined;
	}

	return _st;
}

/// Sets the editor open state.
/// @param {Bool} _on true to open, false to close
function __gm3d_ed_set_active(_ed, _on) {
	if (_ed == undefined) {
		return;
	}
	var _was = _ed.active;
	_ed.active = _on;
	global.gm3d_editor_active = _on;
	if (_was && !_on && variable_struct_exists(_ed.rt, "on_close")) {
		_ed.rt.on_close(_ed.inst);
	}
}

/// Opens the editor UI (same as F1).
function gm3d_editor_enable() {
	var _e = gm3d_editor_inst();
	if (_e != undefined) {
		__gm3d_ed_set_active(_e, true);
	}
}

/// Closes the editor UI, leaving the scene running.
function gm3d_editor_disable() {
	var _e = gm3d_editor_inst();
	if (_e != undefined) {
		__gm3d_ed_set_active(_e, false);
	}
}

/// Toggles the editor UI (same as F1).
function gm3d_editor_toggle() {
	var _e = gm3d_editor_inst();
	if (_e != undefined) {
		__gm3d_ed_set_active(_e, !_e.active);
	}
}

/// True when the editor exists and its UI is open.
function gm3d_editor_is_active() {
	var _e = gm3d_editor_inst();
	return _e != undefined && _e.active;
}

/// Focuses the camera on the current selection.
function gm3d_editor_focus() {
	var _e = gm3d_editor_inst();
	if (_e == undefined) {
		return false;
	}
	return __gm3d_ed_focus_selection(_e);
}

/// Saves the scene, optionally switching files first.
/// @param {String} _fname scene path, undefined keeps the current file
function gm3d_editor_save(_fname) {
	var _e = gm3d_editor_inst();
	if (_e == undefined) {
		return false;
	}
	var _old = _e.scene_file;
	if (_fname != undefined) {
		_e.scene_file = _fname;
	}
	if (__gm3d_ed_save_or_ask(_e)) {
		return true;
	}
	_e.scene_file = _old;
	return false;
}

/// Saves through the OS dialog, always asking for a path.
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

/// Saves, asking for a path when no file is known yet.
function __gm3d_ed_save_or_ask(_ed) {
	if (_ed.scene_file == undefined || _ed.scene_file == "") {
		return __gm3d_ed_save_as(_ed);
	}
	var _ok = __gm3d_ed_save_scene(_ed);
	return _ok;
}

/// Asks to save dirty changes before a discard action.
/// @param {String} _action "new", "load" or "close"
function __gm3d_ed_confirm_ask(_ed, _action) {
	var _dirty = false;
	_dirty = _ed.dirty == true;
	if (!_dirty) {
		__gm3d_ed_confirm_do(_ed, _action);
		return;
	}
	_ed.confirm = { action: _action, open: true };
}

/// Runs the confirmed discard action.
function __gm3d_ed_confirm_do(_ed, _action) {
	if (_action == "new") {
		__gm3d_ed_new_scene(_ed);
	} else if (_action == "load") {
		gm3d_editor_load();
	} else if (_action == "close") {
		__gm3d_ed_set_active(_ed, false);
	}
}

/// Loads a scene at runtime.
/// @param {String} _fname path, undefined asks, empty aborts
function gm3d_editor_load(_fname) {
	var _e = gm3d_editor_inst();
	if (_e == undefined) {
		return false;
	}
	var _old = _e.scene_file;

	if (_fname == undefined) {
		_fname = get_open_filename("Scene JSON (*.json)|*.json", "scene.json");
		if (_fname == "") {
			return false;
		}
	}
	_e.scene_file = _fname;
	if (__gm3d_ed_load_scene(_e)) {
		return true;
	}

	_e.scene_file = _old;
	return false;
}

/// Clears to an empty scene, keeping environment, light and camera.
function gm3d_editor_new_scene() {
	var _e = gm3d_editor_inst();
	if (_e == undefined) {
		return;
	}
	__gm3d_ed_new_scene(_e);
}

/// State
/// Creates the central editor state struct.
function __gm3d_ed_create(_inst, _rt) {
	var _ed = {
		inst: _inst,
		rt: _rt,
		cfg: {
			ndc_yup: true, // Deprecated: use ed.ndc_yup
			keys: {
				toggle: vk_f1,
				tool_move: ord("1"),
				tool_rotate: ord("2"),
				tool_scale: ord("3"),
				del: vk_delete,
				save: ord("S"),
				dupe: ord("D"),
				new_scene: ord("N"),
				cancel: vk_escape,
				focus: ord("F"),
				undo: ord("Z"),
				redo: ord("Y"),
				rename: vk_f2,
				load: ord("L"),
			},
			snap: { on: false, pos: 0.5, rot: 15 }, // Deprecated: use ed.snap_*
			gizmo_px: 90, // Deprecated: use ed.giz.size
			duplicate_offset: 0.6,
		},
		active: true,
		dirty: false,
		assets: [],
		sel: [],
		tracked: [],
		ndc_yup: true,
		giz: {
			tool: Gm3dEdTool.Translate,
			hover: -1,
			drag: -1,
			size: 90,
			starts: [],
			pivot: undefined,
			dir: undefined,
			axis_idx: 0,
			plane_n: undefined,
			center: false,
			planar: false,
			world_len: 1,
			start_hit: undefined,
			mx0: 0,
			my0: 0,
			piv_sx: 0,
			piv_sy: 0,
			last_ang: 0,
			total_ang: 0,
			len: 1,
			len_key: undefined,
			orient: 0,
			sector_a0: 0,
		},
		pick_cycle_x: -10000,
		pick_cycle_y: -10000,
		pick_cycle_time: -10000,
		pick_cycle_index: -1,
		scene_click_idx: -1,
		scene_click_time: -10000,
		rename_name: undefined,
		rename_pos: undefined,
		confirm: undefined,
		undo: [],
		redo: [],
		imgui: undefined,
		imgui_ok: undefined,
		drag_lib: undefined,
		drag_moved: false,
		rect: undefined,
		press_vp: false,
		press_x: 0,
		press_y: 0,
		cube_armed: undefined,
		cube_hover: undefined,
		cube_face: undefined,
		cube_moved: false,
		cube_gx: 0,
		cube_gy: 0,
		cube_off: [85, 100],
		vp: undefined,
		cam_anim: undefined,
		cam_home: undefined,
		hist_before: undefined,
		cube_geom: undefined,
		scene_file: "",
		snap_on: false,
		snap_pos: 0.5,
		snap_rot: 15,
		gw: 1366,
		gh: 768,
	};
	return _ed;
}

/// Input
/// Runs per-frame camera, hotkeys and viewport input in priority order.
function __gm3d_ed_step(_ed, _dt) {
	_ed.gw = max(320, display_get_gui_width());
	_ed.gh = max(200, display_get_gui_height());
	var _keys = _ed.cfg.keys;

	if (keyboard_check_pressed(_keys.toggle)) {
		if (!_ed.active) {
			__gm3d_ed_set_active(_ed, true);
		} else {
			__gm3d_ed_confirm_ask(_ed, "close");
		}
	}
	if (!_ed.active) {
		return;
	}

	var _mx = device_mouse_x_to_gui(0);
	var _my = device_mouse_y_to_gui(0);
	var _typing = __gm3d_ed_ui_typing(_ed);
	var _in_vp = __gm3d_ed_in_viewport(_ed, _mx, _my);
	var _vp = __gm3d_ed_viewport(_ed);
	_ed.vp = _vp;

	var _modal = false;
	_modal = _ed.confirm != undefined;
	if (_modal) {
		if (!_typing && keyboard_check_pressed(_keys.cancel)) {
			_ed.confirm = undefined;
		}
		return;
	}

	__gm3d_ed_cam_fly(_ed, _vp, _dt, !_typing, _in_vp && _ed.drag_lib == undefined);
	__gm3d_ed_cam_anim_step(_ed, _dt);

	__gm3d_ed_step_hotkeys(_ed, _keys, _typing);
	__gm3d_ed_step_cancel(_ed, _keys, _typing);
	if (__gm3d_ed_step_gizmo(_ed, _vp, _mx, _my)) {
		return;
	}
	if (__gm3d_ed_step_libdrop(_ed, _vp, _mx, _my, _in_vp)) {
		return;
	}
	if (__gm3d_ed_step_rect(_ed, _vp, _mx, _my)) {
		return;
	}
	__gm3d_ed_step_hover(_ed, _vp, _mx, _my, _in_vp, _typing);
}

/// Handles tool, nudge and Ctrl hotkeys.
function __gm3d_ed_step_hotkeys(_ed, _keys, _typing) {
	if (!_typing) {
		var _ctrl = keyboard_check(vk_control);
		var _gesture = _ed.giz.drag != -1 || _ed.drag_lib != undefined || (_ed.rect != undefined && _ed.rect.on);
		if (!_ctrl && !_gesture) {
			if (keyboard_check_pressed(_keys.tool_move)) {
				_ed.giz.tool = Gm3dEdTool.Translate;
			}
			if (keyboard_check_pressed(_keys.tool_rotate)) {
				_ed.giz.tool = Gm3dEdTool.Rotate;
			}
			if (keyboard_check_pressed(_keys.tool_scale)) {
				_ed.giz.tool = Gm3dEdTool.Scale;
			}
			if (keyboard_check_pressed(_keys.del)) {
				__gm3d_ed_delete_sel(_ed);
			}
			if (variable_struct_exists(_keys, "focus") && keyboard_check_pressed(_keys.focus)) {
				__gm3d_ed_focus_selection(_ed);
			}
			if (
				variable_struct_exists(_keys, "rename") &&
				keyboard_check_pressed(_keys.rename) &&
				array_length(_ed.sel) > 0
			) {
				__gm3d_ed_rename_begin(_ed, _ed.sel[0]);
			}
			var _njx = keyboard_check_pressed(vk_right) - keyboard_check_pressed(vk_left);
			var _njz = keyboard_check_pressed(vk_down) - keyboard_check_pressed(vk_up);
			if ((_njx != 0 || _njz != 0) && array_length(_ed.sel) > 0) {
				var _nst = _ed.snap_on ? _ed.snap_pos : 0.25;
				var _hb = undefined;
				_hb = __gm3d_ed_history_snap(_ed);
				for (var _ni = 0; _ni < array_length(_ed.sel); _ni++) {
					var _np = _ed.sel[_ni].getLocalPosition();
					_ed.sel[_ni].setLocalPosition(new GM3D_Vec3(_np.x + _njx * _nst, _np.y, _np.z + _njz * _nst));
				}
				__gm3d_ed_rows_follow(_ed, _ed.sel);
				if (_hb != undefined) {
					__gm3d_ed_history_commit(_ed, _hb);
				}
			}
		}
		if (!_gesture && _ctrl && keyboard_check_pressed(_keys.save)) {
			__gm3d_ed_save_or_ask(_ed);
		}
		if (!_gesture && _ctrl && keyboard_check_pressed(_keys.dupe)) {
			__gm3d_ed_duplicate_sel(_ed);
		}
		if (!_gesture && _ctrl && keyboard_check_pressed(_keys.new_scene)) {
			__gm3d_ed_confirm_ask(_ed, "new");
		}
		if (variable_struct_exists(_keys, "load") && !_gesture && _ctrl && keyboard_check_pressed(_keys.load)) {
			__gm3d_ed_confirm_ask(_ed, "load");
		}
		if (!_gesture && _ctrl) {
			var _has_undo = variable_struct_exists(_keys, "undo");
			var _has_redo = variable_struct_exists(_keys, "redo");
			if (_has_undo && !keyboard_check(vk_shift) && keyboard_check_pressed(_keys.undo)) {
				__gm3d_ed_history_undo(_ed);
			} else if (
				(_has_redo && keyboard_check_pressed(_keys.redo)) ||
				(_has_undo && keyboard_check(vk_shift) && keyboard_check_pressed(_keys.undo))
			) {
				__gm3d_ed_history_redo(_ed);
			}
		}
	}
}

/// Handles cascading Esc cancel for confirm, rename, drag, rect and gizmo.
function __gm3d_ed_step_cancel(_ed, _keys, _typing) {
	if (!_typing && keyboard_check_pressed(_keys.cancel)) {
		if (_ed.confirm != undefined) {
			_ed.confirm = undefined;
		} else if (_ed.rename_name != undefined) {
			__gm3d_ed_rename_cancel(_ed);
		} else if (_ed.drag_lib != undefined) {
			_ed.drag_lib = undefined;
		} else if (_ed.rect != undefined) {
			_ed.rect = undefined;
		} else if (_ed.giz.drag != -1) {
			var _g = _ed.giz;
			if (is_array(_g.starts) && array_length(_g.starts) == array_length(_ed.sel)) {
				for (var _i = 0; _i < array_length(_ed.sel); _i++) {
					_ed.sel[_i].setLocalPosition(_g.starts[_i].pos.clone());
					_ed.sel[_i].setLocalRotation(_g.starts[_i].rot.clone());
					_ed.sel[_i].setLocalScale(_g.starts[_i].sca.clone());
				}
				_ed.rt.scene.update(0);
			}
			_ed.giz.drag = -1;
			_ed.hist_before = undefined;
		} else {
			__gm3d_ed_sel_clear(_ed);
		}
	}
}

/// Continues the active gizmo drag; returns true when handled.
function __gm3d_ed_step_gizmo(_ed, _vp, _mx, _my) {
	if (_ed.giz.drag != -1) {
		if (!mouse_check_button(mb_left)) {
			_ed.giz.drag = -1;

			if (_ed.hist_before != undefined) {
				__gm3d_ed_history_commit(_ed, _ed.hist_before);
			}
			__gm3d_ed_rows_follow(_ed, _ed.sel);

			_ed.hist_before = undefined;
		} else {
			__gm3d_ed_gizmo_drag(_ed, _vp, _mx, _my);
		}
		_ed.giz.hover = _ed.giz.drag;
		_ed.rect = undefined;
		_ed.press_vp = false;
		return true;
	}
	return false;
}

/// Continues library drag and drop; returns true when handled.
function __gm3d_ed_step_libdrop(_ed, _vp, _mx, _my, _in_vp) {
	if (_ed.drag_lib != undefined) {
		if (point_distance(_mx, _my, _ed.press_x, _ed.press_y) > 4) {
			_ed.drag_moved = true;
		}
		if (!mouse_check_button(mb_left)) {
			var _drop = undefined;
			if (_ed.drag_moved && _in_vp) {
				_drop = __gm3d_ed_drop_point(_ed, _vp, _mx, _my);
			} else if (!_ed.drag_moved) {
				var _pp = _ed.rt.cam.getLocalPosition();
				var _f = __gm3d_ed_view_forward(_ed);
				var _dist = 5.0;
				_drop = new GM3D_Vec3(_pp.x - _f.x * _dist, _pp.y - _f.y * _dist, _pp.z - _f.z * _dist);
			}
			if (_drop != undefined) {
				var _hb = undefined;
				_hb = __gm3d_ed_history_snap(_ed);
				var _asset = _ed.drag_lib.asset;
				var _n = __gm3d_ed_place(
					_ed,
					_asset.name,
					_asset.model,
					[_drop.x, _drop.y, _drop.z],
					undefined,
					[1, 1, 1],
					__gm3d_ed_fresh_label(_ed, _asset.name),
				);
				if (_n != undefined) {
					_ed.sel = [_n];
					_ed.giz.drag = -1;
				}
				if (_hb != undefined) {
					__gm3d_ed_history_commit(_ed, _hb);
				}
			}
			_ed.drag_lib = undefined;
			_ed.drag_moved = false;
		}
		return true;
	}
	return false;
}

/// Continues rectangle select; returns true when handled.
function __gm3d_ed_step_rect(_ed, _vp, _mx, _my) {
	if (_ed.rect != undefined && _ed.rect.on) {
		_ed.rect.x1 = _mx;
		_ed.rect.y1 = _my;
		if (!mouse_check_button(mb_left)) {
			var _r = __gm3d_ed_rect_norm(_ed.rect);
			if (abs(_r.x1 - _r.x0) > 6 || abs(_r.y1 - _r.y0) > 6) {
				var _hits = __gm3d_ed_pick_rect(_ed.rt.scene.getNodes(), _vp, _r);
				if (keyboard_check(vk_shift)) {
					for (var _i = 0; _i < array_length(_hits); _i++) {
						if (!__gm3d_ed_sel_has(_ed, _hits[_i])) {
							array_push(_ed.sel, _hits[_i]);
						}
					}
				} else {
					_ed.sel = _hits;
				}
			}
			_ed.rect = undefined;
			_ed.press_vp = false;
		}
		return true;
	}
	return false;
}

/// Updates gizmo and viewcube hover plus click pick.
function __gm3d_ed_step_hover(_ed, _vp, _mx, _my, _in_vp, _typing) {
	__gm3d_ed_imgui_ensure(_ed);
	_ed.cube_geom = _ed.imgui.win_cube.open ? __gm3d_ed_viewcube(_ed) : undefined;
	_ed.cube_hover = undefined;
	if (_in_vp && !mouse_check_button(mb_right) && _ed.cube_geom != undefined) {
		_ed.cube_hover = __gm3d_ed_viewcube_cone_at(_ed.cube_geom, _mx, _my);
	}

	_ed.giz.hover = -1;
	if (_in_vp && !mouse_check_button(mb_right)) {
		_ed.giz.hover = __gm3d_ed_gizmo_hover(_ed, _vp, _mx, _my);
	}
	if (_ed.cube_geom != undefined && __gm3d_ed_viewcube_box_at(_ed.cube_geom, _mx, _my)) {
		_ed.giz.hover = -1;
	}

	if (mouse_check_button_pressed(mb_left) && _in_vp && !_typing) {
		if (_ed.cube_geom != undefined && __gm3d_ed_viewcube_box_at(_ed.cube_geom, _mx, _my)) {
			_ed.press_vp = true;
			_ed.press_x = _mx;
			_ed.press_y = _my;
			_ed.cube_armed = true;
			_ed.cube_face = _ed.cube_hover;
			_ed.cube_moved = false;
			_ed.cube_gx = _mx - _ed.cube_geom.cx;
			_ed.cube_gy = _my - _ed.cube_geom.cy;
		} else if (_ed.giz.hover != -1 && array_length(_ed.sel) > 0) {
			_ed.giz.drag = _ed.giz.hover;
			__gm3d_ed_gizmo_begin(_ed, _vp, _mx, _my);
		} else {
			_ed.press_vp = true;
			_ed.press_x = _mx;
			_ed.press_y = _my;
			_ed.rect = { x0: _mx, y0: _my, x1: _mx, y1: _my, on: false };
		}
	}

	if (_ed.press_vp && _ed.rect != undefined && mouse_check_button(mb_left)) {
		if (point_distance(_mx, _my, _ed.press_x, _ed.press_y) > 6) {
			_ed.rect.on = true;
		}
	}
	if (_ed.cube_armed == true && mouse_check_button(mb_left)) {
		if (point_distance(_mx, _my, _ed.press_x, _ed.press_y) > 6) {
			_ed.cube_moved = true;
		}
		if (_ed.cube_moved) {
			var _ncx = clamp(_mx - _ed.cube_gx, 60, max(61, _ed.gw - 60));
			var _ncy = clamp(_my - _ed.cube_gy, 60, max(61, _ed.gh - 60));
			_ed.cube_off = [_ed.gw - _ncx, _ncy];
		}
	}
	if (mouse_check_button_released(mb_left) && _ed.press_vp && (_ed.rect == undefined || !_ed.rect.on)) {
		_ed.press_vp = false;
		_ed.rect = undefined;
		if (_ed.cube_armed == true) {
			_ed.cube_armed = undefined;
			if (_ed.cube_moved) {
				__gm3d_ed_ui_save(_ed);
			}
			if (_in_vp && !_ed.cube_moved && _ed.cube_face != undefined && _ed.cube_geom != undefined) {
				var _rf = __gm3d_ed_viewcube_cone_at(_ed.cube_geom, _mx, _my);
				if (_rf != undefined && _rf[0] == _ed.cube_face[0] && _rf[1] == _ed.cube_face[1]) {
					for (var _fi = 0; _fi < array_length(_ed.cube_geom.faces); _fi++) {
						var _ff = _ed.cube_geom.faces[_fi];
						if (_ff.a == _rf[0] && _ff.s == _rf[1]) {
							__gm3d_ed_viewcube_snap(_ed, _ff.n);
							break;
						}
					}
				}
			}
			_ed.cube_face = undefined;
		} else if (_in_vp) {
			var _hit = __gm3d_ed_pick_cycle(_ed, _ed.rt.scene.getNodes(), _vp, _mx, _my);
			if (keyboard_check(vk_shift)) {
				if (_hit != undefined) {
					__gm3d_ed_sel_toggle(_ed, _hit);
				}
			} else if (_hit != undefined) {
				_ed.sel = [_hit];
				_ed.giz.drag = -1;
			} else {
				__gm3d_ed_sel_clear(_ed);
			}
		}
	}
}

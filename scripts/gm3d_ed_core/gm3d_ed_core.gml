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
	__gm3d_ed_view_save(_ed);
	__gm3d_ed_view_sync(_ed);
	__gm3d_ed_bg_apply(_ed);
	__gm3d_ed_grid_ensure(_ed);
	__gm3d_ed_cameras_mute(_ed);
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
			// Over the scene the live preview is the feedback (no text/circle).
			if (!__gm3d_ed_drag_in_viewport(_ed, _mx, _my)) {
				draw_set_color(make_colour_rgb(90, 140, 250));
				draw_rectangle(_mx + 14, _my + 10, _mx + 150, _my + 32, false);
				draw_set_color(c_white);
				draw_set_valign(fa_middle);
				draw_text(_mx + 22, _my + 21, _ed.drag_lib.asset.name);
				draw_set_valign(fa_top);
			}
		}
		__gm3d_ed_gizmo_draw(_ed, _vp);
		__gm3d_ed_overlay_draw(_ed, _vp);
		__gm3d_ed_viewcube_draw(_ed, _vp);
		if (_ed.cam_speed_notice > 0) {
			var _tip_x = clamp(device_mouse_x_to_gui(0) + 18, 8, _ed.gw - 150);
			var _tip_y = clamp(device_mouse_y_to_gui(0) + 18, 8, _ed.gh - 32);
			draw_set_alpha(min(1, _ed.cam_speed_notice * 2) * 0.85);
			draw_set_color(c_black);
			draw_rectangle(_tip_x, _tip_y, _tip_x + 142, _tip_y + 26, false);
			draw_set_alpha(min(1, _ed.cam_speed_notice * 2));
			draw_set_color(c_white);
			draw_text(_tip_x + 8, _tip_y + 5, "Fly speed " + string_format(_ed.cam_fly_speed, 0, 1));
		}
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
	__gm3d_ed_drop_preview_clear(_ed);
	__gm3d_ed_view_restore(_ed);
	__gm3d_ed_bg_restore(_ed);
	__gm3d_ed_cameras_restore(_ed);
	__gm3d_ed_grid_remove(_ed);
	_ed.grid_mat = undefined;
	if (_ed != undefined && variable_struct_exists(_ed, "grid_src") && _ed.grid_src != undefined) {
		_ed.grid_src.destroy();
		_ed.grid_src = undefined;
	}
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

/// Editor viewport background: soft dark blue, applied on open.
/// The GM3D camera exposes no documented clear color; the background comes
/// from the display buffer clear + the room background layer, so the editor
/// sets the window colour and hides the room "Background" layer while open.
function __gm3d_ed_bg_apply(_ed) {
	if (_ed == undefined) {
		return;
	}
	if (!variable_struct_exists(_ed, "prev_win_colour") || _ed.prev_win_colour == undefined) {
		_ed.prev_win_colour = window_get_colour();
	}
	window_set_colour(#181825);
	var _lyr = layer_get_id("Background");
	_ed.bg_layer = _lyr;
	if (_lyr != -1) {
		layer_set_visible(_lyr, false);
	}
}

/// Restores the window colour and room background hidden by bg_apply.
function __gm3d_ed_bg_restore(_ed) {
	if (_ed == undefined) {
		return;
	}
	if (variable_struct_exists(_ed, "prev_win_colour") && _ed.prev_win_colour != undefined) {
		window_set_colour(_ed.prev_win_colour);
		_ed.prev_win_colour = undefined;
	}
	if (variable_struct_exists(_ed, "bg_layer") && _ed.bg_layer != undefined && _ed.bg_layer != -1) {
		layer_set_visible(_ed.bg_layer, true);
	}
	_ed.bg_layer = undefined;
}

/// Ensures native render resolution and GUI match the window (no letterbox
/// bars, no stretch): application_surface and GUI follow window size, like
/// Unique Engine's resize path. Acts only on change; call per step.
function __gm3d_ed_view_sync(_ed) {
	var _ww = 0;
	var _wh = 0;
	try {
		_ww = window_get_width();
		_wh = window_get_height();
	} catch (_e) {
		return;
	}
	if (_ww <= 0 || _wh <= 0) {
		return;
	}
	if (!variable_struct_exists(_ed, "view_sync")) {
		_ed.view_sync = { w: -1, h: -1 };
	}
	if (_ed.view_sync.w == _ww && _ed.view_sync.h == _wh) {
		return;
	}
	_ed.view_sync.w = _ww;
	_ed.view_sync.h = _wh;
	try {
		if (surface_exists(application_surface)) {
			surface_resize(application_surface, _ww, _wh);
		}
	} catch (_e2) {
	}
	try {
		display_set_gui_size(_ww, _wh);
	} catch (_e3) {
	}
}

/// Saves game viewport state before the editor takes it over.
function __gm3d_ed_view_save(_ed) {
	var _v = { sw: -1, sh: -1, gw: -1, gh: -1 };
	try {
		if (surface_exists(application_surface)) {
			_v.sw = surface_get_width(application_surface);
			_v.sh = surface_get_height(application_surface);
		}
	} catch (_e) {
	}
	try {
		_v.gw = display_get_gui_width();
		_v.gh = display_get_gui_height();
	} catch (_e2) {
	}
	_ed.view_prev = _v;
}

/// Restores game viewport state saved by view_save.
function __gm3d_ed_view_restore(_ed) {
	if (_ed == undefined || !is_struct(_ed.view_prev)) {
		return;
	}
	var _v = _ed.view_prev;
	_ed.view_prev = undefined;
	try {
		if (_v.sw > 0 && _v.sh > 0 && surface_exists(application_surface)) {
			surface_resize(application_surface, _v.sw, _v.sh);
		}
	} catch (_e) {
	}
	try {
		if (_v.gw > 0 && _v.gh > 0) {
			display_set_gui_size(_v.gw, _v.gh);
		}
	} catch (_e2) {
	}
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
	if (_was && !_on) {
		__gm3d_ed_drop_preview_clear(_ed);
		__gm3d_ed_view_restore(_ed);
		__gm3d_ed_bg_restore(_ed);
		__gm3d_ed_grid_remove(_ed);
		__gm3d_ed_cameras_restore(_ed);
		__gm3d_ed_cam_home(_ed);
		if (variable_struct_exists(_ed.rt, "on_close")) {
			_ed.rt.on_close(_ed.inst);
		}
	} else if (!_was && _on) {
		__gm3d_ed_view_save(_ed);
		__gm3d_ed_view_sync(_ed);
		__gm3d_ed_bg_apply(_ed);
		__gm3d_ed_grid_ensure(_ed);
		__gm3d_ed_cameras_mute(_ed);
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

/// Clears to an empty scene. Lights, cameras and the environment are tracked
/// nodes like models, so new scene removes them as well.
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
			size: 120,
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
			rot_mx: 0,
			rot_my: 0,
			rot_tx: 1,
			rot_ty: 0,
			total_ang: 0,
			display_ang: 0,
			len: 1,
			len_key: undefined,
			orient: 0,
			sector_t0: 0,
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
		drag_preview: undefined,
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
		cam_orbit: false,
		cam_pan: false,
		cam_zoom: false,
		cam_fly: false,
		cam_orbit_target: undefined,
		cam_orbit_radius: 10,
		cam_zoom_target: undefined,
		cam_fly_speed: 5,
		cam_speed_notice: 0,
		hist_before: undefined,
		wrap: undefined,
		cube_geom: undefined,
		scene_file: "",
		snap_on: false,
		snap_pos: 0.5,
		snap_rot: 15,
		show_grid: true,
		grid_node: undefined,
		grid_src: undefined,
		grid_mat: undefined,
		prev_win_colour: undefined,
		bg_layer: undefined,
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

	__gm3d_ed_view_sync(_ed);
	var _input = __gm3d_ed_input_context(_ed, _keys);
	var _vp = _input.vp;
	_ed.vp = _vp;

	var _modal = false;
	_modal = _ed.confirm != undefined;
	if (_modal) {
		if (!_input.typing && keyboard_check_pressed(_keys.cancel)) {
			_ed.confirm = undefined;
		}
		return;
	}

	_input.camera_keys = !_input.typing || (keyboard_check(vk_alt) && !_input.text_input);
	_input.camera_viewport = _input.in_viewport;
	if (!_input.camera_viewport && keyboard_check(vk_alt)) {
		_input.camera_viewport = __gm3d_ed_drag_in_viewport(_ed, _input.mx, _input.my);
	}
	_input.camera_zoom = _input.camera_viewport && _ed.drag_lib == undefined;
	__gm3d_ed_cam_fly(_ed, _input, _dt);
	__gm3d_ed_cam_anim_step(_ed, _dt);
	__gm3d_ed_grid_ensure(_ed);

	__gm3d_ed_step_hotkeys(_ed, _input);
	__gm3d_ed_step_cancel(_ed, _input);
	if (__gm3d_ed_step_gizmo(_ed, _input)) {
		return;
	}
	if (__gm3d_ed_step_libdrop(_ed, _input)) {
		return;
	}
	if (__gm3d_ed_step_rect(_ed, _input)) {
		return;
	}
	__gm3d_ed_step_hover(_ed, _input);
}

/// Centralized infinite-drag mouse wrap. While a gizmo
/// transform or a camera gesture is active the OS cursor teleports from one
/// screen edge to the opposite one, so motion never stalls at the border:
/// - gizmo drags use absolute coordinates, so they consume VIRTUAL coords
///   (begin/step/end) that keep growing past the edges;
/// - camera gestures (RMB orbit, MMB pan) are delta-driven, so they only
///   need the edge teleport AFTER their deltas were consumed (wrap_camera).
/// State lives on _ed.wrap: { on, vx, vy, lx, ly }.

/// Starts virtual tracking at the current mouse position.
function __gm3d_ed_wrap_begin(_ed, _mx, _my) {
	_ed.wrap = { on: true, vx: _mx, vy: _my, lx: _mx, ly: _my };
}

/// Stops virtual tracking.
function __gm3d_ed_wrap_end(_ed) {
	if (_ed != undefined) {
		_ed.wrap = undefined;
	}
}

/// Folds the real mouse delta into the virtual position and teleports the OS
/// cursor at the window edges. Returns [vx, vy] for the drag math.
function __gm3d_ed_wrap_step(_ed, _mx, _my) {
	var _w = _ed.wrap;
	if (_w == undefined || !_w.on) {
		return [_mx, _my];
	}
	_w.vx += _mx - _w.lx;
	_w.vy += _my - _w.ly;
	_w.lx = _mx;
	_w.ly = _my;
	var _ww = 0;
	var _wh = 0;
	try {
		_ww = window_get_width();
		_wh = window_get_height();
	} catch (_eW) {
	}
	if (_ww > 16 && _wh > 16) {
		var _nx = _mx;
		var _ny = _my;
		if (_mx < 8) {
			_nx = _ww - 9;
		} else if (_mx > _ww - 9) {
			_nx = 8;
		}
		if (_my < 8) {
			_ny = _wh - 9;
		} else if (_my > _wh - 9) {
			_ny = 8;
		}
		if (_nx != _mx || _ny != _my) {
			try {
				window_mouse_set(round(_nx), round(_ny));
			} catch (_eW2) {
			}
			// Rebase BEFORE the next frame: the teleport jump must never
			// leak into the virtual position.
			_w.lx = _nx;
			_w.ly = _ny;
		}
	}
	return [_w.vx, _w.vy];
}

/// Edge teleport for delta-driven camera gestures (orbit/pan): call AFTER the
/// frame deltas were consumed, so the jump stays out of the motion.
function __gm3d_ed_wrap_camera(_ed) {
	if (_ed == undefined) {
		return;
	}
	var _mx = 0;
	var _my = 0;
	try {
		_mx = device_mouse_x_to_gui(0);
		_my = device_mouse_y_to_gui(0);
	} catch (_eG) {
		return;
	}
	var _ww = 0;
	var _wh = 0;
	try {
		_ww = window_get_width();
		_wh = window_get_height();
	} catch (_eW) {
		return;
	}
	if (_ww <= 16 || _wh <= 16) {
		return;
	}
	var _nx = _mx;
	var _ny = _my;
	if (_mx < 8) {
		_nx = _ww - 9;
	} else if (_mx > _ww - 9) {
		_nx = 8;
	}
	if (_my < 8) {
		_ny = _wh - 9;
	} else if (_my > _wh - 9) {
		_ny = 8;
	}
	if (_nx != _mx || _ny != _my) {
		try {
			window_mouse_set(round(_nx), round(_ny));
		} catch (_eW2) {
		}
	}
}

/// Spawns (once) and moves the live drop preview for the library drag.
/// The preview is an untracked scene node, so save/load/undo/picking ignore
/// it by construction; it is either adopted on drop or destroyed.
function __gm3d_ed_drop_preview_update(_ed, _drop) {
	if (_ed == undefined || _ed.drag_lib == undefined || _drop == undefined) {
		return;
	}
	var _pv = _ed.drag_preview;
	if (_pv == undefined) {
		var _asset = _ed.drag_lib.asset;
		if (_asset == undefined || _asset.model == undefined) {
			return;
		}
		_pv = _asset.model.spawnInto(_ed.rt.scene, undefined);
		if (_pv == undefined) {
			return;
		}
		_pv.setLocalScale(new GM3D_Vec3(1, 1, 1));
		_ed.drag_preview = _pv;
	}
	_pv.setLocalPosition(new GM3D_Vec3(_drop.x, _drop.y, _drop.z));
	// Fresh matrices now: the node must never render one frame at origin.
	_ed.rt.scene.update(0);
}

/// Destroys the live drop preview without tracking it.
function __gm3d_ed_drop_preview_clear(_ed) {
	if (_ed == undefined) {
		return;
	}
	if (_ed.drag_preview != undefined) {
		__gm3d_ed_destroy_subtree(_ed.drag_preview);
		_ed.drag_preview = undefined;
		if (_ed.rt != undefined && _ed.rt.scene != undefined) {
			_ed.rt.scene.update(0);
		}
	}
}

/// Viewport test for the library drag. ImGui keeps mouse capture while a
/// drag-drop payload is active, so WantMouseCapture stays true even over the
/// scene: hit-test real windows instead (the passthrough central dockspace
/// does not count as hovered).
function __gm3d_ed_drag_in_viewport(_ed, _mx, _my) {
	if (_mx < 0 || _mx > _ed.gw || _my < 0 || _my > _ed.gh) {
		return false;
	}
	try {
		if (ImGui.IsWindowHovered(ImGuiHoveredFlags.AnyWindow)) {
			return false;
		}
	} catch (_e) {
	}
	return true;
}

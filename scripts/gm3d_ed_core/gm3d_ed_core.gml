enum Gm3dEdTool {
	View = 0,
	Translate = 1,
	Rotate = 2,
	Scale = 3,
}

// Initializes editor state and restores view.
function gm3d_editor_init(_self, _rt) {
	global.gm3d_editor_active = true;
	var _ed = __gm3d_ed_create(_self, _rt);
	__gm3d_ed_viewcam_seed_from(_ed, _rt.cam);
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

// Updates editor logic and draws UI.
function gm3d_editor_step() {
	var _ed = gm3d_editor_inst();
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

// Warms up editor shaders before rendering.
function gm3d_editor_prerender() {
	var _ed = gm3d_editor_inst();
	if (_ed == undefined) {
		return;
	}
	__gm3d_ed_shaders_warmup(_ed);
}

// Captures outline and executes GPU picking.
function gm3d_editor_postrender() {
	var _ed = gm3d_editor_inst();
	if (_ed == undefined) {
		return;
	}
	if (_ed.thumbs_done != true) {
		gm3d_editor_capture_thumbnails();
	}
	__gm3d_ed_outline_capture(_ed);
	__gm3d_ed_gpupick_execute(_ed);
	__gm3d_ed_preview_render(_ed);
}

// Renders viewport overlays into preview surface (target already set).
function __gm3d_ed_compose_viewport(_ed) {
	var _vp = __gm3d_ed_viewport(_ed);
	__gm3d_ed_outline_composite(_ed);
	__gm3d_ed_gizmo_draw(_ed, _vp);
	__gm3d_ed_overlay_draw(_ed, _vp);
	__gm3d_ed_viewcube_draw(_ed, _vp);
	if (_ed.rect != undefined && _ed.rect.on && variable_struct_exists(_ed, "pvp") && is_struct(_ed.pvp)) {
		var _r = __gm3d_ed_rect_norm(_ed.rect);
		var _ox = _ed.pvp.x;
		var _oy = _ed.pvp.y;
		draw_set_alpha(0.15);
		draw_set_color(make_colour_rgb(90, 140, 250));
		draw_rectangle(_r.x0 - _ox, _r.y0 - _oy, _r.x1 - _ox, _r.y1 - _oy, false);
		draw_set_alpha(1);
		draw_rectangle(_r.x0 - _ox, _r.y0 - _oy, _r.x1 - _ox, _r.y1 - _oy, true);
	}
	draw_set_alpha(1);
	draw_set_color(c_white);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	if (_ed.show_fps == true) {
		draw_set_halign(fa_right);
		draw_set_valign(fa_top);
		draw_set_color(c_white);
		draw_set_alpha(1);
		draw_text(max(60, _vp.winW - 200), 8, "FPS: " + string(round(fps_real)));
		draw_set_halign(fa_left);
		draw_set_valign(fa_top);
	}
	draw_set_alpha(1);
	draw_set_color(c_white);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}

// Draws window-level editor hints and tooltips.
function gm3d_editor_draw() {
	var _ed = gm3d_editor_inst();
	if (_ed == undefined) {
		return;
	}

	var _modal = false;
	_modal = _ed.confirm != undefined || _ed.about != undefined || _ed.scene_dlg != undefined;
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
	if (_ed.active) {
		if (_ed.drag_lib != undefined && _ed.drag_moved) {
			var _mx = device_mouse_x_to_gui(0);
			var _my = device_mouse_y_to_gui(0);

			if (!__gm3d_ed_drag_in_viewport(_ed, _mx, _my)) {
				draw_set_color(make_colour_rgb(90, 140, 250));
				draw_rectangle(_mx + 14, _my + 10, _mx + 150, _my + 32, false);
				draw_set_color(c_white);
				draw_set_valign(fa_middle);
				draw_text(_mx + 22, _my + 21, _ed.drag_lib.asset.name);
				draw_set_valign(fa_top);
			}
		}
		if (_ed.cam_speed_notice > 0) {
			var _tip_w = 174;
			var _tip_h = 36;
			var _tip_x = clamp(device_mouse_x_to_gui(0) + 18, 8, _ed.gw - _tip_w - 8);
			var _tip_y = clamp(device_mouse_y_to_gui(0) + 18, 8, _ed.gh - _tip_h - 8);
			var _tip_alpha = min(1, _ed.cam_speed_notice * 2);
			draw_set_alpha(_tip_alpha * 0.94);
			draw_set_color(make_colour_rgb(22, 28, 38));
			draw_rectangle(_tip_x, _tip_y, _tip_x + _tip_w, _tip_y + _tip_h, true);
			draw_set_alpha(_tip_alpha * 0.8);
			draw_set_color(make_colour_rgb(90, 103, 120));
			draw_rectangle(_tip_x, _tip_y, _tip_x + _tip_w, _tip_y + _tip_h, false);
			draw_set_alpha(_tip_alpha);
			draw_set_color(make_colour_rgb(80, 210, 190));
			draw_rectangle(_tip_x, _tip_y + 5, _tip_x + 3, _tip_y + _tip_h - 5, true);
			draw_set_color(make_colour_rgb(170, 184, 199));
			draw_text_transformed(_tip_x + 12, _tip_y + 11, "FLY SPEED", 0.8, 0.8, 0);
			draw_set_halign(fa_right);
			draw_set_color(c_white);
			draw_text(_tip_x + _tip_w - 12, _tip_y + 9, string_format(_ed.cam_fly_speed, 0, 1));
			draw_set_halign(fa_left);
		}
	}
	if (!_ed.active) {
		draw_set_halign(fa_center);
		draw_set_color(c_white);
		draw_text(display_get_gui_width() * 0.5, 24, "Press F1 for the 3D in-game editor");
		draw_set_halign(fa_left);
	}
	if (_ed.show_fps == true) {
		draw_set_halign(fa_right);
		draw_set_valign(fa_top);
		draw_set_color(c_white);
		draw_set_alpha(1);
		draw_text(max(60, _ed.gw - 460), 40, "FPS: " + string(round(fps_real)));
		draw_set_halign(fa_left);
		draw_set_valign(fa_top);
	}
	draw_set_color(c_white);
	draw_set_alpha(1);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}

// Releases editor resources and restores scene.
function gm3d_editor_cleanup(_ed = undefined) {
	_ed ??= gm3d_editor_inst();
	if (_ed == undefined) {
		return;
	}
	__gm3d_ed_outline_cleanup(_ed);
	__gm3d_ed_gpupick_cleanup(_ed);
	__gm3d_ed_thumbs_free(_ed);
	if (surface_exists(_ed.preview_surf)) {
		surface_free(_ed.preview_surf);
	}
	_ed.preview_surf = undefined;
	__gm3d_ed_ui_save(_ed);
	__gm3d_ed_drop_preview_clear(_ed);
	__gm3d_ed_view_restore(_ed);
	__gm3d_ed_bg_restore(_ed);
	__gm3d_ed_cameras_restore(_ed);
	_ed.show_unlit = false;
	__gm3d_ed_unlit_apply(_ed);
	if (_ed.viewcam != undefined) {
		var _vcc0 = _ed.viewcam.getCameraComponent();
		if (_vcc0 != undefined) {
			_vcc0.setEnabled(false);
		}
	}
	__gm3d_ed_grid_remove(_ed);
	__gm3d_ed_sky_remove(_ed);
	if (variable_struct_exists(_ed, "sky_src") && _ed.sky_src != undefined) {
		_ed.sky_src.destroy();
		_ed.sky_src = undefined;
	}
	_ed.sky_mat = undefined;
	_ed.show_shadows = true;
	__gm3d_ed_shadowpreview_apply(_ed);
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

// Returns current active editor instance.
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

// Applies dark background and hides layer.
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

// Restores previous window background color.
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

// Synchronizes application surface to window size.
function __gm3d_ed_view_sync(_ed) {
	var _ww = 0;
	var _wh = 0;
	_ww = window_get_width();
	_wh = window_get_height();
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
	if (surface_exists(application_surface)) {
		surface_resize(application_surface, _ww, _wh);
	}
	display_set_gui_size(_ww, _wh);
}

// Saves current surface and GUI sizes.
function __gm3d_ed_view_save(_ed) {
	var _v = { sw: -1, sh: -1, gw: -1, gh: -1 };
	if (surface_exists(application_surface)) {
		_v.sw = surface_get_width(application_surface);
		_v.sh = surface_get_height(application_surface);
	}
	_v.gw = display_get_gui_width();
	_v.gh = display_get_gui_height();
	_ed.view_prev = _v;
}

// Restores previously saved surface sizes.
function __gm3d_ed_view_restore(_ed) {
	if (_ed == undefined || !is_struct(_ed.view_prev)) {
		return;
	}
	var _v = _ed.view_prev;
	_ed.view_prev = undefined;
	if (_v.sw > 0 && _v.sh > 0 && surface_exists(application_surface)) {
		surface_resize(application_surface, _v.sw, _v.sh);
	}
	if (_v.gw > 0 && _v.gh > 0) {
		display_set_gui_size(_v.gw, _v.gh);
	}
}

// Toggles editor active state with setup.
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
		__gm3d_ed_sky_remove(_ed);
		__gm3d_ed_cameras_restore(_ed);
		if (_ed.viewcam != undefined) {
			var _vcc = _ed.viewcam.getCameraComponent();
			if (_vcc != undefined) {
				_vcc.setEnabled(false);
			}
		}
		__gm3d_ed_cam_home(_ed);
		_ed.show_shadows = true;
		__gm3d_ed_shadowpreview_apply(_ed);
		_ed.show_unlit = false;
		__gm3d_ed_unlit_apply(_ed);
		if (variable_struct_exists(_ed.rt, "on_close")) {
			_ed.rt.on_close(_ed.inst);
		}
	} else if (!_was && _on) {
		__gm3d_ed_view_save(_ed);
		__gm3d_ed_view_sync(_ed);
		__gm3d_ed_bg_apply(_ed);
		__gm3d_ed_grid_ensure(_ed);
		__gm3d_ed_cameras_mute(_ed);
		__gm3d_ed_viewcam_seed(_ed);
		_ed.open_snapshot = __gm3d_ed_serialize_scene(_ed);
	}
}

// Enables the 3D editor.
function gm3d_editor_enable() {
	var _e = gm3d_editor_inst();
	if (_e != undefined) {
		__gm3d_ed_set_active(_e, true);
	}
}

// Disables the 3D editor.
function gm3d_editor_disable() {
	var _e = gm3d_editor_inst();
	if (_e != undefined) {
		__gm3d_ed_set_active(_e, false);
	}
}

// Toggles editor enabled state.
function gm3d_editor_toggle() {
	var _e = gm3d_editor_inst();
	if (_e != undefined) {
		__gm3d_ed_set_active(_e, !_e.active);
	}
}

// Checks if editor is active.
function gm3d_editor_is_active() {
	var _e = gm3d_editor_inst();
	return _e != undefined && _e.active;
}

// Focuses camera on current selection.
function gm3d_editor_focus() {
	var _e = gm3d_editor_inst();
	if (_e == undefined) {
		return false;
	}
	return __gm3d_ed_focus_selection(_e);
}

// Saves scene to file.
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







// Creates default editor state struct.
function __gm3d_ed_create(_inst, _rt) {
	var _ed = {
		inst: _inst,
		rt: _rt,
		cfg: {
			ndc_yup: true,
			keys: {
				toggle: vk_f1,
				tool_view: ord("V"),
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
			snap: { on: false, pos: 0.5, rot: 15 },
			gizmo_px: 90,
			duplicate_offset: 0.6,
		},
		active: true,
		dirty: false,
		assets: [],
		thumbs_done: false,
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
			orient: 1,
			sector_t0: 0,
		},
		scene_click_idx: -1,
		scene_click_time: -10000,
		scene_anchor: undefined,
		rename_name: undefined,
		rename_pos: undefined,
		confirm: undefined,
		about: undefined,
		scene_dlg: undefined,
		show_fps: false,
		undo: [],
		redo: [],
		imgui: undefined,
		imgui_ok: undefined,
		input_owner: undefined,
		drag_lib: undefined,
		drag_moved: false,
		drag_preview: undefined,
		rect: undefined,
		press_vp: false,
		press_x: 0,
		press_y: 0,
		viewpan_moved: false,
		preview_surf: undefined,
		preview_stable_w: -1,
		preview_stable_h: -1,
		preview_w: 480,
		preview_h: 270,
		pvp: { x: 0, y: 0, w: 1366, h: 768 },
		pvp_hover: false,
		cube_armed: undefined,
		cube_hover: undefined,
		cube_face: undefined,
		cube_moved: false,
		cube_gx: 0,
		cube_gy: 0,
		cube_off: [375, 100],
		vp: undefined,
		viewcam: undefined,
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
		open_snapshot: undefined,
		snap_on: false,
		snap_pos: 0.5,
		snap_rot: 15,
		snap_to_grid: true,
		show_grid: true,
		show_shadows: true,
		show_unlit: false,
		unlit_quiet: false,
		unlit_orig: [],
		magenta_mat: undefined,
		magenta_mat_skin: undefined,
		grid_step: 1,
		grid_node: undefined,
		grid_src: undefined,
		grid_mat: undefined,
		sky_node: undefined,
		sky_src: undefined,
		sky_mat: undefined,
		prev_win_colour: undefined,
		bg_layer: undefined,
		gw: 1366,
		gh: 768,
	};
	return _ed;
}

// Processes input, cameras, and interactions.
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
	if (keyboard_check_pressed(vk_f9)) {
		_ed.show_fps = !_ed.show_fps;
	}

	__gm3d_ed_view_sync(_ed);
	if (_ed.open_snapshot == undefined && _ed.dirty != true) {
		_ed.open_snapshot = __gm3d_ed_serialize_scene(_ed);
	}
	var _input = __gm3d_ed_input_context(_ed, _keys);
	var _vp = _input.vp;
	_ed.vp = _vp;

	var _modal = false;
	_modal = _ed.confirm != undefined || _ed.about != undefined || _ed.scene_dlg != undefined;
	if (_modal) {
		if (!_input.typing && keyboard_check_pressed(_keys.cancel)) {
			_ed.confirm = undefined;
			_ed.about = undefined;
			_ed.scene_dlg = undefined;
		}
		return;
	}

	var _camera_owner_ok = _input.owner == undefined || __gm3d_ed_input_owner_is_camera(_input.owner);
	_input.camera_keys = (_input.typing == false || (keyboard_check(vk_alt) && !_input.text_input)) && _camera_owner_ok;
	_input.camera_viewport = _input.vin && _camera_owner_ok;
	if (!_input.camera_viewport && keyboard_check(vk_alt)) {
		_input.camera_viewport = _camera_owner_ok && __gm3d_ed_drag_in_viewport(_ed, _input.mx, _input.my);
	}
	_input.camera_zoom = _input.camera_viewport && _ed.drag_lib == undefined && _camera_owner_ok;
	__gm3d_ed_cam_fly(_ed, _input, _dt);
	_input.owner = __gm3d_ed_input_owner_sync(_ed);
	_input.gesture_active = _input.owner != undefined && !__gm3d_ed_input_owner_is_camera(_input.owner);
	__gm3d_ed_cam_anim_step(_ed, _dt);
	__gm3d_ed_grid_ensure(_ed);
	__gm3d_ed_grid_follow(_ed);
	__gm3d_ed_sky_ensure(_ed);
	__gm3d_ed_sky_sync(_ed);

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





// Updates asset drag preview position.
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
		__gm3d_ed_magenta_fix(_ed, _pv);
		_pv.setLocalScale(new GM3D_Vec3(1, 1, 1));
		_ed.drag_preview = _pv;
	}
	_pv.setLocalPosition(new GM3D_Vec3(_drop.x, _drop.y, _drop.z));

	_ed.rt.scene.update(0);
}

// Removes asset drag preview node.
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


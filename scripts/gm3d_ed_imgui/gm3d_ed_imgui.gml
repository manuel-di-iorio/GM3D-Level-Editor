/// @module gm3d_ed_imgui
/// ImGui shell with toolbar, menu, assets, scene, inspector and confirm dialog.
/// Binding notes (GMRT ImGui, from ImGUI.yyb metadata + YoYoGames/ImGUI-Sample):
/// image widgets take a sprite via asset_get_index (a bare asset constant crashes the runner),
/// only raster sprites work (vector sprites crash), and the signatures are
/// Image(sprite, subImage, colour, alpha, width, height, uvs) and
/// ImageButton(strID, sprite, subImage, colour, alpha, colourBG, alphaBG,
/// width, height, uvs). Width/height 0 means native sprite size; OMIT uvs for
/// the full sprite (passing undefined throws; [0,0,1,1] samples the whole
/// texture page).

/// True when a GUI point falls on the 3D viewport (not above ImGui windows).
function __gm3d_ed_in_viewport(_ed, _mx, _my) {
	if (__gm3d_ed_imgui_check(_ed)) {
		if (ImGui.WantMouseCapture()) {
			return false;
		}
	}
	return _mx >= 0 && _mx <= _ed.gw && _my >= 0 && _my <= _ed.gh;
}

/// True while ImGui is capturing the keyboard for text input.
function __gm3d_ed_ui_typing(_ed) {
	if (!__gm3d_ed_imgui_check(_ed)) {
		return false;
	}

	if (ImGui.WantKeyboardCapture()) {
		return true;
	}

	if (ImGui.WantTextInput()) {
		return true;
	}

	return false;
}

/// Reads one mixed-value aware axis over the selection.
/// @param _mode 0 position, 1 rotation (deg), 2 scale.
/// @param _idx 0 X, 1 Y, 2 Z.
function __gm3d_ed_axis_val(_ed, _mode, _idx) {
	var _v = 0;
	var _mixed = false;
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		var _c;
		if (_mode == 0) {
			_c = _ed.sel[_i].getLocalPosition();
			_c = _idx == 0 ? _c.x : _idx == 1 ? _c.y : _c.z;
		} else if (_mode == 1) {
			var _e = __gm3d_ed_quat_to_euler(_ed.sel[_i].getLocalRotation());
			_c = radtodeg(_e[_idx]);
		} else {
			var _s = _ed.sel[_i].getLocalScale();
			_c = _idx == 0 ? _s.x : _idx == 1 ? _s.y : _s.z;
		}
		if (_i == 0) {
			_v = _c;
		} else if (abs(_c - _v) > 0.0005) {
			_mixed = true;
		}
	}
	return { mixed: _mixed, val: _v };
}

/// Writes one transform component over the whole selection.
/// @param _mode 0 position, 1 rotation (deg), 2 scale.
/// @param _idx 0 X, 1 Y, 2 Z.
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

/// Returns a fixed 31-char padded buffer for stable text input.
function __gm3d_ed_imgui_pad(_base) {
	if (!is_string(_base)) {
		_base = "";
	}
	var _buf = _base;
	while (string_length(_buf) < 31) {
		_buf += " ";
	}
	return _buf;
}

/// Fixed-length text input with GML-tracked edit session.
/// @param _key unique field id across frames.
/// @return { text, active, was_active }.
function __gm3d_ed_imgui_text(_key, _label, _val) {
	static _active = {};
	var _base = _val;
	if (!is_string(_base)) {
		_base = "";
	}
	var _was = false;
	_was = _active[$ _key] == true;
	var _out = _base;
	var _now = false;

	_out = ImGui.InputText(_label, __gm3d_ed_imgui_pad(_base), ImGuiInputTextFlags.AutoSelectAll);
	_now = ImGui.IsItemActive();

	_active[$ _key] = _now;
	if (!is_string(_out)) {
		return { text: _base, active: _now, was_active: _was };
	}
	return { text: string_trim(_out), active: _now, was_active: _was };
}

/// Text input with placeholder hint and hidden label id.
/// @param _id_label hidden ImGui id (e.g. ##x).
function __gm3d_ed_imgui_text_hint(_id_label, _hint, _val) {
	static _active = {};
	var _base = _val;
	if (!is_string(_base)) {
		_base = "";
	}
	var _was = false;
	_was = _active[$ _id_label] == true;
	var _out = _base;
	var _now = false;

	_out = ImGui.InputTextWithHint(
		_id_label,
		_hint,
		_was ? __gm3d_ed_imgui_pad(_base) : _base,
		ImGuiInputTextFlags.AutoSelectAll,
	);
	_now = ImGui.IsItemActive();

	_active[$ _id_label] = _now;
	if (!is_string(_out)) {
		return _base;
	}
	return string_trim(_out);
}

/// Creates ImGui UI state (window flags and filters) if missing.
function __gm3d_ed_imgui_ensure(_ed) {
	if (_ed.imgui != undefined) {
		return;
	}
	_ed.imgui = {
		cond: ImGuiCond.FirstUseEver,
		style_init: false,
		win_assets: { open: true },
		win_scene: { open: true },
		win_insp: { open: true },
		win_toolbar: { open: true },
		win_cube: { open: true },
		reset_layout: false,
		filter: "",
		scene_filter: "",
		ax_active: {},
		flt_active: {},
		show_kind: { m: true, l: true, c: true, e: true },
	};
}

/// Draws all editor ImGui windows each Step while the editor is active.
function __gm3d_ed_imgui_draw(_ed) {
	if (!_ed.active) {
		return;
	}
	if (!__gm3d_ed_imgui_check(_ed)) {
		return;
	}
	__gm3d_ed_imgui_ensure(_ed);
	__gm3d_ed_imgui_style_once(_ed);
	ImGui.DockSpaceOverViewport(0, 0, ImGuiDockNodeFlags.PassthruCentralNode);
	var _modal_ui = false;
	_modal_ui = _ed.confirm != undefined;
	if (_modal_ui) {
		__gm3d_ed_imgui_confirm(_ed);
		return;
	}
	var _rst = _ed.imgui.reset_layout == true;
	if (_rst) {
		_ed.imgui.cond = ImGuiCond.Always;
	}
	__gm3d_ed_imgui_menu(_ed);
	__gm3d_ed_imgui_toolbar(_ed);
	__gm3d_ed_imgui_assets(_ed);
	__gm3d_ed_imgui_scene_win(_ed);
	__gm3d_ed_imgui_inspector(_ed);
	__gm3d_ed_imgui_confirm(_ed);
	if (_rst) {
		_ed.imgui.cond = ImGuiCond.FirstUseEver;
		_ed.imgui.reset_layout = false;
	}
}

/// Draws one toolbar tool button with a caption; highlighted while active.
/// @param _tip tooltip text.
/// @param _label visible caption.
/// @return True when clicked.
function __gm3d_ed_imgui_tool_btn(_tip, _label, _active) {
	var _pushed = 0;
	if (_active) {
		ImGui.PushStyleColor(ImGuiCol.Button, make_colour_rgb(47, 111, 237), 1);
		_pushed++;
	}
	var _hit = ImGui.Button(_label);
	__gm3d_ed_imgui_pop(_pushed);
	if (ImGui.IsItemHovered()) {
		ImGui.SetTooltip(_tip);
	}
	return _hit;
}

/// Floating scene toolbar for tool switch, snap toggle and camera home.
function __gm3d_ed_imgui_toolbar(_ed) {
	if (!_ed.imgui.win_toolbar.open) {
		return;
	}
	ImGui.SetNextWindowPos(300, 34, _ed.imgui.cond);
	var _flags = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoResize | ImGuiWindowFlags.AlwaysAutoResize;
	if (!ImGui.Begin("##toolbar", _ed.imgui.win_toolbar, _flags)) {
		ImGui.End();
		return;
	}
	if (__gm3d_ed_imgui_tool_btn("Move (1)", "Move", _ed.giz.tool == Gm3dEdTool.Translate)) {
		_ed.giz.tool = Gm3dEdTool.Translate;
	}
	ImGui.SameLine();
	if (__gm3d_ed_imgui_tool_btn("Rotate (2)", "Rotate", _ed.giz.tool == Gm3dEdTool.Rotate)) {
		_ed.giz.tool = Gm3dEdTool.Rotate;
	}
	ImGui.SameLine();
	if (__gm3d_ed_imgui_tool_btn("Scale (3)", "Scale", _ed.giz.tool == Gm3dEdTool.Scale)) {
		_ed.giz.tool = Gm3dEdTool.Scale;
	}
	ImGui.SameLine();
	ImGui.TextDisabled("|");
	ImGui.SameLine();
	_ed.snap_on = ImGui.Checkbox("Snap", _ed.snap_on);
	ImGui.SameLine();
	_ed.show_grid = ImGui.Checkbox("Grid", _ed.show_grid);
	ImGui.SameLine();
	if (__gm3d_ed_imgui_tool_btn("Reset camera to the initial view", "Home", false)) {
		__gm3d_ed_cam_home(_ed, true);
	}
	ImGui.End();
}

/// Returns the UI prefs file path.
function __gm3d_ed_ui_path() {
	return working_directory + "gm3d_editor_ui.json";
}

/// Saves UI prefs (viewcube offset) as JSON.
function __gm3d_ed_ui_save(_ed) {
	if (_ed == undefined) {
		return;
	}
	__gm3d_ed_write_text_file(__gm3d_ed_ui_path(), json_stringify({ cube_off: _ed.cube_off }));
}

/// Loads UI prefs if present, ignoring missing or malformed files.
function __gm3d_ed_ui_load(_ed) {
	if (_ed == undefined) {
		return;
	}
	var _path = __gm3d_ed_ui_path();
	if (!file_exists(_path)) {
		return;
	}
	var _json = __gm3d_ed_read_text_file(_path);
	if (_json == "") {
		return;
	}
	var _data = json_parse(_json);
	if (!is_struct(_data) || !variable_struct_exists(_data, "cube_off")) {
		return;
	}
	var _c = _data.cube_off;
	if (!is_array(_c) || array_length(_c) < 2 || !is_real(_c[0]) || !is_real(_c[1])) {
		return;
	}
	_ed.cube_off = [clamp(_c[0], 0, 10000), clamp(_c[1], 0, 10000)];
}

/// Unsaved-changes confirm dialog for New, Load and Close.
function __gm3d_ed_imgui_confirm(_ed) {
	var _c = undefined;
	_c = _ed.confirm;
	if (_c == undefined) {
		return;
	}
	if (_c.open == false) {
		_ed.confirm = undefined;
		return;
	}
	var _gw = max(640, _ed.gw);
	var _gh = max(400, _ed.gh);
	ImGui.SetNextWindowPos(_gw * 0.5 - 170, _gh * 0.5 - 70, ImGuiCond.Always);
	ImGui.SetNextWindowSize(340, 140, ImGuiCond.Always);
	__gm3d_ed_imgui_bg_alpha(1);
	var _begun = false;
	var _pushed = 0;

	ImGui.PushStyleColor(ImGuiCol.TitleBg, make_colour_rgb(33, 36, 47), 1);
	_pushed++;
	ImGui.PushStyleColor(ImGuiCol.TitleBgActive, make_colour_rgb(33, 36, 47), 1);
	_pushed++;
	_begun = ImGui.Begin("Unsaved changes", _c, ImGuiWindowFlags.NoMove);
	if (!_begun) {
		__gm3d_ed_imgui_pop(_pushed);
		ImGui.End();
		return;
	}
	var _what = "exiting";
	if (_c.action == "new") {
		_what = "creating a new scene";
	} else if (_c.action == "load") {
		_what = "loading a new scene";
	}
	ImGui.Text("Do you want to save changes");
	ImGui.Text("before " + _what + "?");
	if (ImGui.Button("Save", 0, 0)) {
		if (__gm3d_ed_save_or_ask(_ed)) {
			__gm3d_ed_confirm_do(_ed, _c.action);
		}
		_ed.confirm = undefined;
	}
	ImGui.SameLine();
	if (ImGui.Button("Don't save", 0, 0)) {
		if (_c.action == "close") {
			__gm3d_ed_discard_changes(_ed);
		}
		__gm3d_ed_confirm_do(_ed, _c.action);
		_ed.confirm = undefined;
	}
	ImGui.SameLine();
	if (ImGui.Button("Cancel", 0, 0)) {
		_ed.confirm = undefined;
	}
	ImGui.End();
	__gm3d_ed_imgui_pop(_pushed);
}

/// Pops _n ImGui style colors.
/// @param _n color count to pop.
function __gm3d_ed_imgui_pop(_n) {
	for (var _i = 0; _i < _n; _i++) {
		ImGui.PopStyleColor();
	}
}

/// Returns default floating rects for assets, scene and inspector windows.
function __gm3d_ed_imgui_place(_ed) {
	var _gw = max(640, _ed.gw);
	var _gh = max(400, _ed.gh);
	var _top = 30;
	var _gap = 8;
	var _lw = 250;
	var _lh = clamp((_gh - _top - 16) * 0.55, 220, 640);
	var _iw = 280;
	// Transform + one kind section (light/camera/env); ImGui scrolls the rest.
	var _ih = clamp((_gh - _top - 16) * 0.4, 220, 360);
	return {
		assets: { x: 8, y: _top, w: _lw, h: _lh },
		scn: { x: 8, y: _top + _lh + _gap, w: _lw, h: max(140, _gh - (_top + _lh + _gap) - 8) },
		insp: { x: _gw - _iw - 8, y: _gh - _ih - 8, w: _iw, h: _ih },
	};
}

/// Applies the dark navy ImGui theme once.
function __gm3d_ed_imgui_style_once(_ed) {
	if (_ed.imgui.style_init) {
		return;
	}
	_ed.imgui.style_init = true;
	var _bg = make_colour_rgb(20, 26, 41);
	var _panel = make_colour_rgb(16, 21, 34);
	var _accent = make_colour_rgb(37, 99, 235);
	var _accent_hi = make_colour_rgb(45, 60, 95);
	__gm3d_ed_imgui_style_color(ImGuiCol.Text, make_colour_rgb(229, 233, 240), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.TextDisabled, make_colour_rgb(120, 130, 150), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.WindowBg, _bg, 0.9);
	__gm3d_ed_imgui_style_color(ImGuiCol.ChildBg, _panel, 0.9);
	__gm3d_ed_imgui_style_color(ImGuiCol.PopupBg, make_colour_rgb(24, 30, 48), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.Border, make_colour_rgb(38, 48, 75), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.FrameBg, make_colour_rgb(30, 38, 62), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.FrameBgHovered, make_colour_rgb(30, 40, 62), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.FrameBgActive, _accent_hi, 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.TitleBg, _panel, 0.9);
	__gm3d_ed_imgui_style_color(ImGuiCol.TitleBgActive, make_colour_rgb(28, 38, 60), 0.9);
	__gm3d_ed_imgui_style_color(ImGuiCol.MenuBarBg, _panel, 0.9);
	__gm3d_ed_imgui_style_color(ImGuiCol.ScrollbarBg, _panel, 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.ScrollbarGrab, make_colour_rgb(55, 70, 105), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.ScrollbarGrabHovered, make_colour_rgb(75, 92, 135), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.CheckMark, make_colour_rgb(96, 165, 250), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.Button, make_colour_rgb(37, 51, 82), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.ButtonHovered, make_colour_rgb(50, 68, 110), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.ButtonActive, _accent, 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.Header, _accent, 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.HeaderHovered, _accent_hi, 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.HeaderActive, _accent, 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.Separator, make_colour_rgb(38, 48, 75), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.DockingEmptyBg, c_black, 0);
}

/// Sets transparency for the next window.
/// @param _a 0 invisible, 1 opaque.
function __gm3d_ed_imgui_bg_alpha(_a) {
	ImGui.SetNextWindowBgAlpha(_a);
}

/// Applies one ImGui style color.
function __gm3d_ed_imgui_style_color(_col, _rgb, _alpha) {
	ImGui.SetStyleColor(_col, _rgb, _alpha);
	return true;
}

/// Draws the main menu bar (File, Tools, Windows).
function __gm3d_ed_imgui_menu(_ed) {
	var _ui = _ed.imgui;
	var _mbar = false;
	var _do_new = false;
	var _do_load = false;
	var _do_saveas = false;
	var _do_close = false;

	if (!ImGui.BeginMainMenuBar()) {
		return;
	}
	_mbar = true;
	__gm3d_ed_imgui_bg_alpha(1);
	if (ImGui.BeginMenu("File")) {
		ImGui.TextDisabled(_ed.scene_file != "" ? _ed.scene_file : "(unsaved scene)");
		if (ImGui.MenuItem("New", "Ctrl+N")) {
			_do_new = true;
		}
		if (ImGui.MenuItem("Save", "Ctrl+S")) {
			__gm3d_ed_save_or_ask(_ed);
		}
		if (ImGui.MenuItem("Save As...")) {
			_do_saveas = true;
		}
		if (ImGui.MenuItem("Load", "Ctrl+L")) {
			_do_load = true;
		}
		ImGui.Separator();
		if (ImGui.MenuItem("Close Editor", "F1")) {
			_do_close = true;
		}
		ImGui.EndMenu();
	}
	if (ImGui.BeginMenu("Tools")) {
		if (ImGui.MenuItem("Move", "1", { selected: _ed.giz.tool == Gm3dEdTool.Translate, checked: _ed.giz.tool == Gm3dEdTool.Translate })) {
			_ed.giz.tool = Gm3dEdTool.Translate;
		}
		if (ImGui.MenuItem("Rotate", "2", { selected: _ed.giz.tool == Gm3dEdTool.Rotate, checked: _ed.giz.tool == Gm3dEdTool.Rotate })) {
			_ed.giz.tool = Gm3dEdTool.Rotate;
		}
		if (ImGui.MenuItem("Scale", "3", { selected: _ed.giz.tool == Gm3dEdTool.Scale, checked: _ed.giz.tool == Gm3dEdTool.Scale })) {
			_ed.giz.tool = Gm3dEdTool.Scale;
		}
		ImGui.Separator();
		if (ImGui.RadioButton("World axes", _ed.giz.orient == 0)) {
			_ed.giz.orient = 0;
		}
		if (ImGui.RadioButton("Local axes", _ed.giz.orient == 1)) {
			_ed.giz.orient = 1;
		}
		ImGui.Separator();
		_ed.snap_on = ImGui.Checkbox("Snap", _ed.snap_on);
		_ed.snap_pos = ImGui.InputFloat("Snap pos", _ed.snap_pos, 0.05, 0.25);
		_ed.snap_pos = max(0.01, _ed.snap_pos);
		_ed.snap_rot = ImGui.InputFloat("Snap rot", _ed.snap_rot, 1, 5);
		_ed.snap_rot = max(0.5, _ed.snap_rot);
		ImGui.EndMenu();
	}
	if (ImGui.BeginMenu("Create")) {
		if (ImGui.MenuItem("Directional Light")) {
			__gm3d_ed_create_light(_ed, "directional");
		}
		if (ImGui.MenuItem("Point Light")) {
			__gm3d_ed_create_light(_ed, "point");
		}
		// SPOT DISABLED: the GMRT pipeline exposes no cone uniforms, so spot
		// lights render as points. Re-enable when the runtime supports them.
		// if (ImGui.MenuItem("Spot Light")) {
		// 	__gm3d_ed_create_light(_ed, "spot");
		// }
		ImGui.Separator();
		if (ImGui.MenuItem("Perspective Camera")) {
			__gm3d_ed_create_camera(_ed, "perspective");
		}
		if (ImGui.MenuItem("Ortho Camera")) {
			__gm3d_ed_create_camera(_ed, "ortho");
		}
		ImGui.Separator();
		if (__gm3d_ed_env_node(_ed) == undefined) {
			if (ImGui.MenuItem("Environment")) {
				__gm3d_ed_create_env(_ed);
			}
		} else {
			ImGui.TextDisabled("Environment (already in scene)");
		}
		ImGui.EndMenu();
	}
	if (ImGui.BeginMenu("View")) {
		if (ImGui.MenuItem(_ui.win_assets.open ? "[x] Models" : "[  ] Models")) {
			_ui.win_assets.open = !_ui.win_assets.open;
		}
		if (ImGui.MenuItem(_ui.win_scene.open ? "[x] Scene" : "[  ] Scene")) {
			_ui.win_scene.open = !_ui.win_scene.open;
		}
		if (ImGui.MenuItem(_ui.win_insp.open ? "[x] Inspector" : "[  ] Inspector")) {
			_ui.win_insp.open = !_ui.win_insp.open;
		}
		if (ImGui.MenuItem(_ui.win_toolbar.open ? "[x] Toolbar" : "[  ] Toolbar")) {
			_ui.win_toolbar.open = !_ui.win_toolbar.open;
		}
		if (ImGui.MenuItem(_ui.win_cube.open ? "[x] View Cube" : "[  ] View Cube")) {
			_ui.win_cube.open = !_ui.win_cube.open;
		}
		if (ImGui.MenuItem(_ed.show_grid ? "[x] Grid" : "[  ] Grid")) {
			_ed.show_grid = !_ed.show_grid;
		}
		ImGui.Separator();
		if (ImGui.MenuItem("Reset Layout")) {
			_ui.reset_layout = true;
			_ed.cube_off = [85, 100];
			_ui.win_cube.open = true;
			__gm3d_ed_ui_save(_ed);
		}
		ImGui.EndMenu();
	}
	ImGui.EndMainMenuBar();
	_mbar = false;

	__gm3d_ed_menu_do(_ed, _do_new, _do_load, _do_saveas, _do_close);
}

/// Draws the Models asset window.
function __gm3d_ed_imgui_assets(_ed) {
	var _ui = _ed.imgui;
	if (!_ui.win_assets.open) {
		return;
	}
	var _pl = __gm3d_ed_imgui_place(_ed).assets;
	ImGui.SetNextWindowPos(_pl.x, _pl.y, _ui.cond);
	ImGui.SetNextWindowSize(_pl.w, _pl.h, _ui.cond);
	__gm3d_ed_imgui_bg_alpha(0.9);
	var _begun = false;

	if (!ImGui.Begin("Models", _ui.win_assets)) {
		ImGui.End();
		return;
	}
	_begun = true;
	__gm3d_ed_imgui_asset_list(_ed);
	ImGui.End();
}

/// Draws the Scene hierarchy window.
function __gm3d_ed_imgui_scene_win(_ed) {
	var _ui = _ed.imgui;
	if (!_ui.win_scene.open) {
		return;
	}
	var _ps = __gm3d_ed_imgui_place(_ed).scn;
	ImGui.SetNextWindowPos(_ps.x, _ps.y, _ui.cond);
	ImGui.SetNextWindowSize(_ps.w, _ps.h, _ui.cond);
	__gm3d_ed_imgui_bg_alpha(0.9);
	var _begun = false;

	if (!ImGui.Begin("Scene", _ui.win_scene)) {
		ImGui.End();
		return;
	}
	_begun = true;
	__gm3d_ed_imgui_scene_list(_ed);
	ImGui.End();
}

/// Draws the filterable droppable model name list.
function __gm3d_ed_imgui_asset_list(_ed) {
	var _ui = _ed.imgui;
	ImGui.SetNextItemWidth(-1);
	_ui.filter = __gm3d_ed_imgui_text_hint("##filter", "Filter models...", _ui.filter);
	ImGui.Separator();
	var _flt = string_lower(_ui.filter);
	for (var _i = 0; _i < array_length(_ed.assets); _i++) {
		var _a = _ed.assets[_i];
		if (_flt != "" && string_pos(_flt, string_lower(_a.name)) <= 0) {
			continue;
		}
		ImGui.PushID(_i);
		ImGui.Selectable(_a.name, false);
		if (_ed.drag_lib == undefined && ImGui.IsItemHovered()) {
			ImGui.SetTooltip(_a.name + "\nDrag into the scene");
		}

		if (ImGui.BeginDragDropSource(ImGuiDragDropFlags.SourceNoPreviewTooltip)) {
			ImGui.SetDragDropPayload("GM3D_ASSET", _i);
			ImGui.EndDragDropSource();
			if (_ed.drag_lib == undefined || _ed.drag_lib.idx != _i) {
				_ed.drag_lib = { asset: _a, idx: _i };
				_ed.drag_moved = false;
				_ed.press_x = device_mouse_x_to_gui(0);
				_ed.press_y = device_mouse_y_to_gui(0);
			}
		}

		ImGui.PopID();
	}
}

/// Draws the inspector with selection title and transform fields.
function __gm3d_ed_imgui_inspector(_ed) {
	var _ui = _ed.imgui;
	if (!_ui.win_insp.open) {
		return;
	}
	var _pi = __gm3d_ed_imgui_place(_ed).insp;
	ImGui.SetNextWindowPos(_pi.x, _pi.y, _ui.cond);
	ImGui.SetNextWindowSize(_pi.w, _pi.h, _ui.cond);
	__gm3d_ed_imgui_bg_alpha(0.9);
	var _begun = false;

	if (!ImGui.Begin("Inspector", _ui.win_insp)) {
		ImGui.End();
		return;
	}
	_begun = true;
	var _n = array_length(_ed.sel);
	if (_n == 0) {
		ImGui.TextDisabled("No selection");
		ImGui.Text("Click an object or drag a model in.");
	} else {
		var _title = _n == 1 ? __gm3d_ed_label_get(_ed, _ed.sel[0]) : string(_n) + " objects";
		ImGui.Text(_title);
		var _skind = undefined;
		var _stype = undefined;
		if (_n == 1) {
			_skind = __gm3d_ed_kind_of(_ed, _ed.sel[0]);
			if (_skind == "light") {
				var _sen0 = __gm3d_ed_registry_find(_ed, _ed.sel[0]);
				if (_sen0 != undefined && is_struct(_sen0.data) && is_string(_sen0.data.type)) {
					_stype = _sen0.data.type;
				}
			}
		}
		// Transform rows that cannot affect the node are hidden entirely:
		// directional shows rotation only, point shows position only,
		// cameras and spots show position + rotation, environment none.
		var _show_p = true;
		var _show_r = true;
		var _show_s = true;
		if (_n == 1 && _skind != undefined && _skind != "asset") {
			if (_skind == "environment") {
				_show_p = false;
				_show_r = false;
				_show_s = false;
			} else if (_skind == "camera") {
				_show_s = false;
			} else if (_skind == "light") {
				_show_s = false;
				if (_stype == "directional") {
					_show_p = false;
				} else if (_stype == "point") {
					_show_r = false;
				}
			}
		}
		if (_show_p || _show_r || _show_s) {
			ImGui.Separator();
		}
		if (_show_p) {
			__gm3d_ed_imgui_axis_row(_ed, 0, "Position");
		}
		if (_show_r) {
			__gm3d_ed_imgui_axis_row(_ed, 1, "Rotation");
		}
		if (_show_s) {
			__gm3d_ed_imgui_axis_row(_ed, 2, "Scale");
		}
		if (_n == 1 && _skind != undefined && _skind != "asset") {
			var _sen = __gm3d_ed_registry_find(_ed, _ed.sel[0]);
			if (_sen != undefined && is_struct(_sen.data)) {
				if (_skind == "light") {
					__gm3d_ed_imgui_light_sec(_ed, _ed.sel[0], _sen);
				} else if (_skind == "camera") {
					__gm3d_ed_imgui_camera_sec(_ed, _ed.sel[0], _sen);
				} else if (_skind == "environment") {
					__gm3d_ed_imgui_env_sec(_ed, _ed.sel[0], _sen);
				}
			}
		}
	}
	ImGui.End();
}

/// Draws one transform row with X/Y/Z textboxes.
/// @param _mode 0 position, 1 rotation (deg), 2 scale.
function __gm3d_ed_imgui_axis_row(_ed, _mode, _label) {
	var _names = ["X", "Y", "Z"];
	if (_ed.imgui == undefined) {
		__gm3d_ed_imgui_ensure(_ed);
	}
	if (!variable_struct_exists(_ed.imgui, "ax_active")) {
		_ed.imgui.ax_active = {};
	}

	ImGui.PushID(_mode);
	ImGui.AlignTextToFramePadding();
	ImGui.Text(_label);
	for (var _a = 0; _a < 3; _a++) {
		var _av = __gm3d_ed_axis_val(_ed, _mode, _a);
		if (_a == 0) {
			ImGui.SameLine(80);
		} else {
			ImGui.SameLine();
		}
		ImGui.SetNextItemWidth(46);
		var _fkey = "ax" + string(_mode) + "_" + _label + "_" + _names[_a];
		var _was = false;
		_was = _ed.imgui.ax_active[$ _fkey] == true;
		var _nv = ImGui.InputFloat(_names[_a], _av.val, 0, 0);
		var _now = ImGui.IsItemActive();
		_ed.imgui.ax_active[$ _fkey] = _now;
		if (_was && !_now && _nv != _av.val) {
			__gm3d_ed_inspector_apply(_ed, _mode, _a, _nv);
		}
		if (_a < 2) {
			ImGui.SameLine();
			ImGui.Dummy(2, 0);
		}
	}
	ImGui.PopID();
}

/// Float field with commit-on-defocus for prop sections.
/// @return Committed value, or undefined when untouched.
function __gm3d_ed_imgui_prop_float(_ed, _key, _label, _val, _w) {
	if (_ed.imgui == undefined) {
		__gm3d_ed_imgui_ensure(_ed);
	}
	if (!variable_struct_exists(_ed.imgui, "flt_active")) {
		_ed.imgui.flt_active = {};
	}
	ImGui.SetNextItemWidth(_w);
	var _nv = ImGui.InputFloat(_label, _val, 0, 0);
	var _now = ImGui.IsItemActive();
	var _was = _ed.imgui.flt_active[$ _key] == true;
	_ed.imgui.flt_active[$ _key] = _now;
	if (_was && !_now && _nv != _val) {
		return _nv;
	}
	return undefined;
}

/// Finishes a prop edit: re-points tracked rows and commits undo.
/// @param _hb before-snapshot from __gm3d_ed_history_snap.
function __gm3d_ed_props_end(_ed, _hb) {
	__gm3d_ed_rows_follow(_ed, _ed.sel);
	if (_hb != undefined) {
		__gm3d_ed_history_commit(_ed, _hb);
	}
}

/// True when the ImGui binding exposes a widget (probed once, then cached).
/// Guards widgets that exist in docs but may miss from the GMRT binding
/// (e.g. SeparatorText): never call an unprobed widget directly.
function __gm3d_ed_imgui_has_widget(_ed, _name) {
	if (_ed.imgui == undefined) {
		__gm3d_ed_imgui_ensure(_ed);
	}
	if (!variable_struct_exists(_ed.imgui, "widget_probe")) {
		_ed.imgui.widget_probe = {};
	}
	if (variable_struct_exists(_ed.imgui.widget_probe, _name)) {
		return _ed.imgui.widget_probe[$ _name] == true;
	}
	var _ok = false;
	try {
		var _f = ImGui[$ _name];
		_ok = (_f != undefined);
	} catch (_e) {
		_ok = false;
	}
	_ed.imgui.widget_probe[$ _name] = _ok;
	return _ok;
}

/// RGB row with commit-on-defocus; writes into _col when a channel commits.
/// @return True when a commit happened.
function __gm3d_ed_imgui_rgb_row(_ed, _key, _label, _col) {
	ImGui.Text(_label);
	var _names = ["R", "G", "B"];
	var _chg = false;
	for (var _a = 0; _a < 3; _a++) {
		if (_a == 0) {
			ImGui.SameLine(80);
		} else {
			ImGui.SameLine();
		}
		var _cv = __gm3d_ed_imgui_prop_float(_ed, _key + _names[_a], "##" + _key + _names[_a], _col[_a], 46);
		if (_cv != undefined) {
			_col[_a] = clamp(_cv, 0, 255);
			_chg = true;
		}
	}
	return _chg;
}

/// Light section of the inspector (single selection).
function __gm3d_ed_imgui_light_sec(_ed, _node, _en) {
	var _d = _en.data;
	ImGui.Separator();
	ImGui.Text("Light");
	if (ImGui.RadioButton("Directional", _d.type == "directional")) {
		var _hb = __gm3d_ed_history_snap(_ed);
		_d.type = "directional";
		__gm3d_ed_light_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb);
	}
	if (ImGui.RadioButton("Point", _d.type == "point")) {
		var _hb9 = __gm3d_ed_history_snap(_ed);
		_d.type = "point";
		if (_d.range < 0.5) {
			_d.range = 50.0;
		}
		__gm3d_ed_light_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb9);
	}
	// SPOT DISABLED: same reason as the Create menu (no cone uniforms in the
	// pipeline). Loaded spot entries still show below with their cone fields.
	// if (ImGui.RadioButton("Spot", _d.type == "spot")) {
	// 	var _hb0 = __gm3d_ed_history_snap(_ed);
	// 	_d.type = "spot";
	// 	if (_d.range < 0.5) {
	// 		_d.range = 50.0;
	// 	}
	// 	__gm3d_ed_light_apply(_node, _d);
	// 	__gm3d_ed_props_end(_ed, _hb0);
	// }
	var _nen = ImGui.Checkbox("Enabled", _d.enabled == true);
	if (_nen != (_d.enabled == true)) {
		var _hb2 = __gm3d_ed_history_snap(_ed);
		_d.enabled = _nen;
		__gm3d_ed_light_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb2);
	}
	var _nv = __gm3d_ed_imgui_prop_float(_ed, "light_int", "Intensity", _d.intensity, 120);
	if (_nv != undefined) {
		var _hb3 = __gm3d_ed_history_snap(_ed);
		_d.intensity = max(_nv, 0);
		__gm3d_ed_light_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb3);
	}
	var _nc = [_d.color[0], _d.color[1], _d.color[2]];
	if (__gm3d_ed_imgui_rgb_row(_ed, "light_col", "Color", _nc)) {
		var _hb4 = __gm3d_ed_history_snap(_ed);
		_d.color = _nc;
		__gm3d_ed_light_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb4);
	}
	if (_d.type != "directional") {
		var _rg = __gm3d_ed_imgui_prop_float(_ed, "light_range", "Range", _d.range, 120);
		if (_rg != undefined) {
			var _hb5 = __gm3d_ed_history_snap(_ed);
			_d.range = max(_rg, 0.01);
			__gm3d_ed_light_apply(_node, _d);
			__gm3d_ed_props_end(_ed, _hb5);
		}
	}
	if (_d.type == "spot") {
		var _ni = __gm3d_ed_imgui_prop_float(_ed, "light_inner", "Inner cone", _d.inner, 120);
		if (_ni != undefined) {
			var _hb6 = __gm3d_ed_history_snap(_ed);
			_d.inner = clamp(_ni, 0, 89);
			__gm3d_ed_light_apply(_node, _d);
			__gm3d_ed_props_end(_ed, _hb6);
		}
		var _no = __gm3d_ed_imgui_prop_float(_ed, "light_outer", "Outer cone", _d.outer, 120);
		if (_no != undefined) {
			var _hb7 = __gm3d_ed_history_snap(_ed);
			_d.outer = clamp(_no, 1, 89);
			__gm3d_ed_light_apply(_node, _d);
			__gm3d_ed_props_end(_ed, _hb7);
		}
	}
}

/// Camera section of the inspector (single selection).
function __gm3d_ed_imgui_camera_sec(_ed, _node, _en) {
	var _d = _en.data;
	ImGui.Separator();
	ImGui.Text("Camera");
	if (ImGui.RadioButton("Perspective", _d.projection != "ortho")) {
		var _hb = __gm3d_ed_history_snap(_ed);
		_d.projection = "perspective";
		__gm3d_ed_camera_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb);
	}
	if (ImGui.RadioButton("Ortho", _d.projection == "ortho")) {
		var _hb9 = __gm3d_ed_history_snap(_ed);
		_d.projection = "ortho";
		__gm3d_ed_camera_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb9);
	}
	var _nen = ImGui.Checkbox("Enabled", _d.enabled == true);
	if (_nen != (_d.enabled == true)) {
		var _hb2 = __gm3d_ed_history_snap(_ed);
		_d.enabled = _nen;
		__gm3d_ed_camera_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb2);
	}
	if (_d.projection == "ortho") {
		var _ow = __gm3d_ed_imgui_prop_float(_ed, "cam_ow", "Ortho width", _d.ow, 120);
		if (_ow != undefined) {
			var _hb3 = __gm3d_ed_history_snap(_ed);
			_d.ow = max(_ow, 0.01);
			__gm3d_ed_camera_apply(_node, _d);
			__gm3d_ed_props_end(_ed, _hb3);
		}
		var _oh = __gm3d_ed_imgui_prop_float(_ed, "cam_oh", "Ortho height", _d.oh, 120);
		if (_oh != undefined) {
			var _hb4 = __gm3d_ed_history_snap(_ed);
			_d.oh = max(_oh, 0.01);
			__gm3d_ed_camera_apply(_node, _d);
			__gm3d_ed_props_end(_ed, _hb4);
		}
	} else {
		var _fv = __gm3d_ed_imgui_prop_float(_ed, "cam_fov", "FovY deg", _d.fov, 120);
		if (_fv != undefined) {
			var _hb5 = __gm3d_ed_history_snap(_ed);
			_d.fov = clamp(_fv, 1, 179);
			__gm3d_ed_camera_apply(_node, _d);
			__gm3d_ed_props_end(_ed, _hb5);
		}
	}
	var _nr = __gm3d_ed_imgui_prop_float(_ed, "cam_near", "Near", _d.near, 120);
	if (_nr != undefined) {
		var _hb6 = __gm3d_ed_history_snap(_ed);
		_d.near = max(_nr, 0.01);
		__gm3d_ed_camera_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb6);
	}
	var _fr = __gm3d_ed_imgui_prop_float(_ed, "cam_far", "Far", _d.far, 120);
	if (_fr != undefined) {
		var _hb7 = __gm3d_ed_history_snap(_ed);
		_d.far = max(_fr, _d.near + 0.01);
		__gm3d_ed_camera_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb7);
	}
	// Live cameras stay muted while the editor is open (only the viewport
	// camera renders); the Enabled flag above is the game-side file value.
	__gm3d_ed_cameras_mute(_ed);
}

/// Environment section of the inspector (single selection).
function __gm3d_ed_imgui_env_sec(_ed, _node, _en) {
	var _d = _en.data;
	ImGui.Separator();
	ImGui.Text("Environment");
	var _nen = ImGui.Checkbox("Enabled", _d.enabled == true);
	if (_nen != (_d.enabled == true)) {
		var _hb = __gm3d_ed_history_snap(_ed);
		_d.enabled = _nen;
		__gm3d_ed_env_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb);
	}
	ImGui.Text("Size");
	var _ns = [_d.size[0], _d.size[1], _d.size[2]];
	var _names = ["X", "Y", "Z"];
	var _chg = false;
	for (var _a = 0; _a < 3; _a++) {
		if (_a == 0) {
			ImGui.SameLine(80);
		} else {
			ImGui.SameLine();
		}
		var _sv = __gm3d_ed_imgui_prop_float(_ed, "env_size" + _names[_a], "##envsize" + _names[_a], _ns[_a], 46);
		if (_sv != undefined) {
			_ns[_a] = max(_sv, 0.01);
			_chg = true;
		}
	}
	if (_chg) {
		var _hb2 = __gm3d_ed_history_snap(_ed);
		_d.size = _ns;
		__gm3d_ed_env_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb2);
	}
	var _na = [_d.ambient[0], _d.ambient[1], _d.ambient[2]];
	if (__gm3d_ed_imgui_rgb_row(_ed, "env_amb", "Ambient", _na)) {
		var _hb3 = __gm3d_ed_history_snap(_ed);
		_d.ambient = _na;
		__gm3d_ed_env_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb3);
	}
	var _nfg = ImGui.Checkbox("Fog", _d.fog == true);
	if (_nfg != (_d.fog == true)) {
		var _hb4 = __gm3d_ed_history_snap(_ed);
		_d.fog = _nfg;
		__gm3d_ed_env_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb4);
	}
	if (_d.fog == true) {
		var _nf = [_d.fogcolor[0], _d.fogcolor[1], _d.fogcolor[2]];
		if (__gm3d_ed_imgui_rgb_row(_ed, "env_fogc", "Fog color", _nf)) {
			var _hb5 = __gm3d_ed_history_snap(_ed);
			_d.fogcolor = _nf;
			__gm3d_ed_env_apply(_node, _d);
			__gm3d_ed_props_end(_ed, _hb5);
		}
		var _fs = __gm3d_ed_imgui_prop_float(_ed, "env_fogs", "Fog start", _d.fogstart, 120);
		if (_fs != undefined) {
			var _hb6 = __gm3d_ed_history_snap(_ed);
			_d.fogstart = _fs;
			__gm3d_ed_env_apply(_node, _d);
			__gm3d_ed_props_end(_ed, _hb6);
		}
		var _fe = __gm3d_ed_imgui_prop_float(_ed, "env_foge", "Fog end", _d.fogend, 120);
		if (_fe != undefined) {
			var _hb7 = __gm3d_ed_history_snap(_ed);
			_d.fogend = max(_fe, _d.fogstart + 0.01);
			__gm3d_ed_env_apply(_node, _d);
			__gm3d_ed_props_end(_ed, _hb7);
		}
	}
}

/// Eye toggle button for Scene rows. Uses the sprGM3DIconEye sprite when the
/// project has it (dimmed when hidden), else a text button.
/// @return True when clicked.
function __gm3d_ed_imgui_eye(_ed, _hidden) {
	static _eye_spr = -2;
	if (_eye_spr == -2) {
		try {
			_eye_spr = asset_get_index("sprGM3DIconEye");
		} catch (_e) {
			_eye_spr = -1;
		}
	}
	var _hit = false;
	if (_eye_spr != -1) {
		var _tint = _hidden ? make_colour_rgb(105, 115, 135) : c_white;
		// Frameless icon: transparent button colors, sprite at native 15x9.
		ImGui.PushStyleColor(ImGuiCol.Button, c_black, 0);
		ImGui.PushStyleColor(ImGuiCol.ButtonHovered, make_colour_rgb(47, 111, 237), 0.35);
		ImGui.PushStyleColor(ImGuiCol.ButtonActive, make_colour_rgb(47, 111, 237), 0.5);
		try {
			// 9 args: uvs omitted entirely (undefined throws in this
			// binding); omitted uvs default to the full sprite.
			_hit = ImGui.ImageButton("eye", _eye_spr, 0, _tint, 1, c_black, 0, 15, 9);
		} catch (_e2) {
			_eye_spr = -1;
			_hit = ImGui.Button(_hidden ? "Show##eye" : "Hide##eye");
		}
		__gm3d_ed_imgui_pop(3);
	} else if (__gm3d_ed_imgui_has_widget(_ed, "SmallButton")) {
		try {
			_hit = ImGui.SmallButton(_hidden ? "Show##eye" : "Hide##eye");
		} catch (_e3) {
			_ed.imgui.widget_probe[$ "SmallButton"] = false;
			_hit = ImGui.Button(_hidden ? "Show##eye" : "Hide##eye");
		}
	} else {
		_hit = ImGui.Button(_hidden ? "Show##eye" : "Hide##eye");
	}
	if (ImGui.IsItemHovered()) {
		ImGui.SetTooltip(_hidden ? "Show in viewport" : "Hide from viewport");
	}
	return _hit;
}

/// Begins renaming a tracked scene node into a textbox.
/// @param _node tracked scene node to rename.
function __gm3d_ed_rename_begin(_ed, _node) {
	if (_node == undefined) {
		return;
	}
	if (_ed.giz.drag != -1) {
		return;
	}

	if (__gm3d_ed_registry_find(_ed, _node) == undefined) {
		return;
	}
	var _lb = __gm3d_ed_label_get(_ed, _node);
	if (!is_string(_lb) || _lb == "") {
		return;
	}
	var _pp = undefined;
	_pp = _node.getLocalPosition();
	_ed.rename_name = _lb;
	_ed.rename_pos = [_pp.x, _pp.y, _pp.z];
	_ed.imgui.win_scene.open = true;
}

/// Cancels any open rename without applying.
function __gm3d_ed_rename_cancel(_ed) {
	_ed.rename_name = undefined;
	_ed.rename_pos = undefined;
}

/// True when _node matches the rename snapshot position.
function __gm3d_ed_rename_at(_ed, _node) {
	var _rp = _ed.rename_pos;
	var _pp = _node.getLocalPosition();
	return _pp.x == _rp[0] && _pp.y == _rp[1] && _pp.z == _rp[2];
}

/// Draws the filterable scene root list with selection, focus and rename.
function __gm3d_ed_imgui_scene_list(_ed) {
	var _ui = _ed.imgui;
	ImGui.SetNextItemWidth(-1);
	_ui.scene_filter = __gm3d_ed_imgui_text_hint("##scenefilter", "Filter nodes...", _ui.scene_filter);
	if (!variable_struct_exists(_ui, "show_kind")) {
		_ui.show_kind = { m: true, l: true, c: true, e: true };
	}
	var _sk = _ui.show_kind;
	_sk.m = ImGui.Checkbox("M", _sk.m);
	if (ImGui.IsItemHovered()) {
		ImGui.SetTooltip("Show models");
	}
	ImGui.SameLine();
	_sk.l = ImGui.Checkbox("L", _sk.l);
	if (ImGui.IsItemHovered()) {
		ImGui.SetTooltip("Show lights");
	}
	ImGui.SameLine();
	_sk.c = ImGui.Checkbox("C", _sk.c);
	if (ImGui.IsItemHovered()) {
		ImGui.SetTooltip("Show cameras");
	}
	ImGui.SameLine();
	_sk.e = ImGui.Checkbox("E", _sk.e);
	if (ImGui.IsItemHovered()) {
		ImGui.SetTooltip("Show environment");
	}
	ImGui.Separator();
	if (_ed.rt == undefined) {
		ImGui.TextDisabled("No scene");
		return;
	}
	var _roots = [];
	var _del = undefined;
	var _dup = undefined;
	var _foc = undefined;
	var _ren = undefined;
	if (!variable_struct_exists(_ed, "scene_click_idx")) {
		_ed.scene_click_idx = -1;
		_ed.scene_click_time = -10000;
	}
	var _flt = "";
	_flt = string_lower(_ui.scene_filter);
	_roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		var _nd = _roots[_i];
		var _dl = __gm3d_ed_label_get(_ed, _nd);
		var _nk = __gm3d_ed_kind_of(_ed, _nd);
		if (_nk == "light" && !_sk.l) {
			continue;
		}
		if (_nk == "camera" && !_sk.c) {
			continue;
		}
		if (_nk == "environment" && !_sk.e) {
			continue;
		}
		if (_nk != "light" && _nk != "camera" && _nk != "environment" && !_sk.m) {
			continue;
		}
		if (_flt != "" && string_pos(_flt, string_lower(_dl)) <= 0) {
			continue;
		}
		var _row = _dl;
		if (_nk == "light") {
			_row = "[L] " + _dl;
		} else if (_nk == "camera") {
			_row = "[C] " + _dl;
		} else if (_nk == "environment") {
			_row = "[E] " + _dl;
		}
		if (__gm3d_ed_hidden_get(_ed, _nd)) {
			_row += " [hidden]";
		}
		ImGui.PushID(_i);
		var _renaming = false;

		_renaming = _ed.rename_name != undefined && _dl == _ed.rename_name && __gm3d_ed_rename_at(_ed, _nd);

		if (_renaming) {
			var _res = __gm3d_ed_imgui_text("rename", "##rename", _dl);
			if (_res.was_active && !_res.active) {
				var _nn2 = "";
				_nn2 = string_trim(_res.text);
				if (_nn2 != "" && _nn2 != _dl) {
					__gm3d_ed_scene_commit_rename(_ed, _nd, _nn2);
				}
				__gm3d_ed_rename_cancel(_ed);
			}
		} else {
			var _ishid = __gm3d_ed_hidden_get(_ed, _nd);
			if (__gm3d_ed_imgui_eye(_ed, _ishid)) {
				__gm3d_ed_hidden_set(_ed, _nd, !_ishid);
			}
			ImGui.SameLine();
			var _sel = __gm3d_ed_sel_has(_ed, _nd);
			if (ImGui.Selectable(_row, _sel)) {
				__gm3d_ed_scene_click(_ed, _nd, _i);
			}
			var _dbl = false;
			_dbl = ImGui.IsMouseDoubleClicked(0) && ImGui.IsItemHovered();
			if (_dbl) {
				__gm3d_ed_focus_node(_ed, _nd);
			}
		}
		ImGui.PopID();
		__gm3d_ed_imgui_bg_alpha(1);
		if (ImGui.BeginPopupContextItem("ctx##" + string(_i))) {
			if (!__gm3d_ed_sel_has(_ed, _nd)) {
				__gm3d_ed_scene_select(_ed, _nd);
			}
			if (ImGui.MenuItem("Focus", "F")) {
				_foc = _nd;
				ImGui.CloseCurrentPopup();
			}
			if (ImGui.MenuItem("Rename", "F2")) {
				_ren = _nd;
				ImGui.CloseCurrentPopup();
			}
			if (ImGui.MenuItem("Duplicate", "Ctrl+D")) {
				_dup = _nd;
				ImGui.CloseCurrentPopup();
			}
			if (ImGui.MenuItem("Delete", "Del")) {
				_del = _nd;
				ImGui.CloseCurrentPopup();
			}
			ImGui.EndPopup();
		}
	}
	__gm3d_ed_scene_list_commit(_ed, _ren, _foc, _dup, _del);
}

/// Returns true when the native ImGui module is available.
function __gm3d_ed_imgui_check(_ed) {
	if (_ed.imgui_ok != undefined) {
		return _ed.imgui_ok;
	}

	var _v = ImGui.GetVersion();
	_ed.imgui_ok = _v != undefined && _v != "";

	return _ed.imgui_ok;
}

/// Runs deferred File menu actions (new, load, save-as, close).
function __gm3d_ed_menu_do(_ed, _new, _load, _saveas, _close) {
	if (_new) {
		__gm3d_ed_confirm_ask(_ed, "new");
	}
	if (_load) {
		__gm3d_ed_confirm_ask(_ed, "load");
	}
	if (_saveas) {
		__gm3d_ed_save_as(_ed);
	}
	if (_close) {
		__gm3d_ed_confirm_ask(_ed, "close");
	}
}

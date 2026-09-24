/// @module gm3d_ed_imgui
/// ImGui shell with toolbar, menu, assets, scene, inspector and confirm dialog.
/// Binding notes (GMRT ImGui, from ImGUI.yyb metadata): image widgets take a
/// sprite via asset_get_index (a bare asset constant crashes the runner),
/// only raster sprites work (vector sprites crash), and the signatures are
/// Image(sprite, subImage, colour, alpha, width, height) and
/// ImageButton(strID, sprite, subImage, colour, alpha, ...).

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
		icons: {
			move: asset_get_index("sprUiIconCheck"),
			rotate: asset_get_index("sprUiIconSun"),
			scale: asset_get_index("sprUiIconState"),
		},
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

/// Draws one toolbar tool button with an icon; highlighted while active.
/// @param _id Dear ImGui widget id.
/// @param _icon resolved sprite asset (see _ed.imgui.icons).
/// @param _tip tooltip text, also names the tool.
/// @return True when clicked.
function __gm3d_ed_imgui_tool_btn(_ed, _id, _icon, _tip, _active) {
	var _pushed = 0;
	if (_active) {
		ImGui.PushStyleColor(ImGuiCol.Button, make_colour_rgb(47, 111, 237), 1);
		_pushed++;
	}
	var _hit = ImGui.ImageButton(_id, _icon, 0, c_white, 1, 24, 24);
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
	if (__gm3d_ed_imgui_tool_btn(_ed, "tool_move", _ed.imgui.icons.move, "Move (1)", _ed.giz.tool == Gm3dEdTool.Translate)) {
		_ed.giz.tool = Gm3dEdTool.Translate;
	}
	ImGui.SameLine();
	if (__gm3d_ed_imgui_tool_btn(_ed, "tool_rotate", _ed.imgui.icons.rotate, "Rotate (2)", _ed.giz.tool == Gm3dEdTool.Rotate)) {
		_ed.giz.tool = Gm3dEdTool.Rotate;
	}
	ImGui.SameLine();
	if (__gm3d_ed_imgui_tool_btn(_ed, "tool_scale", _ed.imgui.icons.scale, "Scale (3)", _ed.giz.tool == Gm3dEdTool.Scale)) {
		_ed.giz.tool = Gm3dEdTool.Scale;
	}
	ImGui.SameLine();
	ImGui.TextDisabled("|");
	ImGui.SameLine();
	_ed.snap_on = ImGui.Checkbox("Snap", _ed.snap_on);
	ImGui.SameLine();
	if (ImGui.Button("Home", 0, 0)) {
		__gm3d_ed_cam_home(_ed);
	}
	if (ImGui.IsItemHovered()) {
		ImGui.SetTooltip("Reset camera to the initial view");
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
	var _ih = 125;
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
		if (ImGui.RadioButton("Move (1)", _ed.giz.tool == Gm3dEdTool.Translate)) {
			_ed.giz.tool = Gm3dEdTool.Translate;
		}
		if (ImGui.RadioButton("Rotate (2)", _ed.giz.tool == Gm3dEdTool.Rotate)) {
			_ed.giz.tool = Gm3dEdTool.Rotate;
		}
		if (ImGui.RadioButton("Scale (3)", _ed.giz.tool == Gm3dEdTool.Scale)) {
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
	if (ImGui.BeginMenu("Windows")) {
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
		ImGui.Separator();
		__gm3d_ed_imgui_axis_row(_ed, 0, "Position");
		__gm3d_ed_imgui_axis_row(_ed, 1, "Rotation");
		__gm3d_ed_imgui_axis_row(_ed, 2, "Scale");
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
			__gm3d_ed_imgui_sameline_at(80);
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

/// SameLine at a fixed x offset, falling back to plain SameLine.
function __gm3d_ed_imgui_sameline_at(_x) {
	ImGui.SameLine(_x);
	return;
	ImGui.SameLine();
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
		if (_flt != "" && string_pos(_flt, string_lower(_dl)) <= 0) {
			continue;
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
			var _sel = __gm3d_ed_sel_has(_ed, _nd);
			if (ImGui.Selectable(_dl, _sel)) {
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

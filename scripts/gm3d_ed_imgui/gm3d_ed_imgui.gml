// Pads string with spaces to fixed length.
function __gm3d_ed_imgui_pad(_base) {
	if (!is_string(_base)) {
		_base = "";
	}
	var _buf = _base;
	while (string_length(_buf) < 255) {
		_buf += " ";
	}
	return _buf;
}

// Renders editable text input with focus tracking.
function __gm3d_ed_imgui_text(_key, _label, _val) {
	static _active = {};
	static _bufs = {};
	var _base = _val;
	if (!is_string(_base)) {
		_base = "";
	}
	var _was = _active[$ _key] == true;
	if (!_was || !variable_struct_exists(_bufs, _key)) {
		_bufs[$ _key] = __gm3d_ed_imgui_pad(_base);
	}

	var _out = ImGui.InputText(_label, _bufs[$ _key], ImGuiInputTextFlags.AutoSelectAll);
	var _now = ImGui.IsItemActive();

	_active[$ _key] = _now;
	if (!is_string(_out)) {
		return { text: _base, active: _now, was_active: _was };
	}
	_bufs[$ _key] = _out;
	return { text: string_trim(_out), active: _now, was_active: _was };
}

// Edits float via drag control with fallback.
function __gm3d_ed_imgui_dragfloat(_label, _val, _speed) {
	static _has = undefined;
	if (_has == undefined) {
		_has = false;
		try {
			_has = variable_struct_exists(ImGui, "DragFloat");
		} catch (_eP) {
			_has = false;
		}
	}
	if (!_has) {
		return ImGui.InputFloat(_label, _val, 0, 0);
	}
	var _out = _val;
	try {
		_out = ImGui.DragFloat(_label, _val, _speed, 0, 0);
	} catch (_eD) {
		return ImGui.InputFloat(_label, _val, 0, 0);
	}
	if (!is_real(_out)) {
		return _val;
	}
	return _out;
}

// Renders text input showing placeholder hint.
function __gm3d_ed_imgui_text_hint(_id_label, _hint, _val) {
	static _active = {};
	static _bufs = {};
	var _base = _val;
	if (!is_string(_base)) {
		_base = "";
	}
	var _was = _active[$ _id_label] == true;
	if (!_was || !variable_struct_exists(_bufs, _id_label)) {
		_bufs[$ _id_label] = __gm3d_ed_imgui_pad(_base);
	}

	var _out = ImGui.InputTextWithHint(
		_id_label,
		_hint,
		_bufs[$ _id_label],
		ImGuiInputTextFlags.AutoSelectAll,
	);
	var _now = ImGui.IsItemActive();

	_active[$ _id_label] = _now;
	if (!is_string(_out)) {
		return _base;
	}
	_bufs[$ _id_label] = _out;
	return string_trim(_out);
}

// Initializes editor ImGui state if missing.
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
		ax_draft: {},
		flt_active: {},
		flt_draft: {},
		show_kind: { m: true, l: true, c: true, e: true },
		scene_eye_idx: -1,
		scene_eye_till: 0,
	};
}

// Draws all editor ImGui windows and menus.
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

	if (!variable_struct_exists(_ed.imgui, "_pw")) {
		_ed.imgui._pw = 0;
		_ed.imgui._ph = 0;
	}
	var _rsz = _ed.imgui._pw != _ed.gw || _ed.imgui._ph != _ed.gh;
	_ed.imgui._pw = _ed.gw;
	_ed.imgui._ph = _ed.gh;
	var _modal_ui = false;
	_modal_ui = _ed.confirm != undefined || _ed.about != undefined;
	if (_modal_ui) {
		if (_ed.confirm != undefined) {
			__gm3d_ed_imgui_confirm(_ed);
		}
		if (_ed.about != undefined) {
			__gm3d_ed_imgui_about(_ed);
		}
		return;
	}
	var _rst = _ed.imgui.reset_layout == true;
	if (_rst || _rsz) {
		_ed.imgui.cond = ImGuiCond.Always;
		__gm3d_ed_cube_home(_ed);
	}
	__gm3d_ed_imgui_menu(_ed);
	__gm3d_ed_imgui_toolbar(_ed);
	__gm3d_ed_imgui_assets(_ed);
	__gm3d_ed_imgui_scene_win(_ed);
	__gm3d_ed_imgui_inspector(_ed);
	__gm3d_ed_imgui_confirm(_ed);
	__gm3d_ed_imgui_about(_ed);
	if (_rst || _rsz) {
		_ed.imgui.cond = ImGuiCond.FirstUseEver;
		_ed.imgui.reset_layout = false;
	}
}

// Draws toolbar button with tooltip and highlight.
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

// Draws gizmo tools and snap options toolbar.
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
	var _olbl = _ed.giz.orient == 1 ? "Local" : "World";
	if (__gm3d_ed_imgui_tool_btn("Gizmo axes space (" + _olbl + ", click to switch)", _olbl, false)) {
		_ed.giz.orient = _ed.giz.orient == 1 ? 0 : 1;
	}
	ImGui.SameLine();
	ImGui.TextDisabled("|");

	ImGui.SameLine();
	if (__gm3d_ed_imgui_tool_btn("Snap to increments (on/off)", "Snap", _ed.snap_on)) {
		_ed.snap_on = !_ed.snap_on;
	}
	ImGui.SameLine();
	__gm3d_ed_imgui_snap_combo(_ed);
	ImGui.SameLine();
	ImGui.TextDisabled("|");

	ImGui.SameLine();
	if (__gm3d_ed_imgui_tool_btn("Show grid (on/off)", "Grid", _ed.show_grid)) {
		_ed.show_grid = !_ed.show_grid;
	}
	ImGui.SameLine();
	__gm3d_ed_imgui_grid_combo(_ed);
	ImGui.SameLine();
	ImGui.TextDisabled("|");
	ImGui.SameLine();
	if (__gm3d_ed_imgui_tool_btn("Preview shadows (on/off)", "Shadows", _ed.show_shadows != false)) {
		_ed.show_shadows = (_ed.show_shadows == false);
		__gm3d_ed_shadowpreview_apply(_ed);
	}
	ImGui.SameLine();
	if (__gm3d_ed_imgui_tool_btn("Reset camera to the initial view", "Home", false)) {
		__gm3d_ed_cam_home(_ed, true);
	}
	ImGui.End();
}

// Edits movement and rotation snap increments.
function __gm3d_ed_imgui_snap_combo(_ed) {
	if (!__gm3d_ed_imgui_has_widget(_ed, "BeginCombo")) {
		_ed.snap_pos = max(0.01, __gm3d_ed_imgui_dragfloat("##snappos_fb", _ed.snap_pos, 0.005));
		return;
	}
	ImGui.SetNextItemWidth(62);
	var _prev = string(_ed.snap_pos);
	var _open = false;
	try {
		_open = ImGui.BeginCombo("##snapcombo", _prev);
	} catch (_e) {
		_ed.imgui.widget_probe[$ "BeginCombo"] = false;
		_ed.snap_pos = max(0.01, __gm3d_ed_imgui_dragfloat("##snappos_fb", _ed.snap_pos, 0.005));
		return;
	}
	if (!_open) {
		if (ImGui.IsItemHovered()) {
			ImGui.SetTooltip("Snap increments (move / rotate deg)");
		}
		return;
	}
	var _presets = [0.1, 0.25, 0.5, 1, 2];
	for (var _i = 0; _i < array_length(_presets); _i++) {
		var _p = _presets[_i];
		var _sel = abs(_ed.snap_pos - _p) < 0.0001;
		if (ImGui.Selectable(string(_p), _sel)) {
			_ed.snap_pos = _p;
		}
		if (_sel) {
			try {
				ImGui.SetItemDefaultFocus();
			} catch (_e2) {
			}
		}
	}
	ImGui.Separator();
	ImGui.TextDisabled("Move step");
	ImGui.SetNextItemWidth(120);
	_ed.snap_pos = max(0.01, __gm3d_ed_imgui_dragfloat("##snappos_custom", _ed.snap_pos, 0.005));
	ImGui.TextDisabled("Rotate step (deg)");
	ImGui.SetNextItemWidth(120);
	_ed.snap_rot = max(0.5, __gm3d_ed_imgui_dragfloat("##snaprot_custom", _ed.snap_rot, 0.1));
	try {
		ImGui.EndCombo();
	} catch (_e3) {
	}
}

// Edits grid cell size via presets.
function __gm3d_ed_imgui_grid_combo(_ed) {
	if (!variable_struct_exists(_ed, "grid_step") || !is_real(_ed.grid_step)) {
		_ed.grid_step = 1;
	}
	if (!__gm3d_ed_imgui_has_widget(_ed, "BeginCombo")) {
		var _fb = __gm3d_ed_imgui_dragfloat("##gridstep_fb", _ed.grid_step, 0.01);
		__gm3d_ed_grid_set_step(_ed, clamp(_fb, 0.1, 8));
		return;
	}
	ImGui.SetNextItemWidth(62);
	var _prev = string(_ed.grid_step) + "m";
	var _open = false;
	try {
		_open = ImGui.BeginCombo("##gridcombo", _prev);
	} catch (_e) {
		_ed.imgui.widget_probe[$ "BeginCombo"] = false;
		var _fb2 = __gm3d_ed_imgui_dragfloat("##gridstep_fb", _ed.grid_step, 0.01);
		__gm3d_ed_grid_set_step(_ed, clamp(_fb2, 0.1, 8));
		return;
	}
	if (!_open) {
		if (ImGui.IsItemHovered()) {
			ImGui.SetTooltip("Grid cell size (world units)");
		}
		return;
	}
	var _presets = [0.25, 0.5, 1, 2, 4];
	for (var _i = 0; _i < array_length(_presets); _i++) {
		var _p = _presets[_i];
		var _lbl = string(_p) + "m";
		var _sel = abs(_ed.grid_step - _p) < 0.0001;
		if (ImGui.Selectable(_lbl, _sel)) {
			__gm3d_ed_grid_set_step(_ed, _p);
		}
		if (_sel) {
			try {
				ImGui.SetItemDefaultFocus();
			} catch (_e2) {
			}
		}
	}
	ImGui.Separator();
	ImGui.TextDisabled("Cell size (m)");
	ImGui.SetNextItemWidth(120);
	var _c = __gm3d_ed_imgui_dragfloat("##gridstep_custom", _ed.grid_step, 0.01);
	__gm3d_ed_grid_set_step(_ed, clamp(_c, 0.1, 8));
	try {
		ImGui.EndCombo();
	} catch (_e3) {
	}
}

// Returns UI settings file path.
function __gm3d_ed_ui_path() {
	return working_directory + "gm3d_editor_ui.json";
}

// Saves view cube offset to file.
function __gm3d_ed_ui_save(_ed) {
	if (_ed == undefined) {
		return;
	}
	__gm3d_ed_write_text_file(__gm3d_ed_ui_path(), json_stringify({ cube_off: _ed.cube_off }));
}

// Loads view cube offset from file.
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
	if (_c[0] == 85 && _c[1] == 100) {
		__gm3d_ed_cube_home(_ed);
		return;
	}
	_ed.cube_off = [clamp(_c[0], 0, 10000), clamp(_c[1], 0, 10000)];
}

// Shows unsaved changes confirmation dialog.
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
	ImGui.SetNextWindowPos(_gw * 0.5 - 170, _gh * 0.5 - 56, ImGuiCond.Always);
	ImGui.SetNextWindowSize(340, 90, ImGuiCond.Always);
	__gm3d_ed_imgui_bg_alpha(0.95);
	var _begun = false;
	var _pushed = 0;

	ImGui.PushStyleColor(ImGuiCol.TitleBg, make_colour_rgb(33, 36, 47), 1);
	_pushed++;
	ImGui.PushStyleColor(ImGuiCol.TitleBgActive, make_colour_rgb(33, 36, 47), 1);
	_pushed++;
	_begun = ImGui.Begin("Unsaved changes", _c, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoResize);
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

// Shows about dialog.
function __gm3d_ed_imgui_about(_ed) {
	var _a = _ed.about;
	if (_a == undefined) {
		return;
	}
	var _gw = max(640, _ed.gw);
	var _gh = max(400, _ed.gh);
	ImGui.SetNextWindowPos(_gw * 0.5 - 190, _gh * 0.5 - 70, ImGuiCond.Always);
	ImGui.SetNextWindowSize(380, 125, ImGuiCond.Always);
	__gm3d_ed_imgui_bg_alpha(0.95);
	var _pushed = 0;
	ImGui.PushStyleColor(ImGuiCol.TitleBg, make_colour_rgb(33, 36, 47), 1);
	_pushed++;
	ImGui.PushStyleColor(ImGuiCol.TitleBgActive, make_colour_rgb(33, 36, 47), 1);
	_pushed++;
	var _begun = ImGui.Begin("About GM3D Level Editor", _a, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoResize);
	if (!_begun) {
		__gm3d_ed_imgui_pop(_pushed);
		ImGui.End();
		return;
	}
	ImGui.Text("Designed and crafted by Emmanuel Di Iorio,");
	ImGui.Text("aka Xeryan.");
	ImGui.Text("Released under the MIT License - 2026.");
	ImGui.Text("Third-party assets belong to their owners.");
	if (ImGui.Button("OK", 0, 0)) {
		_ed.about = undefined;
	}
	ImGui.End();
	__gm3d_ed_imgui_pop(_pushed);
}

// Pops specified number of style colors.
function __gm3d_ed_imgui_pop(_n) {
	for (var _i = 0; _i < _n; _i++) {
		ImGui.PopStyleColor();
	}
}

// Computes default panel positions and sizes.
function __gm3d_ed_imgui_place(_ed) {
	var _gw = max(800, _ed.gw);
	var _gh = max(500, _ed.gh);
	var _top = 30;
	var _gap = 8;
	var _lw = 250;
	var _iw = 300;
	var _mh = clamp((_gh - _top - _gap * 2) * 0.32, 150, 240);
	var _ih = max(280, _gh - _mh - _top - _gap - 8);
	var _mx = _lw + _gap * 2;
	return {
		scn: { x: 8, y: _top, w: _lw, h: max(200, _gh - _top - 8) },
		insp: { x: _gw - _iw - 8, y: _top, w: _iw, h: _ih },
		assets: { x: _mx, y: _gh - _mh - 8, w: max(200, _gw - _mx - 8), h: _mh },
	};
}

// Applies editor ImGui theme once.
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

	__gm3d_ed_imgui_style_color(ImGuiCol.WindowBg, _bg, 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.ChildBg, _panel, 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.PopupBg, make_colour_rgb(24, 30, 48), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.Border, make_colour_rgb(38, 48, 75), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.FrameBg, make_colour_rgb(30, 38, 62), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.FrameBgHovered, make_colour_rgb(30, 40, 62), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.FrameBgActive, _accent_hi, 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.TitleBg, _panel, 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.TitleBgActive, make_colour_rgb(28, 38, 60), 1);
	__gm3d_ed_imgui_style_color(ImGuiCol.MenuBarBg, _panel, 1);
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

// Sets next window background transparency.
function __gm3d_ed_imgui_bg_alpha(_a) {
	ImGui.SetNextWindowBgAlpha(_a);
}

// Sets ImGui style color value.
function __gm3d_ed_imgui_style_color(_col, _rgb, _alpha) {
	ImGui.SetStyleColor(_col, _rgb, _alpha);
	return true;
}

// Draws main menu bar with actions.
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
	__gm3d_ed_imgui_bg_alpha(0.95);
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
	if (ImGui.BeginMenu("Create")) {
		if (ImGui.MenuItem("Directional Light")) {
			__gm3d_ed_create_light(_ed, "directional");
		}
		if (ImGui.MenuItem("Point Light")) {
			__gm3d_ed_create_light(_ed, "point");
		}

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
			__gm3d_ed_cube_home(_ed);
			_ui.win_cube.open = true;
			__gm3d_ed_ui_save(_ed);
		}
		ImGui.EndMenu();
	}
	if (ImGui.BeginMenu("Help")) {
		if (ImGui.MenuItem("Report a Bug/Feature Request")) {
			try {
				url_open("https://github.com/manuel-di-iorio/GM3D-Level-Editor/issues");
			} catch (_eU) {
			}
		}
		if (ImGui.MenuItem("About")) {
			_ed.about = { open: true };
		}
		ImGui.EndMenu();
	}
	ImGui.EndMainMenuBar();
	_mbar = false;

	__gm3d_ed_menu_do(_ed, _do_new, _do_load, _do_saveas, _do_close);
}

// Draws Models asset browser window.
function __gm3d_ed_imgui_assets(_ed) {
	var _ui = _ed.imgui;
	if (!_ui.win_assets.open) {
		return;
	}
	var _pl = __gm3d_ed_imgui_place(_ed).assets;
	ImGui.SetNextWindowPos(_pl.x, _pl.y, _ui.cond);
	ImGui.SetNextWindowSize(_pl.w, _pl.h, _ui.cond);
	__gm3d_ed_imgui_bg_alpha(0.95);
	var _begun = false;

	if (!ImGui.Begin("Models", _ui.win_assets)) {
		ImGui.End();
		return;
	}
	_begun = true;
	__gm3d_ed_imgui_asset_list(_ed);
	ImGui.End();
}

// Lists filterable draggable model assets.
function __gm3d_ed_imgui_asset_list(_ed) {
	var _ui = _ed.imgui;

	if (!variable_struct_exists(_ui, "models_view")) {
		_ui.models_view = "cards";
	}
	var _fw = 80;
	try {
		_fw = max(80, ImGui.GetContentRegionAvailX() - 108);
	} catch (_eFw) {
	}
	ImGui.SetNextItemWidth(_fw);
	_ui.filter = __gm3d_ed_imgui_text_hint("##filter", "Filter models...", _ui.filter);
	ImGui.SameLine();
	if (__gm3d_ed_imgui_small_btn(_ed, "List", _ui.models_view == "list")) {
		_ui.models_view = "list";
	}
	ImGui.SameLine();
	if (__gm3d_ed_imgui_small_btn(_ed, "Cards", _ui.models_view == "cards")) {
		_ui.models_view = "cards";
	}
	ImGui.Separator();
	var _flt = string_lower(_ui.filter);
	if (_ui.models_view == "cards") {
		__gm3d_ed_imgui_asset_cards(_ed, _flt);
		return;
	}
	for (var _i = 0; _i < array_length(_ed.assets); _i++) {
		var _a = _ed.assets[_i];
		if (_flt != "" && string_pos(_flt, string_lower(_a.name)) <= 0) {
			continue;
		}
		ImGui.PushID(_i);
		ImGui.Selectable(_a.name, false);
		if (_ed.drag_lib == undefined && ImGui.IsItemHovered()) {
			ImGui.SetTooltip(_a.name);
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

// Draws small button with active highlight.
function __gm3d_ed_imgui_small_btn(_ed, _label, _active) {
	var _pushed = 0;
	if (_active) {
		ImGui.PushStyleColor(ImGuiCol.Button, make_colour_rgb(47, 111, 237), 1);
		_pushed++;
	}
	var _hit = ImGui.Button(_label, 46, 0);
	__gm3d_ed_imgui_pop(_pushed);
	return _hit;
}

// Draws assets in grid card layout.
function __gm3d_ed_imgui_asset_cards(_ed, _flt) {
	var _cs = 60;
	var _gap = 12;
	var _avail = 200;
	try {
		_avail = ImGui.GetContentRegionAvailX();
	} catch (_e) {
	}
	var _cols = max(1, floor((_avail + _gap) / (_cs + _gap)));
	var _shown = 0;
	for (var _i = 0; _i < array_length(_ed.assets); _i++) {
		var _a = _ed.assets[_i];
		if (_flt != "" && string_pos(_flt, string_lower(_a.name)) <= 0) {
			continue;
		}
		if (_shown > 0 && _shown mod _cols != 0) {
			ImGui.SameLine(0, _gap);
		}
		__gm3d_ed_imgui_asset_card(_ed, _a, _i, _cs);
		_shown++;
	}
}

// Truncates text to fit pixel width.
function __gm3d_ed_imgui_trunc_text(_text, _maxw) {
	static _cache = {};
	var _ck = _text + "|" + string(_maxw);
	if (variable_struct_exists(_cache, _ck)) {
		return _cache[$ _ck];
	}
	var _out = _text;
	if (_maxw > 8 && string_length(_text) > 3) {
		var _full = -1;
		try {
			_full = ImGui.CalcTextWidth(_text);
		} catch (_e) {
		}
		if (_full > _maxw) {
			_out = "..";
			var _n = string_length(_text) - 1;
			while (_n > 1) {
				var _t = string_copy(_text, 1, _n) + "..";
				var _w = _maxw + 1;
				try {
					_w = ImGui.CalcTextWidth(_t);
				} catch (_e2) {
					_out = _text;
					break;
				}
				if (_w <= _maxw) {
					_out = _t;
					break;
				}
				_n--;
			}
		}
	}
	_cache[$ _ck] = _out;
	return _out;
}

// Draws draggable asset thumbnail card.
function __gm3d_ed_imgui_asset_card(_ed, _a, _i, _cs) {
	var _th = 16;
	var _pad = 4;
	var _qy = _pad;
	var _sx = undefined;
	var _sy = undefined;
	var _dl = undefined;
	try {
		_sx = ImGui.GetCursorScreenPosX();
		_sy = ImGui.GetCursorScreenPosY();
		_dl = ImGui.GetWindowDrawList();
	} catch (_e0) {
	}
	ImGui.PushID(_i);
	var _okbtn = __gm3d_ed_imgui_has_widget(_ed, "InvisibleButton");
	if (_okbtn) {
		try {
			ImGui.InvisibleButton("##card", _cs, _pad + _cs + _th + _pad);
		} catch (_e1) {
			_ed.imgui.widget_probe[$ "InvisibleButton"] = false;
			ImGui.Dummy(_cs, _pad + _cs + _th + _pad);
		}
	} else {
		ImGui.Dummy(_cs, _pad + _cs + _th + _pad);
	}
	var _hov = ImGui.IsItemHovered();
	if (_sx != undefined && _dl != undefined) {
		try {
			var _qx = _sx;
			var _qy0 = _sy + _qy;
			var _thumb = -1;
			if (variable_struct_exists(_a, "thumb") && sprite_exists(_a.thumb)) {
				_thumb = _a.thumb;
			}
			if (_thumb != -1) {
				ImGui.DrawListAddImage(_dl, _thumb, 0, _qx, _qy0, _qx + _cs, _qy0 + _cs, c_white);
			} else {
				var _fill = _hov ? make_colour_rgb(84, 96, 120) : make_colour_rgb(70, 80, 100);
				ImGui.DrawListAddRectFilled(_dl, _qx, _qy0, _qx + _cs, _qy0 + _cs, _fill);
			}
			var _edge = _hov ? make_colour_rgb(120, 140, 175) : make_colour_rgb(50, 58, 76);
			ImGui.DrawListAddRect(_dl, _qx, _qy0, _qx + _cs, _qy0 + _cs, _edge);
			ImGui.DrawListAddText(_dl, _qx + 4, _qy0 + _cs + 1, __gm3d_ed_imgui_trunc_text(_a.name, _cs - 6), c_white);
		} catch (_e2) {
		}
	}
	if (_ed.drag_lib == undefined && _hov) {
		ImGui.SetTooltip(_a.name);
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

// Checks whether ImGui extension is available.
function __gm3d_ed_imgui_check(_ed) {
	if (_ed.imgui_ok != undefined) {
		return _ed.imgui_ok;
	}

	var _v = ImGui.GetVersion();
	_ed.imgui_ok = _v != undefined && _v != "";

	return _ed.imgui_ok;
}

// Executes pending menu bar actions.
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

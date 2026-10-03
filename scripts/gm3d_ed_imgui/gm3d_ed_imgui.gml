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
		_has = variable_struct_exists(ImGui, "DragFloat");
	}
	if (!_has) {
		return ImGui.InputFloat(_label, _val, 0, 0);
	}
	var _out = _val;
	_out = ImGui.DragFloat(_label, _val, _speed, 0, 0);
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
	var _dock_id = ImGui.GetID("GM3DEditorDockspace");
	var _dock_root = ImGui.DockSpaceOverViewport(_dock_id, 0, ImGuiDockNodeFlags.PassthruCentralNode);
	__gm3d_ed_imgui_dock_build(_ed, _dock_root);

	if (!variable_struct_exists(_ed.imgui, "_pw")) {
		_ed.imgui._pw = 0;
		_ed.imgui._ph = 0;
	}
	var _rsz = _ed.imgui._pw != _ed.gw || _ed.imgui._ph != _ed.gh;
	_ed.imgui._pw = _ed.gw;
	_ed.imgui._ph = _ed.gh;
	var _modal_ui = false;
	_modal_ui = _ed.confirm != undefined || _ed.about != undefined || _ed.scene_dlg != undefined;
	if (_modal_ui) {
		if (_ed.confirm != undefined) {
			__gm3d_ed_imgui_confirm(_ed);
		}
		if (_ed.about != undefined) {
			__gm3d_ed_imgui_about(_ed);
		}
		if (_ed.scene_dlg != undefined) {
			__gm3d_ed_imgui_scene_dlg(_ed);
		}
		_ed.imgui.dock_pos_skip = false;
		return;
	}
	var _rst = _ed.imgui.reset_layout == true;
	var _dockable = __gm3d_ed_imgui_dock_ok(_ed);
	if (_rst) {
		_ed.imgui.dock_rebuild = true;
		_ed.imgui.dock_tries = 0;
		__gm3d_ed_cube_home(_ed);
		if (!_dockable) {
			_ed.imgui.cond = ImGuiCond.Always;
		}
	} else if (_rsz) {
		__gm3d_ed_cube_home(_ed);
	}
	__gm3d_ed_imgui_menu(_ed);
	__gm3d_ed_imgui_toolbar(_ed);
	__gm3d_ed_imgui_assets(_ed);
	__gm3d_ed_imgui_scene_win(_ed);
	__gm3d_ed_imgui_inspector(_ed);
	__gm3d_ed_imgui_confirm(_ed);
	__gm3d_ed_imgui_about(_ed);
	__gm3d_ed_imgui_scene_dlg(_ed);
	if (_rst || _rsz) {
		_ed.imgui.cond = ImGuiCond.FirstUseEver;
		_ed.imgui.reset_layout = false;
	}
	_ed.imgui.dock_pos_skip = false;
}

// Draws toolbar button with tooltip and highlight.
function __gm3d_ed_imgui_tool_btn(_tip, _label, _active, _h = 0) {
	var _pushed = 0;
	if (_active) {
		ImGui.PushStyleColor(ImGuiCol.Button, make_colour_rgb(47, 111, 237), 1);
		_pushed++;
	}
	var _hit = ImGui.Button(_label, 0, _h);
	__gm3d_ed_imgui_pop(_pushed);
	if (ImGui.IsItemHovered()) {
		ImGui.SetTooltip(_tip);
	}
	return _hit;
}

// Draws small icon button with tooltip and highlight.
function __gm3d_ed_imgui_icon_btn(_ed, _id, _tip, _active, _fb, _spr, _w = -1, _h = -1) {
	static _cache = {};
	if (!variable_struct_exists(_cache, _spr)) {
		_cache[$ _spr] = asset_get_index(_spr);
	}
	var _sp = _cache[$ _spr];
	if (_sp == -1 || _sp == undefined) {
		_sp = asset_get_index("sprGM3DIconObject");
	}
	var _hit = false;
	if (_sp != -1 && _sp != undefined && __gm3d_ed_imgui_has_widget(_ed, "ImageButton")) {
		var _iw = _w;
		var _ih = _h;
		if (_iw < 0) {
			_iw = sprite_get_width(_sp);
		}
		if (_ih < 0) {
			_ih = sprite_get_height(_sp);
		}
		if (_active) {
			ImGui.PushStyleColor(ImGuiCol.Button, make_colour_rgb(47, 111, 237), 1);
		} else {
			ImGui.PushStyleColor(ImGuiCol.Button, c_black, 0);
		}
		ImGui.PushStyleColor(ImGuiCol.ButtonHovered, make_colour_rgb(47, 111, 237), 0.35);
		ImGui.PushStyleColor(ImGuiCol.ButtonActive, make_colour_rgb(47, 111, 237), 0.5);
		_hit = ImGui.ImageButton(_id, _sp, 0, c_white, 1, c_black, 0, _iw, _ih);
		__gm3d_ed_imgui_pop(3);
	} else if (__gm3d_ed_imgui_has_widget(_ed, "SmallButton")) {
		_hit = ImGui.SmallButton(_fb);
	} else {
		_hit = ImGui.Button(_fb);
	}
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
	var _flags = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoResize | ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoMove;
	if (!ImGui.Begin("##toolbar", _ed.imgui.win_toolbar, _flags)) {
		ImGui.End();
		return;
	}
	if (__gm3d_ed_imgui_icon_btn(_ed, "##tb_view", "View (V)", _ed.giz.tool == Gm3dEdTool.View, "V", "sprGM3DIconHand", 12, 16)) {
		_ed.giz.tool = Gm3dEdTool.View;
	}
	ImGui.SameLine();
	if (__gm3d_ed_imgui_icon_btn(_ed, "##tb_move", "Move (1)", _ed.giz.tool == Gm3dEdTool.Translate, "M", "sprGM3DIconMove", 15, 15)) {
		_ed.giz.tool = Gm3dEdTool.Translate;
	}
	ImGui.SameLine();
	if (__gm3d_ed_imgui_icon_btn(_ed, "##tb_rotate", "Rotate (2)", _ed.giz.tool == Gm3dEdTool.Rotate, "R", "sprGM3DIconRotate", 15, 15)) {
		_ed.giz.tool = Gm3dEdTool.Rotate;
	}
	ImGui.SameLine();
	if (__gm3d_ed_imgui_icon_btn(_ed, "##tb_scale", "Scale (3)", _ed.giz.tool == Gm3dEdTool.Scale, "S", "sprGM3DIconScale", 15, 15)) {
		_ed.giz.tool = Gm3dEdTool.Scale;
	}
	ImGui.SameLine();
	ImGui.TextDisabled("|");

	ImGui.SameLine();
	var _olbl = _ed.giz.orient == 1 ? "Local" : "World";
	if (__gm3d_ed_imgui_tool_btn("Gizmo axes space (" + _olbl + ", click to switch)", _olbl, false, 22)) {
		_ed.giz.orient = _ed.giz.orient == 1 ? 0 : 1;
	}
	ImGui.SameLine();
	ImGui.TextDisabled("|");

	ImGui.SameLine();
	if (__gm3d_ed_imgui_icon_btn(_ed, "##tb_snap", "Snap to increments (on/off)", _ed.snap_on, "Sn", "sprGM3DIconSnap", 15, 15)) {
		_ed.snap_on = !_ed.snap_on;
	}
	ImGui.SameLine();
	if (__gm3d_ed_imgui_icon_btn(_ed, "##tb_grid", "Show grid (on/off)", _ed.show_grid, "Gr", "sprGM3DIconGrid", 15, 15)) {
		_ed.show_grid = !_ed.show_grid;
	}
	ImGui.SameLine();
	__gm3d_ed_imgui_grid_snap(_ed);
	ImGui.SameLine();
	ImGui.TextDisabled("|");
	ImGui.SameLine();
	if (__gm3d_ed_imgui_icon_btn(_ed, "##tb_unlit", "Unlit Draw Mode", _ed.show_unlit == true, "Un", "sprGM3DIconUnlit", 15, 15)) {
		_ed.show_unlit = true;
		_ed.show_shadows = false;
		__gm3d_ed_unlit_apply(_ed);
		__gm3d_ed_shadowpreview_apply(_ed);
	}
	ImGui.SameLine();
	if (__gm3d_ed_imgui_icon_btn(_ed, "##tb_shaded", "Shaded Draw Mode", _ed.show_unlit != true, "Sh", "sprGM3DIconShaded", 15, 15)) {
		_ed.show_unlit = false;
		_ed.show_shadows = true;
		__gm3d_ed_unlit_apply(_ed);
		__gm3d_ed_shadowpreview_apply(_ed);
	}
	ImGui.SameLine();
	ImGui.TextDisabled("|");
	ImGui.SameLine();
	if (__gm3d_ed_imgui_icon_btn(_ed, "##tb_home", "Reset camera to the initial view", false, "Hm", "sprGM3DIconCenter", 15, 15)) {
		__gm3d_ed_cam_home(_ed, true);
	}
	ImGui.End();
}

// Edits grid size and snap increments in one place.
function __gm3d_ed_imgui_grid_snap(_ed) {
	if (!variable_struct_exists(_ed, "grid_step") || !is_real(_ed.grid_step)) {
		_ed.grid_step = 1;
	}
	if (!variable_struct_exists(_ed, "snap_to_grid")) {
		_ed.snap_to_grid = true;
	}
	if (!variable_struct_exists(_ed, "snap_pos") || !is_real(_ed.snap_pos)) {
		_ed.snap_pos = 0.5;
	}
	if (!__gm3d_ed_imgui_has_widget(_ed, "BeginCombo")) {
		var _fb = __gm3d_ed_imgui_dragfloat("##gridsnap_fb", _ed.grid_step, 0.01);
		__gm3d_ed_grid_set_step(_ed, clamp(_fb, 0.1, 8));
		return;
	}
	ImGui.SetNextItemWidth(62);
	var _prev = string(_ed.grid_step) + "m";
	var _open = false;
	_open = ImGui.BeginCombo("##gridsnap", _prev);
	if (!_open) {
		if (ImGui.IsItemHovered()) {
			ImGui.SetTooltip("Grid and Snap");
		}
		return;
	}
	_ed.snap_to_grid = ImGui.Checkbox("Snap to Grid", _ed.snap_to_grid == true);
	ImGui.Separator();
	ImGui.TextDisabled("Grid size (m)");
	var _presets = [0.25, 0.5, 1, 2, 4];
	for (var _i = 0; _i < array_length(_presets); _i++) {
		var _p = _presets[_i];
		var _lbl = string(_p) + "m";
		var _sel = abs(_ed.grid_step - _p) < 0.0001;
		if (ImGui.Selectable(_lbl, _sel)) {
			__gm3d_ed_grid_set_step(_ed, _p);
		}
		if (_sel) {
			ImGui.SetItemDefaultFocus();
		}
	}
	ImGui.Separator();
	ImGui.TextDisabled("Cell size (m)");
	ImGui.SetNextItemWidth(120);
	var _c = __gm3d_ed_imgui_dragfloat("##gridsnap_custom", _ed.grid_step, 0.01);
	__gm3d_ed_grid_set_step(_ed, clamp(_c, 0.1, 8));
	if (_ed.snap_to_grid != true) {
		ImGui.Separator();
		ImGui.TextDisabled("Move step");
		var _mpres = [0.1, 0.25, 0.5, 1, 2];
		for (var _j = 0; _j < array_length(_mpres); _j++) {
			var _mp = _mpres[_j];
			var _msel = abs(_ed.snap_pos - _mp) < 0.0001;
			if (ImGui.Selectable(string(_mp), _msel)) {
				_ed.snap_pos = _mp;
			}
			if (_msel) {
				ImGui.SetItemDefaultFocus();
			}
		}
		ImGui.SetNextItemWidth(120);
		_ed.snap_pos = max(0.01, __gm3d_ed_imgui_dragfloat("##gridsnap_move", _ed.snap_pos, 0.005));
	}
	ImGui.Separator();
	ImGui.TextDisabled("Rotate step (deg)");
	ImGui.SetNextItemWidth(120);
	_ed.snap_rot = max(0.5, __gm3d_ed_imgui_dragfloat("##gridsnap_rot", _ed.snap_rot, 0.1));
	ImGui.EndCombo();
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
	__gm3d_ed_write_text_file(__gm3d_ed_ui_path(), json_stringify({ cube_off: _ed.cube_off }, true));
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
	__gm3d_ed_imgui_bg_alpha(1);
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
		if (__gm3d_ed_save_or_ask(_ed, _c.action)) {
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
	if (_a.open == false) {
		_ed.about = undefined;
		return;
	}
	var _gw = max(640, _ed.gw);
	var _gh = max(400, _ed.gh);
	ImGui.SetNextWindowPos(_gw * 0.5 - 190, _gh * 0.5 - 60, ImGuiCond.Always);
	ImGui.SetNextWindowSize(380, 110, ImGuiCond.Always);
	__gm3d_ed_imgui_bg_alpha(1);
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
	ImGui.Text("Developed by Emmanuel Di Iorio aka Xeryan.");
	ImGui.Text("Released under the MIT License - 2026.");
	ImGui.Text("Third-party assets belong to their owners.");
	if (ImGui.Button("OK", 0, 0)) {
		_ed.about = undefined;
	}
	ImGui.End();
	__gm3d_ed_imgui_pop(_pushed);
}

// Shows save/load scene dialog (name only, fixed folder).
function __gm3d_ed_imgui_scene_dlg(_ed) {
	var _dlg = _ed.scene_dlg;
	if (_dlg == undefined) {
		return;
	}
	if (_dlg.open == false) {
		_ed.scene_dlg = undefined;
		return;
	}
	var _is_save = _dlg.mode != "load";
	var _gw = max(640, _ed.gw);
	var _gh = max(400, _ed.gh);
	var _ww = 400;
	var _wh = _is_save ? 120 : 250;
	ImGui.SetNextWindowPos(_gw * 0.5 - _ww * 0.5, _gh * 0.5 - _wh * 0.5, ImGuiCond.Always);
	ImGui.SetNextWindowSize(_ww, _wh, ImGuiCond.Always);
	__gm3d_ed_imgui_bg_alpha(1);
	var _pushed = 0;
	ImGui.PushStyleColor(ImGuiCol.TitleBg, make_colour_rgb(33, 36, 47), 1);
	_pushed++;
	ImGui.PushStyleColor(ImGuiCol.TitleBgActive, make_colour_rgb(33, 36, 47), 1);
	_pushed++;
	var _begun = ImGui.Begin(_is_save ? "Save scene" : "Load scene", _dlg, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoResize);
	if (!_begun) {
		__gm3d_ed_imgui_pop(_pushed);
		ImGui.End();
		return;
	}
	ImGui.Text("Scene name:");
	if (!variable_struct_exists(_dlg, "buf") || !is_string(_dlg.buf)) {
		_dlg.buf = __gm3d_ed_imgui_pad(_dlg.name);
	}
	var _out = ImGui.InputText("##scene_dlg_name", _dlg.buf, ImGuiInputTextFlags.AutoSelectAll);
	if (is_string(_out)) {
		_dlg.buf = _out;
		_dlg.name = string_trim(_out);
	}
	if (_dlg.error != "" && _dlg.name != _dlg.err_name) {
		_dlg.error = "";
		_dlg.err_name = "";
	}
	var _shown = 0;
	if (!_is_save) {
		ImGui.Separator();
		ImGui.TextDisabled("Existing:");
		for (var _i = 0; _i < array_length(_dlg.list); _i++) {
			if (_shown >= 3) {
				break;
			}
			var _n = _dlg.list[_i];
			if (ImGui.Selectable(_n, _dlg.name == _n)) {
				_dlg.name = _n;
				_dlg.buf = __gm3d_ed_imgui_pad(_n);
			}
			if (ImGui.IsMouseDoubleClicked(0) && ImGui.IsItemHovered()) {
				__gm3d_ed_scene_dlg_do_load(_ed);
			}
			_shown++;
		}
	}
	if (_dlg.error != "") {
		ImGui.Text("Error: " + _dlg.error);
	} else if (_is_save && __gm3d_ed_scene_dlg_exists(_ed, _dlg.name)) {
		ImGui.TextDisabled("Exists - saving will overwrite.");
	} else if (!_is_save && array_length(_dlg.list) == 0) {
		ImGui.TextDisabled("No saved scenes yet.");
	} else if (!_is_save && array_length(_dlg.list) > _shown) {
		ImGui.TextDisabled("... +" + string(array_length(_dlg.list) - _shown) + " more (type the name)");
	} else {
		ImGui.Text("");
	}
	if (ImGui.Button(_is_save ? "Save" : "Load", 0, 0)) {
		if (_is_save) {
			__gm3d_ed_scene_dlg_do_save(_ed);
		} else {
			__gm3d_ed_scene_dlg_do_load(_ed);
		}
	}
	ImGui.SameLine();
	if (ImGui.Button("Cancel", 0, 0)) {
		_ed.scene_dlg = undefined;
	}
	if (_ed.scene_dlg != undefined && keyboard_check_pressed(vk_enter)) {
		if (_is_save) {
			__gm3d_ed_scene_dlg_do_save(_ed);
		} else {
			__gm3d_ed_scene_dlg_do_load(_ed);
		}
	}
	ImGui.End();
	__gm3d_ed_imgui_pop(_pushed);
}

// Checks if sanitized name matches a listed scene.
function __gm3d_ed_scene_dlg_exists(_ed, _name) {
	var _clean = string_lower(__gm3d_ed_sanitize_scene_name(_name));
	if (_clean == "") {
		return false;
	}
	var _list = _ed.scene_dlg.list;
	for (var _i = 0; _i < array_length(_list); _i++) {
		if (string_lower(_list[_i]) == _clean) {
			return true;
		}
	}
	return false;
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

// Checks DockBuilder API availability once per session.
function __gm3d_ed_imgui_dock_ok(_ed) {
	if (_ed.imgui == undefined) {
		return false;
	}
	if (variable_struct_exists(_ed.imgui, "dock_ok")) {
		return _ed.imgui.dock_ok == true;
	}
	var _ok = variable_struct_exists(ImGui, "GetID")
		&& variable_struct_exists(ImGui, "DockBuilderRemoveNode")
		&& variable_struct_exists(ImGui, "DockBuilderAddNode")
		&& variable_struct_exists(ImGui, "DockBuilderSplitNode")
		&& variable_struct_exists(ImGui, "DockBuilderDockWindow")
		&& variable_struct_exists(ImGui, "DockBuilderFinish")
		&& variable_struct_exists(ImGui, "DockBuilderSetNodeSize")
		&& variable_struct_exists(ImGui, "DockBuilderSetNodePos");
	_ed.imgui.dock_ok = _ok;
	return _ok;
}

// Builds initial dock layout: Scene left, Inspector right, Models bottom.
// Returns true while a fresh dock layout must win over SetNextWindowPos/Size.
function __gm3d_ed_imgui_dock_fresh(_ed) {
	if (_ed.imgui == undefined) {
		return false;
	}
	return variable_struct_exists(_ed.imgui, "dock_pos_skip") && _ed.imgui.dock_pos_skip == true;
}

// Builds initial dock layout: Scene left (full height), Inspector top-right,
// Models bottom spanning everything except Scene. Split order Left, Down,
// Right gives Models the full bottom strip; windows dock in priority order
// Inspector > Models > Scene, Scene last.
// Runs once per session and on Reset Layout. Undocked windows keep working
// floating via their SetNextWindowPos/Size fallbacks.
function __gm3d_ed_imgui_dock_build(_ed, _root) {
	if (!__gm3d_ed_imgui_dock_ok(_ed)) {
		return;
	}
	if (_root == undefined) {
		return;
	}
	if (variable_struct_exists(_ed.imgui, "dock_built") && _ed.imgui.dock_built == true
	&& !(variable_struct_exists(_ed.imgui, "dock_rebuild") && _ed.imgui.dock_rebuild == true)) {
		return;
	}
	if (!variable_struct_exists(_ed.imgui, "dock_tries")) {
		_ed.imgui.dock_tries = 0;
	}
	if (_ed.imgui.dock_tries > 5) {
		return;
	}
	_ed.imgui.dock_tries++;
	var _gw = max(800, _ed.gw);
	var _gh = max(500, _ed.gh);
	var _top = 30;
	ImGui.DockBuilderRemoveNode(_root);
	ImGui.DockBuilderAddNode(_root, ImGuiDockNodeFlags.DockSpace);
	ImGui.DockBuilderSetNodePos(_root, 0, _top);
	ImGui.DockBuilderSetNodeSize(_root, _gw, max(200, _gh - _top));
	var _s1 = ImGui.DockBuilderSplitNode(_root, ImGuiDir.Left, 0.19);
	if (!is_array(_s1) || array_length(_s1) < 2) {
		return;
	}
	var _left = _s1[0];
	var _r1 = array_length(_s1) > 2 ? _s1[2] : _s1[array_length(_s1) - 1];
	var _s2 = ImGui.DockBuilderSplitNode(_r1, ImGuiDir.Down, 0.32);
	if (!is_array(_s2) || array_length(_s2) < 2) {
		return;
	}
	var _bottom = _s2[0];
	var _r2 = array_length(_s2) > 2 ? _s2[2] : _s2[array_length(_s2) - 1];
	var _s3 = ImGui.DockBuilderSplitNode(_r2, ImGuiDir.Right, 0.26);
	if (!is_array(_s3) || array_length(_s3) < 1) {
		return;
	}
	var _right = _s3[0];
	ImGui.DockBuilderDockWindow("Inspector", _right);
	ImGui.DockBuilderDockWindow("Models", _bottom);
	ImGui.DockBuilderDockWindow("Scene", _left);
	ImGui.DockBuilderFinish(_root);
	_ed.imgui.dock_built = true;
	_ed.imgui.dock_rebuild = false;
	_ed.imgui.dock_pos_skip = true;
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

// Returns NoMove when mouse is over panel body, None on titlebar/outside.
// Latches flags while left button is held to avoid toggling mid-drag.
function __gm3d_ed_imgui_panel_flags(_ed, _key) {
	var _none = ImGuiWindowFlags.None;
	var _nomove = ImGuiWindowFlags.NoMove;
	if (_ed.imgui == undefined) {
		return _none;
	}
	if (!variable_struct_exists(_ed.imgui, "_winrect")) {
		_ed.imgui._winrect = {};
	}
	if (!variable_struct_exists(_ed.imgui, "_winflags")) {
		_ed.imgui._winflags = {};
	}
	if (!variable_struct_exists(ImGui, "IsMouseDown") || !variable_struct_exists(ImGui, "GetMousePosX") || !variable_struct_exists(ImGui, "GetMousePosY")) {
		return _none;
	}
	var _down = ImGui.IsMouseDown(0);
	if (_down) {
		var _latched = _ed.imgui._winflags[$ _key];
		return is_real(_latched) ? _latched : _none;
	}
	var _r = _ed.imgui._winrect[$ _key];
	var _flags = _none;
	if (is_struct(_r)) {
		var _mx = ImGui.GetMousePosX();
		var _my = ImGui.GetMousePosY();
		if (is_real(_mx) && is_real(_my) && is_real(_r.x) && is_real(_r.y) && is_real(_r.w) && is_real(_r.h)) {
			if (_mx >= _r.x && _mx <= _r.x + _r.w && _my >= _r.y && _my <= _r.y + _r.h) {
				var _th = is_real(_r.t) && _r.t > 0 ? _r.t : 19;
				if (_my > _r.y + _th) {
					_flags = _nomove;
				}
			}
		}
	}
	_ed.imgui._winflags[$ _key] = _flags;
	return _flags;
}

// Caches current window rect for panel move detection. Call inside Begin/End.
function __gm3d_ed_imgui_panel_save(_ed, _key) {
	if (_ed.imgui == undefined) {
		return;
	}
	if (!variable_struct_exists(ImGui, "GetWindowX") || !variable_struct_exists(ImGui, "GetWindowY") || !variable_struct_exists(ImGui, "GetWindowWidth") || !variable_struct_exists(ImGui, "GetWindowHeight")) {
		return;
	}
	var _x = ImGui.GetWindowX();
	var _y = ImGui.GetWindowY();
	var _w = ImGui.GetWindowWidth();
	var _h = ImGui.GetWindowHeight();
	if (!is_real(_x) || !is_real(_y) || !is_real(_w) || !is_real(_h)) {
		return;
	}
	var _t = 19;
	if (variable_struct_exists(ImGui, "GetFrameHeight")) {
		var _fh = ImGui.GetFrameHeight();
		if (is_real(_fh) && _fh > 0) {
			_t = _fh;
		}
	}
	if (!variable_struct_exists(_ed.imgui, "_winrect")) {
		_ed.imgui._winrect = {};
	}
	_ed.imgui._winrect[$ _key] = { x: _x, y: _y, w: _w, h: _h, t: _t };
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
			url_open("https://github.com/manuel-di-iorio/GM3D-Level-Editor/issues");
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
	if (!__gm3d_ed_imgui_dock_fresh(_ed)) {
		ImGui.SetNextWindowPos(_pl.x, _pl.y, _ui.cond);
		ImGui.SetNextWindowSize(_pl.w, _pl.h, _ui.cond);
	}
	__gm3d_ed_imgui_bg_alpha(1);
	var _begun = false;

	var _pflags = __gm3d_ed_imgui_panel_flags(_ed, "assets");
	if (!ImGui.Begin("Models", _ui.win_assets, _pflags)) {
		__gm3d_ed_imgui_panel_save(_ed, "assets");
		ImGui.End();
		return;
	}
	__gm3d_ed_imgui_panel_save(_ed, "assets");
	_begun = true;
	__gm3d_ed_imgui_asset_list(_ed);
	ImGui.End();
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

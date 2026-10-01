// Draws Scene hierarchy window.
function __gm3d_ed_imgui_scene_win(_ed) {
	var _ui = _ed.imgui;
	if (!_ui.win_scene.open) {
		return;
	}
	var _ps = __gm3d_ed_imgui_place(_ed).scn;
	ImGui.SetNextWindowPos(_ps.x, _ps.y, _ui.cond);
	ImGui.SetNextWindowSize(_ps.w, _ps.h, _ui.cond);
	__gm3d_ed_imgui_bg_alpha(0.95);
	var _begun = false;

	if (!ImGui.Begin("Scene", _ui.win_scene)) {
		ImGui.End();
		return;
	}
	_begun = true;
	__gm3d_ed_imgui_scene_list(_ed);
	ImGui.End();
}

// Draws visibility toggle eye button.
function __gm3d_ed_imgui_eye(_ed, _hidden, _ghost) {
	static _eye_open = -2;
	static _eye_shut = -2;
	if (_eye_open == -2) {
		try {
			_eye_open = asset_get_index("sprGM3DIconEye");
		} catch (_e) {
			_eye_open = -1;
		}
	}
	if (_eye_shut == -2) {
		try {
			_eye_shut = asset_get_index("sprGM3DIconEyeClosed");
		} catch (_e0) {
			_eye_shut = -1;
		}
	}
	var _eye_spr = _hidden ? _eye_shut : _eye_open;
	var _tint = c_white;
	if (_eye_spr == -1 && _hidden) {
		_eye_spr = _eye_open;
		_tint = make_colour_rgb(105, 115, 135);
	}
	var _hit = false;
	if (_eye_spr != -1) {

		ImGui.PushStyleColor(ImGuiCol.Button, c_black, 0);
		ImGui.PushStyleColor(ImGuiCol.ButtonHovered, make_colour_rgb(47, 111, 237), 0.35);
		ImGui.PushStyleColor(ImGuiCol.ButtonActive, make_colour_rgb(47, 111, 237), 0.5);
		var _ew = 15;
		var _eh = 11;
		try {
			_ew = sprite_get_width(_eye_spr);
			_eh = sprite_get_height(_eye_spr);
		} catch (_e1) {
		}
		try {

			_hit = ImGui.ImageButton("eye", _eye_spr, 0, _tint, _ghost ? 0 : 1, c_black, 0, _ew, _eh);
		} catch (_e2) {
			if (_hidden) {
				_eye_shut = -1;
			} else {
				_eye_open = -1;
			}
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

// Starts in-place node rename mode.
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

// Cancels active node rename.
function __gm3d_ed_rename_cancel(_ed) {
	_ed.rename_name = undefined;
	_ed.rename_pos = undefined;
}

// Checks node matches rename target position.
function __gm3d_ed_rename_at(_ed, _node) {
	var _rp = _ed.rename_pos;
	var _pp = _node.getLocalPosition();
	return _pp.x == _rp[0] && _pp.y == _rp[1] && _pp.z == _rp[2];
}

// Draws icon image with vertical offset.
function __gm3d_ed_imgui_icon_shifted(_spr, _tint, _iw, _ih, _dy) {
	var _sx = undefined;
	var _sy = undefined;
	var _dl = undefined;
	try {
		_sx = ImGui.GetCursorScreenPosX();
		_sy = ImGui.GetCursorScreenPosY();
		_dl = ImGui.GetWindowDrawList();
	} catch (_e) {
	}
	ImGui.Dummy(_iw, _ih);
	if (_sx == undefined || _sy == undefined || _dl == undefined) {
		return false;
	}
	try {
		ImGui.DrawListAddImage(_dl, _spr, 0, _sx, _sy + _dy, _sx + _iw, _sy + _dy + _ih, _tint);
	} catch (_e2) {
		return false;
	}
	return true;
}

// Draws node type icon with tooltip.
function __gm3d_ed_imgui_kind_icon(_ed, _nd, _nk, _ishid, _i) {
	var _sn = "sprGM3DIconObject";
	var _tip = "Model";
	if (_nk == "camera") {
		_sn = "sprGM3DIconCamera";
		_tip = "Camera";
	} else if (_nk == "environment") {
		_sn = "sprGM3DIconPointLight";
		_tip = "Environment";
	} else if (_nk == "light") {
		_sn = "sprGM3DIconPointLight";
		_tip = "Point light";
		var _en = __gm3d_ed_registry_find(_ed, _nd);
		if (_en != undefined && is_struct(_en.data) && variable_struct_exists(_en.data, "type") && _en.data.type == "directional") {
			_sn = "sprGM3DIconDirectionalLight";
			_tip = "Directional light";
		}
	}
	var _spr = -1;
	try {
		_spr = asset_get_index(_sn);
	} catch (_e) {
		return;
	}
	if (_spr == -1) {
		return;
	}
	var _iw = 0;
	var _ih = 0;
	try {
		_iw = sprite_get_width(_spr);
		_ih = sprite_get_height(_spr);
	} catch (_e0) {
		return;
	}
	var _tint = _ishid ? make_colour_rgb(105, 115, 135) : c_white;
	if (_sn == "sprGM3DIconDirectionalLight") {
		ImGui.Dummy(1, 0);
		ImGui.SameLine(0, 0);
	}
	try {
		ImGui.Image(_spr, 0, _tint, 1, _iw, _ih);
	} catch (_e2) {
		return;
	}
	if (ImGui.IsItemHovered()) {
		ImGui.SetTooltip(_tip);
		_ed.imgui.scene_eye_idx = _i;
		_ed.imgui.scene_eye_till = current_time + 500;
	}
}

// Draws filterable scene list with selection actions.
function __gm3d_ed_imgui_scene_list(_ed) {
	var _ui = _ed.imgui;
	if (!variable_struct_exists(_ui, "show_kind")) {
		_ui.show_kind = { m: true, l: true, c: true, e: true };
	}
	if (!variable_struct_exists(_ui, "show_kind_open")) {
		_ui.show_kind_open = false;
	}
	if (!variable_struct_exists(_ui, "scene_eye_idx")) {
		_ui.scene_eye_idx = -1;
		_ui.scene_eye_till = 0;
	}
	var _sk = _ui.show_kind;
	var _fw = 80;
	try {
		_fw = max(80, ImGui.GetContentRegionAvailX() - 70);
	} catch (_eFw) {
	}
	ImGui.SetNextItemWidth(_fw);
	_ui.scene_filter = __gm3d_ed_imgui_text_hint("##scenefilter", "Filter nodes...", _ui.scene_filter);
	ImGui.SameLine();
	var _can_popup = __gm3d_ed_imgui_has_widget(_ed, "BeginPopup") && __gm3d_ed_imgui_has_widget(_ed, "OpenPopup");
	if (_can_popup) {
		if (__gm3d_ed_imgui_small_btn_w(_ed, "Filters", false, 56)) {
			try {
				ImGui.OpenPopup("##scenekindfilters");
			} catch (_ePop) {
			}
		}
		if (ImGui.IsItemHovered()) {
			ImGui.SetTooltip("Filter asset types");
		}
		var _opened = false;
		try {
			_opened = ImGui.BeginPopup("##scenekindfilters");
		} catch (_eB) {
			_opened = false;
		}
		if (_opened) {
			_sk.m = ImGui.Checkbox("Models", _sk.m);
			_sk.l = ImGui.Checkbox("Lights", _sk.l);
			_sk.c = ImGui.Checkbox("Cameras", _sk.c);
			_sk.e = ImGui.Checkbox("Environment", _sk.e);
			try {
				ImGui.EndPopup();
			} catch (_eE) {
			}
		}
	} else {
		if (__gm3d_ed_imgui_small_btn_w(_ed, "Filters", _ui.show_kind_open == true, 56)) {
			_ui.show_kind_open = !_ui.show_kind_open;
		}
		if (ImGui.IsItemHovered()) {
			ImGui.SetTooltip("Filter asset types");
		}
		if (_ui.show_kind_open == true) {
			_sk.m = ImGui.Checkbox("Models", _sk.m);
			_sk.l = ImGui.Checkbox("Lights", _sk.l);
			_sk.c = ImGui.Checkbox("Cameras", _sk.c);
			_sk.e = ImGui.Checkbox("Environment", _sk.e);
		}
	}
	ImGui.Separator();
	if (_ed.rt == undefined) {
		ImGui.TextDisabled("No scene");
		return;
	}
	var _del = undefined;
	var _dup = undefined;
	var _foc = undefined;
	var _ren = undefined;
	if (!variable_struct_exists(_ed, "scene_click_idx")) {
		_ed.scene_click_idx = -1;
		_ed.scene_click_time = -10000;
	}
	if (!variable_struct_exists(_ed, "scene_anchor")) {
		_ed.scene_anchor = undefined;
	}
	var _flt = "";
	_flt = string_lower(_ui.scene_filter);

	var _roots = __gm3d_ed_tracked_nodes(_ed);
	var _visible = [];
	for (var _r = 0; _r < array_length(_roots); _r++) {
		var _vn = _roots[_r];
		var _vl = __gm3d_ed_label_get(_ed, _vn);
		var _vk = __gm3d_ed_kind_of(_ed, _vn);
		if (_vk == "light" && !_sk.l) {
			continue;
		}
		if (_vk == "camera" && !_sk.c) {
			continue;
		}
		if (_vk == "environment" && !_sk.e) {
			continue;
		}
		if (_vk != "light" && _vk != "camera" && _vk != "environment" && !_sk.m) {
			continue;
		}
		if (_flt != "" && string_pos(_flt, string_lower(_vl)) <= 0) {
			continue;
		}
		array_push(_visible, _vn);
	}
	for (var _i = 0; _i < array_length(_visible); _i++) {
		var _nd = _visible[_i];
		var _dl = __gm3d_ed_label_get(_ed, _nd);
		var _nk = __gm3d_ed_kind_of(_ed, _nd);
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

			var _eye_show = _ishid || (_ui.scene_eye_idx == _i && current_time <= _ui.scene_eye_till);
			if (__gm3d_ed_imgui_eye(_ed, _ishid, !_eye_show)) {
				__gm3d_ed_hidden_set(_ed, _nd, !_ishid);
			}
			if (ImGui.IsItemHovered()) {
				_ui.scene_eye_idx = _i;
				_ui.scene_eye_till = current_time + 500;
			}
			ImGui.SameLine();
			__gm3d_ed_imgui_kind_icon(_ed, _nd, _nk, _ishid, _i);
			ImGui.SameLine();
			var _sel = __gm3d_ed_sel_has(_ed, _nd);
			if (ImGui.Selectable(_dl, _sel)) {
				__gm3d_ed_scene_click(_ed, _nd, _i, _visible);
			}
			if (ImGui.IsItemHovered()) {
				_ui.scene_eye_idx = _i;
				_ui.scene_eye_till = current_time + 500;
			}
			var _dbl = false;
			_dbl = ImGui.IsMouseDoubleClicked(0) && ImGui.IsItemHovered();
			if (_dbl) {
				__gm3d_ed_focus_node(_ed, _nd);
			}
		}
		ImGui.PopID();
		__gm3d_ed_imgui_bg_alpha(0.95);
		if (ImGui.BeginPopupContextItem("ctx##" + string(_i))) {
			if (!__gm3d_ed_sel_has(_ed, _nd)) {
				__gm3d_ed_scene_select(_ed, _nd);
			}
			var _single = array_length(_ed.sel) <= 1;
			if (_single) {
				if (ImGui.MenuItem("Focus", "F")) {
					_foc = _nd;
					ImGui.CloseCurrentPopup();
				}
				if (ImGui.MenuItem("Rename", "F2")) {
					_ren = _nd;
					ImGui.CloseCurrentPopup();
				}
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

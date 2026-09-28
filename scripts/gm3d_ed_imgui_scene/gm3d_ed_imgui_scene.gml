/// @module gm3d_ed_imgui_scene

/// Draws the Scene hierarchy window.
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

/// Eye toggle button for Scene rows: open eye when visible, closed eye when
/// hidden (dimmed open eye if the closed sprite is missing), else text.
/// Ghost mode renders it transparent for a stable layout (pair with disabled).
/// @return True when clicked.
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
		// Frameless icon: transparent button colors, sprite at native size.
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
			// 9 args: uvs omitted entirely (undefined throws in this
			// binding); omitted uvs default to the full sprite.
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

/// Draws a sprite reserving its layout box but rendering the pixels shifted
/// down by _dy (CSS-absolute style: layout untouched, overlap allowed).
/// @return True when drawn (false = caller falls back to Image).
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

/// Kind filter cell: sprite icon (dimmed when off) plus a small checkbox.
/// @return New flag value.
function __gm3d_ed_imgui_kind_filter(_ed, _sprname, _id, _tip, _val) {
	static _ok = {};
	var _spr = -1;
	try {
		_spr = asset_get_index(_sprname);
	} catch (_e) {
		_spr = -1;
	}
	var _usable = _spr != -1 && _ok[$ _sprname] != false;
	if (_usable) {
		var _tint = _val ? c_white : make_colour_rgb(110, 120, 140);
		var _iw = 0;
		var _ih = 0;
		try {
			_iw = sprite_get_width(_spr);
			_ih = sprite_get_height(_spr);
		} catch (_e0) {
		}
		var _dy = 3;
		if (_sprname == "sprGM3DIconCamera") {
			_dy = 5;
		} else if (_sprname == "sprGM3DIconDirectionalLight") {
			_dy = 2;
		}
		if (!__gm3d_ed_imgui_icon_shifted(_spr, _tint, _iw, _ih, _dy)) {
			try {
				ImGui.Image(_spr, 0, _tint, 1, _iw, _ih);
			} catch (_e2) {
				_ok[$ _sprname] = false;
				_usable = false;
			}
		}
	}
	if (!_usable) {
		ImGui.Text(_id);
	}
	if (ImGui.IsItemHovered()) {
		ImGui.SetTooltip(_tip);
	}
	ImGui.SameLine(0, 7);
	return ImGui.Checkbox("##kf" + _id, _val);
}

/// Kind icon for a Scene row (filter icon set, native size, dimmed when
/// hidden). Point lights and the environment share the PointLight icon.
/// Flags its row for the eye grace period on hover.
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

/// Draws the filterable scene root list with selection, focus and rename.
function __gm3d_ed_imgui_scene_list(_ed) {
	var _ui = _ed.imgui;
	ImGui.SetNextItemWidth(-1);
	_ui.scene_filter = __gm3d_ed_imgui_text_hint("##scenefilter", "Filter nodes...", _ui.scene_filter);
	if (!variable_struct_exists(_ui, "show_kind")) {
		_ui.show_kind = { m: true, l: true, c: true, e: true };
	}
	if (!variable_struct_exists(_ui, "scene_eye_idx")) {
		_ui.scene_eye_idx = -1;
		_ui.scene_eye_till = 0;
	}
	var _sk = _ui.show_kind;
	_sk.m = __gm3d_ed_imgui_kind_filter(_ed, "sprGM3DIconObject", "M", "Show models", _sk.m);
	ImGui.SameLine(0, 14);
	_sk.l = __gm3d_ed_imgui_kind_filter(_ed, "sprGM3DIconDirectionalLight", "L", "Show lights", _sk.l);
	ImGui.SameLine(0, 14);
	_sk.c = __gm3d_ed_imgui_kind_filter(_ed, "sprGM3DIconCamera", "C", "Show cameras", _sk.c);
	ImGui.SameLine(0, 14);
	_sk.e = __gm3d_ed_imgui_kind_filter(_ed, "sprGM3DIconPointLight", "E", "Show environment", _sk.e);
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
			// Eye far left, always the same widget (zero shift): transparent
			// when concealed, clicks ignored unless visible. Hover works on
			// the whole row including the invisible slot.
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
				__gm3d_ed_scene_click(_ed, _nd, _i);
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

// Lists filterable draggable model assets.
function __gm3d_ed_imgui_asset_list(_ed) {
	var _ui = _ed.imgui;

	if (!variable_struct_exists(_ui, "models_view")) {
		_ui.models_view = "cards";
	}
	var _fw = 80;
	_fw = max(80, ImGui.GetContentRegionAvailX() - 108);
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
	return __gm3d_ed_imgui_small_btn_w(_ed, _label, _active, 46);
}

// Draws small button with active highlight and custom width.
function __gm3d_ed_imgui_small_btn_w(_ed, _label, _active, _w) {
	var _pushed = 0;
	if (_active) {
		ImGui.PushStyleColor(ImGuiCol.Button, make_colour_rgb(47, 111, 237), 1);
		_pushed++;
	}
	var _hit = ImGui.Button(_label, _w, 0);
	__gm3d_ed_imgui_pop(_pushed);
	return _hit;
}

// Draws assets in grid card layout.
function __gm3d_ed_imgui_asset_cards(_ed, _flt) {
	var _cs = 60;
	var _gap = 12;
	var _avail = 200;
	_avail = ImGui.GetContentRegionAvailX();
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
		_full = ImGui.CalcTextWidth(_text);
		if (_full > _maxw) {
			_out = "..";
			var _n = string_length(_text) - 1;
			while (_n > 1) {
				var _t = string_copy(_text, 1, _n) + "..";
				var _w = _maxw + 1;
				_w = ImGui.CalcTextWidth(_t);
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
	_sx = ImGui.GetCursorScreenPosX();
	_sy = ImGui.GetCursorScreenPosY();
	_dl = ImGui.GetWindowDrawList();
	ImGui.PushID(_i);
	var _okbtn = __gm3d_ed_imgui_has_widget(_ed, "InvisibleButton");
	if (_okbtn) {
		ImGui.InvisibleButton("##card", _cs, _pad + _cs + _th + _pad);
	} else {
		ImGui.Dummy(_cs, _pad + _cs + _th + _pad);
	}
	var _hov = ImGui.IsItemHovered();
	if (_sx != undefined && _dl != undefined) {
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

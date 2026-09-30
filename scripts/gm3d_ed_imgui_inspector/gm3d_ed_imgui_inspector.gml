// Gets shared axis value detecting mixed selection.
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

// Draws Inspector window for current selection.
function __gm3d_ed_imgui_inspector(_ed) {
	var _ui = _ed.imgui;
	if (!_ui.win_insp.open) {
		return;
	}
	var _pi = __gm3d_ed_imgui_place(_ed).insp;
	ImGui.SetNextWindowPos(_pi.x, _pi.y, _ui.cond);
	ImGui.SetNextWindowSize(_pi.w, _pi.h, _ui.cond);
	__gm3d_ed_imgui_bg_alpha(0.95);
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

// Edits Position Rotation or Scale axis row.
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

	var _speed = _mode == 1 ? 0.1 : 0.01;
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

		if (!variable_struct_exists(_ed.imgui, "ax_draft")) {
			_ed.imgui.ax_draft = {};
		}
		var _input = _av.val;
		if (_was && variable_struct_exists(_ed.imgui.ax_draft, _fkey)) {
			var _dr = _ed.imgui.ax_draft[$ _fkey];
			if (is_real(_dr)) {
				_input = _dr;
			}
		}
		var _nv = __gm3d_ed_imgui_dragfloat(_names[_a], _input, _speed);
		var _now = ImGui.IsItemActive();
		_ed.imgui.ax_active[$ _fkey] = _now;
		if (_now) {
			_ed.imgui.ax_draft[$ _fkey] = _nv;
		} else {
			if (variable_struct_exists(_ed.imgui.ax_draft, _fkey)) {
				variable_struct_remove(_ed.imgui.ax_draft, _fkey);
			}
			if (_was && _nv != _av.val) {
				__gm3d_ed_inspector_apply(_ed, _mode, _a, _nv);
			}
		}
		if (_a < 2) {
			ImGui.SameLine();
			ImGui.Dummy(2, 0);
		}
	}
	ImGui.PopID();
}

// Edits float property with edit tracking.
function __gm3d_ed_imgui_prop_float(_ed, _key, _label, _val, _w) {
	if (_ed.imgui == undefined) {
		__gm3d_ed_imgui_ensure(_ed);
	}
	if (!variable_struct_exists(_ed.imgui, "flt_active")) {
		_ed.imgui.flt_active = {};
	}
	if (!variable_struct_exists(_ed.imgui, "flt_draft")) {
		_ed.imgui.flt_draft = {};
	}
	ImGui.SetNextItemWidth(_w);
	var _was = _ed.imgui.flt_active[$ _key] == true;
	var _input = _val;
	if (_was && variable_struct_exists(_ed.imgui.flt_draft, _key)) {
		var _dr = _ed.imgui.flt_draft[$ _key];
		if (is_real(_dr)) {
			_input = _dr;
		}
	}
	var _nv = __gm3d_ed_imgui_dragfloat(_label, _input, 0.01);
	var _now = ImGui.IsItemActive();
	_ed.imgui.flt_active[$ _key] = _now;
	if (_now) {
		_ed.imgui.flt_draft[$ _key] = _nv;
		return undefined;
	}
	if (variable_struct_exists(_ed.imgui.flt_draft, _key)) {
		variable_struct_remove(_ed.imgui.flt_draft, _key);
	}
	if (_was && _nv != _val) {
		return _nv;
	}
	return undefined;
}

// Updates rows and commits history snapshot.
function __gm3d_ed_props_end(_ed, _hb) {
	__gm3d_ed_rows_follow(_ed, _ed.sel);
	if (_hb != undefined) {
		__gm3d_ed_history_commit(_ed, _hb);
	}
}

// Checks cached ImGui widget availability.
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

// Edits color with undo history grouping.
function __gm3d_ed_imgui_color_edit(_ed, _key, _label, _packed) {
	if (_ed.imgui == undefined) {
		__gm3d_ed_imgui_ensure(_ed);
	}
	if (!variable_struct_exists(_ed.imgui, "col_gest")) {
		_ed.imgui.col_gest = {};
	}
	var _nv = ImGui.ColorEdit3(_label, _packed);
	var _now = ImGui.IsItemActive();
	var _rec = _ed.imgui.col_gest[$ _key];
	var _was = is_struct(_rec) && _rec.active == true;
	if (_now && !_was) {
		_ed.imgui.col_gest[$ _key] = { active: true, before: __gm3d_ed_history_snap(_ed) };
	}
	if (!_now && _was) {
		var _hb = _rec.before;
		_ed.imgui.col_gest[$ _key] = { active: false, before: undefined };
		__gm3d_ed_rows_follow(_ed, _ed.sel);
		if (_hb != undefined) {
			__gm3d_ed_history_commit(_ed, _hb);
		}
	}
	if (_nv != _packed) {
		return _nv;
	}
	return undefined;
}

// Edits light properties in Inspector.
function __gm3d_ed_imgui_light_sec(_ed, _node, _en) {
	var _d = _en.data;
	ImGui.Separator();
	ImGui.Text("Light");
	if (ImGui.RadioButton("Directional", _d.type == "directional")) {
		var _hb = __gm3d_ed_history_snap(_ed);
		_d.type = "directional";
		__gm3d_ed_light_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb);
		__gm3d_ed_sel_apply_tool(_ed);
	}
	if (ImGui.RadioButton("Point", _d.type == "point")) {
		var _hb9 = __gm3d_ed_history_snap(_ed);
		_d.type = "point";
		if (_d.range < 0.5) {
			_d.range = 50.0;
		}
		__gm3d_ed_light_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb9);
		__gm3d_ed_sel_apply_tool(_ed);
	}

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
	var _nc = __gm3d_ed_imgui_color_edit(_ed, "light_col", "Color", make_colour_rgb(_d.color[0], _d.color[1], _d.color[2]));
	if (_nc != undefined) {
		_d.color = [colour_get_red(_nc), colour_get_green(_nc), colour_get_blue(_nc)];
		__gm3d_ed_light_apply(_node, _d);
		_ed.dirty = true;
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

// Edits camera properties in Inspector.
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
		var _fv = __gm3d_ed_imgui_prop_float(_ed, "cam_fov", "Fov", _d.fov, 120);
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

	__gm3d_ed_cameras_mute(_ed);
}

// Edits environment properties in Inspector.
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
	var _na = __gm3d_ed_imgui_color_edit(_ed, "env_amb", "Ambient", make_colour_rgb(_d.ambient[0], _d.ambient[1], _d.ambient[2]));
	if (_na != undefined) {
		_d.ambient = [colour_get_red(_na), colour_get_green(_na), colour_get_blue(_na)];
		__gm3d_ed_env_apply(_node, _d);
		_ed.dirty = true;
	}
	var _nfg = ImGui.Checkbox("Fog", _d.fog == true);
	if (_nfg != (_d.fog == true)) {
		var _hb4 = __gm3d_ed_history_snap(_ed);
		_d.fog = _nfg;
		__gm3d_ed_env_apply(_node, _d);
		__gm3d_ed_props_end(_ed, _hb4);
	}
	if (_d.fog == true) {
		var _nf = __gm3d_ed_imgui_color_edit(_ed, "env_fogc", "Fog color", make_colour_rgb(_d.fogcolor[0], _d.fogcolor[1], _d.fogcolor[2]));
		if (_nf != undefined) {
			_d.fogcolor = [colour_get_red(_nf), colour_get_green(_nf), colour_get_blue(_nf)];
			__gm3d_ed_env_apply(_node, _d);
			_ed.dirty = true;
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

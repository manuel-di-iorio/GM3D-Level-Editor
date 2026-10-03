// Returns default light property values.
function __gm3d_ed_light_defaults() {
	return { type: "directional", color: [255, 255, 255], intensity: 1.0, range: 50.0, inner: 30.0, outer: 45.0, enabled: true, shadow: false, shadowRes: 2048, shadowDist: 20.0, shadowNormal: 0.05 };
}

// Returns default camera property values.
function __gm3d_ed_camera_defaults() {
	return { projection: "perspective", fov: 60.0, ow: 10.0, oh: 10.0, near: 0.1, far: 500.0, enabled: true };
}

// Returns default environment property values.
function __gm3d_ed_env_defaults() {
	return {
		size: [20000.0, 20000.0, 20000.0],
		ambient: [70, 70, 85],
		fog: false,
		fogcolor: [192, 192, 192],
		fogstart: 20.0,
		fogend: 100.0,
		enabled: true,
	};
}

// Safely calls bound component getter with fallback.
function __gm3d_ed_comp_get(_comp, _m, _fb) {
	if (_comp == undefined || !is_string(_m) || _m == "") {
		return _fb;
	}
	var _f = _comp[$ _m];
	if (_f == undefined) {
		return _fb;
	}
	return method(_comp, _f)();
}

// Converts light enum to string.
function __gm3d_ed_light_type_to_str(_v) {
	if (_v == GM3D_ELightType.Point) {
		return "point";
	}
	if (_v == GM3D_ELightType.Spot) {
		return "spot";
	}
	if (_v == GM3D_ELightType.Directional) {
		return "directional";
	}
	return undefined;
}

// Converts light string to enum.
function __gm3d_ed_light_type_to_enum(_s) {
	if (_s == "point") {
		return GM3D_ELightType.Point;
	}
	if (_s == "spot") {
		return GM3D_ELightType.Spot;
	}
	return GM3D_ELightType.Directional;
}

// Converts projection enum to string.
function __gm3d_ed_cam_proj_to_str(_v) {
	if (_v == GM3D_ECameraProjection.Orthographic) {
		return "ortho";
	}
	if (_v == GM3D_ECameraProjection.Perspective) {
		return "perspective";
	}
	return undefined;
}

// Converts projection string to enum.
function __gm3d_ed_cam_proj_to_enum(_s) {
	if (_s == "ortho") {
		return GM3D_ECameraProjection.Orthographic;
	}
	return GM3D_ECameraProjection.Perspective;
}

// Reads light properties from node.
function __gm3d_ed_light_read(_node) {
	var _d = __gm3d_ed_light_defaults();
	var _lc = undefined;
	_lc = _node.getLightComponent();
	if (_lc == undefined) {
		return _d;
	}
	var _t = __gm3d_ed_light_type_to_str(__gm3d_ed_comp_get(_lc, "getType", undefined));
	if (_t != undefined) {
		_d.type = _t;
	}
	var _c = __gm3d_ed_comp_get(_lc, "getColor", undefined);
	if (is_real(_c)) {
		_d.color = [colour_get_red(_c), colour_get_green(_c), colour_get_blue(_c)];
	}
	var _v = __gm3d_ed_comp_get(_lc, "getIntensity", undefined);
	if (is_real(_v)) {
		_d.intensity = _v;
	}
	_v = __gm3d_ed_comp_get(_lc, "getRange", undefined);
	if (is_real(_v) && _v > 0) {
		_d.range = _v;
	}
	_v = __gm3d_ed_comp_get(_lc, "getInnerConeAngle", undefined);
	if (is_real(_v)) {
		_d.inner = radtodeg(_v);
	}
	_v = __gm3d_ed_comp_get(_lc, "getOuterConeAngle", undefined);
	if (is_real(_v)) {
		_d.outer = radtodeg(_v);
	}
	_v = __gm3d_ed_comp_get(_lc, "getEnabled", undefined);
	if (_v != undefined) {
		_d.enabled = (_v == true || _v == 1);
	}
	_v = __gm3d_ed_comp_get(_lc, "getShadowEnabled", undefined);
	if (_v != undefined) {
		_d.shadow = (_v == true || _v == 1);
	}
	_v = __gm3d_ed_comp_get(_lc, "getShadowResolution", undefined);
	if (is_real(_v) && _v > 0) {
		_d.shadowRes = _v;
	}
	_v = __gm3d_ed_comp_get(_lc, "getShadowDistance", undefined);
	if (is_real(_v) && _v > 0) {
		_d.shadowDist = _v;
	}
	_v = __gm3d_ed_comp_get(_lc, "getShadowNormalOffset", undefined);
	if (is_real(_v) && _v >= 0) {
		_d.shadowNormal = _v;
	}
	return _d;
}

// Applies light properties to node.
function __gm3d_ed_light_apply(_node, _d) {
	if (_node == undefined || _d == undefined) {
		return;
	}
	var _lc = undefined;
	_lc = _node.getLightComponent();
	if (_lc == undefined) {
		return;
	}
	_lc.setType(__gm3d_ed_light_type_to_enum(_d.type));
	var _cc = _d.color;
	_lc.setColor(make_colour_rgb(clamp(_cc[0], 0, 255), clamp(_cc[1], 0, 255), clamp(_cc[2], 0, 255)));
	_lc.setIntensity(max(_d.intensity, 0));
	if (_d.type != "directional") {
		_lc.setRange(max(_d.range, 0.01));
	}
	if (_d.type == "spot") {
		_lc.setInnerConeAngle(degtorad(clamp(_d.inner, 0, 89)));
		_lc.setOuterConeAngle(degtorad(clamp(_d.outer, 1, 89)));
	}
	_lc.setEnabled(_d.enabled == true);
	if (_d.type == "directional") {
		_lc.setShadowEnabled(_d.shadow == true);
		_lc.setShadowResolution(clamp(round(_d.shadowRes), 128, 4096));
		_lc.setShadowDistance(max(_d.shadowDist, 1));
		_lc.setShadowNormalOffset(clamp(_d.shadowNormal, 0, 1));
	}
	var _pv = gm3d_editor_inst();
	if (_pv != undefined && _pv.show_shadows == false) {
		_lc.setShadowEnabled(false);
	}
}

// Warns once when the runtime shadow API is missing.
function __gm3d_ed_shadow_warn() {
	if (variable_global_exists("gm3d_ed_shadow_warned") && global.gm3d_ed_shadow_warned == true) {
		return;
	}
	global.gm3d_ed_shadow_warned = true;
	show_debug_message("[gm3d_editor] shadow API unavailable on GM3D_LightComponent");
}

// Applies shadow preview override to tracked directionals.
function __gm3d_ed_shadowpreview_apply(_ed) {
	if (_ed == undefined) {
		return;
	}
	var _roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		if (__gm3d_ed_kind_of(_ed, _roots[_i]) != "light") {
			continue;
		}
		var _en = __gm3d_ed_registry_find(_ed, _roots[_i]);
		if (_en == undefined || !is_struct(_en.data) || _en.data.type != "directional") {
			continue;
		}
		var _lc = _roots[_i].getLightComponent();
		if (_lc == undefined) {
			continue;
		}
		_lc.setShadowEnabled(_ed.show_shadows != false && _en.data.shadow == true);
	}
}

// Reads camera properties from node.
function __gm3d_ed_camera_read(_node) {
	var _d = __gm3d_ed_camera_defaults();
	var _cc = undefined;
	_cc = _node.getCameraComponent();
	if (_cc == undefined) {
		return _d;
	}
	var _p = __gm3d_ed_cam_proj_to_str(__gm3d_ed_comp_get(_cc, "getProjection", undefined));
	if (_p != undefined) {
		_d.projection = _p;
	}
	var _v = __gm3d_ed_comp_get(_cc, "getFovY", undefined);
	if (is_real(_v) && _v > 0) {
		_d.fov = radtodeg(_v);
	}
	_v = __gm3d_ed_comp_get(_cc, "getOrthoWidth", undefined);
	if (is_real(_v) && _v > 0) {
		_d.ow = _v;
	}
	_v = __gm3d_ed_comp_get(_cc, "getOrthoHeight", undefined);
	if (is_real(_v) && _v > 0) {
		_d.oh = _v;
	}
	_v = __gm3d_ed_comp_get(_cc, "getNear", undefined);
	if (is_real(_v) && _v > 0) {
		_d.near = _v;
	}
	_v = __gm3d_ed_comp_get(_cc, "getFar", undefined);
	if (is_real(_v) && _v > _d.near) {
		_d.far = _v;
	}
	_v = __gm3d_ed_comp_get(_cc, "getEnabled", undefined);
	if (_v != undefined) {
		_d.enabled = (_v == true || _v == 1);
	}
	return _d;
}

// Applies camera properties to node.
function __gm3d_ed_camera_apply(_node, _d) {
	if (_node == undefined || _d == undefined) {
		return;
	}
	var _cc = undefined;
	_cc = _node.getCameraComponent();
	if (_cc == undefined) {
		return;
	}
	_cc.setProjection(__gm3d_ed_cam_proj_to_enum(_d.projection));
	if (_d.projection == "ortho") {
		_cc.setOrthoWidth(max(_d.ow, 0.01));
		_cc.setOrthoHeight(max(_d.oh, 0.01));
	} else {
		_cc.setFovY(degtorad(clamp(_d.fov, 1, 179)));
	}
	_cc.setNear(max(_d.near, 0.01));
	_cc.setFar(max(_d.far, _d.near + 0.01));
	_cc.setEnabled(_d.enabled == true);
}

// Reads environment properties from node.
function __gm3d_ed_env_read(_node) {
	var _d = __gm3d_ed_env_defaults();
	var _ec = undefined;
	_ec = _node.getEnvironmentVolumeComponent();
	if (_ec == undefined) {
		return _d;
	}
	var _s = __gm3d_ed_comp_get(_ec, "getSize", undefined);
	if (is_array(_s) && array_length(_s) == 3) {
		_d.size = [max(_s[0], 0.01), max(_s[1], 0.01), max(_s[2], 0.01)];
	} else if (is_struct(_s) && variable_struct_exists(_s, "x")) {
		_d.size = [max(_s.x, 0.01), max(_s.y, 0.01), max(_s.z, 0.01)];
	}
	var _c = __gm3d_ed_comp_get(_ec, "getAmbientColor", undefined);
	if (is_real(_c)) {
		_d.ambient = [colour_get_red(_c), colour_get_green(_c), colour_get_blue(_c)];
	}
	var 	_v = __gm3d_ed_comp_get(_ec, "getFogEnabled", undefined);
	if (_v != undefined) {
		_d.fog = (_v == true || _v == 1);
	}
	_c = __gm3d_ed_comp_get(_ec, "getFogColor", undefined);
	if (is_real(_c)) {
		_d.fogcolor = [colour_get_red(_c), colour_get_green(_c), colour_get_blue(_c)];
	}
	_v = __gm3d_ed_comp_get(_ec, "getFogStart", undefined);
	if (is_real(_v)) {
		_d.fogstart = _v;
	}
	_v = __gm3d_ed_comp_get(_ec, "getFogEnd", undefined);
	if (is_real(_v)) {
		_d.fogend = _v;
	}
	_v = __gm3d_ed_comp_get(_ec, "getEnabled", undefined);
	if (_v != undefined) {
		_d.enabled = (_v == true || _v == 1);
	}
	return _d;
}

// Applies environment properties to node.
function __gm3d_ed_env_apply(_node, _d) {
	if (_node == undefined || _d == undefined) {
		return;
	}
	var _ec = undefined;
	_ec = _node.getEnvironmentVolumeComponent();
	if (_ec == undefined) {
		return;
	}
	_ec.setSize(new GM3D_Vec3(max(_d.size[0], 0.01), max(_d.size[1], 0.01), max(_d.size[2], 0.01)));
	var _ac = _d.ambient;
	_ec.setAmbientColor(make_colour_rgb(clamp(_ac[0], 0, 255), clamp(_ac[1], 0, 255), clamp(_ac[2], 0, 255)));
	_ec.setFogEnabled(_d.fog == true);
	var _fc = _d.fogcolor;
	_ec.setFogColor(make_colour_rgb(clamp(_fc[0], 0, 255), clamp(_fc[1], 0, 255), clamp(_fc[2], 0, 255)));
	_ec.setFogStart(_d.fogstart);
	_ec.setFogEnd(max(_d.fogend, _d.fogstart + 0.01));
	_ec.setEnabled(_d.enabled == true);
}

// Registers existing light node for editing.
function __gm3d_ed_track_light(_ed, _node, _label = undefined) {
	if (_ed == undefined || _node == undefined) {
		return undefined;
	}
	var _d = __gm3d_ed_light_read(_node);
	var _pp = _node.getLocalPosition();
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = __gm3d_ed_fresh_label(_ed, _node.name);
	}
	__gm3d_ed_kind_register(_ed, _node, "light", "", [_pp.x, _pp.y, _pp.z], _label, _d);
	if (_d.type == "directional") {
		__gm3d_ed_hidden_set(_ed, _node, true);
	}
	return _node;
}

// Registers existing camera node for editing.
function __gm3d_ed_track_camera(_ed, _node, _label = undefined) {
	if (_ed == undefined || _node == undefined) {
		return undefined;
	}
	var _d = __gm3d_ed_camera_read(_node);
	var _pp = _node.getLocalPosition();
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = __gm3d_ed_fresh_label(_ed, _node.name);
	}
	__gm3d_ed_kind_register(_ed, _node, "camera", "", [_pp.x, _pp.y, _pp.z], _label, _d);
	__gm3d_ed_hidden_set(_ed, _node, true);
	__gm3d_ed_cameras_mute(_ed);
	return _node;
}

// Resolves gameplay camera: MainCamera label first, else first enabled, else first.
function __gm3d_ed_gamecam_resolve(_ed) {
	if (_ed == undefined) {
		return undefined;
	}
	var _roots = __gm3d_ed_root_tracked(_ed);
	var _first = undefined;
	var _enabled = undefined;
	for (var _i = 0; _i < array_length(_roots); _i++) {
		if (__gm3d_ed_kind_of(_ed, _roots[_i]) != "camera") {
			continue;
		}
		if (_first == undefined) {
			_first = _roots[_i];
		}
		var _en = __gm3d_ed_registry_find(_ed, _roots[_i]);
		if (_en == undefined || !is_struct(_en.data)) {
			continue;
		}
		if (is_string(_en.label) && _en.label == "MainCamera") {
			return _roots[_i];
		}
		if (_enabled == undefined && _en.data.enabled == true) {
			_enabled = _roots[_i];
		}
	}
	if (_enabled != undefined) {
		return _enabled;
	}
	return _first;
}

// Ensures a gameplay camera exists, creating a default one when missing.
function __gm3d_ed_gamecam_ensure(_ed) {
	var _g = __gm3d_ed_gamecam_resolve(_ed);
	if (_g != undefined) {
		return _g;
	}
	if (_ed == undefined || _ed.rt == undefined || _ed.rt.scene == undefined) {
		return undefined;
	}
	var _lbl = __gm3d_ed_fresh_label(_ed, "MainCamera");
	var _node = _ed.rt.scene.createNode(_lbl);
	if (_node == undefined) {
		return undefined;
	}
	var _cc = new GM3D_CameraComponent();
	_node.addComponent(_cc);
	var _dpos = [0, 2, 5];
	if (_ed.inst != undefined && _ed.inst != noone && variable_instance_exists(_ed.inst, "camPos")) {
		var _cp0 = _ed.inst.camPos;
		_dpos = [_cp0.x, _cp0.y, _cp0.z];
	}
	_node.setLocalPosition(new GM3D_Vec3(_dpos[0], _dpos[1], _dpos[2]));
	var _cd = __gm3d_ed_camera_defaults();
	__gm3d_ed_camera_apply(_node, _cd);
	_ed.rt.scene.update(0);
	var _pp = _node.getLocalPosition();
	__gm3d_ed_kind_register(_ed, _node, "camera", "", [_pp.x, _pp.y, _pp.z], _lbl, _cd);
	return _node;
}

// Registers existing environment node for editing.
function __gm3d_ed_track_env(_ed, _node, _label = undefined) {
	if (_ed == undefined || _node == undefined) {
		return undefined;
	}
	var _d = __gm3d_ed_env_read(_node);
	var _pp = _node.getLocalPosition();
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = __gm3d_ed_fresh_label(_ed, _node.name);
	}
	__gm3d_ed_kind_register(_ed, _node, "environment", "", [_pp.x, _pp.y, _pp.z], _label, _d);
	__gm3d_ed_hidden_set(_ed, _node, true);
	return _node;
}

// Creates new light node in scene.
function __gm3d_ed_create_light(_ed, _type) {
	if (_ed == undefined || _ed.rt == undefined) {
		return undefined;
	}
	if (_type != "point" && _type != "spot") {
		_type = "directional";
	}
	var _hb = __gm3d_ed_history_snap(_ed);
	var _base = _type == "point" ? "Point" : _type == "spot" ? "Spot" : "Directional";
	var _lbl = __gm3d_ed_fresh_label(_ed, _base);
	var _node = _ed.rt.scene.createNode(_lbl);
	if (_node == undefined) {
		return undefined;
	}
	var _lc = new GM3D_LightComponent();
	_node.addComponent(_lc);
	if (_type == "directional") {
		_node.setLocalPosition(new GM3D_Vec3(0, 3, 0));
		_node.setLocalRotation(__gm3d_ed_euler_to_quat(degtorad(-50), 0, 0));
	} else {
		_node.setLocalPosition(new GM3D_Vec3(0, 2, 0));
	}
	var _d = __gm3d_ed_light_defaults();
	_d.type = _type;
	__gm3d_ed_light_apply(_node, _d);
	_ed.rt.scene.update(0);
	var _pp = _node.getLocalPosition();
	__gm3d_ed_kind_register(_ed, _node, "light", "", [_pp.x, _pp.y, _pp.z], _lbl, _d);
	_ed.sel = [_node];
	_ed.giz.drag = -1;
	__gm3d_ed_sel_apply_tool(_ed);
	__gm3d_ed_history_commit(_ed, _hb);
	return _node;
}

// Creates new camera node in scene.
function __gm3d_ed_create_camera(_ed, _proj) {
	if (_ed == undefined || _ed.rt == undefined) {
		return undefined;
	}
	if (_proj != "ortho") {
		_proj = "perspective";
	}
	var _hb = __gm3d_ed_history_snap(_ed);
	var _lbl = __gm3d_ed_fresh_label(_ed, _proj == "ortho" ? "OrthoCam" : "Camera");
	var _node = _ed.rt.scene.createNode(_lbl);
	if (_node == undefined) {
		return undefined;
	}
	var _cc = new GM3D_CameraComponent();
	_node.addComponent(_cc);
	_node.setLocalPosition(new GM3D_Vec3(0, 2, 5));
	var _d = __gm3d_ed_camera_defaults();
	_d.projection = _proj;
	__gm3d_ed_camera_apply(_node, _d);
	_ed.rt.scene.update(0);
	var _pp = _node.getLocalPosition();
	__gm3d_ed_kind_register(_ed, _node, "camera", "", [_pp.x, _pp.y, _pp.z], _lbl, _d);
	_ed.sel = [_node];
	_ed.giz.drag = -1;
	__gm3d_ed_history_commit(_ed, _hb);
	__gm3d_ed_cameras_mute(_ed);
	return _node;
}

// Creates new environment node in scene.
function __gm3d_ed_create_env(_ed) {
	if (_ed == undefined || _ed.rt == undefined) {
		return undefined;
	}
	if (__gm3d_ed_env_node(_ed) != undefined) {
		return undefined;
	}
	var _hb = __gm3d_ed_history_snap(_ed);
	var _lbl = __gm3d_ed_fresh_label(_ed, "Environment");
	var _node = _ed.rt.scene.createNode(_lbl);
	if (_node == undefined) {
		return undefined;
	}
	var _ec = new GM3D_EnvironmentVolumeComponent();
	_node.addComponent(_ec);
	var _d = __gm3d_ed_env_defaults();
	__gm3d_ed_env_apply(_node, _d);
	_ed.rt.scene.update(0);
	__gm3d_ed_kind_register(_ed, _node, "environment", "", [0, 0, 0], _lbl, _d);
	__gm3d_ed_hidden_set(_ed, _node, true);
	_ed.sel = [_node];
	_ed.giz.drag = -1;
	__gm3d_ed_history_commit(_ed, _hb);
	return _node;
}

// Finds tracked environment node.
function __gm3d_ed_env_node(_ed) {
	var _roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		if (__gm3d_ed_kind_of(_ed, _roots[_i]) == "environment") {
			return _roots[_i];
		}
	}
	return undefined;
}

// Disables all tracked scene cameras.
function __gm3d_ed_cameras_mute(_ed) {
	if (_ed == undefined || _ed.rt == undefined) {
		return;
	}
	var _roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		if (_roots[_i] == _ed.rt.cam) {
			continue;
		}
		if (__gm3d_ed_kind_of(_ed, _roots[_i]) != "camera") {
			continue;
		}
		var _cc = _roots[_i].getCameraComponent();
		if (_cc != undefined) {
			_cc.setEnabled(false);
		}
	}
}

// Restores tracked cameras enabled state.
function __gm3d_ed_cameras_restore(_ed) {
	if (_ed == undefined || _ed.rt == undefined) {
		return;
	}
	var _roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		var _en = __gm3d_ed_registry_find(_ed, _roots[_i]);
		if (_en == undefined || !is_struct(_en.data)) {
			continue;
		}
		if (__gm3d_ed_kind_of(_ed, _roots[_i]) != "camera") {
			continue;
		}
		var _cc = _roots[_i].getCameraComponent();
		if (_cc != undefined) {
			_cc.setEnabled(_en.data.enabled == true);
		}
	}
}

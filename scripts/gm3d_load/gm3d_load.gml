// Loads scene file into runtime scene.
function gm3d_load(_scene, _fname, _models) {
	var _rep = { placed: 0, failed: 0 };
	if (_scene == undefined || _fname == undefined || _fname == "" || !is_struct(_models)) {
		return _rep;
	}
	if (!file_exists(_fname)) {
		return _rep;
	}
	var _json = "";
	var _f = file_text_open_read(_fname);
	if (_f < 0) {
		return _rep;
	}
	while (!file_text_eof(_f)) {
		_json += file_text_read_string(_f);
		file_text_readln(_f);
	}
	file_text_close(_f);
	if (_json == "") {
		return _rep;
	}
	var _data = undefined;
	_data = json_parse(_json);
	if (!is_struct(_data) || !variable_struct_exists(_data, "nodes") || !is_array(_data.nodes)) {
		return _rep;
	}
	var _nodes = _data.nodes;
	for (var _i = 0; _i < array_length(_nodes); ++_i) {
		var _ok = false;
		_ok = __gm3d_load_node(_scene, _models, _nodes[_i]) != undefined;
		if (_ok) {
			_rep.placed++;
		} else {
			_rep.failed++;
		}
	}
	_scene.update(0);
	return _rep;
}

// Spawns single node from descriptor.
function __gm3d_load_node(_scene, _models, _p) {
	if (_scene == undefined || !is_struct(_p)) {
		return undefined;
	}
	var _kind = undefined;
	if (variable_struct_exists(_p, "kind") && is_string(_p.kind) && _p.kind != "") {
		_kind = _p.kind;
	}
	var _name = "node";
	if (variable_struct_exists(_p, "name") && is_string(_p.name) && _p.name != "") {
		_name = _p.name;
	}
	if (_kind == "light" || _kind == "camera" || _kind == "environment") {
		return __gm3d_load_prop(_scene, _p, _kind, _name);
	}
	if (_kind != "asset") {
		return undefined;
	}
	if (!variable_struct_exists(_p, "asset") || !is_string(_p.asset) || _p.asset == "") {
		return undefined;
	}
	var _akey = _p.asset;
	if (!variable_struct_exists(_models, _akey)) {
		return undefined;
	}
	var _model = _models[$ _akey];
	if (_model == undefined) {
		return undefined;
	}
	var _node = _model.spawnInto(_scene, undefined);
	if (_node == undefined) {
		return undefined;
	}
	_node.setLocalPosition(__gm3d_load_vec3(_p, "position", 0, 0, 0));
	_node.setLocalScale(__gm3d_load_vec3(_p, "scale", 1, 1, 1));
	_node.setLocalRotation(__gm3d_load_quat(_p));
	if (variable_struct_exists(_p, "flags") && is_struct(_p.flags)) {
		__gm3d_ed_flags_apply(_node, _p.flags.castShadows == true, _p.flags.receiveShadows == true);
	}
	return _node;
}

// Creates light camera environment from descriptor.
function __gm3d_load_prop(_scene, _p, _kind, _name) {
	var _node = _scene.createNode(_name);
	if (_node == undefined) {
		return undefined;
	}
	_node.setLocalPosition(__gm3d_load_vec3(_p, "position", 0, 0, 0));
	_node.setLocalScale(__gm3d_load_vec3(_p, "scale", 1, 1, 1));
	_node.setLocalRotation(__gm3d_load_quat(_p));
	if (_kind == "light" && is_struct(_p.light)) {
		var _lc = new GM3D_LightComponent();
		_node.addComponent(_lc);
		var _l = _p.light;
		_lc.setType(_l.type == "point" ? GM3D_ELightType.Point : _l.type == "spot" ? GM3D_ELightType.Spot : GM3D_ELightType.Directional);
		if (is_array(_l.color) && array_length(_l.color) == 3) {
			_lc.setColor(make_colour_rgb(clamp(_l.color[0], 0, 255), clamp(_l.color[1], 0, 255), clamp(_l.color[2], 0, 255)));
		}
		if (is_real(_l.intensity)) {
			_lc.setIntensity(max(_l.intensity, 0));
		}
		if (is_real(_l.range) && _l.range > 0) {
			_lc.setRange(_l.range);
		}
		if (is_real(_l.innerCone)) {
			_lc.setInnerConeAngle(degtorad(clamp(_l.innerCone, 0, 89)));
		}
		if (is_real(_l.outerCone)) {
			_lc.setOuterConeAngle(degtorad(clamp(_l.outerCone, 1, 89)));
		}
		_lc.setEnabled(!variable_struct_exists(_l, "enabled") || _l.enabled == true);
		if (variable_struct_exists(_l, "shadow") && is_struct(_l.shadow)) {
			var _sh = _l.shadow;
			_lc.setShadowEnabled(!variable_struct_exists(_sh, "enabled") || _sh.enabled == true);
			if (variable_struct_exists(_sh, "resolution") && is_real(_sh.resolution) && _sh.resolution > 0) {
				_lc.setShadowResolution(clamp(round(_sh.resolution), 128, 4096));
			}
			if (variable_struct_exists(_sh, "distance") && is_real(_sh.distance) && _sh.distance > 0) {
				_lc.setShadowDistance(max(_sh.distance, 1));
			}
			if (variable_struct_exists(_sh, "normalOffset") && is_real(_sh.normalOffset) && _sh.normalOffset >= 0) {
				_lc.setShadowNormalOffset(clamp(_sh.normalOffset, 0, 1));
			}
		}
	} else if (_kind == "camera" && is_struct(_p.camera)) {
		var _cc = new GM3D_CameraComponent();
		_node.addComponent(_cc);
		var _c = _p.camera;
		_cc.setProjection(_c.projection == "ortho" ? GM3D_ECameraProjection.Orthographic : GM3D_ECameraProjection.Perspective);
		if (_c.projection == "ortho") {
			if (is_real(_c.orthoWidth) && _c.orthoWidth > 0) {
				_cc.setOrthoWidth(_c.orthoWidth);
			}
			if (is_real(_c.orthoHeight) && _c.orthoHeight > 0) {
				_cc.setOrthoHeight(_c.orthoHeight);
			}
		} else if (is_real(_c.fovY) && _c.fovY > 0) {
			_cc.setFovY(degtorad(clamp(_c.fovY, 1, 179)));
		}
		if (is_real(_c.near) && _c.near > 0) {
			_cc.setNear(_c.near);
		}
		if (is_real(_c.far) && _c.far > 0) {
			_cc.setFar(_c.far);
		}
		_cc.setEnabled(!variable_struct_exists(_c, "enabled") || _c.enabled == true);
	} else if (_kind == "environment" && is_struct(_p.environment)) {
		var _ec = new GM3D_EnvironmentVolumeComponent();
		_node.addComponent(_ec);
		var _e = _p.environment;
		if (is_array(_e.size) && array_length(_e.size) == 3) {
			_ec.setSize(new GM3D_Vec3(max(_e.size[0], 0.01), max(_e.size[1], 0.01), max(_e.size[2], 0.01)));
		}
		if (is_array(_e.ambient) && array_length(_e.ambient) == 3) {
			_ec.setAmbientColor(make_colour_rgb(clamp(_e.ambient[0], 0, 255), clamp(_e.ambient[1], 0, 255), clamp(_e.ambient[2], 0, 255)));
		}
		_ec.setFogEnabled(variable_struct_exists(_e, "fogEnabled") && _e.fogEnabled == true);
		if (is_array(_e.fogColor) && array_length(_e.fogColor) == 3) {
			_ec.setFogColor(make_colour_rgb(clamp(_e.fogColor[0], 0, 255), clamp(_e.fogColor[1], 0, 255), clamp(_e.fogColor[2], 0, 255)));
		}
		if (is_real(_e.fogStart)) {
			_ec.setFogStart(_e.fogStart);
		}
		if (is_real(_e.fogEnd)) {
			_ec.setFogEnd(_e.fogEnd);
		}
		_ec.setEnabled(!variable_struct_exists(_e, "enabled") || _e.enabled == true);
	} else {
		_node.destroy();
		return undefined;
	}
	return _node;
}

// Parses vector from descriptor with fallback.
function __gm3d_load_vec3(_p, _field, _fx, _fy, _fz) {
	var _a = _p[$ _field];
	if (is_array(_a) && array_length(_a) == 3 && is_real(_a[0]) && is_real(_a[1]) && is_real(_a[2])) {
		return new GM3D_Vec3(_a[0], _a[1], _a[2]);
	}
	return new GM3D_Vec3(_fx, _fy, _fz);
}

// Parses quaternion from descriptor with fallback.
function __gm3d_load_quat(_p) {
	var _a = _p.rotation;
	if (is_array(_a) && array_length(_a) == 4 && is_real(_a[0]) && is_real(_a[1]) && is_real(_a[2]) && is_real(_a[3])) {
		var _q = new GM3D_Quaternion();
		_q.x = _a[0];
		_q.y = _a[1];
		_q.z = _a[2];
		_q.w = _a[3];
		return _q.normalizeSafe(0.000001);
	}
	var _q0 = new GM3D_Quaternion();
	return _q0;
}

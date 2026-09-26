/// @module gm3d_ed_registry
/// Asset library, tracked placements, selection and labels.

/// Adds a loaded model handle to the Models library.
/// @param _model loaded handle spawned by the editor via spawnInto (caller owns loading)
function gm3d_editor_asset_add(_ed, _name, _model) {
	if (_ed == undefined) {
		return;
	}
	if (!variable_struct_exists(_ed, "assets") || !is_array(_ed.assets)) {
		_ed.assets = [];
	}
	if (_name == undefined || _name == "" || _model == undefined) {
		return;
	}
	array_push(_ed.assets, { name: _name, model: _model });
}

/// Clears the Models library.
function gm3d_editor_asset_clear(_ed) {
	if (_ed == undefined) {
		return;
	}
	_ed.assets = [];
}

/// Clears the selection and any gizmo hover/drag state.
function __gm3d_ed_sel_clear(_ed) {
	_ed.sel = [];
	_ed.giz.drag = -1;
	_ed.giz.hover = -1;
}

/// True when _node is in the current selection.
function __gm3d_ed_sel_has(_ed, _node) {
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		if (_ed.sel[_i] == _node) {
			return true;
		}
	}
	return false;
}

/// Adds _node to the selection, or removes it when already selected.
function __gm3d_ed_sel_toggle(_ed, _node) {
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		if (_ed.sel[_i] == _node) {
			array_delete(_ed.sel, _i, 1);
			return;
		}
	}
	array_push(_ed.sel, _node);
}

/// Finds a library model by name.
/// @return Model handle or undefined when missing.
function __gm3d_ed_asset_find(_ed, _name) {
	var _lib = _ed.assets;
	if (!is_array(_lib)) {
		return undefined;
	}
	for (var _i = 0; _i < array_length(_lib); _i++) {
		if (_lib[_i].name == _name) {
			return _lib[_i].model;
		}
	}

	return undefined;
}

/// Records a spawned placement by live name and position.
/// @param _pos3 [x, y, z] spawn position used for matching.
/// @param _label Display name, defaults to the live node name.
function __gm3d_ed_spawn_register(_ed, _node, _asset, _pos3, _label = undefined) {
	__gm3d_ed_kind_register(_ed, _node, "asset", _asset, _pos3, _label, undefined);
}

/// Records any tracked node (asset, light, camera, environment).
/// @param _kind "asset", "light", "camera" or "environment".
/// @param _asset library name for assets, "" otherwise.
/// @param _pos3 [x, y, z] spawn position used for matching.
/// @param _label Display name, defaults to the live node name.
/// @param _data kind props (light/camera/environment structs), undefined for assets.
function __gm3d_ed_kind_register(_ed, _node, _kind, _asset, _pos3, _label = undefined, _data = undefined) {
	if (_ed == undefined || _node == undefined) {
		return;
	}
	if (_kind == undefined || !is_string(_kind) || _kind == "") {
		_kind = "asset";
	}
	if (_kind == "asset" && (_asset == undefined || _asset == "")) {
		return;
	}
	if (!variable_struct_exists(_ed, "tracked") || !is_array(_ed.tracked)) {
		_ed.tracked = [];
	}
	var _nm = "node";
	_nm = _node.name;
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = _nm;
	}
	array_push(_ed.tracked, {
		kind: _kind,
		asset: _asset,
		name: _nm,
		label: _label,
		pos: _pos3 != undefined ? _pos3 : [0, 0, 0],
		data: _data,
		hidden: false,
	});
}

/// Spawns one library model into the live scene and tracks the placement.
/// Single funnel for every editor creation path (drop, duplicate, load):
/// the editor owns placement (spawnInto, TRS, registry entry). When the
/// adapter defines on_spawn(inst, node, asset, model), it runs after TRS so
/// the game can finish the instance (animation state, AI, ...) without
/// owning placement.
/// @param _asset library name for tracking.
/// @param _model loaded handle from gm3d_editor_asset_add.
/// @param _pos3 [x, y, z] spawn position.
/// @param _rot rotation quat or undefined for the spawn default.
/// @param _scale3 [sx, sy, sz] spawn scale.
/// @param _label display name, defaults to the live node name.
/// @return Spawned root node or undefined.
function __gm3d_ed_place(_ed, _asset, _model, _pos3, _rot, _scale3, _label = undefined) {
	if (_ed == undefined || _model == undefined) {
		return undefined;
	}
	var _node = _model.spawnInto(_ed.rt.scene, undefined);
	if (_node == undefined) {
		return undefined;
	}
	_node.setLocalPosition(new GM3D_Vec3(_pos3[0], _pos3[1], _pos3[2]));
	_node.setLocalScale(new GM3D_Vec3(_scale3[0], _scale3[1], _scale3[2]));
	if (_rot != undefined) {
		_node.setLocalRotation(_rot);
	}
	if (variable_struct_exists(_ed.rt, "on_spawn")) {
		_ed.rt.on_spawn(_ed.inst, _node, _asset, _model);
	}
	var _pp = _node.getLocalPosition();
	__gm3d_ed_spawn_register(_ed, _node, _asset, [_pp.x, _pp.y, _pp.z], _label);
	return _node;
}

/// Tracks a game-spawned node so it appears in Scene, Inspector, save and undo.
function gm3d_editor_track_node(_ed, _asset, _node, _label = undefined) {
	if (_ed == undefined || _node == undefined) {
		return;
	}
	var _pp = _node.getLocalPosition();
	__gm3d_ed_spawn_register(_ed, _node, _asset, [_pp.x, _pp.y, _pp.z], _label);
}

/// Returns a unique display label based on _base.
/// @return Free label (appends " 2", " 3", ...).
function __gm3d_ed_fresh_label(_ed, _base) {
	if (_base == undefined || !is_string(_base) || _base == "") {
		_base = "node";
	}
	var _reg = _ed.tracked;
	if (!is_array(_reg)) {
		return _base;
	}
	var _lbl = _base;
	var _n = 2;
	var _taken = true;
	while (_taken) {
		_taken = false;
		for (var _i = 0; _i < array_length(_reg); _i++) {
			if (_reg[_i].label == _lbl) {
				_taken = true;
				break;
			}
		}
		if (_taken) {
			_lbl = _base + " " + string(_n);
			_n++;
		}
	}
	return _lbl;
}

/// Re-points tracked rows at the live positions of moved nodes.
function __gm3d_ed_rows_follow(_ed, _nodes) {
	if (!is_array(_nodes)) {
		return;
	}
	for (var _i = 0; _i < array_length(_nodes); _i++) {
		var _en = __gm3d_ed_registry_find(_ed, _nodes[_i]);
		if (_en == undefined) {
			continue;
		}
		var _pp = _nodes[_i].getLocalPosition();
		_en.pos = [_pp.x, _pp.y, _pp.z];
	}
}

/// Drops the tracked entry nearest to a node.
function __gm3d_ed_spawn_unregister(_ed, _node) {
	var _reg = _ed.tracked;
	if (!is_array(_reg)) {
		return;
	}
	var _nm = _node.name;
	var _pp = _node.getLocalPosition();
	var _best = -1;
	var _bestd = 1000000000;
	for (var _k = 0; _k < array_length(_reg); _k++) {
		var _re = _reg[_k];
		if (_re.name != _nm) {
			continue;
		}
		var _d =
			(_re.pos[0] - _pp.x) * (_re.pos[0] - _pp.x) +
			(_re.pos[1] - _pp.y) * (_re.pos[1] - _pp.y) +
			(_re.pos[2] - _pp.z) * (_re.pos[2] - _pp.z);
		if (_d < _bestd) {
			_bestd = _d;
			_best = _k;
		}
	}
	if (_best >= 0) {
		array_delete(_reg, _best, 1);
	}
}

/// Finds the tracked entry for a node by live name and nearest position.
/// @return Tracked entry or undefined.
function __gm3d_ed_registry_find(_ed, _node) {
	var _reg = [];
	_reg = _ed.tracked;
	if (!is_array(_reg)) {
		return undefined;
	}
	var _nm = undefined;
	_nm = _node.name;
	var _pp = undefined;
	_pp = _node.getLocalPosition();
	var _best = undefined;
	var _bestd = 1000000000;
	for (var _j = 0; _j < array_length(_reg); _j++) {
		var _re = _reg[_j];
		if (_re.name != _nm) {
			continue;
		}
		var _dx = _re.pos[0] - _pp.x;
		var _dy = _re.pos[1] - _pp.y;
		var _dz = _re.pos[2] - _pp.z;
		var _d = _dx * _dx + _dy * _dy + _dz * _dz;
		if (_d < _bestd) {
			_bestd = _d;
			_best = _re;
		}
	}
	return _best;
}

/// Returns the library name for a node.
function __gm3d_ed_asset_name(_ed, _node) {
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en == undefined) {
		return undefined;
	}
	return _en.asset;
}

/// Returns the display label for a node, or the live node name when untracked.
function __gm3d_ed_label_get(_ed, _node) {
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en != undefined && is_string(_en.label) && _en.label != "") {
		return _en.label;
	}
	var _nm = "node";
	_nm = _node.name;
	return _nm;
}

/// Builds a serializable asset descriptor for a live node.
/// @return Descriptor or undefined when the library entry is missing.
function __gm3d_ed_asset_desc(_ed, _node) {
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en == undefined) {
		return undefined;
	}
	var _label = _en.label;
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = _node.name;
	}
	var _p = _node.getLocalPosition();
	var _q = _node.getLocalRotation();
	var _s = _node.getLocalScale();
	return {
		asset: _en.asset,
		name: _label,
		position: [_p.x, _p.y, _p.z],
		rotation: [_q.x, _q.y, _q.z, _q.w],
		scale: [_s.x, _s.y, _s.z],
	};
}

/// Returns root nodes that have a tracked registry entry.
function __gm3d_ed_root_tracked(_ed) {
	var _out = [];
	var _roots = _ed.rt.scene.getNodes();
	for (var _i = 0; _i < array_length(_roots); _i++) {
		var _nd = _roots[_i];
		if (_nd.parent != undefined) {
			continue;
		}
		if (__gm3d_ed_registry_find(_ed, _nd) == undefined) {
			continue;
		}
		array_push(_out, _nd);
	}
	return _out;
}

/// ---- Light / camera / environment kinds ----
/// Tracked/file/UI props use degrees for angles and [r, g, b] 0-255 for
/// colors; conversion to GM3D units (radians, packed color) happens in the
/// apply functions below.

/// Default light props.
function __gm3d_ed_light_defaults() {
	return { type: "directional", color: [255, 255, 255], intensity: 1.0, range: 50.0, inner: 30.0, outer: 45.0, enabled: true };
}

/// Default camera props.
function __gm3d_ed_camera_defaults() {
	return { projection: "perspective", fov: 60.0, ow: 10.0, oh: 10.0, near: 0.1, far: 500.0, enabled: true };
}

/// Default environment props.
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

/// Safe zero-arg component getter: returns _fb when missing or failing.
/// Some GM3D getters may not exist on every runtime; editor props then fall
/// back to the tracked data / defaults instead of crashing.
function __gm3d_ed_comp_get(_comp, _m, _fb) {
	if (_comp == undefined || !is_string(_m) || _m == "") {
		return _fb;
	}
	try {
		var _f = _comp[$ _m];
		if (_f == undefined) {
			return _fb;
		}
		return _f();
	} catch (_e) {
		return _fb;
	}
}

/// Maps a GM3D light type enum to its editor string.
function __gm3d_ed_light_type_to_str(_v) {
	try {
		if (_v == GM3D_ELightType.Point) {
			return "point";
		}
		if (_v == GM3D_ELightType.Spot) {
			return "spot";
		}
		if (_v == GM3D_ELightType.Directional) {
			return "directional";
		}
	} catch (_e) {
	}
	return undefined;
}

/// Maps an editor light type string to the GM3D enum.
function __gm3d_ed_light_type_to_enum(_s) {
	if (_s == "point") {
		return GM3D_ELightType.Point;
	}
	if (_s == "spot") {
		return GM3D_ELightType.Spot;
	}
	return GM3D_ELightType.Directional;
}

/// Maps a GM3D projection enum to its editor string.
function __gm3d_ed_cam_proj_to_str(_v) {
	try {
		if (_v == GM3D_ECameraProjection.Orthographic) {
			return "ortho";
		}
		if (_v == GM3D_ECameraProjection.Perspective) {
			return "perspective";
		}
	} catch (_e) {
	}
	return undefined;
}

/// Maps an editor projection string to the GM3D enum.
function __gm3d_ed_cam_proj_to_enum(_s) {
	if (_s == "ortho") {
		return GM3D_ECameraProjection.Orthographic;
	}
	return GM3D_ECameraProjection.Perspective;
}

/// Reads live light props into an editor struct (tracked-data shape).
function __gm3d_ed_light_read(_node) {
	var _d = __gm3d_ed_light_defaults();
	var _lc = undefined;
	try {
		_lc = _node.getLightComponent();
	} catch (_e) {
		return _d;
	}
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
	if (is_bool(_v)) {
		_d.enabled = _v;
	}
	return _d;
}

/// Pushes editor light props into the live component.
function __gm3d_ed_light_apply(_node, _d) {
	if (_node == undefined || _d == undefined) {
		return;
	}
	var _lc = undefined;
	try {
		_lc = _node.getLightComponent();
	} catch (_e) {
		return;
	}
	if (_lc == undefined) {
		return;
	}
	try {
		_lc.setType(__gm3d_ed_light_type_to_enum(_d.type));
	} catch (_e) {
	}
	try {
		var _cc = _d.color;
		_lc.setColor(make_colour_rgb(clamp(_cc[0], 0, 255), clamp(_cc[1], 0, 255), clamp(_cc[2], 0, 255)));
	} catch (_e) {
	}
	try {
		_lc.setIntensity(max(_d.intensity, 0));
	} catch (_e) {
	}
	if (_d.type != "directional") {
		try {
			_lc.setRange(max(_d.range, 0.01));
		} catch (_e) {
		}
	}
	if (_d.type == "spot") {
		try {
			_lc.setInnerConeAngle(degtorad(clamp(_d.inner, 0, 89)));
		} catch (_e) {
		}
		try {
			_lc.setOuterConeAngle(degtorad(clamp(_d.outer, 1, 89)));
		} catch (_e) {
		}
	}
	try {
		_lc.setEnabled(_d.enabled == true);
	} catch (_e) {
	}
}

/// Reads live camera props into an editor struct (tracked-data shape).
function __gm3d_ed_camera_read(_node) {
	var _d = __gm3d_ed_camera_defaults();
	var _cc = undefined;
	try {
		_cc = _node.getCameraComponent();
	} catch (_e) {
		return _d;
	}
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
	if (is_bool(_v)) {
		_d.enabled = _v;
	}
	return _d;
}

/// Pushes editor camera props into the live component.
function __gm3d_ed_camera_apply(_node, _d) {
	if (_node == undefined || _d == undefined) {
		return;
	}
	var _cc = undefined;
	try {
		_cc = _node.getCameraComponent();
	} catch (_e) {
		return;
	}
	if (_cc == undefined) {
		return;
	}
	try {
		_cc.setProjection(__gm3d_ed_cam_proj_to_enum(_d.projection));
	} catch (_e) {
	}
	if (_d.projection == "ortho") {
		try {
			_cc.setOrthoWidth(max(_d.ow, 0.01));
		} catch (_e) {
		}
		try {
			_cc.setOrthoHeight(max(_d.oh, 0.01));
		} catch (_e) {
		}
	} else {
		try {
			_cc.setFovY(degtorad(clamp(_d.fov, 1, 179)));
		} catch (_e) {
		}
	}
	try {
		_cc.setNear(max(_d.near, 0.01));
	} catch (_e) {
	}
	try {
		_cc.setFar(max(_d.far, _d.near + 0.01));
	} catch (_e) {
	}
	try {
		_cc.setEnabled(_d.enabled == true);
	} catch (_e) {
	}
}

/// Reads live environment props into an editor struct (tracked-data shape).
function __gm3d_ed_env_read(_node) {
	var _d = __gm3d_ed_env_defaults();
	var _ec = undefined;
	try {
		_ec = _node.getEnvironmentVolumeComponent();
	} catch (_e) {
		return _d;
	}
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
	var _v = __gm3d_ed_comp_get(_ec, "getFogEnabled", undefined);
	if (is_bool(_v)) {
		_d.fog = _v;
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
	if (is_bool(_v)) {
		_d.enabled = _v;
	}
	return _d;
}

/// Pushes editor environment props into the live component.
function __gm3d_ed_env_apply(_node, _d) {
	if (_node == undefined || _d == undefined) {
		return;
	}
	var _ec = undefined;
	try {
		_ec = _node.getEnvironmentVolumeComponent();
	} catch (_e) {
		return;
	}
	if (_ec == undefined) {
		return;
	}
	try {
		_ec.setSize(max(_d.size[0], 0.01), max(_d.size[1], 0.01), max(_d.size[2], 0.01));
	} catch (_e) {
	}
	try {
		var _ac = _d.ambient;
		_ec.setAmbientColor(make_colour_rgb(clamp(_ac[0], 0, 255), clamp(_ac[1], 0, 255), clamp(_ac[2], 0, 255)));
	} catch (_e) {
	}
	try {
		_ec.setFogEnabled(_d.fog == true);
	} catch (_e) {
	}
	try {
		var _fc = _d.fogcolor;
		_ec.setFogColor(make_colour_rgb(clamp(_fc[0], 0, 255), clamp(_fc[1], 0, 255), clamp(_fc[2], 0, 255)));
	} catch (_e) {
	}
	try {
		_ec.setFogStart(_d.fogstart);
	} catch (_e) {
	}
	try {
		_ec.setFogEnd(max(_d.fogend, _d.fogstart + 0.01));
	} catch (_e) {
	}
	try {
		_ec.setEnabled(_d.enabled == true);
	} catch (_e) {
	}
}

/// Returns the tracked kind of a node ("asset", "light", "camera",
/// "environment"), detecting untracked component nodes as fallback.
/// @return Kind string or undefined.
function __gm3d_ed_kind_of(_ed, _node) {
	if (_node == undefined) {
		return undefined;
	}
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en != undefined && is_string(_en.kind) && _en.kind != "") {
		return _en.kind;
	}
	try {
		if (_node.getLightComponent() != undefined) {
			return "light";
		}
	} catch (_e) {
	}
	try {
		if (_node.getCameraComponent() != undefined) {
			return "camera";
		}
	} catch (_e) {
	}
	try {
		if (_node.getEnvironmentVolumeComponent() != undefined) {
			return "environment";
		}
	} catch (_e) {
	}
	if (_en != undefined) {
		return "asset";
	}
	return undefined;
}

/// Tracks a game-created light node so it appears in Scene, Inspector, save and undo.
function gm3d_editor_light_add(_ed, _node, _label = undefined) {
	if (_ed == undefined || _node == undefined) {
		return undefined;
	}
	var _d = __gm3d_ed_light_read(_node);
	var _pp = _node.getLocalPosition();
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = __gm3d_ed_fresh_label(_ed, _node.name);
	}
	__gm3d_ed_kind_register(_ed, _node, "light", "", [_pp.x, _pp.y, _pp.z], _label, _d);
	return _node;
}

/// Tracks a game-created camera node so it appears in Scene, Inspector, save and undo.
function gm3d_editor_camera_add(_ed, _node, _label = undefined) {
	if (_ed == undefined || _node == undefined) {
		return undefined;
	}
	var _d = __gm3d_ed_camera_read(_node);
	var _pp = _node.getLocalPosition();
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = __gm3d_ed_fresh_label(_ed, _node.name);
	}
	__gm3d_ed_kind_register(_ed, _node, "camera", "", [_pp.x, _pp.y, _pp.z], _label, _d);
	__gm3d_ed_cameras_mute(_ed);
	return _node;
}

/// Tracks a game-created environment node so it appears in Scene, Inspector, save and undo.
function gm3d_editor_environment_add(_ed, _node, _label = undefined) {
	if (_ed == undefined || _node == undefined) {
		return undefined;
	}
	var _d = __gm3d_ed_env_read(_node);
	var _pp = _node.getLocalPosition();
	if (_label == undefined || !is_string(_label) || _label == "") {
		_label = __gm3d_ed_fresh_label(_ed, _node.name);
	}
	__gm3d_ed_kind_register(_ed, _node, "environment", "", [_pp.x, _pp.y, _pp.z], _label, _d);
	return _node;
}

/// Creates a light node with default props, tracks it and selects it; undoable.
/// @param _type "directional", "point" or "spot".
/// @return New node or undefined.
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
	__gm3d_ed_history_commit(_ed, _hb);
	return _node;
}

/// Creates a camera node with default props, tracks it and selects it; undoable.
/// @param _proj "perspective" or "ortho".
/// @return New node or undefined.
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

/// Creates the environment node with default props; undoable. No-op when one exists.
/// @return New node or undefined.
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
	_ed.sel = [_node];
	_ed.giz.drag = -1;
	__gm3d_ed_history_commit(_ed, _hb);
	return _node;
}

/// Returns the tracked environment node, or undefined.
function __gm3d_ed_env_node(_ed) {
	var _roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		if (__gm3d_ed_kind_of(_ed, _roots[_i]) == "environment") {
			return _roots[_i];
		}
	}
	return undefined;
}

/// Disables rendering of every tracked camera on the live scene.
/// While the editor is open only the viewport camera (ed.rt.cam, never
/// tracked) renders: editor cameras are manipulated, never previewed.
/// Tracked data keeps the game-side enabled flag untouched.
function __gm3d_ed_cameras_mute(_ed) {
	if (_ed == undefined || _ed.rt == undefined) {
		return;
	}
	var _roots = __gm3d_ed_root_tracked(_ed);
	for (var _i = 0; _i < array_length(_roots); _i++) {
		if (__gm3d_ed_kind_of(_ed, _roots[_i]) != "camera") {
			continue;
		}
		try {
			var _cc = _roots[_i].getCameraComponent();
			if (_cc != undefined) {
				_cc.setEnabled(false);
			}
		} catch (_e) {
		}
	}
}

/// Restores live camera rendering from the tracked enabled flags.
/// Call when the editor closes so the game resumes its own cameras.
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
		try {
			var _cc = _roots[_i].getCameraComponent();
			if (_cc != undefined) {
				_cc.setEnabled(_en.data.enabled == true);
			}
		} catch (_e) {
		}
	}
}

/// True when a gizmo tool can meaningfully edit a node.
/// Directional lights aim with rotation (position unused); point lights place
/// with position (rotation unused); scale never affects lights or cameras;
/// the environment ignores TRS entirely.
function __gm3d_ed_tool_allowed(_ed, _node, _tool) {
	if (_node == undefined) {
		return false;
	}
	var _kind = __gm3d_ed_kind_of(_ed, _node);
	if (_kind == undefined || _kind == "asset") {
		return true;
	}
	if (_kind == "environment") {
		return false;
	}
	if (_tool == Gm3dEdTool.Scale) {
		return false;
	}
	if (_kind == "camera") {
		return true;
	}
	var _type = "directional";
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en != undefined && is_struct(_en.data) && is_string(_en.data.type)) {
		_type = _en.data.type;
	}
	if (_tool == Gm3dEdTool.Translate) {
		return _type != "directional";
	}
	if (_tool == Gm3dEdTool.Rotate) {
		return _type != "point";
	}
	return true;
}

/// True when the current gizmo tool applies to at least one selected node.
function __gm3d_ed_gizmo_allowed(_ed) {
	if (_ed == undefined || !is_array(_ed.sel) || array_length(_ed.sel) == 0) {
		return false;
	}
	for (var _i = 0; _i < array_length(_ed.sel); _i++) {
		var _sn = _ed.sel[_i];
		if (__gm3d_ed_hidden_get(_ed, _sn)) {
			continue;
		}
		if (__gm3d_ed_tool_allowed(_ed, _sn, _ed.giz.tool)) {
			return true;
		}
	}
	return false;
}

/// True when a tracked node is hidden from viewport, picking and gizmo.
/// Editor-only: never serialized, toggled from the Scene context menu.
function __gm3d_ed_hidden_get(_ed, _node) {
	if (_ed == undefined || _node == undefined) {
		return false;
	}
	var _en = __gm3d_ed_registry_find(_ed, _node);
	return _en != undefined && _en.hidden == true;
}

/// Hides or shows a tracked node in the editor (mesh components off, helpers
/// off, unpickable, no gizmo). Game props and the save file are untouched.
/// @return True when the node is tracked.
function __gm3d_ed_hidden_set(_ed, _node, _hide) {
	if (_ed == undefined || _node == undefined) {
		return false;
	}
	var _en = __gm3d_ed_registry_find(_ed, _node);
	if (_en == undefined) {
		return false;
	}
	_en.hidden = (_hide == true);
	var _stack = [_node];
	while (array_length(_stack) > 0) {
		var _cur = array_pop(_stack);
		try {
			var _mc = _cur.getMeshComponent();
			if (_mc != undefined) {
				_mc.setEnabled(!_en.hidden);
			}
		} catch (_e) {
		}
		try {
			var _sk = _cur.getSkinnedMeshComponent();
			if (_sk != undefined) {
				_sk.setEnabled(!_en.hidden);
			}
		} catch (_e) {
		}
		var _kids = _cur.getChildren();
		for (var _k = 0; _k < array_length(_kids); _k++) {
			array_push(_stack, _kids[_k]);
		}
	}
	if (_ed.rt != undefined && _ed.rt.scene != undefined) {
		_ed.rt.scene.update(0);
	}
	return true;
}

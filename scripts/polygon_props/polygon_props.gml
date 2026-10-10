// polygon_props — light/camera/environment defaults, read/apply, creation.

// ---------------------------------------------------------------------------
// Defaults
// ---------------------------------------------------------------------------

// Returns default light property values.
function __polygon_light_defaults() {
  return {
    type: "directional",
    color: [ 255, 255, 255 ],
    intensity: 1.0,
    range: 50.0,
    inner: 30.0,
    outer: 45.0,
    enabled: true,
    shadow: false,
    shadowRes: 2048,
    shadowDist: 20.0,
    shadowNormal: 0.05,
  };
}

// Returns default camera property values.
function __polygon_camera_defaults() {
  return { projection: "perspective", fov: 60.0, ow: 10.0, oh: 10.0, near: 0.1, far: 500.0, enabled: true };
}

// Returns default environment property values.
function __polygon_env_defaults() {
  return {
    size: [ 20000.0, 20000.0, 20000.0 ],
    ambient: [ 70, 70, 85 ],
    fog: false,
    fogcolor: [ 192, 192, 192 ],
    fogstart: 20.0,
    fogend: 100.0,
    enabled: true,
  };
}

// ---------------------------------------------------------------------------
// Enum maps
// ---------------------------------------------------------------------------

// Converts light enum to string.
function __polygon_light_type_to_str(_v) {
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
function __polygon_light_type_to_enum(_s) {
  if (_s == "point") {
    return GM3D_ELightType.Point;
  }

  if (_s == "spot") {
    return GM3D_ELightType.Spot;
  }

  return GM3D_ELightType.Directional;
}

// Converts projection enum to string.
function __polygon_cam_proj_to_str(_v) {
  if (_v == GM3D_ECameraProjection.Orthographic) {
    return "ortho";
  }

  if (_v == GM3D_ECameraProjection.Perspective) {
    return "perspective";
  }

  return undefined;
}

// Converts projection string to enum.
function __polygon_cam_proj_to_enum(_s) {
  if (_s == "ortho") {
    return GM3D_ECameraProjection.Orthographic;
  }

  return GM3D_ECameraProjection.Perspective;
}

// ---------------------------------------------------------------------------
// Lights
// ---------------------------------------------------------------------------

// Reads an enabled-style flag (true/1) with fallback.
function __polygon_read_flag(_v, _cur) {
  return _v == undefined ? _cur : (_v == true || _v == 1);
}

// Reads light properties from node.
function __polygon_light_read(_node) {
  var _d = __polygon_light_defaults();
  var _lc = _node.getLightComponent();

  if (_lc == undefined) {
    return _d;
  }

  var _type = __polygon_light_type_to_str(_lc.getType());

  if (_type != undefined) {
    _d.type = _type;
  }

  var _col = _lc.getColor();

  if (is_real(_col)) {
    _d.color = [ colour_get_red(_col), colour_get_green(_col), colour_get_blue(_col) ];
  }

  var _val = _lc.getIntensity();

  if (is_real(_val)) {
    _d.intensity = _val;
  }

  _val = _lc.getRange();

  if (is_real(_val) && _val > 0) {
    _d.range = _val;
  }

  _val = _lc.getInnerConeAngle();

  if (is_real(_val)) {
    _d.inner = radtodeg(_val);
  }

  _val = _lc.getOuterConeAngle();

  if (is_real(_val)) {
    _d.outer = radtodeg(_val);
  }

  _d.enabled = __polygon_read_flag(_lc.getEnabled(), _d.enabled);
  _d.shadow = __polygon_read_flag(_lc.getShadowEnabled(), _d.shadow);

  _val = _lc.getShadowResolution();

  if (is_real(_val) && _val > 0) {
    _d.shadowRes = _val;
  }

  _val = _lc.getShadowDistance();

  if (is_real(_val) && _val > 0) {
    _d.shadowDist = _val;
  }

  _val = _lc.getShadowNormalOffset();

  if (is_real(_val) && _val >= 0) {
    _d.shadowNormal = _val;
  }

  return _d;
}

// Snaps a shadow map resolution to what LightComponent accepts:
// a power of two in [256, 8192]. Anything else throws at apply time.
function __polygon_shadow_res_snap(_v) {
  if (!is_real(_v)) {
    return 2048;
  }

  var _clamped = clamp(round(_v), 256, 8192);
  var _pow = 256;

  while (_pow * 2 <= _clamped) {
    _pow *= 2;
  }

  var _up = min(_pow * 2, 8192);

  if ((_up - _clamped) < (_clamped - _pow)) {
    _pow = _up;
  }

  return _pow;
}

// Applies light properties to node.
function __polygon_light_apply(_node, _d) {
  if (_node == undefined || _d == undefined) {
    return;
  }

  var _lc = _node.getLightComponent();

  if (_lc == undefined) {
    return;
  }

  _lc.setType(__polygon_light_type_to_enum(_d.type));
  _lc.setColor(make_colour_rgb(clamp(_d.color[0], 0, 255), clamp(_d.color[1], 0, 255), clamp(_d.color[2], 0, 255)));
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
    _lc.setShadowResolution(__polygon_shadow_res_snap(_d.shadowRes));
    _lc.setShadowDistance(max(_d.shadowDist, 1));
    _lc.setShadowNormalOffset(clamp(_d.shadowNormal, 0, 1));
  }

  if (global.polygon_inst.show_shadows == false) {
    _lc.setShadowEnabled(false);
  }
}

// Applies shadow preview override to tracked directionals.
function __polygon_shadowpreview_apply(_ed) {
  if (_ed == undefined) {
    return;
  }

  var _roots = __polygon_root_tracked(_ed);

  for (var _i = 0, _n = array_length(_roots); _i < _n; _i++) {
    var _node = _roots[_i];

    if (__polygon_kind_of(_ed, _node) != "light") {
      continue;
    }

    var _en = __polygon_registry_find(_ed, _node);

    if (_en == undefined || !is_struct(_en.data) || _en.data.type != "directional") {
      continue;
    }

    var _lc = _node.getLightComponent();

    if (_lc == undefined) {
      continue;
    }

    _lc.setShadowEnabled(_ed.show_shadows != false && _en.data.shadow == true);
  }

  _ed.view_dirty = true;
}

// Counts tracked lights (any type; shaders expose 8 slots total).
function __polygon_light_count(_ed) {
  var _n = 0;
  var _ens = __polygon_reg_each(_ed);

  for (var _i = 0, _nt = array_length(_ens); _i < _nt; _i++) {
    var _en = _ens[_i];

    if (is_struct(_en) && variable_struct_exists(_en, "kind") && _en.kind == "light") {
      _n++;
    }
  }

  return _n;
}

// Finds another light node with shadow maps enabled (single map only).
function __polygon_shadow_owner(_ed, _except) {
  if (_ed == undefined) {
    return undefined;
  }

  var _roots = __polygon_tracked_nodes(_ed);

  for (var _i = 0, _n = array_length(_roots); _i < _n; _i++) {
    var _node = _roots[_i];

    if (_node == undefined || __polygon_node_same(_node, _except)) {
      continue;
    }

    if (__polygon_kind_of(_ed, _node) != "light") {
      continue;
    }

    var _en = __polygon_registry_find(_ed, _node);

    if (_en != undefined && is_struct(_en.data) && _en.data.shadow == true) {
      return _node;
    }
  }

  return undefined;
}

// ---------------------------------------------------------------------------
// Cameras
// ---------------------------------------------------------------------------

// Reads camera properties from node.
function __polygon_camera_read(_node) {
  var _d = __polygon_camera_defaults();
  var _cc = _node.getCameraComponent();

  if (_cc == undefined) {
    return _d;
  }

  var _proj = __polygon_cam_proj_to_str(_cc.getProjection());

  if (_proj != undefined) {
    _d.projection = _proj;
  }

  var _val = _cc.getFovY();

  if (is_real(_val) && _val > 0) {
    _d.fov = radtodeg(_val);
  }

  _val = _cc.getOrthoWidth();

  if (is_real(_val) && _val > 0) {
    _d.ow = _val;
  }

  _val = _cc.getOrthoHeight();

  if (is_real(_val) && _val > 0) {
    _d.oh = _val;
  }

  _val = _cc.getNear();

  if (is_real(_val) && _val > 0) {
    _d.near = _val;
  }

  _val = _cc.getFar();

  if (is_real(_val) && _val > _d.near) {
    _d.far = _val;
  }

  _d.enabled = __polygon_read_flag(_cc.getEnabled(), _d.enabled);
  return _d;
}

// Applies camera properties to node.
function __polygon_camera_apply(_node, _d) {
  if (_node == undefined || _d == undefined) {
    return;
  }

  var _cc = _node.getCameraComponent();

  if (_cc == undefined) {
    return;
  }

  _cc.setProjection(__polygon_cam_proj_to_enum(_d.projection));

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

// Resolves gameplay camera: MainCamera label first, else first enabled, else first.
function __polygon_gamecam_resolve(_ed) {
  if (_ed == undefined) {
    return undefined;
  }

  var _pairs = __polygon_root_pairs(_ed);
  var _first = undefined;
  var _enabled = undefined;

  for (var _i = 0, _n = array_length(_pairs); _i < _n; _i++) {
    if (_pairs[_i].en.kind != "camera") {
      continue;
    }

    var _node = _pairs[_i].node;
    var _en = _pairs[_i].en;
    _first ??= _node;

    if (!is_struct(_en.data)) {
      continue;
    }

    if (is_string(_en.label) && _en.label == "MainCamera") {
      return _node;
    }

    if (_enabled == undefined && _en.data.enabled == true) {
      _enabled = _node;
    }
  }

  if (_enabled != undefined) {
    return _enabled;
  }

  return _first;
}

// Ensures a gameplay camera exists, creating a default one when missing.
function __polygon_gamecam_ensure(_ed) {
  var _found = __polygon_gamecam_resolve(_ed);

  if (_found != undefined) {
    return _found;
  }

  if (_ed == undefined || _ed.rt == undefined || _ed.rt.scene == undefined) {
    return undefined;
  }

  var _label = __polygon_fresh_label(_ed, "MainCamera");
  var _node = _ed.rt.scene.createNode(__polygon_wrap_new(_ed));

  if (_node == undefined) {
    return undefined;
  }

  _node.addComponent(new GM3D_CameraComponent());
  var _pos = [ 0, 2, 5 ];

  if (_ed.rt.cam != undefined) {
    var _seed = _ed.rt.cam.getWorldPosition();
    _pos = [ _seed.x, _seed.y, _seed.z ];
  }

  _node.setLocalPosition(new GM3D_Vec3(_pos[0], _pos[1], _pos[2]));
  var _data = __polygon_camera_defaults();
  __polygon_camera_apply(_node, _data);
  _ed.rt.scene.update(0);
  var _pp = _node.getLocalPosition();
  __polygon_kind_register(_ed, _node, "camera", "", [ _pp.x, _pp.y, _pp.z ], _label, _data);
  return _node;
}

// Disables all tracked scene cameras.
function __polygon_cameras_mute(_ed) {
  if (_ed == undefined || _ed.rt == undefined) {
    return;
  }

  var _roots = __polygon_root_tracked(_ed);

  for (var _i = 0, _n = array_length(_roots); _i < _n; _i++) {
    if (_roots[_i] == _ed.rt.cam) {
      continue;
    }

    if (__polygon_kind_of(_ed, _roots[_i]) != "camera") {
      continue;
    }

    var _cc = _roots[_i].getCameraComponent();

    if (_cc != undefined) {
      _cc.setEnabled(false);
    }
  }
}

// Restores tracked cameras enabled state.
function __polygon_cameras_restore(_ed) {
  if (_ed == undefined || _ed.rt == undefined) {
    return;
  }

  var _roots = __polygon_root_tracked(_ed);

  for (var _i = 0, _n = array_length(_roots); _i < _n; _i++) {
    var _en = __polygon_registry_find(_ed, _roots[_i]);

    if (_en == undefined || !is_struct(_en.data)) {
      continue;
    }

    if (__polygon_kind_of(_ed, _roots[_i]) != "camera") {
      continue;
    }

    var _cc = _roots[_i].getCameraComponent();

    if (_cc != undefined) {
      _cc.setEnabled(_en.data.enabled == true);
    }
  }
}

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------

// Reads environment properties from node.
function __polygon_env_read(_node) {
  var _d = __polygon_env_defaults();
  var _ec = _node.getEnvironmentVolumeComponent();

  if (_ec == undefined) {
    return _d;
  }

  var _size = _ec.getSize();

  if (is_array(_size) && array_length(_size) == 3) {
    _d.size = [ max(_size[0], 0.01), max(_size[1], 0.01), max(_size[2], 0.01) ];
  } else if (is_struct(_size) && variable_struct_exists(_size, "x")) {
    _d.size = [ max(_size.x, 0.01), max(_size.y, 0.01), max(_size.z, 0.01) ];
  }

  var _col = _ec.getAmbientColor();

  if (is_real(_col)) {
    _d.ambient = [ colour_get_red(_col), colour_get_green(_col), colour_get_blue(_col) ];
  }

  _d.fog = __polygon_read_flag(_ec.getFogEnabled(), _d.fog);

  _col = _ec.getFogColor();

  if (is_real(_col)) {
    _d.fogcolor = [ colour_get_red(_col), colour_get_green(_col), colour_get_blue(_col) ];
  }

  var _val = _ec.getFogStart();

  if (is_real(_val)) {
    _d.fogstart = _val;
  }

  _val = _ec.getFogEnd();

  if (is_real(_val)) {
    _d.fogend = _val;
  }

  _d.enabled = __polygon_read_flag(_ec.getEnabled(), _d.enabled);
  return _d;
}

// Applies environment properties to node.
function __polygon_env_apply(_node, _d) {
  if (_node == undefined || _d == undefined) {
    return;
  }

  var _ec = _node.getEnvironmentVolumeComponent();

  if (_ec == undefined) {
    return;
  }

  _ec.setSize(new GM3D_Vec3(max(_d.size[0], 0.01), max(_d.size[1], 0.01), max(_d.size[2], 0.01)));
  _ec.setAmbientColor(make_colour_rgb(clamp(_d.ambient[0], 0, 255), clamp(_d.ambient[1], 0, 255), clamp(_d.ambient[2], 0, 255)));
  _ec.setFogEnabled(_d.fog == true);
  _ec.setFogColor(make_colour_rgb(clamp(_d.fogcolor[0], 0, 255), clamp(_d.fogcolor[1], 0, 255), clamp(_d.fogcolor[2], 0, 255)));
  _ec.setFogStart(_d.fogstart);
  _ec.setFogEnd(max(_d.fogend, _d.fogstart + 0.01));
  _ec.setEnabled(_d.enabled == true);
}

// Finds tracked environment node.
function __polygon_env_node(_ed) {
  var _pairs = __polygon_root_pairs(_ed);

  for (var _i = 0, _n = array_length(_pairs); _i < _n; _i++) {
    if (_pairs[_i].en.kind == "environment") {
      return _pairs[_i].node;
    }
  }

  return undefined;
}

// ---------------------------------------------------------------------------
// Creation
// ---------------------------------------------------------------------------

// Registers a fresh node and selects it.
function __polygon_create_finish(_ed, _node, _kind, _label, _data) {
  _ed.rt.scene.update(0);
  var _pos = _node.getLocalPosition();
  __polygon_kind_register(_ed, _node, _kind, "", [ _pos.x, _pos.y, _pos.z ], _label, _data);
  _ed.sel = [ _node ];
  _ed.giz.drag = -1;
}

// Creates new light node in scene (wrapper carries id + component).
function __polygon_create_light(_ed, _type) {
  if (_ed == undefined || _ed.rt == undefined) {
    return undefined;
  }

  if (_type != "point" && _type != "spot") {
    _type = "directional";
  }

  var _before = __polygon_history_snap(_ed);
  var _base = _type == "point" ? "Point" : _type == "spot" ? "Spot" : "Directional";
  var _label = __polygon_fresh_label(_ed, _base);
  var _node = _ed.rt.scene.createNode(__polygon_wrap_new(_ed));

  if (_node == undefined) {
    return undefined;
  }

  _node.addComponent(new GM3D_LightComponent());

  if (_type == "directional") {
    _node.setLocalPosition(new GM3D_Vec3(0, 3, 0));
    _node.setLocalRotation(__polygon_euler_to_quat(degtorad(-50), 0, 0));
  } else {
    _node.setLocalPosition(new GM3D_Vec3(0, 2, 0));
  }

  var _data = __polygon_light_defaults();
  _data.type = _type;
  __polygon_light_apply(_node, _data);
  __polygon_create_finish(_ed, _node, "light", _label, _data);
  _ed.sel = [ _node ];
  _ed.giz.drag = -1;
  __polygon_sel_apply_tool(_ed);
  __polygon_history_commit(_ed, _before);
  return _node;
}

// Creates new camera node in scene (wrapper carries id + component).
function __polygon_create_camera(_ed, _proj) {
  if (_ed == undefined || _ed.rt == undefined) {
    return undefined;
  }

  if (_proj != "ortho") {
    _proj = "perspective";
  }

  var _before = __polygon_history_snap(_ed);
  var _label = __polygon_fresh_label(_ed, _proj == "ortho" ? "OrthoCam" : "Camera");
  var _node = _ed.rt.scene.createNode(__polygon_wrap_new(_ed));

  if (_node == undefined) {
    return undefined;
  }

  _node.addComponent(new GM3D_CameraComponent());
  _node.setLocalPosition(new GM3D_Vec3(0, 2, 5));
  var _data = __polygon_camera_defaults();
  _data.projection = _proj;
  __polygon_camera_apply(_node, _data);
  __polygon_create_finish(_ed, _node, "camera", _label, _data);
  _ed.sel = [ _node ];
  _ed.giz.drag = -1;
  __polygon_history_commit(_ed, _before);
  __polygon_cameras_mute(_ed);
  return _node;
}

// Creates new environment node in scene (wrapper carries id + component).
function __polygon_create_env(_ed) {
  if (_ed == undefined || _ed.rt == undefined) {
    return undefined;
  }

  if (__polygon_env_node(_ed) != undefined) {
    return undefined;
  }

  var _before = __polygon_history_snap(_ed);
  var _label = __polygon_fresh_label(_ed, "Environment");
  var _node = _ed.rt.scene.createNode(__polygon_wrap_new(_ed));

  if (_node == undefined) {
    return undefined;
  }

  _node.addComponent(new GM3D_EnvironmentVolumeComponent());
  var _data = __polygon_env_defaults();
  __polygon_env_apply(_node, _data);
  __polygon_create_finish(_ed, _node, "environment", _label, _data);
  __polygon_hidden_set(_ed, _node, true);
  _ed.sel = [ _node ];
  _ed.giz.drag = -1;
  __polygon_history_commit(_ed, _before);
  return _node;
}

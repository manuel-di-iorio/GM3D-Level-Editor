// polygon_serialize — descriptors, validation, rebuild, scene file IO.

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

// Resolves scene path to absolute path.
function __polygon_scene_path(_ed) {
  var _file = _ed.scene_file;

  if (_file == undefined || _file == "") {
    return "";
  }

  var _abs = string_pos(":", _file) > 0 || string_copy(_file, 1, 2) == "\\\\" || string_copy(_file, 1, 1) == "/";

  if (_abs) {
    return _file;
  }

  return working_directory + _file;
}

// Creates parent directory for path.
function __polygon_ensure_dir(_path) {
  var _at = max(string_last_pos("\\", _path), string_last_pos("/", _path));

  if (_at > 1) {
    directory_create(string_copy(_path, 1, _at - 1));
  }
}

// ---------------------------------------------------------------------------
// Descriptors
// ---------------------------------------------------------------------------

// Converts node to serializable descriptor skipping system.
function __polygon_node_to_descriptor(_ed, _node) {
  if (__polygon_is_grid(_ed, _node)) {
    return undefined;
  }

  if (_ed != undefined && variable_struct_exists(_ed, "rt") && is_struct(_ed.rt)) {
    if (variable_struct_exists(_ed.rt, "cam") && __polygon_node_same(_node, _ed.rt.cam)) {
      return undefined;
    }
  }

  if (_ed != undefined && variable_struct_exists(_ed, "drag_preview") && __polygon_node_same(_node, _ed.drag_preview)) {
    return undefined;
  }

  return __polygon_node_desc(_ed, _node);
}

// Converts tracked node to descriptor.
function __polygon_node_desc(_ed, _node) {
  var _en = __polygon_registry_find(_ed, _node);

  if (_en == undefined) {
    return undefined;
  }

  var _kind = __polygon_kind_of(_ed, _node);

  if (_kind == undefined) {
    return undefined;
  }

  if (_kind == "light" || _kind == "camera" || _kind == "environment") {
    return __polygon_prop_desc(_ed, _node, _kind);
  }

  var _asset = __polygon_asset_desc(_ed, _node);

  if (_asset == undefined) {
    return undefined;
  }

  return {
    kind: "instance",
    id: _asset.id,
    label: _asset.label,
    asset: _asset.asset,
    position: _asset.position,
    rotation: _asset.rotation,
    scale: _asset.scale,
    flags: _asset.flags,
  };
}

// Reads prop data from registry entry, else live from the node.
function __polygon_prop_data(_ed, _node, _kind) {
  var _en = __polygon_registry_find(_ed, _node);

  if (_en != undefined && is_struct(_en.data)) {
    return _en.data;
  }

  if (_kind == "light") {
    return __polygon_light_read(_node);
  } else if (_kind == "camera") {
    return __polygon_camera_read(_node);
  } else {
    return __polygon_env_read(_node);
  }
}

// Builds the light sub-descriptor.
function __polygon_light_desc(_pd) {
  return {
    type: _pd.type,
    color: [ _pd.color[0], _pd.color[1], _pd.color[2] ],
    intensity: _pd.intensity,
    range: _pd.range,
    innerCone: _pd.inner,
    outerCone: _pd.outer,
    enabled: _pd.enabled == true,
    shadow: {
      enabled: _pd.shadow == true,
      resolution: _pd.shadowRes,
      distance: _pd.shadowDist,
      normalOffset: _pd.shadowNormal,
    },
  };
}

// Builds the camera sub-descriptor.
function __polygon_camera_desc(_pd) {
  return {
    projection: _pd.projection,
    fovY: _pd.fov,
    orthoWidth: _pd.ow,
    orthoHeight: _pd.oh,
    near: _pd.near,
    far: _pd.far,
    enabled: _pd.enabled == true,
  };
}

// Builds the environment sub-descriptor.
function __polygon_env_desc(_pd) {
  return {
    size: [ _pd.size[0], _pd.size[1], _pd.size[2] ],
    ambient: [ _pd.ambient[0], _pd.ambient[1], _pd.ambient[2] ],
    fogEnabled: _pd.fog == true,
    fogColor: [ _pd.fogcolor[0], _pd.fogcolor[1], _pd.fogcolor[2] ],
    fogStart: _pd.fogstart,
    fogEnd: _pd.fogend,
    enabled: _pd.enabled == true,
  };
}

// Builds light camera environment descriptor.
function __polygon_prop_desc(_ed, _node, _kind) {
  var _en = __polygon_registry_find(_ed, _node);
  var _label = (_en != undefined && is_string(_en.label) && _en.label != "") ? _en.label : _node.name;
  var _id = (_en != undefined && is_string(_en.id)) ? _en.id : _node.name;
  var _pos = _node.getLocalPosition();
  var _rot = _node.getLocalRotation();
  var _sca = _node.getLocalScale();
  var _desc = {
    kind: _kind,
    id: _id,
    label: _label,
    asset: "",
    position: [ _pos.x, _pos.y, _pos.z ],
    rotation: [ _rot.x, _rot.y, _rot.z, _rot.w ],
    scale: [ _sca.x, _sca.y, _sca.z ],
  };
  var _data = __polygon_prop_data(_ed, _node, _kind);

  if (_kind == "light") {
    _desc.light = __polygon_light_desc(_data);
  } else if (_kind == "camera") {
    _desc.camera = __polygon_camera_desc(_data);
  } else {
    _desc.environment = __polygon_env_desc(_data);
  }

  return _desc;
}

// Serializes tracked nodes to descriptor array.
function __polygon_serialize_scene(_ed) {
  var _nodes = __polygon_tracked_nodes(_ed);
  var _out = [];

  for (var _i = 0, _n = array_length(_nodes); _i < _n; _i++) {
    var _desc = __polygon_node_to_descriptor(_ed, _nodes[_i]);

    if (_desc != undefined) {
      array_push(_out, _desc);
    }
  }

  return _out;
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

// Checks for a real-number field.
function __polygon_req_real(_s, _key) {
  return variable_struct_exists(_s, _key) && is_real(_s[$ _key]);
}

// Checks for a three-element array field.
function __polygon_req_vec3(_s, _key) {
  return variable_struct_exists(_s, _key) && is_array(_s[$ _key]) && array_length(_s[$ _key]) == 3;
}

// Checks for three number array.
function __polygon_is_num3(_d, _key) {
  if (!variable_struct_exists(_d, _key)) {
    return false;
  }

  var _arr = _d[$ _key];
  return is_array(_arr) && array_length(_arr) == 3 && is_real(_arr[0]) && is_real(_arr[1]) && is_real(_arr[2]);
}

// Checks for four number array.
function __polygon_is_num4(_d, _key) {
  if (!variable_struct_exists(_d, _key)) {
    return false;
  }

  var _arr = _d[$ _key];
  return is_array(_arr) && array_length(_arr) == 4 && is_real(_arr[0]) && is_real(_arr[1]) && is_real(_arr[2]) && is_real(_arr[3]);
}

// Validates light descriptor structure.
function __polygon_is_light_struct(_d) {
  if (!variable_struct_exists(_d, "light") || !is_struct(_d.light)) {
    return false;
  }

  var _lit = _d.light;

  if (!variable_struct_exists(_lit, "type") || !is_string(_lit.type)) {
    return false;
  }

  if (_lit.type != "directional" && _lit.type != "point" && _lit.type != "spot") {
    return false;
  }

  if (!__polygon_req_vec3(_lit, "color")) {
    return false;
  }

  if (!__polygon_req_real(_lit, "intensity") || !__polygon_req_real(_lit, "range")) {
    return false;
  }

  if (!__polygon_req_real(_lit, "innerCone") || !__polygon_req_real(_lit, "outerCone")) {
    return false;
  }

  if (variable_struct_exists(_lit, "shadow")) {
    if (!is_struct(_lit.shadow)) {
      return false;
    }

    var _sh = _lit.shadow;

    if (!variable_struct_exists(_sh, "enabled") || !is_bool(_sh.enabled)) {
      return false;
    }

    if (!__polygon_req_real(_sh, "resolution") || !__polygon_req_real(_sh, "distance") || !__polygon_req_real(_sh, "normalOffset")) {
      return false;
    }
  }

  return true;
}

// Validates camera descriptor structure.
function __polygon_is_camera_struct(_d) {
  if (!variable_struct_exists(_d, "camera") || !is_struct(_d.camera)) {
    return false;
  }

  var _cam = _d.camera;

  if (!variable_struct_exists(_cam, "projection") || !is_string(_cam.projection)) {
    return false;
  }

  if (_cam.projection != "perspective" && _cam.projection != "ortho") {
    return false;
  }

  if (!__polygon_req_real(_cam, "fovY") || !__polygon_req_real(_cam, "orthoWidth") || !__polygon_req_real(_cam, "orthoHeight")) {
    return false;
  }

  if (!__polygon_req_real(_cam, "near") || !__polygon_req_real(_cam, "far")) {
    return false;
  }

  return true;
}

// Validates environment descriptor structure.
function __polygon_is_env_struct(_d) {
  if (!variable_struct_exists(_d, "environment") || !is_struct(_d.environment)) {
    return false;
  }

  var _env = _d.environment;

  if (!__polygon_req_vec3(_env, "size") || !__polygon_req_vec3(_env, "ambient") || !__polygon_req_vec3(_env, "fogColor")) {
    return false;
  }

  if (!__polygon_req_real(_env, "fogStart") || !__polygon_req_real(_env, "fogEnd")) {
    return false;
  }

  return true;
}

// Validates scene descriptor array structure (strict v2: kind, id,
// label and asset are all required; no legacy name fallback).
function __polygon_validate_descs(_nodes) {
  if (!is_array(_nodes)) {
    return false;
  }

  for (var _i = 0, _n = array_length(_nodes); _i < _n; _i++) {
    var _desc = _nodes[_i];

    if (!is_struct(_desc)) {
      return false;
    }

    if (!variable_struct_exists(_desc, "kind") || !is_string(_desc.kind)) {
      return false;
    }

    if (!variable_struct_exists(_desc, "id") || !is_string(_desc.id) || _desc.id == "") {
      return false;
    }

    if (!variable_struct_exists(_desc, "label") || !is_string(_desc.label) || _desc.label == "") {
      return false;
    }

    if (!variable_struct_exists(_desc, "asset") || !is_string(_desc.asset)) {
      return false;
    }

    var _kind = _desc.kind;

    if (!__polygon_is_num3(_desc, "position") || !__polygon_is_num4(_desc, "rotation") || !__polygon_is_num3(_desc, "scale")) {
      return false;
    }

    if (_kind == "instance") {
      if (!__polygon_validate_asset_desc(_desc)) {
        return false;
      }
    } else if (_kind == "light") {
      if (!__polygon_is_light_struct(_desc)) {
        return false;
      }
    } else if (_kind == "camera") {
      if (!__polygon_is_camera_struct(_desc)) {
        return false;
      }
    } else if (_kind == "environment") {
      if (!__polygon_is_env_struct(_desc)) {
        return false;
      }
    } else {
      return false;
    }
  }

  return true;
}

// Validates asset descriptor flags (asset key required, non-empty).
function __polygon_validate_asset_desc(_desc) {
  if (!variable_struct_exists(_desc, "asset") || !is_string(_desc.asset) || _desc.asset == "") {
    return false;
  }

  if (variable_struct_exists(_desc, "flags")) {
    if (!is_struct(_desc.flags)) {
      return false;
    }

    if (!variable_struct_exists(_desc.flags, "castShadows") || !is_bool(_desc.flags.castShadows)) {
      return false;
    }

    if (!variable_struct_exists(_desc.flags, "receiveShadows") || !is_bool(_desc.flags.receiveShadows)) {
      return false;
    }
  }

  return true;
}

// ---------------------------------------------------------------------------
// Rebuild
// ---------------------------------------------------------------------------

// Clears tracked scene content, remembering hidden/locked ids.
function __polygon_rebuild_clear(_ed) {
  var _tracked = __polygon_root_tracked(_ed);
  var _hidden = [];
  var _locked = [];

  for (var _i = 0, _n = array_length(_tracked); _i < _n; _i++) {
    var _en = __polygon_registry_find(_ed, _tracked[_i]);

    if (_en != undefined && is_string(_en.id)) {
      if (_en.hidden == true) {
        array_push(_hidden, _en.id);
      }

      if (_en.locked == true) {
        array_push(_locked, _en.id);
      }
    }

    __polygon_destroy_subtree(_tracked[_i]);
  }

  _ed.rt.scene.update(0);
  __polygon_reg_clear(_ed);
  _ed.view_dirty = true;

  if (variable_struct_exists(_ed, "outline") && is_struct(_ed.outline)) {
    _ed.outline.cheap = undefined;
    _ed.outline.has = false;
  }

  return { hidden: _hidden, locked: _locked };
}

// Places one asset descriptor, applying saved shadow flags.
// The id is claimed before the wrapper is born (collisions get fresh).
function __polygon_rebuild_place_asset(_ed, _p, _key) {
  var _model = __polygon_asset_find(_ed, _key);

  if (_model == undefined) {
    throw "unknown model '" + string(_key) + "'";
  }

  var _id = __polygon_wrap_claim(_ed, _p.id);
  var _wrap = _ed.rt.scene.createNode(_id);

  if (_wrap == undefined) {
    throw "place failed for '" + string(_key) + "'";
  }

  var _child = _model.spawnInto(_ed.rt.scene, _wrap);

  if (_child == undefined) {
    _wrap.destroy();
    throw "place failed for '" + string(_key) + "'";
  }

  __polygon_spawn_reset_child(_child);
  __polygon_magenta_fix(_ed, _wrap);
  var _rot = __polygon_quat_from_array(_p.rotation);
  _wrap.setLocalPosition(new GM3D_Vec3(_p.position[0], _p.position[1], _p.position[2]));
  _wrap.setLocalScale(new GM3D_Vec3(_p.scale[0], _p.scale[1], _p.scale[2]));
  _wrap.setLocalRotation(_rot.normalizeSafe(0.000001));

  if (variable_struct_exists(_ed.rt, "on_spawn")) {
    _ed.rt.on_spawn(_wrap, _key, _model);
  }

  var _pp = _wrap.getLocalPosition();
  __polygon_spawn_register(_ed, _wrap, _key, [ _pp.x, _pp.y, _pp.z ], _p.label);
  var _root = _wrap;

  if (variable_struct_exists(_p, "flags") && is_struct(_p.flags)) {
    var _cast = _p.flags.castShadows == true;
    var _recv = _p.flags.receiveShadows == true;
    var _en = __polygon_registry_find(_ed, _root);

    if (_en != undefined) {
      _en.data = { castShadows: _cast, receiveShadows: _recv };
    }

    __polygon_flags_apply(_root, _cast, _recv);
  }
}

// Restores hidden/locked states by id after rebuild.
function __polygon_rebuild_restore_states(_ed, _states) {
  var _roots = __polygon_root_tracked(_ed);

  for (var _i = 0, _n = array_length(_roots); _i < _n; _i++) {
    var _en = __polygon_registry_find(_ed, _roots[_i]);

    if (_en == undefined || !is_string(_en.id)) {
      continue;
    }

    if (array_contains(_states.hidden, _en.id)) {
      __polygon_hidden_set(_ed, _roots[_i], true);
    }

    if (array_contains(_states.locked, _en.id)) {
      __polygon_locked_set(_ed, _roots[_i], true);
    }
  }
}

// Clears scene and rebuilds from descriptors.
function __polygon_rebuild(_ed, _nodes) {
  _ed.unlit_quiet = false;
  var _report = { placed: 0, failed: 0, err: "" };

  if (!is_array(_nodes)) {
    _nodes = [];
  }

  if (!__polygon_validate_descs(_nodes)) {
    throw "invalid descriptors";
  }

  __polygon_drop_preview_clear(_ed);
  var _states = __polygon_rebuild_clear(_ed);
  _ed.unlit_quiet = true;

  for (var _i = 0, _n = array_length(_nodes); _i < _n; _i++) {
    var _p = _nodes[_i];

    if (!is_struct(_p)) {
      continue;
    }

    var _kind = _p.kind;

    if (_kind == "light" || _kind == "camera" || _kind == "environment") {
      if (__polygon_rebuild_prop(_ed, _p, _kind) == undefined) {
        throw "place failed for '" + string(_p.id) + "'";
      }

      _report.placed++;
      continue;
    }

    if (_kind != "instance") {
      throw "unknown kind '" + string(_kind) + "'";
    }

    __polygon_rebuild_place_asset(_ed, _p, _p.asset);
    _report.placed++;
  }

  _ed.unlit_quiet = false;
  _ed.rt.scene.update(0);
  __polygon_seq_reseed(_ed);
  __polygon_gamecam_ensure(_ed);
  __polygon_cameras_mute(_ed);
  __polygon_unlit_apply(_ed);
  __polygon_rebuild_restore_states(_ed, _states);

  return _report;
}

// Reads light data from a descriptor (defaults + overrides).
function __polygon_rebuild_light_data(_p) {
  var _data = __polygon_light_defaults();
  var _lit = _p.light;
  _data.type = _lit.type;
  _data.color = [ _lit.color[0], _lit.color[1], _lit.color[2] ];
  _data.intensity = _lit.intensity;
  _data.range = _lit.range;
  _data.inner = _lit.innerCone;
  _data.outer = _lit.outerCone;
  _data.enabled = variable_struct_exists(_lit, "enabled") ? _lit.enabled == true : true;
  _data.shadow = false;
  _data.shadowRes = 2048;
  _data.shadowDist = 20.0;
  _data.shadowNormal = 0.05;

  if (variable_struct_exists(_lit, "shadow") && is_struct(_lit.shadow)) {
    var _sh = _lit.shadow;
    _data.shadow = variable_struct_exists(_sh, "enabled") ? _sh.enabled == true : false;

    if (variable_struct_exists(_sh, "resolution") && is_real(_sh.resolution) && _sh.resolution > 0) {
      _data.shadowRes = _sh.resolution;
    }

    if (variable_struct_exists(_sh, "distance") && is_real(_sh.distance) && _sh.distance > 0) {
      _data.shadowDist = _sh.distance;
    }

    if (variable_struct_exists(_sh, "normalOffset") && is_real(_sh.normalOffset) && _sh.normalOffset >= 0) {
      _data.shadowNormal = _sh.normalOffset;
    }
  }

  return _data;
}

// Reads camera data from a descriptor.
function __polygon_rebuild_camera_data(_p) {
  var _data = __polygon_camera_defaults();
  var _cam = _p.camera;
  _data.projection = _cam.projection;
  _data.fov = _cam.fovY;
  _data.ow = _cam.orthoWidth;
  _data.oh = _cam.orthoHeight;
  _data.near = _cam.near;
  _data.far = _cam.far;
  _data.enabled = variable_struct_exists(_cam, "enabled") ? _cam.enabled == true : true;
  return _data;
}

// Reads environment data from a descriptor.
function __polygon_rebuild_env_data(_p) {
  var _data = __polygon_env_defaults();
  var _env = _p.environment;
  _data.size = [ _env.size[0], _env.size[1], _env.size[2] ];
  _data.ambient = [ _env.ambient[0], _env.ambient[1], _env.ambient[2] ];
  _data.fog = variable_struct_exists(_env, "fogEnabled") ? _env.fogEnabled == true : false;
  _data.fogcolor = [ _env.fogColor[0], _env.fogColor[1], _env.fogColor[2] ];
  _data.fogstart = _env.fogStart;
  _data.fogend = _env.fogEnd;
  _data.enabled = variable_struct_exists(_env, "enabled") ? _env.enabled == true : true;
  return _data;
}

// Rebuilds light camera environment node (wrapper carries id).
function __polygon_rebuild_prop(_ed, _p, _kind) {
  var _rot = __polygon_quat_from_array(_p.rotation);
  var _node = _ed.rt.scene.createNode(__polygon_wrap_claim(_ed, _p.id));

  if (_node == undefined) {
    return undefined;
  }

  _node.setLocalPosition(new GM3D_Vec3(_p.position[0], _p.position[1], _p.position[2]));
  _node.setLocalScale(new GM3D_Vec3(_p.scale[0], _p.scale[1], _p.scale[2]));
  _node.setLocalRotation(_rot.normalizeSafe(0.000001));
  var _data = undefined;

  if (_kind == "light") {
    _node.addComponent(new GM3D_LightComponent());
    _data = __polygon_rebuild_light_data(_p);
    __polygon_light_apply(_node, _data);
  } else if (_kind == "camera") {
    _node.addComponent(new GM3D_CameraComponent());
    _data = __polygon_rebuild_camera_data(_p);
    __polygon_camera_apply(_node, _data);
  } else {
    _node.addComponent(new GM3D_EnvironmentVolumeComponent());
    _data = __polygon_rebuild_env_data(_p);
    __polygon_env_apply(_node, _data);
  }

  _ed.rt.scene.update(0);
  var _pos = _node.getLocalPosition();
  __polygon_kind_register(_ed, _node, _kind, "", [ _pos.x, _pos.y, _pos.z ], _p.label, _data);

  if (_kind == "environment") {
    __polygon_hidden_set(_ed, _node, true);
  }

  if (_kind == "light" && is_struct(_data) && variable_struct_exists(_data, "type") && _data.type == "directional") {
    __polygon_hidden_set(_ed, _node, true);
  }

  return _node;
}

// ---------------------------------------------------------------------------
// Load and save
// ---------------------------------------------------------------------------

// Writes serialized scene to JSON file (v2: seq + id/label/asset).
function __polygon_save_scene(_ed) {
  __polygon_reg_ensure(_ed);
  var _nodes = __polygon_serialize_scene(_ed);
  var _json = json_stringify({ version: 2, seq: _ed.id_seq, nodes: _nodes }, true);
  var _path = __polygon_scene_path(_ed);

  if (_path == "") {
    return false;
  }

  __polygon_ensure_dir(_path);

  if (!__polygon_write_text_file(_path, _json)) {
    return false;
  }

  _ed.dirty = false;
  return true;
}

// Loads scene JSON into editor.
function __polygon_load_scene(_ed) {
  var _path = __polygon_scene_path(_ed);

  if (_path == "" || !file_exists(_path)) {
    return false;
  }

  var _json = __polygon_read_text_file(_path);

  if (_json == "") {
    return false;
  }

  var _data = json_parse(_json);
  var _ok = is_struct(_data) && _data.version == 2 && variable_struct_exists(_data, "nodes") && is_array(_data.nodes);

  if (!_ok) {
    return false;
  }

  if (variable_struct_exists(_data, "seq") && is_real(_data.seq)) {
    __polygon_reg_ensure(_ed);
    _ed.id_seq = max(_ed.id_seq, floor(_data.seq));
  }

  __polygon_rebuild(_ed, _data.nodes);
  __polygon_viewcam_seed(_ed);
  _ed.sel = [];
  _ed.giz.drag = -1;
  _ed.giz.hover = -1;
  __polygon_history_clear(_ed);
  _ed.dirty = false;
  return true;
}

// ---------------------------------------------------------------------------
// File IO
// ---------------------------------------------------------------------------

// Reads whole text file contents.
function __polygon_read_text_file(_path) {
  if (_path == "" || !file_exists(_path)) {
    return "";
  }

  var _file = file_text_open_read(_path);

  if (_file < 0) {
    return "";
  }

  var _out = "";

  while (!file_text_eof(_file)) {
    _out += file_text_read_string(_file);
    file_text_readln(_file);
  }

  file_text_close(_file);
  return _out;
}

// Writes text to file.
function __polygon_write_text_file(_path, _txt) {
  var _file = file_text_open_write(_path);

  if (_file < 0) {
    return false;
  }

  file_text_write_string(_file, _txt);
  file_text_close(_file);
  return file_exists(_path);
}

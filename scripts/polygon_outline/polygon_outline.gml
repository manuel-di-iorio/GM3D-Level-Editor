// polygon_outline — selection outline mask capture and glow composite.

// ---------------------------------------------------------------------------
// State and materials
// ---------------------------------------------------------------------------

// Gets or creates outline state.
function __polygon_outline_cfg(_ed) {
  if (_ed == undefined) {
    return undefined;
  }

  if (!variable_struct_exists(_ed, "outline") || !is_struct(_ed.outline)) {
    _ed.outline = {
      mask: undefined,
      mw: 0,
      mh: 0,
      has: false,
      white: undefined,
      whiteSkin: undefined,
      mats_ok: undefined,
      warned: false,
      warmed: false,
      color: [ 0.369, 0.467, 0.608 ], // #5E779B (was orange [1.0, 0.55, 0.1], keep for future use)
      thickness: 1,
      strength: 1.5,
      glow: 0.75,
      threshold: 0.9,
      sig: undefined,
    };
  }

  return _ed.outline;
}

// Logs outline warning once.
function __polygon_outline_warn(_ed, _o, _msg) {
  if (_o.warned) {
    return;
  }

  _o.warned = true;
}

// Ensures outline mask materials exist.
function __polygon_outline_mats(_ed, _o) {
  if (_o.mats_ok == true && _o.white != undefined && _o.whiteSkin != undefined) {
    return true;
  }

  if (_o.mats_ok == false) {
    return false;
  }

  var _flat = new GM3D_Material("polygon_mask");
  _flat.setShader(GM3D_ERenderPass.Forward, shPolygonEditorMask);
  var _skin = new GM3D_Material("polygon_mask_skin");
  _skin.setShader(GM3D_ERenderPass.Forward, shPolygonEditorMaskSkin);
  _o.white = _flat;
  _o.whiteSkin = _skin;
  _o.mats_ok = true;
  return true;
}

// Preinitializes outline materials and surface.
function __polygon_outline_warmup(_ed, _o) {
  if (variable_struct_exists(_o, "warmed") && _o.warmed == true) {
    return;
  }

  _o.warmed = true;

  if (!__polygon_outline_mats(_ed, _o)) {
    return;
  }

  if (application_surface == undefined || !surface_exists(application_surface)) {
    return;
  }

  __polygon_outline_mask_surface(_ed, _o, _ed.scene_w, _ed.scene_h);
}

// Frees outline surfaces and materials.
function __polygon_outline_cleanup(_ed) {
  if (_ed == undefined || !variable_struct_exists(_ed, "outline") || !is_struct(_ed.outline)) {
    return;
  }

  var _o = _ed.outline;

  if (_o.mask != undefined && surface_exists(_o.mask)) {
    surface_free(_o.mask);
  }

  if (_o.white != undefined) {
    _o.white.destroy();
  }

  if (_o.whiteSkin != undefined) {
    _o.whiteSkin.destroy();
  }

  _ed.outline = undefined;
}

// ---------------------------------------------------------------------------
// Mask surface
// ---------------------------------------------------------------------------

// Ensures outline mask surface size (old size retired, never freed live:
// the mask is a render target of this frame's not-yet-submitted commands).
function __polygon_outline_mask_surface(_ed, _o, _w, _h) {
  if (_w <= 0 || _h <= 0) {
    return false;
  }

  if (_o.mask != undefined && surface_exists(_o.mask) && _o.mw == _w && _o.mh == _h) {
    return true;
  }

  if (_o.mask != undefined && surface_exists(_o.mask)) {
    __polygon_surf_retire(_ed, _o.mask);
  }

  _o.mask = undefined;
  _o.mw = 0;
  _o.mh = 0;
  _o.mask = surface_create(_w, _h);
  _o.mw = _w;
  _o.mh = _h;

  if (!surface_exists(_o.mask)) {
    _o.mask = undefined;
    return false;
  }

  return true;
}

// ---------------------------------------------------------------------------
// Node processing
// ---------------------------------------------------------------------------

// Checks whether an entry was marked for this outline capture.
function __polygon_outline_is_sel(_entry, _epoch) {
  if (_entry == undefined) {
    return false;
  }

  return variable_struct_exists(_entry, "__polygon_outline_epoch") && variable_struct_get(_entry, "__polygon_outline_epoch") == _epoch;
}

// Disables one component, recording it for restore.
function __polygon_outline_mute_comp(_comp, _muted) {
  if (_comp == undefined || !_comp.getEnabled()) {
    return;
  }

  _comp.setEnabled(false);
  array_push(_muted, { comp: _comp, was: true });
}

// Swaps one component to the mask material, recording the original.
function __polygon_outline_swap_comp(_comp, _skinned, _o, _swapped) {
  if (_comp == undefined) {
    return;
  }

  var _orig = _comp.getMaterial();

  if (_orig == undefined || _orig == _o.white || _orig == _o.whiteSkin) {
    return;
  }

  array_push(_swapped, { comp: _comp, orig: _orig });
  _comp.setMaterial(_skinned ? _o.whiteSkin : _o.white);
}

// Mutes both mesh components of a node.
function __polygon_outline_mute_node(_node, _muted) {
  __polygon_outline_mute_comp(_node.getMeshComponent(), _muted);
  __polygon_outline_mute_comp(_node.getSkinnedMeshComponent(), _muted);
}

// Applies the mask state to one node using root metadata resolved once per tree.
function __polygon_outline_process_node(_node, _entry, _excluded, _sel_epoch, _o, _swapped, _muted) {
  if (_excluded || !__polygon_outline_is_sel(_entry, _sel_epoch)) {
    __polygon_outline_mute_node(_node, _muted);
    return;
  }

  __polygon_outline_swap_comp(_node.getMeshComponent(), false, _o, _swapped);
  __polygon_outline_swap_comp(_node.getSkinnedMeshComponent(), true, _o, _swapped);
}

// Walks one root tree applying mask state.
function __polygon_outline_walk_tree(_root, _entry, _excluded, _sel_epoch, _o, _swapped, _muted) {
  var _stack = [ _root ];

  while (array_length(_stack) > 0) {
    var _cur = array_pop(_stack);

    if (_cur == undefined) {
      continue;
    }

    __polygon_outline_process_node(_cur, _entry, _excluded, _sel_epoch, _o, _swapped, _muted);
    var _kids = _cur.getChildren();

    for (var _k = array_length(_kids) - 1; _k >= 0; _k--) {
      array_push(_stack, _kids[_k]);
    }
  }
}

// ---------------------------------------------------------------------------
// Fast cache key
// ---------------------------------------------------------------------------

// Appends a vec3 to the outline cache key.
function __polygon_key_vec3(_key, _tag, _v) {
  return _key + _tag + string(_v.x) + "," + string(_v.y) + "," + string(_v.z);
}

// Appends one subtree (transforms + mesh states) to the outline cache key.
function __polygon_outline_node_key(_key, _root) {
  var _scan = [ _root ];

  while (array_length(_scan) > 0) {
    var _cur = array_pop(_scan);

    if (_cur == undefined) {
      continue;
    }

    var _pos = _cur.getLocalPosition();
    var _rot = _cur.getLocalRotation();
    var _sca = _cur.getLocalScale();
    var _mesh = _cur.getMeshComponent();
    var _skin = _cur.getSkinnedMeshComponent();
    _key += "|n" + string(_cur.name);
    _key = __polygon_key_vec3(_key, "p", _pos);
    _key += "q" + string(_rot.x) + "," + string(_rot.y) + "," + string(_rot.z) + "," + string(_rot.w);
    _key = __polygon_key_vec3(_key, "s", _sca);
    _key += "e" + string(_mesh != undefined ? _mesh.getEnabled() : false);
    _key += "k" + string(_skin != undefined ? _skin.getEnabled() : false);
    var _kids = _cur.getChildren();

    for (var _k = array_length(_kids) - 1; _k >= 0; --_k) {
      array_push(_scan, _kids[_k]);
    }
  }

  return _key;
}

// Appends the live camera pose to the outline cache key.
// 5 decimals like the view key: string() rounds to 2, so slow orbit steps
// (0.18 deg/px) would not flip the key and the mask would lag behind.
function __polygon_outline_cam_key(_key, _ed) {
  var _cam = undefined;

  if (_ed.viewcam != undefined) {
    _cam = _ed.viewcam;
  } else if (_ed.rt != undefined) {
    _cam = _ed.rt.cam;
  }

  if (_cam == undefined) {
    return _key;
  }

  var _pos = _cam.getLocalPosition();

  if (_pos != undefined) {
    _key += string_format(_pos.x, 0, 5) + "," + string_format(_pos.y, 0, 5) + "," + string_format(_pos.z, 0, 5) + "|";
  }

  var _rot = _cam.getLocalRotation();

  if (_rot != undefined) {
    _key += string_format(_rot.x, 0, 5) + "," + string_format(_rot.y, 0, 5) + "," + string_format(_rot.z, 0, 5) + "," + string_format(_rot.w, 0, 5) + "|";
  }

  return _key;
}

// Builds tiny pre-check key (camera, sizes, sel count, drag, tracked count).
// Returns undefined when it cannot be built reliably (forces full path).
function __polygon_outline_fast(_ed) {
  if (!is_array(_ed.sel) || _ed.vp == undefined) {
    return undefined;
  }

  var _vp = _ed.vp;
  var _dragging = variable_struct_exists(_ed, "giz") && is_struct(_ed.giz) && _ed.giz.drag != -1;
  var _tracked = __polygon_reg_count(_ed);
  var _key = __polygon_outline_cam_key("", _ed);
  _key += "|p" + string(_vp.fovY) + "," + string(_vp.near) + "," + string(_vp.far);
  _key += "," + string(_vp.winW) + "x" + string(_vp.winH);
  _key += "|s" + string(array_length(_ed.sel)) + "d" + string(_dragging ? 1 : 0);
  _key += "|t" + string(_tracked) + "|v" + string(_ed.scene_w) + "x" + string(_ed.scene_h);

  for (var _i = 0, _n = array_length(_ed.sel); _i < _n; _i++) {
    var _node = _ed.sel[_i];

    if (_node == undefined) {
      _key += "|x";
      continue;
    }

    var _en = __polygon_registry_find(_ed, _node);

    if (_en == undefined) {
      _key += "|?";
      continue;
    }

    // Include all selected subtree transforms and mesh enabled state.
    _key = __polygon_outline_node_key(_key, _node);
    _key += _en.hidden == true ? "h" : "v";
  }

  return _key;
}

// ---------------------------------------------------------------------------
// Capture and composite
// ---------------------------------------------------------------------------

// Marks selected asset entries for this capture, returning the count.
function __polygon_outline_mark_sel(_ed, _epoch) {
  var _count = 0;

  if (!is_array(_ed.sel)) {
    return 0;
  }

  for (var _i = 0, _n = array_length(_ed.sel); _i < _n; _i++) {
    var _node = _ed.sel[_i];

    if (_node == undefined || __polygon_hidden_get(_ed, _node)) {
      continue;
    }

    if (__polygon_kind_of(_ed, _node) != "instance") {
      continue;
    }

    var _en = __polygon_registry_find(_ed, _node);

    if (_en != undefined && !__polygon_outline_is_sel(_en, _epoch)) {
      variable_struct_set(_en, "__polygon_outline_epoch", _epoch);
      _count++;
    }
  }

  return _count;
}

// Renders selection mask for outline.
function __polygon_outline_capture(_ed) {
  if (_ed == undefined || _ed.active != true) {
    return;
  }

  if (!__polygon_scene_panel_open(_ed)) {
    return;
  }

  var _o = __polygon_outline_cfg(_ed);

  if (_o == undefined) {
    return;
  }

  if (_ed.rt == undefined || _ed.rt.scene == undefined || _ed.renderer == undefined) {
    return;
  }

  __polygon_outline_warmup(_ed, _o);

  // Cheap pre-check BEFORE invalidating has: camera, sizes, selection,
  // drag state and counts. While gizmo-dragging the selection moves every
  // frame, so the full path always runs then.
  var _dragging = variable_struct_exists(_ed, "giz") && is_struct(_ed.giz) && _ed.giz.drag != -1;
  var _fast = _dragging ? undefined : __polygon_outline_fast(_ed);

  if (_fast != undefined && variable_struct_exists(_o, "fast") && _o.fast == _fast && _o.has && _o.mask != undefined && surface_exists(_o.mask)) {
    return;
  }

  _o.has = false;
  _o.fast = _fast;

  if (!variable_struct_exists(_o, "sel_epoch")) {
    _o.sel_epoch = 0;
  }

  _o.sel_epoch++;
  var _epoch = _o.sel_epoch;

  if (__polygon_outline_mark_sel(_ed, _epoch) == 0) {
    _o.sig = undefined;
    return;
  }

  if (!__polygon_outline_mats(_ed, _o)) {
    return;
  }

  if (application_surface == undefined || !surface_exists(application_surface)) {
    return;
  }

  var _w = _ed.scene_w;
  var _h = _ed.scene_h;

  if (!(_w > 0) || !(_h > 0)) {
    return;
  }

  // Freeze the outline while the requested size is still changing (active
  // resize): allocating + rendering a fresh mask every frame gets its depth
  // texture destroyed inside the pending submit. Render once it settles.
  var _settled = variable_struct_exists(_o, "req_w") && variable_struct_exists(_o, "req_h") && _o.req_w == _w && _o.req_h == _h;
  _o.req_w = _w;
  _o.req_h = _h;

  if (!_settled) {
    return;
  }

  if (!__polygon_outline_mask_surface(_ed, _o, _w, _h)) {
    return;
  }

  var _grid = variable_struct_exists(_ed, "grid_node") ? _ed.grid_node : undefined;
  var _preview = variable_struct_exists(_ed, "drag_preview") ? _ed.drag_preview : undefined;
  var _swapped = [];
  var _muted = [];
  var _nodes = _ed.rt.scene.getNodes();

  for (var _r = 0, _nn = array_length(_nodes); _r < _nn; _r++) {
    var _root = _nodes[_r];

    if (_root == undefined || _root.parent != undefined) {
      continue;
    }

    var _entry = __polygon_registry_find(_ed, _root);
    var _excluded = (_grid != undefined && _root == _grid) || (_preview != undefined && _root == _preview);
    __polygon_outline_walk_tree(_root, _entry, _excluded, _epoch, _o, _swapped, _muted);
  }

  surface_set_target(_o.mask);
  draw_clear(c_black);
  // Refresh world matrices: the camera moved in step after the last
  // scene.update, so without this the mask lags one move behind the
  // main render (visible as jitter while orbiting).
  _ed.rt.scene.update(0);
  _ed.renderer.render(_ed.rt.scene);
  surface_reset_target();
  _o.has = true;
  _o.sig = _o.fast;
  // Fresh mask: force the main surface to re-render so it gets
  // composited. Without this, a mask that becomes ready on a frame where
  // the view key does not change (e.g. selecting in a still viewport)
  // would sit unseen until the next camera move.
  _ed.view_dirty = true;

  __polygon_walk_restore(_swapped, _muted);
}

// Reads one outline shader uniform handle.
function __polygon_outline_uniform(_name) {
  return shader_get_uniform(shPolygonEditorOutline, _name);
}

// Draws outline glow from mask.
function __polygon_outline_composite(_ed) {
  if (_ed == undefined || _ed.active != true) {
    return;
  }

  if (!variable_struct_exists(_ed, "outline") || !is_struct(_ed.outline)) {
    return;
  }

  var _o = _ed.outline;

  if (!_o.has || _o.mask == undefined || !surface_exists(_o.mask)) {
    return;
  }

  var _gw = _ed.scene_w;
  var _gh = _ed.scene_h;

  if (!(_gw > 0) || !(_gh > 0)) {
    return;
  }

  var _u_color = __polygon_outline_uniform("u_color");
  var _u_texel = __polygon_outline_uniform("u_texel");
  var _u_thick = __polygon_outline_uniform("u_thickness");
  var _u_strength = __polygon_outline_uniform("u_strength");
  var _u_glow = __polygon_outline_uniform("u_glow");
  var _u_thresh = __polygon_outline_uniform("u_threshold");
  var _was_blend = gpu_get_blendenable();
  shader_set(shPolygonEditorOutline);

  if (_u_color != -1) {
    shader_set_uniform_f(_u_color, _o.color[0], _o.color[1], _o.color[2]);
  }

  if (_u_texel != -1 && _o.mw > 0 && _o.mh > 0) {
    shader_set_uniform_f(_u_texel, 1.0 / _o.mw, 1.0 / _o.mh);
  }

  if (_u_thick != -1) {
    shader_set_uniform_f(_u_thick, _o.thickness);
  }

  if (_u_strength != -1) {
    shader_set_uniform_f(_u_strength, _o.strength);
  }

  if (_u_glow != -1) {
    shader_set_uniform_f(_u_glow, _o.glow);
  }

  if (_u_thresh != -1) {
    shader_set_uniform_f(_u_thresh, _o.threshold);
  }

  gpu_set_blendenable(true);
  draw_surface_stretched(_o.mask, 0, 0, _gw, _gh);
  shader_reset();
  gpu_set_blendenable(_was_blend);
  draw_set_alpha(1);
  draw_set_color(c_white);
}

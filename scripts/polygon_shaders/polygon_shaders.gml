// polygon_shaders — shader providers, unlit preview mode, magenta fallbacks.

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

// Returns list of editor shaders.
function __polygon_editor_shaders() {
  return [
    shPolygonEditorGrid, shPolygonEditorMask, shPolygonEditorMaskSkin, shPolygonEditorOutline, shPolygonEditorId, shPolygonEditorIdSkin, shPolygonEditorUnlit,
    shPolygonEditorUnlitSkin, shPolygonEditorSky, shPolygonEditorMagenta, shPolygonEditorMagentaSkin,
    shPolygonEditorLit, shPolygonEditorLitSkin, shPolygonEditorLitShadow, shPolygonEditorLitSkinShadow
  ];
}

// Central content-shader provider: editor-owned lit duplicates.
// Editor code must resolve sStatic/sAnimated-style shaders through here
// instead of referencing content shader assets directly.
function __polygon_lit_shaders() {
  return {
    fwd: shPolygonEditorLit,
    fwd_skin: shPolygonEditorLitSkin,
    sh: shPolygonEditorLitShadow,
    sh_skin: shPolygonEditorLitSkinShadow,
  };
}

// ---------------------------------------------------------------------------
// Unlit preview mode
// ---------------------------------------------------------------------------

// Swaps model materials between lit and unlit forward shaders.
function __polygon_unlit_apply(_ed) {
  if (_ed == undefined || _ed.rt == undefined || _ed.rt.scene == undefined) {
    return;
  }

  if (!variable_struct_exists(_ed, "unlit_orig") || !is_array(_ed.unlit_orig)) {
    _ed.unlit_orig = [];
  }

  if (_ed.show_unlit != true) {
    __polygon_unlit_restore(_ed);
    return;
  }

  var _roots = _ed.rt.scene.getNodes();

  for (var _i = 0, _n = array_length(_roots); _i < _n; _i++) {
    __polygon_unlit_walk(_ed, _roots[_i]);
  }

  _ed.view_dirty = true;
}

// Records original forward shader once per material.
function __polygon_unlit_record(_ed, _mat, _skinned) {
  var _list = _ed.unlit_orig;

  for (var _i = 0, _n = array_length(_list); _i < _n; _i++) {
    if (_list[_i].mat == _mat) {
      return;
    }
  }

  array_push(_list, { mat: _mat, sh: _mat.getShader(GM3D_ERenderPass.Forward), skinned: _skinned });
}

// Restores recorded forward shaders.
function __polygon_unlit_restore(_ed) {
  var _list = _ed.unlit_orig;
  var _lit = __polygon_lit_shaders();
  _ed.unlit_orig = [];

  for (var _i = 0, _n = array_length(_list); _i < _n; _i++) {
    var _entry = _list[_i];
    var _sh = _entry.sh;

    if (_sh == undefined) {
      _sh = _entry.skinned ? _lit.fwd_skin : _lit.fwd;
    }

    _entry.mat.setShader(GM3D_ERenderPass.Forward, _sh);
  }
}

// Checks if a node is editor chrome (never unlit-swapped).
function __polygon_unlit_skip(_node) {
  return is_string(_node.name) && (_node.name == "__editor_grid" || _node.name == "__skybox");
}

// Applies unlit shader to one node's materials, recording originals.
function __polygon_unlit_node(_ed, _node) {
  var _mesh = _node.getMeshComponent();

  if (_mesh != undefined) {
    var _mat = _mesh.getMaterial();

    if (_mat != undefined) {
      __polygon_unlit_record(_ed, _mat, false);
      _mat.setShader(GM3D_ERenderPass.Forward, shPolygonEditorUnlit);
      _mat.setFloat("u_skinned", 0.0);
    }
  }

  var _skin = _node.getSkinnedMeshComponent();

  if (_skin != undefined) {
    var _skin_mat = _skin.getMaterial();

    if (_skin_mat != undefined) {
      __polygon_unlit_record(_ed, _skin_mat, true);
      _skin_mat.setShader(GM3D_ERenderPass.Forward, shPolygonEditorUnlit);
      _skin_mat.setFloat("u_skinned", 1.0);
    }
  }
}

// Applies unlit shader to subtree materials, recording originals.
function __polygon_unlit_walk(_ed, _node) {
  var _stack = [ _node ];

  while (array_length(_stack) > 0) {
    var _cur = array_pop(_stack);

    if (_cur == undefined) {
      continue;
    }

    if (!__polygon_unlit_skip(_cur)) {
      __polygon_unlit_node(_ed, _cur);
    }

    var _kids = _cur.getChildren();

    for (var _k = 0, _n = array_length(_kids); _k < _n; _k++) {
      array_push(_stack, _kids[_k]);
    }
  }
}

// ---------------------------------------------------------------------------
// Magenta fallbacks
// ---------------------------------------------------------------------------

// Ensures shared missing-material magenta materials exist.
function __polygon_magenta_mats(_ed) {
  if (_ed == undefined) {
    return false;
  }

  if (_ed.magenta_mat != undefined && _ed.magenta_mat_skin != undefined) {
    return true;
  }

  var _lit = __polygon_lit_shaders();

  if (_ed.magenta_mat == undefined) {
    var _flat = new GM3D_Material("polygon_magenta");
    _flat.setShader(GM3D_ERenderPass.Forward, shPolygonEditorMagenta);
    _flat.setShader(GM3D_ERenderPass.Shadow, _lit.sh);
    _ed.magenta_mat = _flat;
  }

  if (_ed.magenta_mat_skin == undefined) {
    var _skin = new GM3D_Material("polygon_magenta_skin");
    _skin.setShader(GM3D_ERenderPass.Forward, shPolygonEditorMagentaSkin);
    _skin.setShader(GM3D_ERenderPass.Shadow, _lit.sh_skin);
    _ed.magenta_mat_skin = _skin;
  }

  return true;
}

// Assigns fallback materials to material-less meshes on one node.
function __polygon_magenta_fix_node(_node, _mat, _mat_skin) {
  var _mesh = _node.getMeshComponent();

  if (_mesh != undefined && _mesh.getMaterial() == undefined) {
    _mesh.setMaterial(_mat);
  }

  var _skin = _node.getSkinnedMeshComponent();

  if (_skin != undefined && _mat_skin != undefined && _skin.getMaterial() == undefined) {
    _skin.setMaterial(_mat_skin);
  }
}

// Assigns fallback materials to material-less meshes in subtree.
function __polygon_magenta_fix_mats(_node, _mat, _mat_skin) {
  if (_node == undefined || _mat == undefined) {
    return;
  }

  var _stack = [ _node ];

  while (array_length(_stack) > 0) {
    var _cur = array_pop(_stack);

    if (_cur == undefined) {
      continue;
    }

    __polygon_magenta_fix_node(_cur, _mat, _mat_skin);

    var _kids = _cur.getChildren();

    for (var _k = 0, _n = array_length(_kids); _k < _n; _k++) {
      array_push(_stack, _kids[_k]);
    }
  }
}

// Paints material-less meshes magenta.
function __polygon_magenta_fix(_ed, _node) {
  if (_ed == undefined || _node == undefined) {
    return;
  }

  if (!__polygon_magenta_mats(_ed)) {
    return;
  }

  __polygon_magenta_fix_mats(_node, _ed.magenta_mat, _ed.magenta_mat_skin);
}

// Paints material-less meshes magenta without editor state.
function __polygon_load_magenta_fix(_node) {
  static _flat = undefined;
  static _skin = undefined;

  if (_node == undefined) {
    return;
  }

  var _lit = __polygon_lit_shaders();

  if (_flat == undefined) {
    _flat = new GM3D_Material("polygon_load_magenta");
    _flat.setShader(GM3D_ERenderPass.Forward, shPolygonEditorMagenta);
    _flat.setShader(GM3D_ERenderPass.Shadow, _lit.sh);
  }

  if (_skin == undefined) {
    _skin = new GM3D_Material("polygon_load_magenta_skin");
    _skin.setShader(GM3D_ERenderPass.Forward, shPolygonEditorMagentaSkin);
    _skin.setShader(GM3D_ERenderPass.Shadow, _lit.sh_skin);
  }

  __polygon_magenta_fix_mats(_node, _flat, _skin);
}

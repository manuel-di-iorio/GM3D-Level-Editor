// polygon_scene_walk — subtree walks (roots, mesh components, flags).

// Collects mesh components from node.
function __polygon_walk_collect_comps(_node, _out) {
  var _mesh = _node.getMeshComponent();

  if (_mesh != undefined) {
    array_push(_out, { comp: _mesh, skinned: false });
  }

  var _skin = _node.getSkinnedMeshComponent();

  if (_skin != undefined) {
    array_push(_out, { comp: _skin, skinned: true });
  }
}

// Collects mesh components across a node subtree.
function __polygon_walk_collect_tree(_node, _out) {
  var _stack = [ _node ];

  while (array_length(_stack) > 0) {
    var _cur = array_pop(_stack);

    if (_cur == undefined) {
      continue;
    }

    __polygon_walk_collect_comps(_cur, _out);
    var _kids = _cur.getChildren();

    for (var _k = 0, _n = array_length(_kids); _k < _n; _k++) {
      array_push(_stack, _kids[_k]);
    }
  }
}

// Reads shadow flags across a node subtree.
function __polygon_flags_read(_node) {
  var _cast = true;
  var _recv = true;
  var _found = false;
  var _cb = GM3D_EMeshComponentFlags.CastShadows;
  var _rb = GM3D_EMeshComponentFlags.ReceiveShadows;
  var _comps = [];
  __polygon_walk_collect_tree(_node, _comps);

  for (var _i = 0, _n = array_length(_comps); _i < _n; _i++) {
    var _flags = _comps[_i].comp.getFlags();

    if (!is_real(_flags)) {
      continue;
    }

    _found = true;

    if ((_flags & _cb) == 0) {
      _cast = false;
    }

    if ((_flags & _rb) == 0) {
      _recv = false;
    }
  }

  if (!_found) {
    return { castShadows: true, receiveShadows: true };
  }

  return { castShadows: _cast, receiveShadows: _recv };
}

// Pushes shadow flags across a node subtree.
function __polygon_flags_apply(_node, _cast, _receive) {
  var _cb = GM3D_EMeshComponentFlags.CastShadows;
  var _rb = GM3D_EMeshComponentFlags.ReceiveShadows;
  var _bits = (_cast == true ? _cb : 0) | (_receive == true ? _rb : 0);
  var _comps = [];
  __polygon_walk_collect_tree(_node, _comps);

  for (var _i = 0, _n = array_length(_comps); _i < _n; _i++) {
    _comps[_i].comp.setFlags(_bits);
  }
}

// Disables node meshes and records state.
function __polygon_walk_mute_node(_node, _muted) {
  var _comps = [];
  __polygon_walk_collect_comps(_node, _comps);

  for (var _i = 0, _n = array_length(_comps); _i < _n; _i++) {
    var _comp = _comps[_i].comp;

    if (_comp.getEnabled()) {
      _comp.setEnabled(false);
      array_push(_muted, { comp: _comp, was: true });
    }
  }
}

// Restores materials and enabled states.
function __polygon_walk_restore(_swapped, _muted) {
  for (var _s = 0, _ns = array_length(_swapped); _s < _ns; _s++) {
    _swapped[_s].comp.setMaterial(_swapped[_s].orig);
  }

  for (var _m = 0, _nm = array_length(_muted); _m < _nm; _m++) {
    if (_muted[_m].was) {
      _muted[_m].comp.setEnabled(true);
    }
  }
}

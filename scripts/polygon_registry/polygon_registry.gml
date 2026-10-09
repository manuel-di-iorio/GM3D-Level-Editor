// polygon_registry — tracked node registry (struct by id, wrapper roots).
//
// Invariant: every tracked root is a wrapper.
// Assets are wrapper (empty) -> model root; lights/cameras/envs are a
// single wrapper node carrying the component. Lookup is always direct
// via the node name, which IS the id.

// ---------------------------------------------------------------------------
// Id helpers
// ---------------------------------------------------------------------------

// Returns the wrapper prefix.
function __polygon_wrap_prefix() {
  return "__PolygonEditor__";
}

// Returns the wrapper id of a node, or undefined when not wrapped.
function __polygon_wrap_id_of(_node) {
  if (_node == undefined || !is_string(_node.name)) {
    return undefined;
  }

  var _prefix = __polygon_wrap_prefix();

  if (string_copy(_node.name, 1, string_length(_prefix)) != _prefix) {
    return undefined;
  }

  return _node.name;
}

// Parses the numeric suffix of a wrapper id (or -1).
function __polygon_wrap_id_num(_id) {
  if (!is_string(_id)) {
    return -1;
  }

  var _prefix = __polygon_wrap_prefix();

  if (string_copy(_id, 1, string_length(_prefix)) != _prefix) {
    return -1;
  }

  var _num = real(string_copy(_id, string_length(_prefix) + 1, 32));

  if (!is_real(_num)) {
    return -1;
  }

  return floor(_num);
}

// Ensures the registry struct and id counter exist.
function __polygon_reg_ensure(_ed) {
  if (!variable_struct_exists(_ed, "reg") || !is_struct(_ed.reg)) {
    _ed.reg = {};
  }

  if (!variable_struct_exists(_ed, "id_seq") || !is_real(_ed.id_seq)) {
    _ed.id_seq = 1;
  }
}

// Clears the registry (ids stay monotonic via id_seq).
function __polygon_reg_clear(_ed) {
  _ed.reg = {};
  __polygon_reg_ensure(_ed);
}

// Counts tracked entries.
function __polygon_reg_count(_ed) {
  if (_ed == undefined || !variable_struct_exists(_ed, "reg") || !is_struct(_ed.reg)) {
    return 0;
  }

  return array_length(variable_struct_get_names(_ed.reg));
}

// Lists all registry entries.
function __polygon_reg_each(_ed) {
  var _out = [];

  if (_ed == undefined || !variable_struct_exists(_ed, "reg") || !is_struct(_ed.reg)) {
    return _out;
  }

  var _names = variable_struct_get_names(_ed.reg);

  for (var _i = 0, _n = array_length(_names); _i < _n; _i++) {
    var _en = _ed.reg[$ _names[_i]];

    if (is_struct(_en)) {
      array_push(_out, _en);
    }
  }

  return _out;
}

// Generates a fresh wrapper id.
function __polygon_wrap_new(_ed) {
  __polygon_reg_ensure(_ed);
  var _id = __polygon_wrap_prefix() + string(_ed.id_seq);
  _ed.id_seq++;
  return _id;
}

// Claims a wrapper id: keeps _want when free, else generates fresh.
// Call BEFORE createNode so the node is born with its final id.
function __polygon_wrap_claim(_ed, _want) {
  __polygon_reg_ensure(_ed);

  if (is_string(_want) && _want != "" && __polygon_wrap_id_num(_want) >= 0
    && !variable_struct_exists(_ed.reg, _want)) {
    var _num = __polygon_wrap_id_num(_want);

    if (_num >= _ed.id_seq) {
      _ed.id_seq = _num + 1;
    }

    return _want;
  }

  var _fresh = __polygon_wrap_prefix() + string(_ed.id_seq);

  while (variable_struct_exists(_ed.reg, _fresh)) {
    _ed.id_seq++;
    _fresh = __polygon_wrap_prefix() + string(_ed.id_seq);
  }

  _ed.id_seq++;
  return _fresh;
}

// Reseeds the counter above every id seen in the registry.
function __polygon_seq_reseed(_ed) {
  __polygon_reg_ensure(_ed);
  var _max = _ed.id_seq - 1;
  var _names = variable_struct_get_names(_ed.reg);

  for (var _i = 0, _n = array_length(_names); _i < _n; _i++) {
    _max = max(_max, __polygon_wrap_id_num(_names[_i]));
  }

  _ed.id_seq = _max + 1;
}

// Finds a scene node by wrapper id (direct, with scan fallback).
function __polygon_find_by_id(_ed, _id) {
  if (_ed == undefined || !is_string(_id) || _id == "" || _ed.rt == undefined || _ed.rt.scene == undefined) {
    return undefined;
  }

  var _got = undefined;
  _got = _ed.rt.scene.getNode(_id);
  if (_got != undefined) {
    return _got;
  }

  var _nodes = _ed.rt.scene.getNodes();

  for (var _i = 0, _n = array_length(_nodes); _i < _n; _i++) {
    if (_nodes[_i] != undefined && _nodes[_i].name == _id) {
      return _nodes[_i];
    }
  }

  return undefined;
}

// ---------------------------------------------------------------------------
// Registration and lookup
// ---------------------------------------------------------------------------

// Resets a freshly spawned model root to identity so the wrapper fully
// owns the instance transform. Matches the pre-wrapper behavior where
// place/track/load overwrote the spawned root transform (baked file
// offsets must not compose with the editor transform).
function __polygon_spawn_reset_child(_child) {
  if (_child == undefined) {
    return;
  }

  _child.setLocalPosition(new GM3D_Vec3(0, 0, 0));
  _child.setLocalScale(new GM3D_Vec3(1, 1, 1));
  var _ident = new GM3D_Quaternion();
  _ident.x = 0;
  _ident.y = 0;
  _ident.z = 0;
  _ident.w = 1;
  _child.setLocalRotation(_ident);
}

// Registers spawned asset node for tracking.
function __polygon_spawn_register(_ed, _node, _asset, _pos3, _label = undefined) {
  __polygon_kind_register(_ed, _node, "instance", _asset, _pos3, _label, __polygon_flags_read(_node));
}

// Registers a wrapper node with kind and metadata.
// The node name IS the id; label defaults to it.
function __polygon_kind_register(_ed, _node, _kind, _asset, _pos3, _label = undefined, _data = undefined) {
  if (_ed == undefined || _node == undefined) {
    return;
  }

  if (_kind == undefined || !is_string(_kind) || _kind == "") {
    _kind = "instance";
  }

  if (_kind == "instance" && (_asset == undefined || _asset == "")) {
    return;
  }

  __polygon_reg_ensure(_ed);
  var _id = __polygon_wrap_id_of(_node);

  if (_id == undefined) {
    return;
  }

  if (variable_struct_exists(_ed.reg, _id) && _ed.reg[$ _id].node != _node) {
    return;
  }

  if (_label == undefined || !is_string(_label) || _label == "") {
    _label = _id;
  }

  _ed.reg[$ _id] = {
    id: _id,
    kind: _kind,
    asset: _asset,
    label: _label,
    data: _data,
    hidden: false,
    locked: false,
    node: _node,
  };

  if (_ed.unlit_quiet != true) {
    __polygon_unlit_apply(_ed);
  }
}

// Removes a wrapper node from the registry (direct by id).
function __polygon_spawn_unregister(_ed, _node) {
  if (_ed == undefined || _node == undefined) {
    return;
  }

  __polygon_reg_ensure(_ed);
  var _id = __polygon_wrap_id_of(_node);

  if (_id != undefined && variable_struct_exists(_ed.reg, _id)) {
    variable_struct_remove(_ed.reg, _id);
  }
}

// Finds the registry entry for a node (direct by wrapper id).
function __polygon_registry_find(_ed, _node) {
  if (_ed == undefined || _node == undefined) {
    return undefined;
  }

  __polygon_reg_ensure(_ed);
  var _id = __polygon_wrap_id_of(_node);

  if (_id == undefined || !variable_struct_exists(_ed.reg, _id)) {
    return undefined;
  }

  return _ed.reg[$ _id];
}

// Returns asset id for node.
function __polygon_asset_name(_ed, _node) {
  var _en = __polygon_registry_find(_ed, _node);

  if (_en == undefined) {
    return undefined;
  }

  return _en.asset;
}

// Returns display label for node.
function __polygon_label_get(_ed, _node) {
  var _en = __polygon_registry_find(_ed, _node);

  if (_en != undefined && is_string(_en.label) && _en.label != "") {
    return _en.label;
  }

  var _id = __polygon_wrap_id_of(_node);

  if (_id != undefined) {
    return _id;
  }

  return _node.name;
}

// ---------------------------------------------------------------------------
// Descriptors and root lists
// ---------------------------------------------------------------------------

// Builds asset descriptor with transform.
function __polygon_asset_desc(_ed, _node) {
  var _en = __polygon_registry_find(_ed, _node);

  if (_en == undefined) {
    return undefined;
  }

  var _label = _en.label;

  if (_label == undefined || !is_string(_label) || _label == "") {
    _label = _en.id;
  }

  var _pos = _node.getLocalPosition();
  var _rot = _node.getLocalRotation();
  var _sca = _node.getLocalScale();
  var _cast = true;
  var _recv = true;

  if (is_struct(_en.data)) {
    _cast = _en.data.castShadows == true;
    _recv = _en.data.receiveShadows == true;
  }

  return {
    id: _en.id,
    asset: _en.asset,
    label: _label,
    position: [ _pos.x, _pos.y, _pos.z ],
    rotation: [ _rot.x, _rot.y, _rot.z, _rot.w ],
    scale: [ _sca.x, _sca.y, _sca.z ],
    flags: { castShadows: _cast, receiveShadows: _recv },
  };
}

// Lists tracked root scene nodes (via stored refs, no lookup).
function __polygon_root_tracked(_ed) {
  var _out = [];
  var _ens = __polygon_reg_each(_ed);

  for (var _i = 0, _n = array_length(_ens); _i < _n; _i++) {
    var _node = variable_struct_exists(_ens[_i], "node") ? _ens[_i].node : undefined;

    if (_node == undefined || _node.parent != undefined) {
      continue;
    }

    array_push(_out, _node);
  }

  return _out;
}

// Lists tracked root nodes with their entries (single pass, no lookup).
function __polygon_root_pairs(_ed) {
  var _out = [];

  if (_ed == undefined) {
    return _out;
  }

  var _ens = __polygon_reg_each(_ed);

  for (var _i = 0, _n = array_length(_ens); _i < _n; _i++) {
    var _en = _ens[_i];
    var _node = variable_struct_exists(_en, "node") ? _en.node : undefined;

    if (_node == undefined || _node.parent != undefined) {
      continue;
    }

    if (__polygon_is_grid(_ed, _node)) {
      continue;
    }

    if (variable_struct_exists(_ed, "drag_preview") && _node == _ed.drag_preview) {
      continue;
    }

    array_push(_out, { node: _node, en: _en });
  }

  return _out;
}

// Resolves registry entries to scene nodes (via stored refs, no lookup).
function __polygon_tracked_nodes(_ed) {
  var _out = [];

  if (_ed == undefined || _ed.rt == undefined || _ed.rt.scene == undefined) {
    return _out;
  }

  var _ens = __polygon_reg_each(_ed);

  for (var _i = 0, _n = array_length(_ens); _i < _n; _i++) {
    var _node = variable_struct_exists(_ens[_i], "node") ? _ens[_i].node : undefined;

    if (_node == undefined || _node.parent != undefined) {
      continue;
    }

    if (__polygon_is_grid(_ed, _node)) {
      continue;
    }

    if (variable_struct_exists(_ed, "drag_preview") && _node == _ed.drag_preview) {
      continue;
    }

    array_push(_out, _node);
  }

  return _out;
}

// Returns the first child of a node, if any.
function __polygon_first_child(_node) {
  if (_node == undefined) {
    return undefined;
  }

  var _kids = _node.getChildren();

  if (!is_array(_kids) || array_length(_kids) == 0) {
    return undefined;
  }

  return _kids[0];
}

// Checks one node for a light/camera/environment component.
function __polygon_comp_kind(_node) {
  if (_node == undefined) {
    return undefined;
  }

  if (_node.getLightComponent() != undefined) {
    return "light";
  }

  if (_node.getCameraComponent() != undefined) {
    return "camera";
  }

  if (_node.getEnvironmentVolumeComponent() != undefined) {
    return "environment";
  }

  return undefined;
}

// Determines node kind from registry, else components (self, then child).
function __polygon_kind_of(_ed, _node) {
  if (_node == undefined) {
    return undefined;
  }

  var _en = __polygon_registry_find(_ed, _node);

  if (_en != undefined && is_string(_en.kind) && _en.kind != "") {
    return _en.kind;
  }

  var _self = __polygon_comp_kind(_node);

  if (_self != undefined) {
    return _self;
  }

  var _child = __polygon_comp_kind(__polygon_first_child(_node));

  if (_child != undefined) {
    return _child;
  }

  if (_en != undefined) {
    return "instance";
  }

  return undefined;
}

// Generates a unique nonconflicting node label.
function __polygon_fresh_label(_ed, _base) {
  if (_base == undefined || !is_string(_base) || _base == "") {
    _base = "node";
  }

  var _label = _base;
  var _n = 2;
  var _taken = true;

  while (_taken) {
    _taken = false;
    var _ens = __polygon_reg_each(_ed);

    for (var _i = 0, _nt = array_length(_ens); _i < _nt; _i++) {
      if (_ens[_i].label == _label) {
        _taken = true;
        break;
      }
    }

    if (_taken) {
      _label = _base + " " + string(_n);
      _n++;
    }
  }

  return _label;
}

// ---------------------------------------------------------------------------
// Placement (wrapper + model spawned inside)
// ---------------------------------------------------------------------------

function __polygon_place(_ed, _asset, _model, _pos3, _rot, _scale3, _label = undefined) {
  if (_ed == undefined || _model == undefined) {
    return undefined;
  }

  var _wrap = _ed.rt.scene.createNode(__polygon_wrap_new(_ed));

  if (_wrap == undefined) {
    return undefined;
  }

  var _node = _model.spawnInto(_ed.rt.scene, _wrap);

  if (_node == undefined) {
    _wrap.destroy();
    return undefined;
  }

  __polygon_spawn_reset_child(_node);
  __polygon_magenta_fix(_ed, _wrap);
  _wrap.setLocalPosition(new GM3D_Vec3(_pos3[0], _pos3[1], _pos3[2]));
  _wrap.setLocalScale(new GM3D_Vec3(_scale3[0], _scale3[1], _scale3[2]));

  if (_rot != undefined) {
    _wrap.setLocalRotation(_rot);
  }

  // Contract: on_spawn receives the wrapper (walk the subtree for content).
  if (variable_struct_exists(_ed.rt, "on_spawn")) {
    _ed.rt.on_spawn(_wrap, _asset, _model);
  }

  var _pos = _wrap.getLocalPosition();
  __polygon_spawn_register(_ed, _wrap, _asset, [ _pos.x, _pos.y, _pos.z ], _label);
  return _wrap;
}

// Respawns a library model at a live node's transform, inside a wrapper
// that preserves the live id when present.
function __polygon_track_place_asset(_ed, _key, _model, _node, _label) {
  var _pos = _node.getLocalPosition();
  var _sca = _node.getLocalScale();
  var _wrap = _ed.rt.scene.createNode(__polygon_wrap_claim(_ed, __polygon_wrap_id_of(_node)));

  if (_wrap == undefined) {
    return undefined;
  }

  var _child = _model.spawnInto(_ed.rt.scene, _wrap);

  if (_child == undefined) {
    _wrap.destroy();
    return undefined;
  }

  __polygon_spawn_reset_child(_child);
  __polygon_magenta_fix(_ed, _wrap);
  _wrap.setLocalPosition(new GM3D_Vec3(_pos.x, _pos.y, _pos.z));
  _wrap.setLocalScale(new GM3D_Vec3(_sca.x, _sca.y, _sca.z));
  _wrap.setLocalRotation(_node.getLocalRotation().clone());

  if (variable_struct_exists(_ed.rt, "on_spawn")) {
    _ed.rt.on_spawn(_wrap, _key, _model);
  }

  var _pp = _wrap.getLocalPosition();
  __polygon_spawn_register(_ed, _wrap, _key, [ _pp.x, _pp.y, _pp.z ], _label);
  return _wrap;
}

// Imports a live game node into the editor scene (copy) for editing.
// The game world is never touched: assets respawn from the library by
// id (keeping save provenance), lights/cameras/env are recreated from
// live settings. A live wrapper id is preserved; bare nodes get a fresh
// one. Returns the editor wrapper node, or undefined.
function polygon_track(_kind, _asset, _node, _label = undefined) {
  var _ed = __polygon_inst();

  if (_ed == undefined) {
    return undefined;
  }

  if (_node == undefined) {
    return undefined;
  }

  if (_kind == "light") {
    return __polygon_track_adopt_light(_ed, _node, _label);
  }

  if (_kind == "camera") {
    return __polygon_track_adopt_camera(_ed, _node, _label);
  }

  if (_kind == "environment") {
    return __polygon_track_adopt_env(_ed, _node, _label);
  }

  var _model = __polygon_asset_find(_ed, _asset);

  if (_model == undefined) {
    return undefined;
  }

  var _new = __polygon_track_place_asset(_ed, _asset, _model, _node, _label);

  if (_new == undefined) {
    return undefined;
  }

  __polygon_track_adopt_flags(_node, _new);
  return _new;
}

// ---------------------------------------------------------------------------
// Auto-import matching
// ---------------------------------------------------------------------------

// Lists library entries whose model root name equals the live node name.
// Entries are keyed by load path, so duplicate root names can coexist;
// the caller adopts only on a unique candidate.
function __polygon_asset_cands(_ed, _name) {
  var _out = [];

  if (!is_string(_name) || _name == "" || !is_array(_ed.assets)) {
    return _out;
  }

  for (var _i = 0, _n = array_length(_ed.assets); _i < _n; _i++) {
    var _entry = _ed.assets[_i];

    if (!is_struct(_entry) || !is_string(_entry.name) || _entry.name == "") {
      continue;
    }

    if (_entry.name == _name && is_string(_entry.key) && _entry.key != "") {
      array_push(_out, _entry);
    }
  }

  return _out;
}

// Collects unique material names across a node subtree.
function __polygon_node_mat_names(_node) {
  var _names = [];
  var _comps = [];
  __polygon_walk_collect_tree(_node, _comps);

  for (var _i = 0, _n = array_length(_comps); _i < _n; _i++) {
    var _mat = _comps[_i].comp.getMaterial();

    if (_mat == undefined) {
      continue;
    }

    var _get = _mat[$ "getName"];

    if (_get == undefined) {
      continue;
    }

    var _name = "";
    _name = method(_mat, _get)();
    if (is_string(_name) && _name != "" && !array_contains(_names, _name)) {
      array_push(_names, _name);
    }
  }

  return _names;
}

// Reads a model library's material names (undefined when unavailable).
function __polygon_model_mat_names(_model) {
  if (_model == undefined) {
    return undefined;
  }

  var _get = _model[$ "getMaterialNames"];

  if (_get == undefined) {
    return undefined;
  }

  var _list = [];
  _list = method(_model, _get)();
  return is_array(_list) ? _list : undefined;
}

// Checks two material name lists for set equality.
function __polygon_same_mat_set(_names, _lib) {
  if (array_length(_lib) != array_length(_names)) {
    return false;
  }

  for (var _m = 0, _n = array_length(_names); _m < _n; _m++) {
    if (!array_contains(_lib, _names[_m])) {
      return false;
    }
  }

  return true;
}

// Matches a live node to a library asset by material names.
// Spawned clones share their source materials, so this works even when
// node names carry no hint of the model they came from. Requires an exact
// material-set match: subset matching false-positives on the first library
// entry when kits share palette materials, so ambiguous (0 or 2+) exact
// matches return undefined instead of a wrong model.
function __polygon_asset_match_materials(_ed, _node) {
  if (_node == undefined || !is_array(_ed.assets)) {
    return undefined;
  }

  var _names = __polygon_node_mat_names(_node);

  if (array_length(_names) == 0) {
    return undefined;
  }

  var _best = undefined;

  for (var _a = 0, _na = array_length(_ed.assets); _a < _na; _a++) {
    var _entry = _ed.assets[_a];

    if (!is_struct(_entry) || _entry.model == undefined) {
      continue;
    }

    var _lib = __polygon_model_mat_names(_entry.model);

    if (_lib == undefined) {
      continue;
    }

    if (__polygon_same_mat_set(_names, _lib) && is_string(_entry.key) && _entry.key != "") {
      if (_best != undefined) {
        return undefined;
      }

      _best = _entry.key;
    }
  }

  return _best;
}

// Returns the matchable content of a live node: the first child when the
// node itself is a wrapper, else the node.
function __polygon_adopt_content(_node) {
  if (_node != undefined && __polygon_wrap_id_of(_node) != undefined) {
    var _child = __polygon_first_child(_node);

    if (_child != undefined) {
      return _child;
    }
  }

  return _node;
}

// Resolves a live node to a library id (root name, else materials).
function __polygon_track_match(_ed, _node) {
  var _content = __polygon_adopt_content(_node);
  var _cands = __polygon_asset_cands(_ed, _content.name);

  if (array_length(_cands) == 1) {
    return _cands[0].key;
  }

  if (array_length(_cands) == 0) {
    return __polygon_asset_match_materials(_ed, _content);
  }

  return undefined;
}

// Imports one live root node, inferring kind from components.
// Non-root nodes are skipped (they arrive with their model subtree).
function __polygon_track_adopt_auto(_ed, _node) {
  if (_node == undefined || _node.parent != undefined) {
    return undefined;
  }

  var _content = __polygon_adopt_content(_node);

  if (__polygon_comp_kind(_content) != undefined || __polygon_comp_kind(_node) != undefined) {
    var _pkind = __polygon_comp_kind(_node);

    if (_pkind == undefined) {
      _pkind = __polygon_comp_kind(_content);
    }

    if (_pkind == "light") {
      return __polygon_track_adopt_light(_ed, _node, undefined);
    }

    if (_pkind == "camera") {
      return __polygon_track_adopt_camera(_ed, _node, undefined);
    }

    return __polygon_track_adopt_env(_ed, _node, undefined);
  }

  var _matched = __polygon_track_match(_ed, _node);

  if (_matched == undefined) {
    return undefined;
  }

  var _model = __polygon_asset_find(_ed, _matched);

  if (_model == undefined) {
    return undefined;
  }

  var _base = __polygon_asset_label(__polygon_asset_get(_ed, _matched));

  if (_base == "") {
    _base = _content.name;
  }

  var _new = __polygon_track_place_asset(_ed, _matched, _model, _node, _base);

  if (_new == undefined) {
    return undefined;
  }

  __polygon_track_adopt_flags(_node, _new);
  return _new;
}

// Copies mesh shadow flags from a live subtree to an adopted copy.
// Both trees share structure, so a parallel walk aligns components.
function __polygon_track_adopt_flags(_src_node, _dst_node) {
  var _src_list = [];
  var _dst_list = [];
  __polygon_walk_collect_tree(_src_node, _src_list);
  __polygon_walk_collect_tree(_dst_node, _dst_list);
  var _n = min(array_length(_src_list), array_length(_dst_list));

  for (var _i = 0; _i < _n; _i++) {
    var _src_comp = _src_list[_i].comp;
    var _dst_comp = _dst_list[_i].comp;

    if (_src_comp == undefined || _dst_comp == undefined) {
      continue;
    }

    var _get = _src_comp[$ "getFlags"];
    var _set = _dst_comp[$ "setFlags"];

    if (_get == undefined || _set == undefined) {
      continue;
    }

    method(_dst_comp, _set)(method(_src_comp, _get)());
  }
}

// ---------------------------------------------------------------------------
// Prop adoption (wrapper node carries the component + id)
// ---------------------------------------------------------------------------

// Finds the component-bearing node in a live subtree (self, then child).
function __polygon_adopt_comp_node(_node) {
  if (_node == undefined) {
    return undefined;
  }

  if (__polygon_comp_kind(_node) != undefined) {
    return _node;
  }

  var _child = __polygon_first_child(_node);

  if (_child != undefined && __polygon_comp_kind(_child) != undefined) {
    return _child;
  }

  return undefined;
}

// Creates a positioned editor wrapper node, preserving the live id.
function __polygon_track_make_node(_ed, _label, _node) {
  var _pos = _node.getLocalPosition();
  var _new = _ed.rt.scene.createNode(__polygon_wrap_claim(_ed, __polygon_wrap_id_of(_node)));

  if (_new == undefined) {
    return undefined;
  }

  _new.setLocalPosition(new GM3D_Vec3(_pos.x, _pos.y, _pos.z));
  _new.setLocalRotation(_node.getLocalRotation().clone());
  return _new;
}

// Adopts a live light node into the editor scene.
function __polygon_track_adopt_light(_ed, _node, _label = undefined) {
  var _src = __polygon_adopt_comp_node(_node);

  if (_src == undefined || _src.getLightComponent() == undefined) {
    return undefined;
  }

  var _data = __polygon_light_read(_src);

  if (_label == undefined || !is_string(_label) || _label == "") {
    _label = __polygon_fresh_label(_ed, _node.name);
  }

  var _new = __polygon_track_make_node(_ed, _label, _node);

  if (_new == undefined) {
    return undefined;
  }

  _new.addComponent(new GM3D_LightComponent());
  __polygon_light_apply(_new, _data);
  _ed.rt.scene.update(0);
  var _pos = _new.getLocalPosition();
  __polygon_kind_register(_ed, _new, "light", "", [ _pos.x, _pos.y, _pos.z ], _label, _data);

  if (_data.type == "directional") {
    __polygon_hidden_set(_ed, _new, true);
  }

  return _new;
}

// Adopts a live camera node into the editor scene.
function __polygon_track_adopt_camera(_ed, _node, _label = undefined) {
  var _src = __polygon_adopt_comp_node(_node);

  if (_src == undefined || _src.getCameraComponent() == undefined) {
    return undefined;
  }

  var _data = __polygon_camera_read(_src);
  var _pos = _node.getLocalPosition();

  if (_label == undefined || !is_string(_label) || _label == "") {
    _label = __polygon_fresh_label(_ed, _node.name);
  }

  var _new = __polygon_track_make_node(_ed, _label, _node);

  if (_new == undefined) {
    return undefined;
  }

  _new.addComponent(new GM3D_CameraComponent());
  __polygon_camera_apply(_new, _data);
  _ed.rt.scene.update(0);
  __polygon_kind_register(_ed, _new, "camera", "", [ _pos.x, _pos.y, _pos.z ], _label, _data);
  __polygon_hidden_set(_ed, _new, true);
  __polygon_cameras_mute(_ed);
  return _new;
}

// Adopts a live environment node into the editor scene.
function __polygon_track_adopt_env(_ed, _node, _label = undefined) {
  var _src = __polygon_adopt_comp_node(_node);

  if (_src == undefined || _src.getEnvironmentVolumeComponent() == undefined) {
    return undefined;
  }

  var _data = __polygon_env_read(_src);
  var _pos = _node.getLocalPosition();

  if (_label == undefined || !is_string(_label) || _label == "") {
    _label = __polygon_fresh_label(_ed, _node.name);
  }

  var _new = _ed.rt.scene.createNode(__polygon_wrap_claim(_ed, __polygon_wrap_id_of(_node)));

  if (_new == undefined) {
    return undefined;
  }

  _new.addComponent(new GM3D_EnvironmentVolumeComponent());
  _new.setLocalPosition(new GM3D_Vec3(_pos.x, _pos.y, _pos.z));
  __polygon_env_apply(_new, _data);
  _ed.rt.scene.update(0);
  __polygon_kind_register(_ed, _new, "environment", "", [ _pos.x, _pos.y, _pos.z ], _label, _data);
  __polygon_hidden_set(_ed, _new, true);
  return _new;
}

// polygon_history — undo/redo snapshots of scene + selection.

// ---------------------------------------------------------------------------
// Stacks and snapshots
// ---------------------------------------------------------------------------

// Clears undo and redo history stacks.
function __polygon_history_clear(_ed) {
  if (_ed == undefined) {
    return;
  }

  _ed.undo = [];
  _ed.redo = [];
}

// Ensures undo/redo stacks exist.
function __polygon_history_stacks(_ed) {
  if (!is_array(_ed.undo)) {
    _ed.undo = [];
  }

  if (!is_array(_ed.redo)) {
    _ed.redo = [];
  }
}

// Captures current scene and selection as snapshot.
function __polygon_history_snap(_ed) {
  var _nodes = __polygon_serialize_scene(_ed);
  var _sel = [];

  for (var _i = 0, _n = array_length(_ed.sel); _i < _n; _i++) {
    var _desc = __polygon_node_desc(_ed, _ed.sel[_i]);

    if (_desc != undefined) {
      array_push(_sel, _desc);
    }
  }

  return { json: json_stringify(_nodes), sel: _sel };
}

// Pushes prior snapshot onto undo stack.
function __polygon_history_commit(_ed, _before) {
  var _cur = __polygon_history_snap(_ed);

  if (_cur.json == _before.json) {
    return;
  }

  __polygon_history_stacks(_ed);
  array_push(_ed.undo, _before);
  _ed.redo = [];

  while (array_length(_ed.undo) > 100) {
    array_delete(_ed.undo, 0, 1);
  }

  _ed.dirty = true;
  _ed.view_dirty = true;

  if (variable_struct_exists(_ed, "outline") && is_struct(_ed.outline)) {
    _ed.outline.cheap = undefined;
  }
}

// ---------------------------------------------------------------------------
// Selection restore (by wrapper id)
// ---------------------------------------------------------------------------

// Restores selection from saved node descriptors (matched by id).
function __polygon_history_restore_sel(_ed, _sel_descs) {
  var _out = [];

  if (is_array(_sel_descs)) {
    for (var _i = 0, _nsel = array_length(_sel_descs); _i < _nsel; _i++) {
      var _want = _sel_descs[_i];

      if (_want == undefined || !is_string(_want.id)) {
        continue;
      }

      var _node = __polygon_find_by_id(_ed, _want.id);

      if (_node != undefined) {
        array_push(_out, _node);
      }
    }
  }

  _ed.sel = _out;
  _ed.giz.drag = -1;
}

// ---------------------------------------------------------------------------
// Undo and redo
// ---------------------------------------------------------------------------

// Peeks the top stack entry with parsed scene data (undefined when empty).
function __polygon_history_peek(_stack) {
  if (!is_array(_stack) || array_length(_stack) == 0) {
    return undefined;
  }

  var _entry = _stack[array_length(_stack) - 1];
  var _data = json_parse(_entry.json);

  if (!is_array(_data)) {
    return undefined;
  }

  return { entry: _entry, data: _data };
}

// Moves one snapshot between stacks and rebuilds the scene from it.
function __polygon_history_apply(_ed, _from, _to) {
  var _peek = __polygon_history_peek(_from);

  if (_peek == undefined) {
    return false;
  }

  __polygon_history_stacks(_ed);
  var _cur = __polygon_history_snap(_ed);
  array_pop(_from);
  array_push(_to, _cur);
  __polygon_rebuild(_ed, _peek.data);
  __polygon_history_restore_sel(_ed, _peek.entry.sel);
  return true;
}

// Reverts scene to previous undo snapshot.
function __polygon_history_undo(_ed) {
  if (_ed == undefined) {
    return false;
  }

  return __polygon_history_apply(_ed, _ed.undo, _ed.redo);
}

// Reapplies scene from redo snapshot.
function __polygon_history_redo(_ed) {
  if (_ed == undefined) {
    return false;
  }

  return __polygon_history_apply(_ed, _ed.redo, _ed.undo);
}

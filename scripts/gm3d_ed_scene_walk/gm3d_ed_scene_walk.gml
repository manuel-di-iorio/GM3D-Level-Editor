// Finds root ancestor of scene node.
function __gm3d_ed_walk_root(_node) {
	var _root = _node;
	var _guard = 0;
	try {
		while (_root.parent != undefined && _guard < 1024) {
			_root = _root.parent;
			_guard++;
		}
	} catch (_e) {
	}
	return _root;
}

// Collects mesh components from node.
function __gm3d_ed_walk_collect_comps(_node, _out) {
	try {
		var _mc = _node.getMeshComponent();
		if (_mc != undefined) {
			array_push(_out, { comp: _mc, skinned: false });
		}
	} catch (_e) {
	}
	try {
		var _sk = _node.getSkinnedMeshComponent();
		if (_sk != undefined) {
			array_push(_out, { comp: _sk, skinned: true });
		}
	} catch (_e2) {
	}
}

// Collects mesh components across a node subtree.
function __gm3d_ed_walk_collect_tree(_node, _out) {
	var _stack = [_node];
	while (array_length(_stack) > 0) {
		var _cur = array_pop(_stack);
		if (_cur == undefined) {
			continue;
		}
		__gm3d_ed_walk_collect_comps(_cur, _out);
		var _kids = [];
		try {
			_kids = _cur.getChildren();
		} catch (_e) {
			_kids = [];
		}
		for (var _k = 0; _k < array_length(_kids); _k++) {
			array_push(_stack, _kids[_k]);
		}
	}
}

// Reads shadow flags across a node subtree.
function __gm3d_ed_flags_read(_node) {
	var _cast = true;
	var _recv = true;
	var _found = false;
	var _cb = 1;
	var _rb = 2;
	try {
		_cb = GM3D_EMeshComponentFlags.CastShadows;
		_rb = GM3D_EMeshComponentFlags.ReceiveShadows;
	} catch (_e) {
	}
	var _list = [];
	__gm3d_ed_walk_collect_tree(_node, _list);
	for (var _i = 0; _i < array_length(_list); _i++) {
		var _f = undefined;
		try {
			_f = _list[_i].comp.getFlags();
		} catch (_e2) {
			_f = undefined;
		}
		if (!is_real(_f)) {
			continue;
		}
		_found = true;
		if ((_f & _cb) == 0) {
			_cast = false;
		}
		if ((_f & _rb) == 0) {
			_recv = false;
		}
	}
	if (!_found) {
		return { castShadows: true, receiveShadows: true };
	}
	return { castShadows: _cast, receiveShadows: _recv };
}

// Pushes shadow flags across a node subtree.
function __gm3d_ed_flags_apply(_node, _cast, _receive) {
	var _cb = 1;
	var _rb = 2;
	try {
		_cb = GM3D_EMeshComponentFlags.CastShadows;
		_rb = GM3D_EMeshComponentFlags.ReceiveShadows;
	} catch (_e) {
	}
	var _bits = (_cast == true ? _cb : 0) | (_receive == true ? _rb : 0);
	var _list = [];
	__gm3d_ed_walk_collect_tree(_node, _list);
	for (var _i = 0; _i < array_length(_list); _i++) {
		try {
			_list[_i].comp.setFlags(_bits);
		} catch (_e2) {
		}
	}
}

// Disables node meshes and records state.
function __gm3d_ed_walk_mute_node(_node, _muted) {
	var _list = [];
	__gm3d_ed_walk_collect_comps(_node, _list);
	for (var _i = 0; _i < array_length(_list); _i++) {
		var _comp = _list[_i].comp;
		var _was = true;
		try {
			_was = _comp.getEnabled();
		} catch (_e) {
			_was = true;
		}
		if (_was) {
			try {
				_comp.setEnabled(false);
			} catch (_e2) {
			}
		}
		array_push(_muted, { comp: _comp, was: _was });
	}
}

// Restores materials and enabled states.
function __gm3d_ed_walk_restore(_swapped, _muted) {
	try {
		for (var _s = 0; _s < array_length(_swapped); _s++) {
			_swapped[_s].comp.setMaterial(_swapped[_s].orig);
		}
		for (var _m = 0; _m < array_length(_muted); _m++) {
			if (_muted[_m].was) {
				_muted[_m].comp.setEnabled(true);
			}
		}
	} catch (_e) {
	}
}

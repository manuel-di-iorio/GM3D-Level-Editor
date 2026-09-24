/// @module gm3d_ed_picking
/// Scene picking: pick-all, click cycling and rect selection.

/// Returns all root nodes under a screen point, nearest first.
/// @param _nodes Scene root nodes from the runtime adapter.
function __gm3d_ed_pick_all(_nodes, _vp, _mx, _my) {
	var _ray = __gm3d_ed_screen_ray(_vp, _mx, _my);
	var _hits = [];
	for (var _i = 0; _i < array_length(_nodes); _i++) {
		var _node = _nodes[_i];
		if (_node.parent != undefined) {
			continue;
		}
		var _box = __gm3d_ed_node_aabb(_node);
		if (!_box.valid) {
			continue;
		}
		var _t = __gm3d_ed_ray_aabb(_ray.origin, _ray.dir, _box.min, _box.max);
		if (_t >= 0) {
			array_push(_hits, { node: _node, dist: _t });
		}
	}
	__gm3d_ed_sort_by_field(_hits, "dist", true);
	return _hits;
}

/// Cycles through overlapping objects under the cursor on repeated clicks.
/// @param _nodes Scene root nodes from the runtime adapter.
function __gm3d_ed_pick_cycle(_ed, _nodes, _vp, _mx, _my) {
	var _hits = __gm3d_ed_pick_all(_nodes, _vp, _mx, _my);
	if (array_length(_hits) == 0) {
		_ed.pick_cycle_index = -1;
		return undefined;
	}
	var _same =
		point_distance(_ed.pick_cycle_x, _ed.pick_cycle_y, _mx, _my) <= 10 && current_time - _ed.pick_cycle_time <= 700;
	if (_same) {
		_ed.pick_cycle_index = (_ed.pick_cycle_index + 1) mod array_length(_hits);
	} else {
		_ed.pick_cycle_index = 0;
	}
	_ed.pick_cycle_x = _mx;
	_ed.pick_cycle_y = _my;
	_ed.pick_cycle_time = current_time;
	return _hits[_ed.pick_cycle_index].node;
}

/// Returns root nodes intersecting a normalized screen rect.
/// @param _r Normalized rect { x0, y0, x1, y1 }.
function __gm3d_ed_pick_rect(_nodes, _vp, _r) {
	var _out = [];
	for (var _i = 0; _i < array_length(_nodes); _i++) {
		var _node = _nodes[_i];
		if (_node.parent != undefined) {
			continue;
		}
		var _box = __gm3d_ed_node_aabb(_node);
		if (!_box.valid) {
			continue;
		}
		var _mn = _box.min;
		var _mx = _box.max;
		var _hit = false;
		for (var _ix = 0; _ix < 2 && !_hit; _ix++)
			for (var _iy = 0; _iy < 2 && !_hit; _iy++)
				for (var _iz = 0; _iz < 2 && !_hit; _iz++) {
					var _s = __gm3d_ed_world_to_screen(
						_vp,
						new GM3D_Vec3(_ix == 0 ? _mn.x : _mx.x, _iy == 0 ? _mn.y : _mx.y, _iz == 0 ? _mn.z : _mx.z),
					);
					if (_s != undefined && _s[0] >= _r.x0 && _s[0] <= _r.x1 && _s[1] >= _r.y0 && _s[1] <= _r.y1) {
						_hit = true;
					}
				}
		if (!_hit) {
			var _c = __gm3d_ed_world_to_screen(_vp, _node.getWorldPosition());
			if (_c != undefined && _c[0] >= _r.x0 && _c[0] <= _r.x1 && _c[1] >= _r.y0 && _c[1] <= _r.y1) {
				_hit = true;
			}
		}
		if (_hit) {
			array_push(_out, _node);
		}
	}
	return _out;
}

// Builds viewport matrices and camera data.
function __gm3d_ed_viewport(_ed) {
	var _camNode = _ed.rt.cam;
	var _comp = _camNode.getCameraComponent();

	var _fov = pi / 3.0;
	var _near = 0.1;
	var _far = 10000.0;
	var _w = display_get_gui_width();
	var _h = display_get_gui_height();
	if (_w <= 0 || _h <= 0) {
		_w = 1366.0;
		_h = 768.0;
	}
	var _ox = 0;
	var _oy = 0;
	if (__gm3d_ed_preview_open(_ed) && variable_struct_exists(_ed, "pvp") && is_struct(_ed.pvp) && _ed.pvp.w > 0 && _ed.pvp.h > 0) {
		_w = _ed.pvp.w;
		_h = _ed.pvp.h;
		_ox = _ed.pvp.x;
		_oy = _ed.pvp.y;
	}

	if (_comp != undefined) {
		_fov = _comp.getFovY();
		_near = _comp.getNear();
		_far = _comp.getFar();
	}

	var _aspect = _w / _h;

	var _wm = _camNode.getWorldMatrix();
	var _view = _wm.clone();
	_view.invert();

	var _proj = GM3D_Matrix4.perspective(_fov, _aspect, _near, _far);
	var _vp = _proj.clone();
	_vp.multiply(_view);
	var _inv = _vp.clone();
	_inv.invert();

	var _camRight = _camNode.getWorldRight();
	var _camUp = _camNode.getWorldUp();
	var _camForward = _camNode.getWorldForward();

	return {
		camNode: _camNode,
		ndc_yup: _ed.ndc_yup,
		winW: _w,
		winH: _h,
		offX: _ox,
		offY: _oy,
		fovY: _fov,
		near: _near,
		far: _far,
		view: _view,
		proj: _proj,
		viewProj: _vp,
		inv: _inv,
		camForward: _camForward,
		camRight: _camRight,
		camUp: _camUp,
	};
}

// Converts world position to screen coordinates.
function __gm3d_ed_world_to_screen(_vp, _p) {
	var _v = new GM3D_Vec4(_p.x, _p.y, _p.z, 1.0);
	_v.applyMatrix4(_vp.viewProj);
	if (_v.w <= 0.0001) {
		return undefined;
	}
	var _nx = _v.x / _v.w;
	var _ny = _v.y / _v.w;
	if (_nx < -2.0 || _nx > 2.0 || _ny < -2.0 || _ny > 2.0) {
		return undefined;
	}
	var _sx = (_nx * 0.5 + 0.5) * _vp.winW;
	var _sy;
	if (_vp.ndc_yup) {
		_sy = (1.0 - (_ny * 0.5 + 0.5)) * _vp.winH;
	} else {
		_sy = (_ny * 0.5 + 0.5) * _vp.winH;
	}
	return [_sx, _sy];
}

// Unprojects NDC coordinates to world space.
function __gm3d_ed_unproject(_inv, _nx, _ny, _nz) {
	var _v = new GM3D_Vec4(_nx, _ny, _nz, 1.0);
	_v.applyMatrix4(_inv);
	if (abs(_v.w) < 0.0001) {
		_v.w = 1.0;
	}
	return new GM3D_Vec3(_v.x / _v.w, _v.y / _v.w, _v.z / _v.w);
}

// Creates world ray from screen pixel.
function __gm3d_ed_screen_ray(_vp, _mx, _my) {
	var _nx = (2.0 * _mx) / _vp.winW - 1.0;
	var _ny;
	if (_vp.ndc_yup) {
		_ny = 1.0 - (2.0 * _my) / _vp.winH;
	} else {
		_ny = (2.0 * _my) / _vp.winH - 1.0;
	}

	var _nearW = __gm3d_ed_unproject(_vp.inv, _nx, _ny, -1.0);
	var _farW = __gm3d_ed_unproject(_vp.inv, _nx, _ny, 1.0);

	var _dir = new GM3D_Vec3();
	_dir.subVectors(_farW, _nearW);
	_dir.normalizeSafe(0.000001);

	return { origin: _nearW, dir: _dir };
}

// Intersects ray with plane.
function __gm3d_ed_ray_plane(_origin, _dir, _point, _normal) {
	var _d = _dir.dot(_normal);
	if (abs(_d) < 0.000001) {
		return undefined;
	}
	var _t = _point.dot(_normal) - _origin.dot(_normal);
	_t /= _d;
	if (_t < 0.0) {
		return undefined;
	}
	var _hit = new GM3D_Vec3();
	_hit.copy(_dir);
	_hit.multiplyScalar(_t);
	_hit.add(_origin);
	return _hit;
}

// Intersects ray with axis-aligned bounding box.
function __gm3d_ed_ray_aabb(_origin, _dir, _min, _max) {
	var _tmin = 0.0;
	var _tmax = 1000000000;
	for (var i = 0; i < 3; ++i) {
		var _o, _d, _lo, _hi;
		if (i == 0) {
			_o = _origin.x;
			_d = _dir.x;
			_lo = _min.x;
			_hi = _max.x;
		} else if (i == 1) {
			_o = _origin.y;
			_d = _dir.y;
			_lo = _min.y;
			_hi = _max.y;
		} else {
			_o = _origin.z;
			_d = _dir.z;
			_lo = _min.z;
			_hi = _max.z;
		}

		if (abs(_d) < 0.000001) {
			if (_o < _lo || _o > _hi) {
				return -1;
			}
		} else {
			var _invD = 1.0 / _d;
			var _t1 = (_lo - _o) * _invD;
			var _t2 = (_hi - _o) * _invD;
			if (_t1 > _t2) {
				var _tmp = _t1;
				_t1 = _t2;
				_t2 = _tmp;
			}
			if (_t1 > _tmin) {
				_tmin = _t1;
			}
			if (_t2 < _tmax) {
				_tmax = _t2;
			}
			if (_tmin > _tmax) {
				return -1;
			}
		}
	}
	return _tmin;
}

// Computes world bounding box for subtree.
function __gm3d_ed_node_aabb(_node) {
	var _min = undefined;
	var _max = undefined;
	var _stack = [_node];

	while (array_length(_stack) > 0) {
		var _cur = array_pop(_stack);
		var _wm = _cur.getWorldMatrix();
		_wm = _wm.clone();
		var _boxes = [];

		var _comps = _cur.getMeshComponents();
		for (var i = 0; i < array_length(_comps); ++i) {
			var _cm = _comps[i].getMesh();
			if (_cm == undefined) {
				continue;
			}
			var _cb = _cm.getBoundingBox();
			if (_cb == undefined || _cb.min == undefined || _cb.max == undefined) {
				continue;
			}
			array_push(_boxes, { min: _cb.min, max: _cb.max });
		}
		var _skn = _cur.getSkinnedMeshComponent();
		if (_skn != undefined) {
			var _smn = _skn.getMesh();
			if (_smn != undefined) {
				var _sbn = _smn.getBoundingBox();
				if (_sbn != undefined && _sbn.min != undefined && _sbn.max != undefined) {
					array_push(_boxes, { min: _sbn.min, max: _sbn.max });
				}
			}
		}

		for (var i = 0; i < array_length(_boxes); ++i) {
			var _bMin = _boxes[i].min;
			var _bMax = _boxes[i].max;
			if (_bMin == undefined || _bMax == undefined) {
				continue;
			}

			for (var ix = 0; ix < 2; ++ix) {
				for (var iy = 0; iy < 2; ++iy) {
					for (var iz = 0; iz < 2; ++iz) {
						var _p = new GM3D_Vec3(
							ix == 0 ? _bMin.x : _bMax.x,
							iy == 0 ? _bMin.y : _bMax.y,
							iz == 0 ? _bMin.z : _bMax.z,
						);
						var _transformed = _wm.transformPoint(_p);
						if (_transformed != undefined) _p = _transformed;
						if (_min == undefined) {
							_min = _p.clone();
							_max = _p.clone();
						} else {
							_min.x = min(_min.x, _p.x);
							_min.y = min(_min.y, _p.y);
							_min.z = min(_min.z, _p.z);
							_max.x = max(_max.x, _p.x);
							_max.y = max(_max.y, _p.y);
							_max.z = max(_max.z, _p.z);
						}
					}
				}
			}
		}

		var _kids = _cur.getChildren();
		for (var k = 0; k < array_length(_kids); ++k) {
			array_push(_stack, _kids[k]);
		}
	}

	if (_min == undefined) {
		return { min: undefined, max: undefined, valid: false };
	}
	return { min: _min, max: _max, valid: true };
}

// Draws 2D line with width.
function __gm3d_ed_vp_line(_ed, _x1, _y1, _x2, _y2, _wd, _col) {
	draw_line_width_color(_x1, _y1, _x2, _y2, _wd, _col, _col);
}

// Clips polygon and projects to screen.
function __gm3d_ed_clip_screen_poly(_vp, _corners) {
	var _eps = 0.001;
	var _clip = [];
	for (var _i = 0; _i < array_length(_corners); _i++) {
		var _v = new GM3D_Vec4(_corners[_i].x, _corners[_i].y, _corners[_i].z, 1.0);
		_v.applyMatrix4(_vp.viewProj);
		array_push(_clip, _v);
	}
	var _n = array_length(_clip);
	var _any = false;
	for (var _a = 0; _a < _n; _a++) {
		if (_clip[_a].w >= _eps) {
			_any = true;
			break;
		}
	}
	if (!_any) {
		return [];
	}
	var _out = [];
	for (var _e = 0; _e < _n; _e++) {
		var _cur = _clip[_e];
		var _nxt = _clip[(_e + 1) mod _n];
		var _cinc = _cur.w >= _eps;
		var _ninc = _nxt.w >= _eps;
		if (_ninc) {
			if (!_cinc) {
				array_push(_out, __gm3d_ed_clip_lerp(_cur, _nxt, _eps));
			}
			array_push(_out, _nxt);
		} else if (_cinc) {
			array_push(_out, __gm3d_ed_clip_lerp(_cur, _nxt, _eps));
		}
	}
	var _sp = [];
	for (var _s = 0; _s < array_length(_out); _s++) {
		var _p = _out[_s];
		var _nx = _p.x / _p.w;
		var _ny = _p.y / _p.w;
		var _sx = (_nx * 0.5 + 0.5) * _vp.winW;
		var _sy = 0;
		if (_vp.ndc_yup) {
			_sy = (1.0 - (_ny * 0.5 + 0.5)) * _vp.winH;
		} else {
			_sy = (_ny * 0.5 + 0.5) * _vp.winH;
		}
		array_push(_sp, [_sx, _sy]);
	}
	return _sp;
}

// Projects corner array to screen positions.
function __gm3d_ed_world_corners_to_screen(_vp, _corners) {
	var _out = [];
	for (var _i = 0; _i < array_length(_corners); _i++) {
		array_push(_out, __gm3d_ed_world_to_screen(_vp, _corners[_i]));
	}
	return _out;
}

/// @module gm3d_ed_input

/// Resolves the active gesture owner and clears owners whose gesture ended.
function __gm3d_ed_input_owner_sync(_ed) {
	var _owner = _ed.input_owner;
	if (_owner == undefined) {
		if (_ed.giz.drag != -1) {
			_owner = "gizmo";
		} else if (_ed.drag_lib != undefined) {
			_owner = "library";
		} else if (_ed.cube_armed == true) {
			_owner = "viewcube";
		} else if (_ed.rect != undefined) {
			_owner = "rect";
		} else if (_ed.cam_orbit) {
			_owner = "camera_orbit";
		} else if (_ed.cam_zoom) {
			_owner = "camera_zoom";
		} else if (_ed.cam_fly) {
			_owner = "camera_fly";
		} else if (_ed.cam_pan) {
			_owner = "camera_pan";
		}
	}
	if (
		(_owner == "gizmo" && _ed.giz.drag == -1) ||
		(_owner == "library" && _ed.drag_lib == undefined) ||
		(_owner == "viewcube" && _ed.cube_armed != true) ||
		(_owner == "rect" && _ed.rect == undefined) ||
		(_owner == "camera_orbit" && !_ed.cam_orbit) ||
		(_owner == "camera_zoom" && !_ed.cam_zoom) ||
		(_owner == "camera_fly" && !_ed.cam_fly) ||
		(_owner == "camera_pan" && !_ed.cam_pan)
	) {
		_owner = undefined;
	}
	_ed.input_owner = _owner;
	return _owner;
}

/// True when the active owner is one of the camera gestures.
function __gm3d_ed_input_owner_is_camera(_owner) {
	return _owner == "camera_orbit" || _owner == "camera_zoom" || _owner == "camera_fly" || _owner == "camera_pan";
}

/// Clears the owner only when the requested gesture currently owns input.
function __gm3d_ed_input_owner_clear(_ed, _owner) {
	if (_ed.input_owner == _owner) {
		_ed.input_owner = undefined;
	}
}

/// Captures shared per-frame input state before camera and editor handlers run.
function __gm3d_ed_input_context(_ed, _keys) {
	var _mx = device_mouse_x_to_gui(0);
	var _my = device_mouse_y_to_gui(0);
	var _mouse_capture = false;
	var _keyboard_capture = false;
	var _text_input = false;
	if (__gm3d_ed_imgui_check(_ed)) {
		_keyboard_capture = ImGui.WantKeyboardCapture();
		_text_input = ImGui.WantTextInput();
		_mouse_capture = ImGui.WantMouseCapture();
	}
	var _typing = _keyboard_capture || _text_input;
	var _in_viewport = !_mouse_capture && _mx >= 0 && _mx <= _ed.gw && _my >= 0 && _my <= _ed.gh;
	var _vp = __gm3d_ed_viewport(_ed);
	var _owner = __gm3d_ed_input_owner_sync(_ed);
	return {
		keys: _keys,
		mx: _mx,
		my: _my,
		vp: _vp,
		mouse_capture: _mouse_capture,
		keyboard_capture: _keyboard_capture,
		text_input: _text_input,
		typing: _typing,
		in_viewport: _in_viewport,
		owner: _owner,
		gesture_active: _owner != undefined && !__gm3d_ed_input_owner_is_camera(_owner),
		camera_keys: false,
		camera_viewport: _in_viewport,
		camera_zoom: false,
	};
}

/// Handles tool, nudge and Ctrl hotkeys.
function __gm3d_ed_step_hotkeys(_ed, _input) {
	var _keys = _input.keys;
	var _typing = _input.typing;
	var _gesture = _input.gesture_active;
	if (!_typing) {
		var _ctrl = keyboard_check(vk_control);
		if (!_ctrl && !_gesture) {
			if (keyboard_check_pressed(_keys.tool_move)) {
				_ed.giz.tool = Gm3dEdTool.Translate;
			}
			if (keyboard_check_pressed(_keys.tool_rotate)) {
				_ed.giz.tool = Gm3dEdTool.Rotate;
			}
			if (keyboard_check_pressed(_keys.tool_scale)) {
				_ed.giz.tool = Gm3dEdTool.Scale;
			}
			if (keyboard_check_pressed(_keys.del)) {
				__gm3d_ed_delete_sel(_ed);
			}
			if (variable_struct_exists(_keys, "focus") && keyboard_check_pressed(_keys.focus)) {
				__gm3d_ed_focus_selection(_ed);
			}
			if (
				variable_struct_exists(_keys, "rename") &&
				keyboard_check_pressed(_keys.rename) &&
				array_length(_ed.sel) > 0
			) {
				__gm3d_ed_rename_begin(_ed, _ed.sel[0]);
			}
			var _njx = keyboard_check_pressed(vk_right) - keyboard_check_pressed(vk_left);
			var _njz = keyboard_check_pressed(vk_down) - keyboard_check_pressed(vk_up);
			if ((_njx != 0 || _njz != 0) && array_length(_ed.sel) > 0) {
				var _nst = _ed.snap_on ? _ed.snap_pos : 0.25;
				var _hb = undefined;
				_hb = __gm3d_ed_history_snap(_ed);
				for (var _ni = 0; _ni < array_length(_ed.sel); _ni++) {
					if (!__gm3d_ed_tool_allowed(_ed, _ed.sel[_ni], Gm3dEdTool.Translate) || __gm3d_ed_hidden_get(_ed, _ed.sel[_ni])) {
						continue;
					}
					var _np = _ed.sel[_ni].getLocalPosition();
					_ed.sel[_ni].setLocalPosition(new GM3D_Vec3(_np.x + _njx * _nst, _np.y, _np.z + _njz * _nst));
				}
				__gm3d_ed_rows_follow(_ed, _ed.sel);
				if (_hb != undefined) {
					__gm3d_ed_history_commit(_ed, _hb);
				}
			}
		}
		if (!_gesture && _ctrl && keyboard_check_pressed(_keys.save)) {
			__gm3d_ed_save_or_ask(_ed);
		}
		if (!_gesture && _ctrl && keyboard_check_pressed(_keys.dupe)) {
			__gm3d_ed_duplicate_sel(_ed);
		}
		if (!_gesture && _ctrl && keyboard_check_pressed(_keys.new_scene)) {
			__gm3d_ed_confirm_ask(_ed, "new");
		}
		if (variable_struct_exists(_keys, "load") && !_gesture && _ctrl && keyboard_check_pressed(_keys.load)) {
			__gm3d_ed_confirm_ask(_ed, "load");
		}
		if (!_gesture && _ctrl) {
			var _has_undo = variable_struct_exists(_keys, "undo");
			var _has_redo = variable_struct_exists(_keys, "redo");
			if (_has_undo && !keyboard_check(vk_shift) && keyboard_check_pressed(_keys.undo)) {
				__gm3d_ed_history_undo(_ed);
			} else if (
				(_has_redo && keyboard_check_pressed(_keys.redo)) ||
				(_has_undo && keyboard_check(vk_shift) && keyboard_check_pressed(_keys.undo))
			) {
				__gm3d_ed_history_redo(_ed);
			}
		}
	}
}

/// Handles cascading Esc cancel for confirm, rename, drag, rect and gizmo.
function __gm3d_ed_step_cancel(_ed, _input) {
	var _keys = _input.keys;
	var _typing = _input.typing;
	if (!_typing && keyboard_check_pressed(_keys.cancel)) {
		if (_ed.confirm != undefined) {
			_ed.confirm = undefined;
		} else if (_ed.rename_name != undefined) {
			__gm3d_ed_rename_cancel(_ed);
		} else if (_ed.drag_lib != undefined) {
			__gm3d_ed_drop_preview_clear(_ed);
			_ed.drag_lib = undefined;
			_ed.drag_moved = false;
			__gm3d_ed_input_owner_clear(_ed, "library");
		} else if (_ed.cube_armed == true) {
			_ed.cube_armed = undefined;
			_ed.cube_face = undefined;
			_ed.cube_moved = false;
			_ed.press_vp = false;
			__gm3d_ed_input_owner_clear(_ed, "viewcube");
		} else if (_ed.rect != undefined) {
			_ed.rect = undefined;
			_ed.press_vp = false;
			__gm3d_ed_input_owner_clear(_ed, "rect");
		} else if (_ed.giz.drag != -1) {
			var _g = _ed.giz;
			if (is_array(_g.starts) && array_length(_g.starts) == array_length(_ed.sel)) {
				for (var _i = 0; _i < array_length(_ed.sel); _i++) {
					_ed.sel[_i].setLocalPosition(_g.starts[_i].pos.clone());
					_ed.sel[_i].setLocalRotation(_g.starts[_i].rot.clone());
					_ed.sel[_i].setLocalScale(_g.starts[_i].sca.clone());
				}
				_ed.rt.scene.update(0);
			}
			_ed.giz.drag = -1;
			__gm3d_ed_wrap_end(_ed);
			_ed.hist_before = undefined;
			__gm3d_ed_input_owner_clear(_ed, "gizmo");
		} else {
			__gm3d_ed_sel_clear(_ed);
		}
	}
}

/// Continues the active gizmo drag; returns true when handled.
function __gm3d_ed_step_gizmo(_ed, _input) {
	var _vp = _input.vp;
	var _mx = _input.mx;
	var _my = _input.my;
	if (_ed.giz.drag != -1) {
		if (!mouse_check_button(mb_left)) {
			_ed.giz.drag = -1;

			if (_ed.hist_before != undefined) {
				__gm3d_ed_history_commit(_ed, _ed.hist_before);
			}
			__gm3d_ed_wrap_end(_ed);
			__gm3d_ed_rows_follow(_ed, _ed.sel);

			_ed.hist_before = undefined;
			__gm3d_ed_input_owner_clear(_ed, "gizmo");
		} else {
			if (_ed.wrap == undefined) {
				__gm3d_ed_wrap_begin(_ed, _mx, _my);
			}
			var _wv = __gm3d_ed_wrap_step(_ed, _mx, _my);
			__gm3d_ed_gizmo_drag(_ed, _vp, _wv[0], _wv[1]);
			// Keep tracked positions following the live nodes every frame.
			// Entries match by live name + nearest recorded position and two
			// placements from the same asset share the live name: without a
			// per-frame follow, dragging a (just created/duplicated) node
			// near a similar one makes registry_find snap to the wrong entry
			// (outline flicker, wrong hidden/kind, corrupt rows_follow on
			// release). Small per-frame deltas keep the 1-to-1 mapping stable.
			__gm3d_ed_rows_follow(_ed, _ed.sel);
		}
		_ed.giz.hover = _ed.giz.drag;
		_ed.rect = undefined;
		_ed.press_vp = false;
		return true;
	}
	return false;
}

/// Continues library drag and drop; returns true when handled.
function __gm3d_ed_step_libdrop(_ed, _input) {
	var _vp = _input.vp;
	var _mx = _input.mx;
	var _my = _input.my;
	if (_ed.drag_lib != undefined) {
		var _drop_vp = __gm3d_ed_drag_in_viewport(_ed, _mx, _my);
		if (point_distance(_mx, _my, _ed.press_x, _ed.press_y) > 4) {
			_ed.drag_moved = true;
		}
		if (_ed.drag_moved && _drop_vp) {
			var _dpv = __gm3d_ed_drop_point(_ed, _vp, _mx, _my);
			if (_dpv == undefined) {
				// Ray misses the ground (e.g. sky): no positionable point,
				// so the preview hides instead of sitting somewhere stale.
				__gm3d_ed_drop_preview_clear(_ed);
			} else {
				__gm3d_ed_drop_preview_update(_ed, _dpv);
			}
		}
		if (!mouse_check_button(mb_left)) {
			var _drop = undefined;
			if (_ed.drag_moved && _drop_vp) {
				_drop = __gm3d_ed_drop_point(_ed, _vp, _mx, _my);
			} else if (!_ed.drag_moved) {
				var _pp = _ed.rt.cam.getLocalPosition();
				var _f = __gm3d_ed_view_forward(_ed);
				var _dist = 5.0;
				_drop = new GM3D_Vec3(_pp.x - _f.x * _dist, _pp.y - _f.y * _dist, _pp.z - _f.z * _dist);
			}
			if (_drop != undefined) {
				var _hb = undefined;
				_hb = __gm3d_ed_history_snap(_ed);
				var _asset = _ed.drag_lib.asset;
				if (_ed.drag_preview != undefined) {
					// Adopt the preview: final TRS plus registry entry, no
					// second spawn, so the preview never flickers.
					_ed.drag_preview.setLocalPosition(new GM3D_Vec3(_drop.x, _drop.y, _drop.z));
					if (variable_struct_exists(_ed.rt, "on_spawn")) {
						_ed.rt.on_spawn(_ed.inst, _ed.drag_preview, _asset.name, _asset.model);
					}
					var _ap = _ed.drag_preview.getLocalPosition();
					__gm3d_ed_spawn_register(_ed, _ed.drag_preview, _asset.name, [_ap.x, _ap.y, _ap.z], __gm3d_ed_fresh_label(_ed, _asset.name));
					_ed.sel = [_ed.drag_preview];
					_ed.giz.drag = -1;
					_ed.drag_preview = undefined;
				} else {
					var _n = __gm3d_ed_place(
						_ed,
						_asset.name,
						_asset.model,
						[_drop.x, _drop.y, _drop.z],
						undefined,
						[1, 1, 1],
						__gm3d_ed_fresh_label(_ed, _asset.name),
					);
					if (_n != undefined) {
						_ed.sel = [_n];
						_ed.giz.drag = -1;
					}
				}
				if (_hb != undefined) {
					__gm3d_ed_history_commit(_ed, _hb);
				}
			} else {
				__gm3d_ed_drop_preview_clear(_ed);
			}
			_ed.drag_lib = undefined;
			_ed.drag_moved = false;
			__gm3d_ed_input_owner_clear(_ed, "library");
		}
		return true;
	}
	return false;
}

/// Continues rectangle select; returns true when handled.
function __gm3d_ed_step_rect(_ed, _input) {
	var _vp = _input.vp;
	var _mx = _input.mx;
	var _my = _input.my;
	if (_ed.rect != undefined && _ed.rect.on) {
		_ed.rect.x1 = _mx;
		_ed.rect.y1 = _my;
		if (!mouse_check_button(mb_left)) {
			var _r = __gm3d_ed_rect_norm(_ed.rect);
			if (abs(_r.x1 - _r.x0) > 6 || abs(_r.y1 - _r.y0) > 6) {
				// GPU rect pick, executed in Draw (valid 3D render context)
				// same frame: one ID render + one buffer download + region
				// scan, then replace vs shift-add with the old semantics.
				__gm3d_ed_gpupick_request_rect(_ed, _r, keyboard_check(vk_shift));
			}
			_ed.rect = undefined;
			_ed.press_vp = false;
			__gm3d_ed_input_owner_clear(_ed, "rect");
		}
		return true;
	}
	return false;
}

/// Updates gizmo and viewcube hover plus click pick.
function __gm3d_ed_step_hover(_ed, _input) {
	var _vp = _input.vp;
	var _mx = _input.mx;
	var _my = _input.my;
	var _in_vp = _input.in_viewport;
	var _typing = _input.typing;
	__gm3d_ed_imgui_ensure(_ed);
	_ed.cube_geom = _ed.imgui.win_cube.open ? __gm3d_ed_viewcube(_ed) : undefined;
	_ed.cube_hover = undefined;
	if (_in_vp && !mouse_check_button(mb_right) && _ed.cube_geom != undefined) {
		_ed.cube_hover = __gm3d_ed_viewcube_cone_at(_ed.cube_geom, _mx, _my);
	}

	_ed.giz.hover = -1;
	if (_in_vp && !mouse_check_button(mb_right)) {
		_ed.giz.hover = __gm3d_ed_gizmo_hover(_ed, _vp, _mx, _my);
	}
	if (_ed.cube_geom != undefined && __gm3d_ed_viewcube_box_at(_ed.cube_geom, _mx, _my)) {
		_ed.giz.hover = -1;
	}

	if (mouse_check_button_pressed(mb_left) && _in_vp && !_typing && !keyboard_check(vk_alt) && _input.owner == undefined) {
		if (_ed.cube_geom != undefined && __gm3d_ed_viewcube_box_at(_ed.cube_geom, _mx, _my)) {
			_ed.input_owner = "viewcube";
			_input.owner = "viewcube";
			_input.gesture_active = true;
			_ed.press_vp = true;
			_ed.press_x = _mx;
			_ed.press_y = _my;
			_ed.cube_armed = true;
			_ed.cube_face = _ed.cube_hover;
			_ed.cube_moved = false;
			_ed.cube_gx = _mx - _ed.cube_geom.cx;
			_ed.cube_gy = _my - _ed.cube_geom.cy;
		} else if (_ed.giz.hover != -1 && array_length(_ed.sel) > 0) {
			_ed.input_owner = "gizmo";
			_input.owner = "gizmo";
			_input.gesture_active = true;
			_ed.giz.drag = _ed.giz.hover;
			__gm3d_ed_gizmo_begin(_ed, _vp, _mx, _my);
		} else {
			_ed.input_owner = "rect";
			_input.owner = "rect";
			_input.gesture_active = true;
			_ed.press_vp = true;
			_ed.press_x = _mx;
			_ed.press_y = _my;
			_ed.rect = { x0: _mx, y0: _my, x1: _mx, y1: _my, on: false };
		}
	}

	if (_ed.press_vp && _ed.rect != undefined && mouse_check_button(mb_left)) {
		if (point_distance(_mx, _my, _ed.press_x, _ed.press_y) > 6) {
			_ed.rect.on = true;
		}
	}
	if (_ed.cube_armed == true && mouse_check_button(mb_left)) {
		if (point_distance(_mx, _my, _ed.press_x, _ed.press_y) > 6) {
			_ed.cube_moved = true;
		}
		if (_ed.cube_moved) {
			var _ncx = clamp(_mx - _ed.cube_gx, 60, max(61, _ed.gw - 60));
			var _ncy = clamp(_my - _ed.cube_gy, 60, max(61, _ed.gh - 60));
			_ed.cube_off = [_ed.gw - _ncx, _ncy];
		}
	}
	if (mouse_check_button_released(mb_left) && _ed.press_vp && (_ed.rect == undefined || !_ed.rect.on)) {
		_ed.press_vp = false;
		_ed.rect = undefined;
		__gm3d_ed_input_owner_clear(_ed, "rect");
		if (_ed.cube_armed == true) {
			_ed.cube_armed = undefined;
			__gm3d_ed_input_owner_clear(_ed, "viewcube");
			if (_ed.cube_moved) {
				__gm3d_ed_ui_save(_ed);
			}
			if (_in_vp && !_ed.cube_moved && _ed.cube_face != undefined && _ed.cube_geom != undefined) {
				var _rf = __gm3d_ed_viewcube_cone_at(_ed.cube_geom, _mx, _my);
				if (_rf != undefined && _rf[0] == _ed.cube_face[0] && _rf[1] == _ed.cube_face[1]) {
					for (var _fi = 0; _fi < array_length(_ed.cube_geom.faces); _fi++) {
						var _ff = _ed.cube_geom.faces[_fi];
						if (_ff.a == _rf[0] && _ff.s == _rf[1]) {
							__gm3d_ed_viewcube_snap(_ed, _ff.n);
							break;
						}
					}
				}
			}
			_ed.cube_face = undefined;
		} else if (_in_vp) {
			// GPU ID pick, executed in Draw (valid 3D render context) same
			// frame: precise per-pixel topmost with depth, icons first.
			__gm3d_ed_gpupick_request_click(_ed, _mx, _my, keyboard_check(vk_shift));
		}
	}
}

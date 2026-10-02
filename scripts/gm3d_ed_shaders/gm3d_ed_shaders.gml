// Returns list of editor shaders.
function __gm3d_ed_editor_shaders() {
	return [shGM3DGrid, shGM3DMask, shGM3DMaskSkin, shGM3DOutline, shGM3DId, shGM3DIdSkin, shGM3DUnlit, shGM3DUnlitSkin, shGM3DSky];
}

// Precompiles editor shaders using tiny surface.
function __gm3d_ed_shaders_warmup(_ed) {
	if (_ed == undefined) {
		return;
	}
	if (variable_struct_exists(_ed, "shaders_warmed") && _ed.shaders_warmed == true) {
		return;
	}
	_ed.shaders_warmed = true;
	var _surf = undefined;
	try {
		_surf = surface_create(8, 8);
	} catch (_e) {
		_surf = undefined;
	}
	if (_surf == undefined || !surface_exists(_surf)) {
		return;
	}
	try {
		surface_set_target(_surf);
		draw_clear(c_black);
		var _list = __gm3d_ed_editor_shaders();
		for (var _i = 0; _i < array_length(_list); _i++) {
			try {
				shader_set(_list[_i]);
				draw_rectangle(0, 0, 2, 2, false);
				shader_reset();
			} catch (_eS) {
				try {
					shader_reset();
				} catch (_eR) {
				}
			}
		}
		surface_reset_target();
	} catch (_eW) {
		try {
			shader_reset();
		} catch (_eR2) {
		}
		try {
			surface_reset_target();
		} catch (_eT) {
		}
	}
	try {
		if (surface_exists(_surf)) {
			surface_free(_surf);
		}
	} catch (_eF) {
	}
}

// Swaps model materials between lit and unlit forward shaders.
function __gm3d_ed_unlit_apply(_ed) {
	if (_ed == undefined || _ed.rt == undefined || _ed.rt.scene == undefined) {
		return;
	}
	var _on = _ed.show_unlit == true;
	var _roots = [];
	try {
		_roots = _ed.rt.scene.getNodes();
	} catch (_e) {
		return;
	}
	for (var _pass = 0; _pass < 2; _pass++) {
		for (var _r = 0; _r < array_length(_roots); _r++) {
			__gm3d_ed_unlit_walk(_ed, _roots[_r], _on, _pass);
		}
	}
}

// Applies unlit or lit shader to subtree materials for one pass.
function __gm3d_ed_unlit_walk(_ed, _node, _on, _pass) {
	var _stack = [_node];
	while (array_length(_stack) > 0) {
		var _cur = array_pop(_stack);
		if (_cur == undefined) {
			continue;
		}
		var _skip = false;
		try {
			_skip = is_string(_cur.name) && (_cur.name == "__editor_grid" || _cur.name == "__skybox");
		} catch (_eN) {
		}
		if (!_skip) {
			try {
				if (_pass == 0) {
					var _mc = _cur.getMeshComponent();
					if (_mc != undefined) {
						var _mm = _mc.getMaterial();
						if (_mm != undefined) {
							_mm.setShader(GM3D_ERenderPass.Forward, _on ? shGM3DUnlit : sStatic);
						}
					}
				} else {
					var _sk = _cur.getSkinnedMeshComponent();
					if (_sk != undefined) {
						var _sm = _sk.getMaterial();
						if (_sm != undefined) {
							_sm.setShader(GM3D_ERenderPass.Forward, _on ? shGM3DUnlitSkin : sAnimated);
						}
					}
				}
			} catch (_eM) {
			}
		}
		var _kids = [];
		try {
			_kids = _cur.getChildren();
		} catch (_eK) {
		}
		for (var _k = 0; _k < array_length(_kids); _k++) {
			array_push(_stack, _kids[_k]);
		}
	}
}

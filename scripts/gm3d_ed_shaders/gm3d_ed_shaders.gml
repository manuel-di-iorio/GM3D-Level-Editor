// Returns list of editor shaders.
function __gm3d_ed_editor_shaders() {
	return [
        shGM3DGrid, shGM3DMask, shGM3DMaskSkin, shGM3DOutline, shGM3DId, shGM3DIdSkin, shGM3DUnlit, 
        shGM3DUnlitSkin, shGM3DSky
    ];
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
	if (!variable_struct_exists(_ed, "unlit_orig") || !is_array(_ed.unlit_orig)) {
		_ed.unlit_orig = [];
	}
	if (_ed.show_unlit != true) {
		__gm3d_ed_unlit_restore(_ed);
		return;
	}
	var _roots = [];
	try {
		_roots = _ed.rt.scene.getNodes();
	} catch (_e) {
		return;
	}
	for (var _r = 0; _r < array_length(_roots); _r++) {
		__gm3d_ed_unlit_walk(_ed, _roots[_r]);
	}
}

// Records original forward shader once per material.
function __gm3d_ed_unlit_record(_ed, _mm, _skinned) {
	var _list = _ed.unlit_orig;
	for (var _i = 0; _i < array_length(_list); _i++) {
		if (_list[_i].mat == _mm) {
			return;
		}
	}
	var _sh = undefined;
	try {
		_sh = _mm.getShader(GM3D_ERenderPass.Forward);
	} catch (_eG) {
	}
	array_push(_list, { mat: _mm, sh: _sh, skinned: _skinned });
}

// Restores recorded forward shaders.
function __gm3d_ed_unlit_restore(_ed) {
	var _list = _ed.unlit_orig;
	_ed.unlit_orig = [];
	for (var _i = 0; _i < array_length(_list); _i++) {
		var _e = _list[_i];
		var _sh = _e.sh;
		if (_sh == undefined) {
			_sh = _e.skinned ? sAnimated : sStatic;
		}
		try {
			_e.mat.setShader(GM3D_ERenderPass.Forward, _sh);
		} catch (_eS) {
		}
	}
}

// Applies unlit shader to subtree materials, recording originals.
function __gm3d_ed_unlit_walk(_ed, _node) {
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
				var _mc = _cur.getMeshComponent();
				if (_mc != undefined) {
					var _mm = _mc.getMaterial();
					if (_mm != undefined) {
						__gm3d_ed_unlit_record(_ed, _mm, false);
						_mm.setShader(GM3D_ERenderPass.Forward, shGM3DUnlit);
						try {
							_mm.setFloat("u_skinned", 0.0);
						} catch (_eF) {
						}
					}
				}
			} catch (_eM) {
			}
			try {
				var _sk = _cur.getSkinnedMeshComponent();
				if (_sk != undefined) {
					var _sm = _sk.getMaterial();
					if (_sm != undefined) {
						__gm3d_ed_unlit_record(_ed, _sm, true);
						_sm.setShader(GM3D_ERenderPass.Forward, shGM3DUnlit);
						try {
							_sm.setFloat("u_skinned", 1.0);
						} catch (_eF2) {
						}
					}
				}
			} catch (_eM2) {
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

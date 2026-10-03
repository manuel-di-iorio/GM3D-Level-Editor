// Returns list of editor shaders.
function __gm3d_ed_editor_shaders() {
	return [
        shGM3DGrid, shGM3DMask, shGM3DMaskSkin, shGM3DOutline, shGM3DId, shGM3DIdSkin, shGM3DUnlit, 
        shGM3DUnlitSkin, shGM3DSky, shGM3DMagenta, shGM3DMagentaSkin
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
	_surf = surface_create(8, 8);
	if (_surf == undefined || !surface_exists(_surf)) {
		return;
	}
	surface_set_target(_surf);
	draw_clear(c_black);
	var _list = __gm3d_ed_editor_shaders();
	for (var _i = 0; _i < array_length(_list); _i++) {
		shader_set(_list[_i]);
		draw_rectangle(0, 0, 2, 2, false);
		shader_reset();
	}
	surface_reset_target();
	if (surface_exists(_surf)) {
		surface_free(_surf);
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
	_roots = _ed.rt.scene.getNodes();
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
	_sh = _mm.getShader(GM3D_ERenderPass.Forward);
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
		_e.mat.setShader(GM3D_ERenderPass.Forward, _sh);
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
		_skip = is_string(_cur.name) && (_cur.name == "__editor_grid" || _cur.name == "__skybox");
		if (!_skip) {
			var _mc = _cur.getMeshComponent();
			if (_mc != undefined) {
				var _mm = _mc.getMaterial();
				if (_mm != undefined) {
					__gm3d_ed_unlit_record(_ed, _mm, false);
					_mm.setShader(GM3D_ERenderPass.Forward, shGM3DUnlit);
					_mm.setFloat("u_skinned", 0.0);
				}
			}
			var _sk = _cur.getSkinnedMeshComponent();
			if (_sk != undefined) {
				var _sm = _sk.getMaterial();
				if (_sm != undefined) {
					__gm3d_ed_unlit_record(_ed, _sm, true);
					_sm.setShader(GM3D_ERenderPass.Forward, shGM3DUnlit);
					_sm.setFloat("u_skinned", 1.0);
				}
			}
		}
		var _kids = [];
		_kids = _cur.getChildren();
		for (var _k = 0; _k < array_length(_kids); _k++) {
			array_push(_stack, _kids[_k]);
		}
	}
}

// Ensures shared missing-material magenta materials exist.
function __gm3d_ed_magenta_mats(_ed) {
	if (_ed == undefined) {
		return false;
	}
	if (_ed.magenta_mat != undefined && _ed.magenta_mat_skin != undefined) {
		return true;
	}
	if (_ed.magenta_mat == undefined) {
		var _m = new GM3D_Material("gm3d_ed_magenta");
		_m.setShader(GM3D_ERenderPass.Forward, shGM3DMagenta);
		_m.setShader(GM3D_ERenderPass.Shadow, sStaticShadow);
		_ed.magenta_mat = _m;
	}
	if (_ed.magenta_mat_skin == undefined) {
		var _ms = new GM3D_Material("gm3d_ed_magenta_skin");
		_ms.setShader(GM3D_ERenderPass.Forward, shGM3DMagentaSkin);
		_ms.setShader(GM3D_ERenderPass.Shadow, sAnimatedShadow);
		_ed.magenta_mat_skin = _ms;
	}
	return true;
}

// Assigns fallback materials to material-less meshes in subtree.
function __gm3d_ed_magenta_fix_mats(_node, _mat, _mat_skin) {
	if (_node == undefined || _mat == undefined) {
		return;
	}
	var _stack = [_node];
	while (array_length(_stack) > 0) {
		var _cur = array_pop(_stack);
		if (_cur == undefined) {
			continue;
		}
		var _mc = _cur.getMeshComponent();
		if (_mc != undefined && _mc.getMaterial() == undefined) {
			_mc.setMaterial(_mat);
		}
		var _sk = _cur.getSkinnedMeshComponent();
		if (_sk != undefined && _mat_skin != undefined && _sk.getMaterial() == undefined) {
			_sk.setMaterial(_mat_skin);
		}
		var _kids = _cur.getChildren();
		for (var _k = 0; _k < array_length(_kids); _k++) {
			array_push(_stack, _kids[_k]);
		}
	}
}

// Paints material-less meshes magenta.
function __gm3d_ed_magenta_fix(_ed, _node) {
	if (_ed == undefined || _node == undefined) {
		return;
	}
	if (!__gm3d_ed_magenta_mats(_ed)) {
		return;
	}
	__gm3d_ed_magenta_fix_mats(_node, _ed.magenta_mat, _ed.magenta_mat_skin);
}

// Paints material-less meshes magenta without editor state.
function __gm3d_load_magenta_fix(_node) {
	static _m = undefined;
	static _ms = undefined;
	if (_node == undefined) {
		return;
	}
	if (_m == undefined) {
		_m = new GM3D_Material("gm3d_load_magenta");
		_m.setShader(GM3D_ERenderPass.Forward, shGM3DMagenta);
		_m.setShader(GM3D_ERenderPass.Shadow, sStaticShadow);
	}
	if (_ms == undefined) {
		_ms = new GM3D_Material("gm3d_load_magenta_skin");
		_ms.setShader(GM3D_ERenderPass.Forward, shGM3DMagentaSkin);
		_ms.setShader(GM3D_ERenderPass.Shadow, sAnimatedShadow);
	}
	__gm3d_ed_magenta_fix_mats(_node, _m, _ms);
}

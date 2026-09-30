// Returns list of editor shaders.
function __gm3d_ed_editor_shaders() {
	return [shGM3DGrid, shGM3DMask, shGM3DMaskSkin, shGM3DOutline, shGM3DId, shGM3DIdSkin];
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

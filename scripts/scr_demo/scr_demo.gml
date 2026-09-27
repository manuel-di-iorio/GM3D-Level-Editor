/// Create the runtime scene, renderer and default environment/light/camera.
/// @param {Id.Instance} _self owning object instance
function demo_create(_self) {
	_self.scene = GM3D_Scene.createEmpty();

	_self.renderer = new GM3D_Renderer();

	_self.assets = [];

	_self.asset_cache = {};

	_self.camNode = undefined;
	_self.camComp = undefined;
	_self.camPos = new GM3D_Vec3(-1.3, 1.0, 4.5);
	_self.camYaw = 190.0;
	_self.camPitch = 10.0;

	var _envNode = _self.scene.createNode("Environment");
	var _envComp = new GM3D_EnvironmentVolumeComponent();
	_envNode.addComponent(_envComp);
	_envComp.setSize(20000.0, 20000.0, 20000.0);
	_envComp.setAmbientColor(make_colour_rgb(70, 70, 85));
	_self.envNode = _envNode;
	_self.envComp = _envComp;

	var _lightNode = _self.scene.createNode("Sun");
	var _lightComp = new GM3D_LightComponent();
	_lightNode.addComponent(_lightComp);
	_lightComp.setType(GM3D_ELightType.Directional);
	_lightComp.setColor(c_white);
	_lightComp.setIntensity(1.0);
	demo_align_node(_lightNode, new GM3D_Vec3(0.35, 0.8, 0.45));
	_self.lightNode = _lightNode;
	_self.lightComp = _lightComp;

	var _camNode = _self.scene.createNode("MainCamera");
	var _camComp = new GM3D_CameraComponent();
	_camNode.addComponent(_camComp);
	_camComp.setFar(10000.0);
	_camComp.setScreenRect([0.0, 0.0, 1.0, 1.0]);
	_self.camNode = _camNode;
	_self.camComp = _camComp;

	demo_place_camera(_self);
}

/// Tear down the runtime scene and release the renderer.
/// @param {Id.Instance} _self owning object instance
function demo_destroy(_self) {
	if (!is_undefined(_self.scene)) {
		_self.scene.destroy();
	}
	_self.scene = undefined;
	_self.camNode = undefined;
	_self.camComp = undefined;

	for (var i = 0; i < array_length(_self.assets); ++i) {
		_self.assets[i].destroy();
	}
	_self.assets = [];

	_self.renderer = undefined;
}

/// Advance the scene graph by an explicit delta. The gateway steps the live
/// world only while the editor is closed; the editor itself advances with 0
/// (frozen poses, fresh matrices) straight on the adapter scene.
/// @param {Id.Instance} _self owning object instance
function demo_step(_self) {
	_self.scene.update(delta_time * 0.000001);
}

/// Render the scene through the renderer.
/// @param {Id.Instance} _self owning object instance
function demo_render(_self) {
	_self.renderer.render(_self.scene);
}

/// Load a glTF file, freeze it and register it for cleanup. Dev-side loading
/// example: a real game loads its models its own way and passes the handles
/// to gm3d_editor_asset_add; the editor never sees paths.
/// Frozen sources are cached by path: spawnInto reuses meshes, so repeated
/// spawns of the same asset never re-parse the file.
/// @param {Id.Instance} _self owning object instance
/// @param {String} _path relative path under the working directory
/// @return {Any} loaded scene or undefined
function demo_load_model(_self, _path) {
	var _src = undefined;

	if (variable_struct_exists(_self.asset_cache, _path)) {
		_src = _self.asset_cache[$ _path];
	}

	if (_src == undefined) {
		_src = GM3D_Scene.loadGltf(working_directory + _path);
		if (_src == undefined) {
			return undefined;
		}
		demo_assign_shaders(_src);
		_src.freeze();
		array_push(_self.assets, _src);
		_self.asset_cache[$ _path] = _src;
	}
	return _src;
}

/// Assign the sample lighting shaders to every material in a frozen source
/// scene. Skinned meshes need the animated shader (GPU bone skinning); the
/// rest get the static shader. Without this, skinned geometry is not drawn.
/// @param {Any} _scene source scene to assign shaders to
function demo_assign_shaders(_scene) {
	var _nodes = _scene.getNodes();
	var _materials = _scene.getMaterials();

	for (var _matIdx = 0; _matIdx < array_length(_materials); ++_matIdx) {
		_materials[_matIdx].setShader(sStatic);
	}

	for (var _nodeIdx = 0; _nodeIdx < array_length(_nodes); ++_nodeIdx) {
		var _node = _nodes[_nodeIdx];
		var _skinnedComp = _node.getSkinnedMeshComponent();
		if (_skinnedComp != undefined) {
			var _skinnedMat = _skinnedComp.getMaterial();
			if (_skinnedMat != undefined) {
				_skinnedMat.setShader(sAnimated);
			}
		}
	}
}

/// Optional adapter hook: finish an editor-placed instance.
/// Runs after the editor sets TRS, so the game can add per-instance setup
/// (animation state, AI, ...) without owning placement. Static props need
/// nothing here.
/// @param {Id.Instance} _self owning object instance
/// @param {Any} _node freshly placed root node
/// @param {String} _asset library name
/// @param {Any} _src loaded (frozen) source scene, as passed to gm3d_editor_asset_add
function demo_on_spawn(_self, _node, _asset, _src) {
	if (_node == undefined || _src == undefined) {
		return;
	}

	if (_src.animationCount > 0) {
		var _anim = demo_find_anim(_node);
		if (_anim != undefined) {
			var _idx = demo_find_anim_index(_src, "idle");
			_anim.setEnabled(true);
			_anim.setTime(0.0);
			_anim.setSpeed(1.0);
			_anim.play(_idx, true);
		}
	}
}

/// Find the first animation component in a node subtree.
/// @param {Any} _node root node
/// @return {Any} animation component or undefined
function demo_find_anim(_node) {
	if (_node == undefined) {
		return undefined;
	}
	var _comp = _node.getAnimationComponent();
	if (_comp != undefined) {
		return _comp;
	}
	var _children = _node.getChildren();
	for (var i = 0; i < array_length(_children); ++i) {
		var _nested = demo_find_anim(_children[i]);
		if (_nested != undefined) {
			return _nested;
		}
	}
	return undefined;
}

/// Resolve an animation index by name with substring fallback.
/// @param {Any} _src loaded scene
/// @param {String} _name preferred animation name
/// @return {Real} animation index
function demo_find_anim_index(_src, _name) {
	var _count = _src.animationCount;
	var _target = string_lower(string(_name));
	var _fallback = -1;
	for (var i = 0; i < _count; ++i) {
		var _anim = _src.getAnimation(i);
		var _nm = string_lower(string(_anim.path));
		if (_nm == _target) {
			return i;
		}
		if (_fallback < 0 && string_pos(_target, _nm) > 0) {
			_fallback = i;
		}
	}
	if (_fallback >= 0) {
		return _fallback;
	}
	return 0;
}

/// Build the forward direction vector from yaw and pitch, matching the
/// GM3D sample camera convention.
/// @param {Real} _yaw degrees
/// @param {Real} _pitch degrees
/// @return {Any} forward unit vector
function demo_forward(_yaw, _pitch) {
	var _y = degtorad(_yaw);
	var _p = degtorad(_pitch);
	var _cp = cos(_p);
	return new GM3D_Vec3(sin(_y) * _cp, sin(_p), -cos(_y) * _cp);
}

/// Rotate a node so its forward axis points toward _dir.
/// @param {Any} _node scene node
/// @param {Any} _dir direction vector
function demo_align_node(_node, _dir) {
	var _forward = _dir.clone();
	_forward.normalize();
	var _up = GM3D_Vec3.up();
	if (abs(_forward.dot(_up)) >= 0.999) {
		_up = GM3D_Vec3.forward();
	}
	var _rot = GM3D_Quaternion.fromLookRotation(_forward, _up);
	_node.setLocalRotation(_rot.normalizeSafe(0.000001));
}

/// Adapter surface consumed by the editor (see gm3d_editor header).
/// A real game provides the same shape on its own runtime: the live scene
/// and camera node as data, plus optional hooks for the game-owned
/// decisions. on_spawn runs after the editor places an instance so the game
/// can finish it (animation state, AI); on_close is optional: the editor
/// calls it once when the UI closes so the game can resume its own
/// business. The editor always passes the game instance as the first
/// function argument explicitly, so nothing depends on method-binding or
/// closure scope rules. Rebuild the adapter if you ever recreate the
/// scene or camera node.
/// @param {Id.Instance} _self owning object instance
/// @return {Struct} adapter { scene, cam, on_spawn?, on_close? }
function demo_adapter(_self) {
	return {
		scene: _self.scene,
		cam: _self.camNode,
		on_spawn: demo_on_spawn,
		on_close: demo_on_close,
	};
}

/// Editor-closed hook: game-side resume actions. The demo world simply
/// keeps stepping from the editor camera, so nothing is needed here.
/// @param {Id.Instance} _self owning object instance
function demo_on_close(_self) {}

/// Push the camera controller state into the camera node.
/// @param {Id.Instance} _self owning object instance
function demo_place_camera(_self) {
	_self.camNode.setLocalPosition(_self.camPos);
	demo_align_node(_self.camNode, demo_forward(_self.camYaw, _self.camPitch));
}

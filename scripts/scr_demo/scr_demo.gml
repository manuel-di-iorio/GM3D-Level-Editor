// Creates demo scene with environment.
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
	_envComp.setSize(new GM3D_Vec3(20000.0, 20000.0, 20000.0));
	_envComp.setAmbientColor(make_colour_rgb(70, 70, 85));

	var _lightNode = _self.scene.createNode("Sun");
	var _lightComp = new GM3D_LightComponent();
	_lightNode.addComponent(_lightComp);
	_lightComp.setType(GM3D_ELightType.Directional);
	_lightComp.setColor(c_white);
	_lightComp.setIntensity(1.0);
	_lightComp.setShadowEnabled(true);
	_lightComp.setShadowResolution(2048);
	_lightComp.setShadowDistance(30.0);
	_lightComp.setShadowNormalOffset(0.05);
	_lightNode.setLocalPosition(new GM3D_Vec3(0.3, 2.2, 1.3));
	demo_align_node(_lightNode, new GM3D_Vec3(0.35, 0.8, 0.45));

	var _camNode = _self.scene.createNode("MainCamera");
	var _camComp = new GM3D_CameraComponent();
	_camNode.addComponent(_camComp);
	_camComp.setFar(10000.0);
	_camComp.setScreenRect([0.0, 0.0, 1.0, 1.0]);
	_self.camNode = _camNode;
	_self.camComp = _camComp;

	demo_place_camera(_self);

	_self.demo_track = [
		["camera", "", _camNode, "MainCamera"],
		["light", "", _lightNode, "Sun"],
		["environment", "", _envNode, "Environment"],
	];
	var _def = [
		["Platform", "kenney_platformer-kit/platform.glb", [0, -0.4, 0], undefined, [2.4, 2.4, 2.4]],
		["Tree", "kenney_platformer-kit/tree.glb", [-3.2, 0, -3.6], undefined, [1.2, 1.2, 1.2]],
		["Pine", "kenney_platformer-kit/tree-pine.glb", [3.4, 0, -3.2], undefined, [1.1, 1.1, 1.1]],
		["Flowers", "kenney_platformer-kit/flowers.glb", [-1.6, 0, -1.8], undefined, [1, 1, 1]],
		["Grass", "kenney_platformer-kit/grass.glb", [1.8, 0, -1.6], undefined, [1, 1, 1]],
		["Rocks", "kenney_platformer-kit/rocks.glb", [0, 0, -2.8], [0, 0.1736481934785843, 0, 0.9848078489303589], [1.1, 1.1, 1.1]],
		["Character", "kenney_mini-characters/character-female-b.glb", [-0.9, 0, 0], [0, 0.1736481934785843, 0, 0.9848078489303589], [1, 1, 1]],
		["Fox", "kenney_cube-pets_1.0/animal-fox.glb", [0.95, 0, 0.55], [0, -0.2164396196603775, 0, 0.9762960076332092], [0.3, 0.3, 0.3]],
	];
	for (var i = 0; i < array_length(_def); ++i) {
		var _d = _def[i];
		var _node = demo_spawn_asset(_self, _d[0], _d[1], _d[2], _d[3], _d[4]);
		if (_node != undefined) {
			array_push(_self.demo_track, ["asset", _d[0], _node, _d[0]]);
		}
	}
	_self.scene.update(0);
}

// Loads model and spawns scene node.
function demo_spawn_asset(_self, _asset, _path, _pos, _rot = undefined, _scale = undefined) {
	var _src = demo_load_model(_self, _path);
	if (_src == undefined) {
		return undefined;
	}
	var _node = _src.spawnInto(_self.scene, undefined);
	if (_node == undefined) {
		return undefined;
	}
	_node.setLocalPosition(new GM3D_Vec3(_pos[0], _pos[1], _pos[2]));
	if (_scale != undefined) {
		_node.setLocalScale(new GM3D_Vec3(_scale[0], _scale[1], _scale[2]));
	} else {
		_node.setLocalScale(new GM3D_Vec3(1, 1, 1));
	}
	if (_rot != undefined) {
		var _q = new GM3D_Quaternion();
		_q.x = _rot[0];
		_q.y = _rot[1];
		_q.z = _rot[2];
		_q.w = _rot[3];
		_node.setLocalRotation(_q.normalizeSafe(0.000001));
	}
	demo_on_spawn(_self, _node, _asset, _src);
	return _node;
}

// Destroys demo scene and assets.
function demo_destroy(_self) {
	if (!is_undefined(_self.scene)) {
		_self.scene.destroy();
	}
	_self.scene = undefined;
	_self.camNode = undefined;
	_self.camComp = undefined;
	_self.demo_track = undefined;

	for (var i = 0; i < array_length(_self.assets); ++i) {
		_self.assets[i].destroy();
	}
	_self.assets = [];

	_self.renderer = undefined;
}

// Updates demo scene animation.
function demo_step(_self) {
	_self.scene.update(delta_time * 0.000001);
}

// Renders demo scene.
function demo_render(_self) {
	_self.renderer.render(_self.scene);
}

// Loads cached GLTF model file.
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

// Assigns static and skinned shaders.
function demo_assign_shaders(_scene) {
	var _nodes = _scene.getNodes();
	var _materials = _scene.getMaterials();

	for (var _matIdx = 0; _matIdx < array_length(_materials); ++_matIdx) {
		_materials[_matIdx].setShader(GM3D_ERenderPass.Forward, sStatic);
		_materials[_matIdx].setShader(GM3D_ERenderPass.Shadow, sStaticShadow);
	}

	for (var _nodeIdx = 0; _nodeIdx < array_length(_nodes); ++_nodeIdx) {
		var _node = _nodes[_nodeIdx];
		var _skinnedComp = _node.getSkinnedMeshComponent();
		if (_skinnedComp != undefined) {
			var _skinnedMat = _skinnedComp.getMaterial();
			if (_skinnedMat != undefined) {
				_skinnedMat.setShader(GM3D_ERenderPass.Forward, sAnimated);
				_skinnedMat.setShader(GM3D_ERenderPass.Shadow, sAnimatedShadow);
			}
		}
	}
}

// Assigns lighting shaders across a live node subtree.
function demo_assign_instance_shaders(_node) {
	var _stack = [_node];
	while (array_length(_stack) > 0) {
		var _cur = array_pop(_stack);
		if (_cur == undefined) {
			continue;
		}
		var _mc = _cur.getMeshComponent();
		if (_mc != undefined) {
			var _mm = undefined;
			_mm = _mc.getMaterial();
			if (_mm != undefined) {
				_mm.setShader(GM3D_ERenderPass.Forward, sStatic);
				_mm.setShader(GM3D_ERenderPass.Shadow, sStaticShadow);
			}
		}
		var _sk = _cur.getSkinnedMeshComponent();
		if (_sk != undefined) {
			var _sm = undefined;
			_sm = _sk.getMaterial();
			if (_sm != undefined) {
				_sm.setShader(GM3D_ERenderPass.Forward, sAnimated);
				_sm.setShader(GM3D_ERenderPass.Shadow, sAnimatedShadow);
			}
		}
		var _kids = [];
		_kids = _cur.getChildren();
		for (var _k = 0; _k < array_length(_kids); _k++) {
			array_push(_stack, _kids[_k]);
		}
	}
}

// Starts idle animation on spawned node.
function demo_on_spawn(_self, _node, _asset, _src) {
	if (_node == undefined || _src == undefined) {
		return;
	}
	demo_assign_instance_shaders(_node);

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

// Finds animation component recursively.
function demo_find_anim(_node) {
	if (_node == undefined) {
		return undefined;
	}
	var _found = _node.findAnimationComponent();
	if (_found != undefined) {
		return _found;
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

// Finds animation index by name.
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

// Computes forward vector from angles.
function demo_forward(_yaw, _pitch) {
	var _y = degtorad(_yaw);
	var _p = degtorad(_pitch);
	var _cp = cos(_p);
	return new GM3D_Vec3(sin(_y) * _cp, sin(_p), -cos(_y) * _cp);
}

// Orients node toward direction vector.
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

// Builds editor runtime adapter struct.
function demo_adapter(_self) {
	return {
		scene: _self.scene,
		cam: _self.camNode,
		on_spawn: demo_on_spawn,
	};
}

// Positions camera from stored settings.
function demo_place_camera(_self) {
	_self.camNode.setLocalPosition(_self.camPos);
	demo_align_node(_self.camNode, demo_forward(_self.camYaw, _self.camPitch));
}

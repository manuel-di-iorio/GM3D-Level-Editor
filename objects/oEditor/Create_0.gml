demo_create(id);
gm3d_editor_init(id, demo_adapter(id));

var _lib = [
	["Platform", "kenney_platformer-kit/platform.glb"],
	["Tree", "kenney_platformer-kit/tree.glb"],
	["Pine", "kenney_platformer-kit/tree-pine.glb"],
	["Flowers", "kenney_platformer-kit/flowers.glb"],
	["Grass", "kenney_platformer-kit/grass.glb"],
	["Rocks", "kenney_platformer-kit/rocks.glb"],
	["Character", "kenney_mini-characters/character-female-b.glb"],
	["Fox", "kenney_cube-pets_1.0/animal-fox.glb"],
];

for (var _i = 0, _n = array_length(_lib); _i < _n; _i++) {
	var _model = _lib[_i];
	gm3d_editor_asset_add(_model[0], demo_load_model(id, _model[1]));
}

for (var _k = 0; _k < array_length(id.demo_track); ++_k) {
	var _t = id.demo_track[_k];
	gm3d_editor_track(_t[0], _t[1], _t[2], _t[3]);
}

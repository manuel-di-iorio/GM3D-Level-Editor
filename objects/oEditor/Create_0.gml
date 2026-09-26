demo_create(id);
ed = gm3d_editor_init(id, demo_adapter(id));

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
	gm3d_editor_asset_add(ed, _model[0], demo_load_model(id, _model[1]));
}

// The demo light and environment join the editor like any other node:
// they show in Scene, save to JSON and undo. The demo camera stays the
// editor viewport camera (never tracked, never saved).
gm3d_editor_light_add(ed, id.lightNode, "Sun");
gm3d_editor_environment_add(ed, id.envNode, "Environment");

gm3d_editor_load("demo.json");
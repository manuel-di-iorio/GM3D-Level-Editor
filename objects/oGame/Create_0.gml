demo_create();

var config = {
  scene: demo_scene,
  cam: demo_cam,
  on_spawn: demo_on_spawn,
  assets: [
    demo_load_model("kenney_platformer-kit/platform.glb"),
    demo_load_model("kenney_platformer-kit/tree.glb"),
    demo_load_model("kenney_platformer-kit/tree-pine.glb"),
    demo_load_model("kenney_platformer-kit/flowers.glb"),
    demo_load_model("kenney_platformer-kit/grass.glb"),
    demo_load_model("kenney_platformer-kit/rocks.glb"),
    demo_load_model("kenney_mini-characters/character-female-b.glb"),
    demo_load_model("kenney_cube-pets_1.0/animal-fox.glb"),
  ],
};

instance_create_layer(0, 0, layer, oEditor, { config });
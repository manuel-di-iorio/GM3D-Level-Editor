////////////////////////////////////////////////////////////////////////////////
//
// Vertex shader for static (non-skinned) shadow geometry.
//
// Transforms vertex position to directional shadow-map clip space and passes
// texture coordinates for alpha-cutout evaluation.
//
// Ported from YoYoGames/GM3D-Samples (develop branch, shStaticShadow).
//
////////////////////////////////////////////////////////////////////////////////

// Attributes
attribute vec3 in_Position;
attribute vec2 in_TextureCoord;

// Varyings
varying vec2 vTexCoord;

void main()
{
	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(in_Position, 1.0);
	vTexCoord = in_TextureCoord;
}

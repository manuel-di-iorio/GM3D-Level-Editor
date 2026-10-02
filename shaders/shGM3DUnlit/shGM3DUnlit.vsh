////////////////////////////////////////////////////////////////////////////////
//
// Vertex shader for unlit (flat) static geometry.
//
// Passes position through for projection; lighting varyings omitted.
//
////////////////////////////////////////////////////////////////////////////////

// Attributes
attribute vec3 in_Position;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;

// Varyings
varying vec4 vColor;
varying vec2 vTexCoord;

void main()
{
	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(in_Position, 1.0);
	vColor = in_Colour;
	vTexCoord = in_TextureCoord;
}

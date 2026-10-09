////////////////////////////////////////////////////////////////////////////////
//
// Vertex shader for instanced static (non-skinned) shadow geometry.
//
// Reads a per-instance world matrix, transforms vertex position to directional
// shadow-map clip space, and passes texture coordinates for alpha-cutout
// evaluation.
//
////////////////////////////////////////////////////////////////////////////////

// Attributes
attribute vec3 in_Position;
attribute vec2 in_TextureCoord;

// Per-instance attributes
attribute vec4 in_InstanceMatrixCol0;
attribute vec4 in_InstanceMatrixCol1;
attribute vec4 in_InstanceMatrixCol2;
attribute vec4 in_InstanceMatrixCol3;

// Varyings
varying vec2 vTexCoord;

void main()
{
	mat4 world = mat4(
		in_InstanceMatrixCol0,
		in_InstanceMatrixCol1,
		in_InstanceMatrixCol2,
		in_InstanceMatrixCol3
	);
	gl_Position = gm_Matrices[MATRIX_PROJECTION] * gm_Matrices[MATRIX_VIEW] * world * vec4(in_Position, 1.0);
	vTexCoord = in_TextureCoord;
}
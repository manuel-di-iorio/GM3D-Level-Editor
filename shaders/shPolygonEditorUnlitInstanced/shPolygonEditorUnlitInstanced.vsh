////////////////////////////////////////////////////////////////////////////////
//
// Vertex shader for unlit (flat) instanced static geometry.
//
// Reads a per-instance world matrix from vertex attributes.
//
////////////////////////////////////////////////////////////////////////////////

// Attributes
attribute vec3 in_Position;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;

// Per-instance attributes
attribute vec4 in_InstanceMatrixCol0;
attribute vec4 in_InstanceMatrixCol1;
attribute vec4 in_InstanceMatrixCol2;
attribute vec4 in_InstanceMatrixCol3;

// Varyings
varying vec4 vColor;
varying vec2 vTexCoord;

void main()
{
	// Instance world matrix
	mat4 world = mat4(
		in_InstanceMatrixCol0,
		in_InstanceMatrixCol1,
		in_InstanceMatrixCol2,
		in_InstanceMatrixCol3
	);

	vec4 worldPos = world * vec4(in_Position, 1.0);

	gl_Position = gm_Matrices[MATRIX_PROJECTION] * gm_Matrices[MATRIX_VIEW] * worldPos;
	vColor = in_Colour;
	vTexCoord = in_TextureCoord;
}

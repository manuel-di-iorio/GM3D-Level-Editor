////////////////////////////////////////////////////////////////////////////////
//
// Vertex shader for the editor grid.
//
// The model is a single quad and every line is procedural in the fragment
// stage, so this passes through only what the pattern needs: the world
// position (line pattern) and the view depth (distance bands). No normals,
// colors, UVs, tangents, lighting or fog: the grid is unlit by design.
//
////////////////////////////////////////////////////////////////////////////////

// Attributes
attribute vec3 in_Position;

// Varyings
varying vec3 vWorldPosition;
varying float vViewDepth;

void main()
{
	vec4 p = vec4(in_Position, 1.0);

	vec4 worldPos = gm_Matrices[MATRIX_WORLD] * p;
	vWorldPosition = worldPos.xyz;

	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * p;
	vViewDepth = gl_Position.w;
}

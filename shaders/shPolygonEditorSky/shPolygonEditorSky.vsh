////////////////////////////////////////////////////////////////////////////////
//
// Vertex shader for skydome background.
//
// Passes object-space direction through; the dome node is positioned at the
// camera each step, so object direction equals view direction.
//
////////////////////////////////////////////////////////////////////////////////

// Attributes
attribute vec3 in_Position;

// Varyings
varying vec3 vDir;

void main()
{
	vDir = in_Position;
	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(in_Position, 1.0);
}

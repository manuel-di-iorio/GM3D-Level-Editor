////////////////////////////////////////////////////////////////////////////////
//
// Vertex shader for unlit (flat) skinned geometry.
//
// Blends bone matrices to skin the position; lighting varyings omitted.
//
////////////////////////////////////////////////////////////////////////////////

#define MAX_BONES 128

// Attributes
attribute vec3 in_Position;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;
attribute vec4 in_BlendWeight;
attribute vec4 in_BlendIndices;

// Uniforms
uniform mat4 gm_BoneMatrices[MAX_BONES];

// Varyings
varying vec4 vColor;
varying vec2 vTexCoord;

void main()
{
	// Skin weights
	int j0 = int(in_BlendIndices.x + 0.5);
	int j1 = int(in_BlendIndices.y + 0.5);
	int j2 = int(in_BlendIndices.z + 0.5);
	int j3 = int(in_BlendIndices.w + 0.5);

	mat4 skin = gm_BoneMatrices[j0] * in_BlendWeight.x
		+ gm_BoneMatrices[j1] * in_BlendWeight.y
		+ gm_BoneMatrices[j2] * in_BlendWeight.z
		+ gm_BoneMatrices[j3] * in_BlendWeight.w;

	vec4 p = skin * vec4(in_Position, 1.0);

	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * p;
	vColor = in_Colour;
	vTexCoord = in_TextureCoord;
}

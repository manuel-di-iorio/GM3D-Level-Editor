////////////////////////////////////////////////////////////////////////////////
//
// Vertex shader for unlit (flat) geometry, static and skinned.
//
// u_skinned selects the skinning path (bone matrices); static meshes ignore
// the bone attributes and take the direct path.
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
uniform float u_skinned;

// Varyings
varying vec4 vColor;
varying vec2 vTexCoord;

void main()
{
	vec4 p = vec4(in_Position, 1.0);
	if (u_skinned > 0.5) {
		int j0 = int(in_BlendIndices.x + 0.5);
		int j1 = int(in_BlendIndices.y + 0.5);
		int j2 = int(in_BlendIndices.z + 0.5);
		int j3 = int(in_BlendIndices.w + 0.5);

		mat4 skin = gm_BoneMatrices[j0] * in_BlendWeight.x
			+ gm_BoneMatrices[j1] * in_BlendWeight.y
			+ gm_BoneMatrices[j2] * in_BlendWeight.z
			+ gm_BoneMatrices[j3] * in_BlendWeight.w;

		p = skin * p;
	}

	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * p;
	vColor = in_Colour;
	vTexCoord = in_TextureCoord;
}

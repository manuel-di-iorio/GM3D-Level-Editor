////////////////////////////////////////////////////////////////////////////////
//
// Vertex shader for unlit (flat) instanced skinned geometry.
//
// Reads a per-instance world matrix and blends bone matrices sampled from
// a texture atlas.
//
////////////////////////////////////////////////////////////////////////////////

#define MAX_BONES 128

// Attributes
attribute vec3 in_Position;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;
attribute vec4 in_BlendWeight;
attribute vec4 in_BlendIndices;

// Per-instance attributes
attribute vec4 in_InstanceMatrixCol0;
attribute vec4 in_InstanceMatrixCol1;
attribute vec4 in_InstanceMatrixCol2;
attribute vec4 in_InstanceMatrixCol3;
attribute float in_BoneAtlasRow;

// Uniforms
uniform sampler2D gm_BoneAtlas;
uniform float gm_BoneAtlasHeight;

// Varyings
varying vec4 vColor;
varying vec2 vTexCoord;

// Reads a 4x4 bone matrix from the bone atlas texture for the current instance
// row.
mat4 fetchBone(int boneIndex)
{
	float invWidth = 1.0 / float(MAX_BONES * 4);
	float invHeight = 1.0 / gm_BoneAtlasHeight;
	float v = (in_BoneAtlasRow + 0.5) * invHeight;
	vec4 c0 = texture2D(gm_BoneAtlas, vec2((float(boneIndex * 4 + 0) + 0.5) * invWidth, v));
	vec4 c1 = texture2D(gm_BoneAtlas, vec2((float(boneIndex * 4 + 1) + 0.5) * invWidth, v));
	vec4 c2 = texture2D(gm_BoneAtlas, vec2((float(boneIndex * 4 + 2) + 0.5) * invWidth, v));
	vec4 c3 = texture2D(gm_BoneAtlas, vec2((float(boneIndex * 4 + 3) + 0.5) * invWidth, v));
	return mat4(c0, c1, c2, c3);
}

void main()
{
	// Instance world matrix
	mat4 world = mat4(
		in_InstanceMatrixCol0,
		in_InstanceMatrixCol1,
		in_InstanceMatrixCol2,
		in_InstanceMatrixCol3
	);

	// Skin weights
	int j0 = int(in_BlendIndices.x + 0.5);
	int j1 = int(in_BlendIndices.y + 0.5);
	int j2 = int(in_BlendIndices.z + 0.5);
	int j3 = int(in_BlendIndices.w + 0.5);

	mat4 skin = fetchBone(j0) * in_BlendWeight.x
		+ fetchBone(j1) * in_BlendWeight.y
		+ fetchBone(j2) * in_BlendWeight.z
		+ fetchBone(j3) * in_BlendWeight.w;

	vec4 p = skin * vec4(in_Position, 1.0);
	vec4 worldPos = world * p;

	gl_Position = gm_Matrices[MATRIX_PROJECTION] * gm_Matrices[MATRIX_VIEW] * worldPos;
	vColor = in_Colour;
	vTexCoord = in_TextureCoord;
}

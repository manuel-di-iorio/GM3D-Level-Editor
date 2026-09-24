////////////////////////////////////////////////////////////////////////////////
//
// Vertex shader for skinned (animated) geometry.
//
// Blends bone matrices from a uniform array to skin vertex position and TBN
// frame, then transforms to world space. Computes fog factor passed to the
// fragment stage.
//
////////////////////////////////////////////////////////////////////////////////

#define MAX_BONES 128

// Attributes
attribute vec3 in_Position;
attribute vec3 in_Normal;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;
attribute vec4 in_Tangent;
attribute vec4 in_BlendWeight;
attribute vec4 in_BlendIndices;

// Uniforms
uniform mat4 gm_BoneMatrices[MAX_BONES];

// Varyings
varying vec3 vT;
varying vec3 vN;
varying float vSign;
varying float vHasTangent;

varying vec4 vColor;
varying vec2 vTexCoord;
varying vec3 vWorldPosition;
varying float vFogFactor;

// Computes world-space tangent and normal.
void buildTBN(
	vec4 tangent, vec3 normal, mat3 xformMat3,
	out vec3 outT, out vec3 outN, out float outHasTangent
) {
	outHasTangent = (dot(tangent, tangent) > 0.0) ? 1.0 : 0.0;
	outT = xformMat3 * tangent.xyz;
	outN = xformMat3 * normal;
	outN = normalize(outN);
	outT = normalize(outT);
	outT = normalize(outT - outN * dot(outT, outN));
}

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

	// TBN frame
	buildTBN(
		in_Tangent, in_Normal,
		mat3(gm_Matrices[MATRIX_WORLD]) * mat3(skin),
		vT, vN, vHasTangent
	);
	vSign = in_Tangent.w;

	// Output
	vec4 worldPos = gm_Matrices[MATRIX_WORLD] * p;
	vWorldPosition = worldPos.xyz;

	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * p;
	float fogEnable = gm_VS_FogEnabled ? 1.0 : 0.0;
	vFogFactor = fogEnable * (gl_Position.w - gm_FogStart) * gm_RcpFogRange;
	vColor = in_Colour;
	vTexCoord = in_TextureCoord;
}

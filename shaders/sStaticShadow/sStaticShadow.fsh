////////////////////////////////////////////////////////////////////////////////
//
// Fragment shader for static (non-skinned) shadow geometry.
//
// Discards masked fragments and writes raster depth into the shadow map.
//
// Ported from YoYoGames/GM3D-Samples (develop branch, shStaticShadow).
//
////////////////////////////////////////////////////////////////////////////////

// Varyings
varying vec2 vTexCoord;

// Material uniforms
uniform vec4 gm_BaseColorFactor;
uniform vec2 gm_BaseTexture_Offset;
uniform vec2 gm_BaseTexture_Scale;
uniform float gm_BaseTexture_Rotation;
uniform int gm_AlphaMode;
uniform float gm_AlphaCutoff;

// Applies the base texture transform used by the material.
vec2 transformTexCoord(vec2 uv)
{
	vec2 transformed = uv * gm_BaseTexture_Scale + gm_BaseTexture_Offset;
	if (gm_BaseTexture_Rotation != 0.0) {
		float s = sin(gm_BaseTexture_Rotation);
		float c = cos(gm_BaseTexture_Rotation);
		transformed = mat2(c, s, -s, c) * (transformed - 0.5) + 0.5;
	}
	return transformed;
}

void main()
{
	if (gm_AlphaMode == 1
		&& texture2D(gm_BaseTexture, transformTexCoord(vTexCoord)).a * gm_BaseColorFactor.a < gm_AlphaCutoff) {
		discard;
	}
	gl_FragColor = vec4(gl_FragCoord.z);
}

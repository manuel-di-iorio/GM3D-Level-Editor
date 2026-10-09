////////////////////////////////////////////////////////////////////////////////
//
// Fragment shader for skinned (animated) shadow geometry.
//
// Discards masked fragments and writes raster depth into the shadow map.
//
// Ported from YoYoGames/GM3D-Samples (develop branch, shAnimatedShadow).
//
////////////////////////////////////////////////////////////////////////////////

// Varyings
varying vec2 vTexCoord;

// Material uniforms
uniform vec4 gm_BaseColorFactor;
uniform int gm_AlphaMode;
uniform float gm_AlphaCutoff;

void main()
{
	if (gm_AlphaMode == 1 && texture2D(gm_BaseTexture, vTexCoord).a * gm_BaseColorFactor.a < gm_AlphaCutoff) {
		discard;
	}
	gl_FragColor = vec4(gl_FragCoord.z);
}

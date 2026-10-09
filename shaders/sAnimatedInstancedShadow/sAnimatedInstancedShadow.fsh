////////////////////////////////////////////////////////////////////////////////
//
// Fragment shader for instanced skinned (animated) shadow geometry.
//
// Discards masked fragments and writes raster depth into the shadow map.
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
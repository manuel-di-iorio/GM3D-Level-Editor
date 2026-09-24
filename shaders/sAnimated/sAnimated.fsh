////////////////////////////////////////////////////////////////////////////////
//
// Fragment shader for skinned (animated) geometry.
//
// Applies Lambert diffuse lighting (directional + point lights), texture
// coordinate transformation, alpha cutout/blend, and linear fog.
//
////////////////////////////////////////////////////////////////////////////////

#define MAX_LIGHTS 8

// Varyings from vertex shader
varying vec3 vT;
varying vec3 vN;
varying float vSign;
varying float vHasTangent;
varying vec4 vColor;
varying vec2 vTexCoord;
varying vec3 vWorldPosition;
varying float vFogFactor;

// Material uniforms
uniform vec4 gm_BaseColorFactor;
uniform vec2 gm_BaseTexture_Offset;
uniform vec2 gm_BaseTexture_Scale;
uniform float gm_BaseTexture_Rotation;

// Alpha mode: 0 = OPAQUE, 1 = MASK, 2 = BLEND
uniform int gm_AlphaMode;
uniform float gm_AlphaCutoff;

// Lighting uniforms
uniform vec4 gm_AmbientColour;
uniform vec4 gm_Lights_Direction[MAX_LIGHTS]; // xyz = direction toward scene, w = enabled (1) or disabled (0)
uniform vec4 gm_Lights_PosRange[MAX_LIGHTS];  // xyz = world position, w = range (0 = disabled)
uniform vec4 gm_Lights_Colour[MAX_LIGHTS];    // rgb = colour

// Applies offset, scale, and optional rotation to a UV coordinate.
vec2 transformTexCoord(vec2 uv, vec2 offset, vec2 scale, float rotation)
{
	vec2 transformed = uv * scale + offset;
	if (rotation != 0.0) {
		float s = sin(rotation);
		float c = cos(rotation);
		mat2 rotMat = mat2(c, s, -s, c);
		transformed = rotMat * (transformed - 0.5) + 0.5;
	}
	return transformed;
}

void main()
{
	// Base color
	vec2 baseUV = transformTexCoord(
		vTexCoord,
		gm_BaseTexture_Offset,
		gm_BaseTexture_Scale,
		gm_BaseTexture_Rotation
	);
	vec4 baseTexture = texture2D(gm_BaseTexture, baseUV);
	vec4 baseColor = gm_BaseColorFactor * vColor * baseTexture;
	float outputAlpha = (gm_AlphaMode == 2) ? baseColor.a : 1.0;

	if (gm_AlphaMode == 1 && baseColor.a < gm_AlphaCutoff) {
		discard;
	}

	vec3 N = normalize(vN);

	// Ambient
	vec3 light = gm_AmbientColour.rgb;

	// Directional lights
	for (int i = 0; i < MAX_LIGHTS; ++i) {
		vec3 L = -gm_Lights_Direction[i].xyz;
		if (dot(L, L) > 0.0001) {
			float NdotL = max(0.0, dot(N, normalize(L)));
			light += NdotL * gm_Lights_Colour[i].rgb;
		}
	}

	// Point lights
	for (int i = 0; i < MAX_LIGHTS; ++i) {
		float range = gm_Lights_PosRange[i].w;
		if (range > 0.0) {
			vec3 toLight = gm_Lights_PosRange[i].xyz - vWorldPosition;
			float dist = length(toLight);
			float NdotL = max(0.0, dot(N, toLight / dist));
			float attenuation = clamp(1.0 - dist / range, 0.0, 1.0);
			light += NdotL * attenuation * gm_Lights_Colour[i].rgb;
		}
	}

	// Fog and output
	vec3 litColor = baseColor.rgb * light;
	float fogBlend = gm_PS_FogEnabled ? clamp(vFogFactor, 0.0, 1.0) : 0.0;
	litColor = mix(litColor, gm_FogColour.rgb, fogBlend);
	gl_FragColor = vec4(litColor, outputAlpha);
}

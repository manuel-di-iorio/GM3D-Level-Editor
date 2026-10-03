////////////////////////////////////////////////////////////////////////////////
//
// Fragment shader for skydome background.
//
// Vertical gradient (top / horizon / bottom) plus sun glow disk.
// Unlit, no fog, no shadows, opaque.
//
// Day/night cycle derived from the sun direction Y component (elevation):
//   sunElev > 0.25  -> full day
//   sunElev ~ 0     -> sunset / sunrise
//   sunElev < -0.15 -> full night
//
////////////////////////////////////////////////////////////////////////////////

// Varyings
varying vec3 vDir;

// Gradient exponents
#define SKY_TOP_POW 0.6
#define SKY_BOT_BLEND 0.05

// Sky uniforms – u_skyTop/Horizon/Bottom are the base DAY palette.
uniform vec3 u_skyTop;
uniform vec3 u_skyHorizon;
uniform vec3 u_skyBottom;
uniform vec3 u_sunDir;
uniform vec3 u_sunColor;
uniform float u_sunGlow;

void main()
{
	vec3 d = normalize(vDir);

	// Normalize sun direction.
	vec3 sd = u_sunDir;
	float sl = length(sd);
	sd = sl > 0.0001 ? sd / sl : vec3(0.0, 1.0, 0.0);

	// Sun elevation: +1 = zenith, 0 = horizon, -1 = nadir.
	float sunElev = sd.y;

	// =====================================================================
	// Palette blending: day -> sunset -> night
	// =====================================================================

	vec3 dayTop     = u_skyTop;
	vec3 dayHorizon = u_skyHorizon;
	vec3 dayBottom  = u_skyBottom;

	// Sunset / sunrise – realistic warm tones:
	//   upper sky fades to deep indigo,
	//   horizon glows soft peach-pink,
	//   ground darkens to a warm neutral.
	vec3 sunsetTop     = vec3(0.10, 0.08, 0.25);
	vec3 sunsetHorizon = vec3(0.95, 0.55, 0.35);
	vec3 sunsetBottom  = vec3(0.15, 0.10, 0.08);

	// Night – very deep dark blue.
	vec3 nightTop     = vec3(0.005, 0.006, 0.04);
	vec3 nightHorizon = vec3(0.010, 0.014, 0.05);
	vec3 nightBottom  = vec3(0.003, 0.003, 0.012);

	float tSunset = smoothstep(0.25, 0.0, sunElev);
	float tNight  = smoothstep(-0.05, -0.20, sunElev);

	vec3 skyTop     = mix(mix(dayTop,     sunsetTop,     tSunset), nightTop,     tNight);
	vec3 skyHorizon = mix(mix(dayHorizon, sunsetHorizon, tSunset), nightHorizon, tNight);
	vec3 skyBottom  = mix(mix(dayBottom,  sunsetBottom,  tSunset), nightBottom,  tNight);

	// Sky gradient.
	vec3 col = d.y >= 0.0
		? mix(skyHorizon, skyTop, pow(d.y, SKY_TOP_POW))
		: mix(skyHorizon, skyBottom, smoothstep(0.0, SKY_BOT_BLEND, -d.y));

	// Sun visibility attenuator (fades to zero below horizon).
	float sunVis = clamp(sunElev * 8.0 + 0.5, 0.0, 1.0);

	// =====================================================================
	// Sun – tight disk, warm golden-yellow halo with no blue cast
	// =====================================================================
	float s = max(dot(d, sd), 0.0);

	// Much tighter disk (6000 exponent = smaller radius, less bloom).
	float _disk = pow(s, 6000.0) * 1.2;

	// Warm golden sky tint close to the sun – stronger yellow bias.
	float _warmth = pow(s, 32.0) * 0.28 * u_sunGlow * sunVis;
	col = mix(col, vec3(1.0, 0.86, 0.42), _warmth);

	// Golden-yellow halo – tight inner ring + soft outer glow (pure warm, no cyan).
	vec3 haloCol = vec3(1.0, 0.84, 0.36);
	vec3 _halo = (pow(s, 180.0) * 0.20 + pow(s, 32.0) * 0.045) * haloCol;
	col += u_sunColor * (_disk + _halo) * u_sunGlow * sunVis;

	gl_FragColor = vec4(col, 1.0);
}

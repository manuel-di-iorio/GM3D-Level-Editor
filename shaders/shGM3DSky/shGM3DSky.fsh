////////////////////////////////////////////////////////////////////////////////
//
// Fragment shader for skydome background.
//
// Vertical gradient (top / horizon / bottom) plus sun glow disk and
// procedural starfield at night.
// Unlit, no fog, no shadows, opaque.
//
// Day/night cycle derived from the sun direction Y component (elevation):
//   sunElev > 0.25  -> full day
//   sunElev ~ 0     -> sunset / sunrise
//   sunElev < -0.15 -> full night (starfield visible)
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

// =====================================================================
// Procedural hashing for starfield
// =====================================================================
float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3)
{
	p3  = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float hash14(vec4 p4)
{
	p4 = fract(p4 * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.x + p4.y) * (p4.z + p4.w));
}

// Return a tangent basis (T,B) perpendicular to unit vector d.
void basisTB(vec3 d, out vec3 T, out vec3 B)
{
	if (abs(d.y) < 0.9)
	{
		T = normalize(cross(vec3(0.0, 1.0, 0.0), d));
	}
	else
	{
		T = normalize(cross(vec3(1.0, 0.0, 0.0), d));
	}
	B = normalize(cross(d, T));
}

// ---------------------------------------------------------------------
// Star contribution from a single candidate "cell".
//
// dir       : pixel direction (unit) on the sphere
// cellDir   : the direction of the cell center on the sphere (unit-ish)
// scale     : spherical grid density (higher = smaller cell)
// cellSeed  : hashed cell index
// coreK     : falloff of the bright core
// haloK     : falloff of the faint outer halo
// haloAmp   : amplitude of the halo relative to core
//
// Uses a proper local 2D tangent-plane projection so the star is
// always a round disk, never a line/sliver even at poles / equator.
// ---------------------------------------------------------------------
float starSample(vec3 dir, vec3 cellDir, float scale, vec3 cellSeed,
                 float coreK, float haloK, float haloAmp)
{
	vec3 T, B;
	basisTB(cellDir, T, B);

	// Project the pixel direction onto the star's local 2D plane.
	float dx = dot(dir, T) * scale;
	float dy = dot(dir, B) * scale;

	// Random offset inside the cell (uniform, ~cell-sized jitter).
	// Using a 2D offset in the plane is consistent at any cell angle.
	vec2 off = vec2(hash13(cellSeed + 1.3), hash13(cellSeed + 9.7)) - 0.5;
	dx -= off.x;
	dy -= off.y;

	float r2 = dx * dx + dy * dy;
	float core = exp(-r2 * coreK);
	float halo = exp(-r2 * haloK) * haloAmp;
	return core + halo;
}

// ---------------------------------------------------------------------
// One layer of stars. Sparse (most cells empty). We check the cell
// under 'd' plus all 26 neighbors (3x3x3) so that a star placed near
// a cell boundary still renders correctly when we view it from an
// adjacent cell – this eliminates "line" / crack artifacts.
// ---------------------------------------------------------------------
float starLayer(vec3 d, float scale, float density,
                float coreK, float haloK, float haloAmp,
                float magLo, float magHi, vec3 seedOffset)
{
	vec3 p = d * scale;
	vec3 pi = floor(p);

	float acc = 0.0;

	// Iterate 3x3x3 neighborhood.
	for (int z = -1; z <= 1; ++z)
	for (int y = -1; y <= 1; ++y)
	for (int x = -1; x <= 1; ++x)
	{
		vec3 nb = pi + vec3(float(x), float(y), float(z));
		vec3 seed = nb + seedOffset;

		float spawn = hash13(seed);
		if (spawn >= density) continue;

		// Compute the center direction of this neighbor cell.
		vec3 pf = fract(p) - 0.5;
		// "local to neighbour" fractional offset
		vec3 nf = pf - vec3(float(x), float(y), float(z));
		vec3 cellDir = normalize(d - nf / scale);

		// Magnitude from a second hash so it's decorrelated from spawn.
		float mag = magLo + (magHi - magLo) * hash14(vec4(nb, 2.17));

		acc += starSample(d, cellDir, scale, seed,
		                  coreK, haloK, haloAmp) * mag;
	}
	return acc;
}

// Produce a realistic starfield (brightness in ~[0, 1.2]) rendered on
// the upper hemisphere. Density is gently tapered near the horizon
// (atmospheric extinction) but stars are visible all the way down.
float starField(vec3 d)
{
	// Slight fade near horizon for realistic atmospheric extinction.
	// Keeps stars visible almost at d.y == 0, not a hard cut.
	float upFade = smoothstep(-0.04, 0.10, d.y);
	if (upFade <= 0.0) return 0.0;

	float bright = 0.0;

	// Layer 1 – rare, large, very bright stars (a few dozen total)
	bright += starLayer(d,
		90.0,   // scale
		0.011,  // density (was 0.018)
		900.0,  // coreK
		130.0,  // haloK
		0.24,   // haloAmp (slightly more halo for remaining ones)
		0.80,   // magLo (brighter min)
		1.20,   // magHi
		vec3(0.1, 2.9, 4.7)
	);

	// Layer 2 – medium, common stars (bulk)
	bright += starLayer(d,
		210.0,
		0.013,  // density (was 0.022)
		2200.0,
		340.0,
		0.09,
		0.40,
		0.85,
		vec3(5.3, 1.1, 7.8)
	);

	// Layer 3 – tiny faint background stars (subtle grain)
	bright += starLayer(d,
		460.0,
		0.009,  // density (was 0.016)
		6500.0,
		0.0,
		0.0,
		0.12,
		0.38,
		vec3(2.6, 8.4, 3.2)
	);

	return bright * upFade;
}

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
	// Sun – fixed-size small disk + warm halo (halo grows at sunset).
	// The disk size is angularly constant (independent of sun elevation)
	// so the sun does not appear to grow between sunrise and midday.
	// =====================================================================
	float s = dot(d, sd);

	// Approximate angular distance from sun center:
	//   theta ≈ acos(s) ≈ sqrt(2(1-s))   for s close to 1
	// We just use (1-s) directly as a monotonic proxy for thresholding.
	float sunAng = 1.0 - clamp(s, -1.0, 1.0);

	// Sun disk – clearly visible small disk, angularly constant, game-sized.
	const float SUN_RADIUS = 0.00045;
	const float SUN_EDGE   = 0.00018;
	float disk = (1.0 - smoothstep(SUN_RADIUS, SUN_RADIUS + SUN_EDGE, sunAng));
	// Make disk 12% brighter for a clear bloom-like core.
	float diskBright = 1.12;

	// Halo – warm glow. Only the halo grows at sunset (atmospheric
	// scattering illusion); the hard disk remains fixed size.
	float sPos = max(s, 0.0);
	float haloTight  = pow(sPos, 220.0) * 0.20;
	float haloLoose  = pow(sPos, 40.0)  * 0.06;
	vec3  haloCol    = vec3(1.0, 0.84, 0.36);
	vec3  halo       = (haloTight + haloLoose) * haloCol;

	// Warm sky tint close to the sun – stronger near horizon (sunset).
	float warmthPow = mix(32.0, 18.0, tSunset);
	float warmthAmp = mix(0.22, 0.38, tSunset);
	float warmth    = pow(sPos, warmthPow) * warmthAmp * u_sunGlow * sunVis;
	col = mix(col, vec3(1.0, 0.86, 0.42), warmth);

	// Composite: disk uses u_sunColor as tint (so artist can tweak),
	// halo is pre-tinted above.
	col += u_sunColor * disk * diskBright * u_sunGlow * sunVis;
	col += u_sunColor * halo * u_sunGlow * sunVis;

	// =====================================================================
	// Starfield – procedural, visible only at night.
	// Stars are rendered up to the horizon (with a soft fade for realism).
	// =====================================================================
	float starAmount = tNight * smoothstep(-0.08, 0.04, d.y);
	if (starAmount > 0.001)
	{
		float stars = starField(d);

		// Coherent per-star spectral tint.
		// Use a coarse seed so the same color is stable across the full
		// Gaussian profile of a star (prevents patchy / multi-colored stars).
		vec3 seedCol = floor(d * 260.0);
		float tCol = hash13(seedCol + 9.3);
		vec3 starCol;
		if (tCol < 0.70)
		{
			starCol = mix(vec3(1.00, 1.00, 1.00),
			              vec3(0.95, 0.97, 1.00),
			              hash13(seedCol + 4.1));
		}
		else if (tCol < 0.82)
		{
			starCol = mix(vec3(0.78, 0.86, 1.00),
			              vec3(0.62, 0.78, 1.00),
			              hash13(seedCol + 5.2));
		}
		else if (tCol < 0.94)
		{
			starCol = mix(vec3(1.00, 0.95, 0.82),
			              vec3(1.00, 0.84, 0.58),
			              hash13(seedCol + 6.7));
		}
		else
		{
			starCol = mix(vec3(1.00, 0.72, 0.52),
			              vec3(1.00, 0.58, 0.44),
			              hash13(seedCol + 7.9));
		}

		col += starCol * stars * starAmount;
	}

	gl_FragColor = vec4(col, 1.0);
}

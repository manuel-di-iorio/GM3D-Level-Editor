////////////////////////////////////////////////////////////////////////////////
//
// Fragment shader for skydome background.
//
// Vertical gradient (top / horizon / bottom) plus sun glow disk. Unlit,
// no fog, no shadows, opaque.
//
////////////////////////////////////////////////////////////////////////////////

// Varyings
varying vec3 vDir;

// Gradient exponents: top eases toward zenith; below the horizon the
// ground color takes over across a short band then stays flat and dark
// (Unity-like terrain), instead of washing out toward the horizon.
#define SKY_TOP_POW 0.6
#define SKY_BOT_BLEND 0.05

// Sky uniforms (linear 0..1 colors set from code)
uniform vec3 u_skyTop;
uniform vec3 u_skyHorizon;
uniform vec3 u_skyBottom;
uniform vec3 u_sunDir;
uniform vec3 u_sunColor;
uniform float u_sunGlow;

void main()
{
	vec3 d = normalize(vDir);
	vec3 col = d.y >= 0.0
		? mix(u_skyHorizon, u_skyTop, pow(d.y, SKY_TOP_POW))
		: mix(u_skyHorizon, u_skyBottom, smoothstep(0.0, SKY_BOT_BLEND, -d.y));
	vec3 sd = u_sunDir;
	float sl = length(sd);
	sd = sl > 0.0001 ? sd / sl : vec3(0.0, 1.0, 0.0);
	float s = max(dot(d, sd), 0.0);
	col += u_sunColor * (pow(s, 800.0) * 1.2 + pow(s, 8.0) * 0.18) * u_sunGlow;
	gl_FragColor = vec4(col, 1.0);
}

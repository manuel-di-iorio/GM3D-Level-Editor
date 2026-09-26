////////////////////////////////////////////////////////////////////////////////
//
// Fragment shader for the editor grid (Unity-style procedural grid).
//
// The model is a single large quad at Y=0; lines are computed per-pixel
// from the world position. fwidth() gives each line exact pixel coverage
// and drives the LOD fade: every scale dissolves exactly when its cells go
// sub-pixel, handing over to the next one, so the grid looks infinite and
// never merges into a solid wash: no geometry aliasing, no MSAA and no
// mipmaps needed. A gentle horizon fade softens the far edge of the quad.
// Pixels with no line are discarded, and edge pixels blend toward u_grid_bg
// (pushed live from window_get_colour()), so the quad never paints its own
// background and edges never dip below it. Unlit: fixed palette, fully
// independent of scene lights and fog.
//
////////////////////////////////////////////////////////////////////////////////

// Line pitch in world units and palette (tune to taste).
#define GRID_MINOR_STEP 1.0
#define GRID_MAJOR_STEP 5.0
#define GRID_MINOR_COL vec3(0.30, 0.30, 0.30)
#define GRID_MAJOR_COL vec3(0.36, 0.36, 0.36)

// Line half-width in pixels (1.0 = standard, lower = thinner).
#define GRID_WIDTH 0.65

// AA only where needed (Unity-like): below GRID_AA_W0 cells-per-pixel the
// edges are binary razor-sharp; past GRID_AA_W1 they are fully smooth.
// Driven by fwidth, so it kicks in far away AND at grazing angles nearby,
// staying crisp everywhere else.
#define GRID_AA_W0 0.4
#define GRID_AA_W1 1.2

// Gentle horizon dissolve (view depth): the LOD fade below already kills
// merging scales, this only softens the far edge of the quad over a long,
// smooth gradient so no cutoff line is ever visible.
#define GRID_HORIZON_A 120.0
#define GRID_HORIZON_B 220.0

// Varyings from vertex shader
varying vec3 vWorldPosition;
varying float vViewDepth;

// Background color, pushed per-frame from window_get_colour(): edge pixels
// blend toward the real background, never below it.
uniform vec3 u_grid_bg;

// Coverage (0..1) of the grid lines at one pitch, anti-aliased via the
// screen-space derivative.
float gridLine(vec2 _p, float _step) {
	vec2 _q = _p / _step;
	vec2 _w = max(fwidth(_q), vec2(0.0001));
	vec2 _g = abs(fract(_q - 0.5) - 0.5) / _w / GRID_WIDTH;
	float _d = min(min(_g.x, _g.y), 1.0);
	float _hard = 1.0 - step(1.0, _d);
	float _soft = 1.0 - smoothstep(0.5, 1.0, _d);
	float _aa = clamp((max(_w.x, _w.y) - GRID_AA_W0) / max(GRID_AA_W1 - GRID_AA_W0, 0.001), 0.0, 1.0);
	return mix(_hard, _soft, _aa);
}

// Extra early fade for minors only (Unity-like): fine lines melt away
// with distance even where still resolvable, majors carry the far field.
// Smoothstep over a long range: no visible band edge, ever.
#define GRID_MINOR_DIST_A 15.0
#define GRID_MINOR_DIST_B 75.0
float distBand(float _d, float _a, float _b) {
	return 1.0 - smoothstep(_a, _b, _d);
}

// LOD fade for one scale (Unity-style): fully visible while its cells are
// comfortably resolved, dissolving across the Nyquist zone so nothing is
// left to shimmer: gone by ~1 cell-per-pixel, where lines would break into
// dashes. Each scale hands over to the next before that point.
float lodFade(vec2 _p, float _step) {
	vec2 _q = _p / _step;
	float _w = max(max(fwidth(_q).x, fwidth(_q).y), 0.0001);
	return 1.0 - smoothstep(0.6, 1.1, _w);
}

void main()
{
	float minor = gridLine(vWorldPosition.xz, GRID_MINOR_STEP) * lodFade(vWorldPosition.xz, GRID_MINOR_STEP) * distBand(vViewDepth, GRID_MINOR_DIST_A, GRID_MINOR_DIST_B);
	float major = gridLine(vWorldPosition.xz, GRID_MAJOR_STEP) * lodFade(vWorldPosition.xz, GRID_MAJOR_STEP);
	float horizon = 1.0 - smoothstep(GRID_HORIZON_A, GRID_HORIZON_B, vViewDepth);
	float cover = clamp(minor + major, 0.0, 1.0) * horizon;
	if (cover <= 0.01) {
		discard;
	}
	vec3 gridCol = mix(u_grid_bg, minor * GRID_MINOR_COL + major * GRID_MAJOR_COL, cover);

	gl_FragColor = vec4(gridCol, 1.0);
}

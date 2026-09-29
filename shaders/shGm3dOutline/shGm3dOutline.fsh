/**
 * Outline composite fragment shader (Unique UeOutlinePass style, no x-ray).
 *
 * gm_BaseTexture holds the mask surface: selection in solid white, occluders
 * with their normal shading, background black. The mask is binarized by a
 * luminance threshold so only the white silhouette feeds the Sobel kernel;
 * shaded occluders stay below it. Non-edge pixels output alpha 0, so the
 * GUI blend leaves the scene untouched except on the silhouette border.
 * Occluded selection parts never reach the mask (depth-tested mask pass),
 * hence no see-through outline.
 */

varying vec2 v_vTexcoord;

uniform vec3 u_color;
uniform vec2 u_texel;
uniform float u_thickness;
uniform float u_strength;
uniform float u_glow;
uniform float u_threshold;

float maskAt(vec2 _uv)
{
    vec3 c = texture2D(gm_BaseTexture, _uv).rgb;
    float lum = dot(c, vec3(0.299, 0.587, 0.114));
    return step(u_threshold, lum);
}

float detectEdge(vec2 _uv)
{
    vec2 tx = u_texel * u_thickness;

    float tl = maskAt(_uv + vec2(-tx.x, -tx.y));
    float t  = maskAt(_uv + vec2( 0.0, -tx.y));
    float tr = maskAt(_uv + vec2( tx.x, -tx.y));
    float l  = maskAt(_uv + vec2(-tx.x,  0.0));
    float r  = maskAt(_uv + vec2( tx.x,  0.0));
    float bl = maskAt(_uv + vec2(-tx.x,  tx.y));
    float b  = maskAt(_uv + vec2( 0.0,  tx.y));
    float br = maskAt(_uv + vec2( tx.x,  tx.y));

    float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
    float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;

    return length(vec2(gx, gy));
}

void main()
{
    // Hard border cut: a silhouette clipped by the viewport would otherwise
    // draw a false straight edge along the screen border. Discarded outright
    // (not faded) so no faint remnant survives; margin covers the Sobel
    // kernel radius plus filtering.
    vec2 _b = min(v_vTexcoord, 1.0 - v_vTexcoord);
    vec2 _m = (u_thickness + 2.5) * u_texel;
    if (_b.x < _m.x || _b.y < _m.y) {
        gl_FragColor = vec4(u_color, 0.0);
        return;
    }
    float edge = detectEdge(v_vTexcoord) * u_strength;
    float alpha = 1.0 - exp(-edge * (1.0 + u_glow));
    gl_FragColor = vec4(u_color, alpha);
}

/**
 * GM3D selection mask fragment shader (shared by static and skinned mask).
 * Solid white: the edge pass thresholds on luminance, so shaded occluders
 * rendered with their own materials stay below the white level while the
 * selection is exactly 1.0.
 */

void main()
{
    gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
}

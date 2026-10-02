/**
 * GM3D ID picking fragment shader (static variant).
 * Flat u_id output, set per placement via mat.setFloatArray("u_id", ...).
 * Alpha stays 1: id 0 (black) is reserved for "miss".
 */

uniform vec4 u_id;

void main()
{
    gl_FragColor = u_id;
}

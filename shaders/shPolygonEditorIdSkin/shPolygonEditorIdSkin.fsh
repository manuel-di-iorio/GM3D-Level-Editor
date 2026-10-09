/**
 * GM3D ID picking fragment shader (skinned variant).
 * Flat u_id output, see shGm3dId.fsh.
 */

uniform vec4 u_id;

void main()
{
    gl_FragColor = u_id;
}

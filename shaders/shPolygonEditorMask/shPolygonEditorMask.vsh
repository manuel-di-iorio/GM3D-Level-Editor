/**
 * GM3D selection mask shader (static geometry).
 * Renders the silhouette as solid white on black, no lighting, no fog, no
 * textures: input for the Sobel outline composite (Unique UeOutlinePass style).
 * Only in_Position is declared, like shGM3DGrid: extra vertex attributes
 * present in GM3D buffers are ignored.
 */

attribute vec3 in_Position;

void main()
{
    vec4 object_space_pos = vec4(in_Position.x, in_Position.y, in_Position.z, 1.0);
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;
}

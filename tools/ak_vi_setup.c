/*
 * AK3918 RTSP video setup helper.
 *
 * Called in place of ak_vi_set_flip_mirror() by the test RTSP binary.
 * Preserve the requested orientation, then disable libplat_vi's automatic
 * exposure-driven FPS switching.  This deliberately does NOT force a
 * particular sensor FPS; the test is intended to reveal the native FPS
 * that remains after automatic switching is disabled.
 */
extern int ak_vi_set_flip_mirror(void *vi, int flip, int mirror);
extern int ak_vi_set_switch_fps_enable(void *vi, int enable);

int ak_vi_setup(void *vi, int flip, int mirror)
{
    int rc = ak_vi_set_flip_mirror(vi, flip, mirror);

    if (rc != 0)
        return rc;

    return ak_vi_set_switch_fps_enable(vi, 0);
}

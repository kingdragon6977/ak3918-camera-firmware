/* Keep the full-resolution RTSP sensor at 30 FPS (encoder requests 25). */
extern int ak_vi_set_flip_mirror(void *vi, int flip, int mirror);
extern int ak_vi_set_switch_fps_enable(void *vi, int enable);
extern int ak_vi_set_fps(void *vi, int fps);

int ak_vi_setup(void *vi, int flip, int mirror)
{
    int rc = ak_vi_set_flip_mirror(vi, flip, mirror);
    if (rc != 0)
        return rc;
    rc = ak_vi_set_switch_fps_enable(vi, 0);
    if (rc != 0)
        return rc;
    return ak_vi_set_fps(vi, 30);
}

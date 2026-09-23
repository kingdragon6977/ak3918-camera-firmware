/*
 * AK3918 RTSP audio shim.
 *
 * Interposes ak_ai_set_source().  After the vendor function successfully
 * selects the MIC source, apply a fixed input volume through the vendor's
 * real ak_ai_set_volume() API.  This avoids patching the AI handle's cached
 * volume field, which does not itself program the ADC.
 *
 * Build for the camera's ARM Linux userspace, then launch RTSP with:
 *   LD_PRELOAD=/tmp/libak_audio_gain.so \
 *   LD_LIBRARY_PATH=/tmp:/usr/lib:/lib /tmp/rtsp-flip00
 *
 * Override at build time, e.g. -DAK_FIXED_AI_VOLUME=4.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>

#ifndef AK_FIXED_AI_VOLUME
#define AK_FIXED_AI_VOLUME 4
#endif

typedef int (*set_source_fn)(void *ai, int source);
typedef int (*set_volume_fn)(void *ai, int volume);

int ak_ai_set_source(void *ai, int source)
{
    static set_source_fn real_set_source;
    static set_volume_fn real_set_volume;
    int rc, vrc;

    if (!real_set_source)
        real_set_source = (set_source_fn)dlsym(RTLD_NEXT, "ak_ai_set_source");
    if (!real_set_volume)
        real_set_volume = (set_volume_fn)dlsym(RTLD_NEXT, "ak_ai_set_volume");

    if (!real_set_source || !real_set_volume) {
        fprintf(stderr, "[ak-audio-gain] dlsym failed: %s\n", dlerror());
        return -1;
    }

    rc = real_set_source(ai, source);
    if (rc != 0)
        return rc;

    vrc = real_set_volume(ai, AK_FIXED_AI_VOLUME);
    fprintf(stderr, "[ak-audio-gain] source=%d volume=%d rc=%d\n",
            source, AK_FIXED_AI_VOLUME, vrc);
    return vrc;
}

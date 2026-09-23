/*
 * AK3918 RTSP audio gain helper.
 *
 * This intentionally does NOT interpose ak_ai_set_source().  Instead,
 * libapp_rtsp can be binary-patched to call this function in place of
 * ak_ai_set_source().  The helper performs both operations using normal
 * unresolved ELF symbols that the camera's vendor libraries provide.
 *
 * This avoids dlsym/RTLD_NEXT and therefore avoids importing a modern
 * GLIBC-versioned dlsym symbol from the host cross-toolchain.
 */
#include <stdio.h>

#ifndef AK_FIXED_AI_VOLUME
#define AK_FIXED_AI_VOLUME 4
#endif

extern int ak_ai_set_source(void *ai, int source);
extern int ak_ai_set_volume(void *ai, int volume);

int ak_audio_set_source_and_gain(void *ai, int source)
{
    int rc = ak_ai_set_source(ai, source);
    int vrc;

    if (rc != 0)
        return rc;

    vrc = ak_ai_set_volume(ai, AK_FIXED_AI_VOLUME);
    fprintf(stderr, "[ak-audio-gain] source=%d volume=%d rc=%d\n",
            source, AK_FIXED_AI_VOLUME, vrc);
    return vrc;
}

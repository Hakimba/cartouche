// SPDX-License-Identifier: GPL-3.0-or-later
#include <jni.h>
#include <malloc.h>

JNIEXPORT void JNICALL Java_app_cartouche_android_NativeHeap_release(JNIEnv *env, jclass type) {
    mallopt(M_PURGE, 0);
}

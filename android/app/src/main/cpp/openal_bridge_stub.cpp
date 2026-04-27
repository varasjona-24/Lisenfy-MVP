#include <jni.h>
#include <android/log.h>

#define LOG_TAG "OpenALBridge"
#define ALOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_example_listenfy_OpenALBridge_nativePlay(
        JNIEnv *,
        jobject,
        jbyteArray,
        jint,
        jint,
        jboolean) {
    ALOGW("OpenAL Soft is not bundled; native playback is unavailable.");
    return JNI_FALSE;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_listenfy_OpenALBridge_nativePause(JNIEnv *, jobject) {}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_listenfy_OpenALBridge_nativeResume(JNIEnv *, jobject) {}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_listenfy_OpenALBridge_nativeSeek(JNIEnv *, jobject, jfloat) {}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_listenfy_OpenALBridge_nativeStop(JNIEnv *, jobject) {}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_listenfy_OpenALBridge_nativeRelease(JNIEnv *, jobject) {}

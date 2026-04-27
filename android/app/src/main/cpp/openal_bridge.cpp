#include <jni.h>
#include <android/log.h>
#include <vector>
#include <cstring>

#include <AL/al.h>
#include <AL/alc.h>
#include <AL/alext.h>

#define LOG_TAG "OpenALBridge"
#define ALOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static ALCdevice *gDevice = nullptr;
static ALCcontext *gContext = nullptr;
static ALuint gSource = 0;
static ALuint gBuffer = 0;

static bool ensureContext(bool enableHrtf) {
    if (gDevice && gContext) return true;

    gDevice = alcOpenDevice(nullptr);
    if (!gDevice) {
        ALOGE("alcOpenDevice failed");
        return false;
    }

    if (enableHrtf) {
        ALCint attrs[] = {
            ALC_HRTF_SOFT, ALC_TRUE,
            0
        };
#ifdef ALC_SOFT_reset_device
        auto resetFn = reinterpret_cast<LPALCRESETDEVICESOFT>(
            alcGetProcAddress(gDevice, "alcResetDeviceSOFT"));
        if (resetFn) {
            resetFn(gDevice, attrs);
        }
#endif
    }

    gContext = alcCreateContext(gDevice, nullptr);
    if (!gContext || !alcMakeContextCurrent(gContext)) {
        ALOGE("alcCreateContext failed");
        return false;
    }

    alGenSources(1, &gSource);
    alGenBuffers(1, &gBuffer);
    return true;
}

static void releaseAll() {
    if (gSource) {
        alSourceStop(gSource);
        alDeleteSources(1, &gSource);
        gSource = 0;
    }
    if (gBuffer) {
        alDeleteBuffers(1, &gBuffer);
        gBuffer = 0;
    }
    if (gContext) {
        alcMakeContextCurrent(nullptr);
        alcDestroyContext(gContext);
        gContext = nullptr;
    }
    if (gDevice) {
        alcCloseDevice(gDevice);
        gDevice = nullptr;
    }
}

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_example_listenfy_OpenALBridge_nativePlay(
        JNIEnv *env,
        jobject,
        jbyteArray pcm,
        jint sampleRate,
        jint channels,
        jboolean enableHrtf) {

    if (!ensureContext(enableHrtf == JNI_TRUE)) {
        return JNI_FALSE;
    }

    const jsize len = env->GetArrayLength(pcm);
    if (len <= 0) return JNI_FALSE;

    std::vector<char> buffer(static_cast<size_t>(len));
    env->GetByteArrayRegion(pcm, 0, len, reinterpret_cast<jbyte*>(buffer.data()));

    ALenum format = (channels == 1) ? AL_FORMAT_MONO16 : AL_FORMAT_STEREO16;
    alBufferData(gBuffer, format, buffer.data(), len, sampleRate);
    alSourcei(gSource, AL_BUFFER, gBuffer);
    alSourcePlay(gSource);

    return JNI_TRUE;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_listenfy_OpenALBridge_nativePause(
        JNIEnv *, jobject) {
    if (gSource) {
        alSourcePause(gSource);
    }
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_listenfy_OpenALBridge_nativeResume(
        JNIEnv *, jobject) {
    if (gSource) {
        alSourcePlay(gSource);
    }
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_listenfy_OpenALBridge_nativeSeek(
        JNIEnv *, jobject, jfloat seconds) {
    if (gSource) {
        alSourcef(gSource, AL_SEC_OFFSET, seconds);
    }
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_listenfy_OpenALBridge_nativeStop(
        JNIEnv *, jobject) {
    if (gSource) {
        alSourceStop(gSource);
    }
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_listenfy_OpenALBridge_nativeRelease(
        JNIEnv *, jobject) {
    releaseAll();
}

#ifndef RUNNER_AUDIO_OUTPUTS_H_
#define RUNNER_AUDIO_OUTPUTS_H_
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <memory>
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateAudioOutputsChannel(flutter::BinaryMessenger* messenger);
#endif

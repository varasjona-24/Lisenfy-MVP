#include "audio_outputs.h"

#include <windows.h>
#include <initguid.h>
#include <mmdeviceapi.h>
#include <devicetopology.h>
#include <functiondiscoverykeys_devpkey.h>
#include <devpkey.h>
#include <shellapi.h>
#include <propsys.h>
#include <propvarutil.h>
#include <wrl/client.h>
#include <flutter/standard_method_codec.h>
#include <string>

using Microsoft::WRL::ComPtr;
using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

namespace {
std::string Utf8(const std::wstring& text) {
  if (text.empty()) return {};
  int size = WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
  std::string result(size, 0);
  WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), result.data(), size, nullptr, nullptr);
  return result;
}
std::wstring ReadText(IPropertyStore* store, REFPROPERTYKEY key) {
  PROPVARIANT value;
  PropVariantInit(&value);
  std::wstring text;
  if (SUCCEEDED(store->GetValue(key, &value)) && value.vt == VT_LPWSTR && value.pwszVal) text = value.pwszVal;
  PropVariantClear(&value);
  return text;
}
std::wstring DeviceId(IMMDevice* device) {
  LPWSTR value = nullptr;
  std::wstring id;
  if (SUCCEEDED(device->GetId(&value)) && value) id = value;
  CoTaskMemFree(value);
  return id;
}
std::string Kind(IMMDevice* endpoint, IMMDeviceEnumerator* enumerator, IPropertyStore* properties) {
  ComPtr<IDeviceTopology> topology;
  ComPtr<IConnector> connector;
  if (SUCCEEDED(endpoint->Activate(__uuidof(IDeviceTopology), CLSCTX_ALL, nullptr,
      reinterpret_cast<void**>(topology.GetAddressOf()))) && SUCCEEDED(topology->GetConnector(0, &connector))) {
    LPWSTR adapterId = nullptr;
    if (SUCCEEDED(connector->GetDeviceIdConnectedTo(&adapterId)) && adapterId) {
      ComPtr<IMMDevice> adapter;
      ComPtr<IPropertyStore> adapterProps;
      std::wstring bus;
      if (SUCCEEDED(enumerator->GetDevice(adapterId, &adapter)) &&
          SUCCEEDED(adapter->OpenPropertyStore(STGM_READ, &adapterProps))) {
        const PROPERTYKEY key = {DEVPKEY_Device_EnumeratorName.fmtid, DEVPKEY_Device_EnumeratorName.pid};
        bus = ReadText(adapterProps.Get(), key);
      }
      CoTaskMemFree(adapterId);
      if (bus == L"USB") return "usb";
      if (bus.find(L"BTH") != std::wstring::npos || bus.find(L"Bluetooth") != std::wstring::npos) return "bluetooth";
    }
  }
  PROPVARIANT form;
  PropVariantInit(&form);
  DWORD factor = UnknownFormFactor;
  if (SUCCEEDED(properties->GetValue(PKEY_AudioEndpoint_FormFactor, &form)) && form.vt == VT_UI4) factor = form.ulVal;
  PropVariantClear(&form);
  if (factor == DigitalAudioDisplayDevice) return "hdmi";
  if (factor == Headphones || factor == Headset || factor == Handset) return "earpiece";
  if (factor == Speakers) return "speaker";
  if (factor == LineLevel) return "wired";
  if (factor == RemoteNetworkDevice) return "network";
  return "unknown";
}
}  // namespace

std::unique_ptr<flutter::MethodChannel<EncodableValue>>
CreateAudioOutputsChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "listenfy/bluetooth_audio", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() == "openAudioSettings") {
      auto status = ShellExecuteW(nullptr, L"open", L"ms-settings:sound", nullptr, nullptr, SW_SHOWNORMAL);
      result->Success(EncodableValue(reinterpret_cast<INT_PTR>(status) > 32));
      return;
    }
    if (call.method_name() != "getAudioDevices") { result->NotImplemented(); return; }
    ComPtr<IMMDeviceEnumerator> enumerator;
    ComPtr<IMMDeviceCollection> endpoints;
    if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
        IID_PPV_ARGS(&enumerator))) || FAILED(enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &endpoints))) {
      result->Error("AUDIO_OUTPUTS", "Could not enumerate audio outputs");
      return;
    }
    ComPtr<IMMDevice> active;
    std::wstring activeId;
    if (SUCCEEDED(enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &active))) activeId = DeviceId(active.Get());
    UINT count = 0;
    if (FAILED(endpoints->GetCount(&count))) { result->Error("AUDIO_OUTPUTS", "Could not count audio outputs"); return; }
    EncodableList devices, outputs;
    bool bluetooth = false;
    for (UINT index = 0; index < count; index++) {
      ComPtr<IMMDevice> endpoint;
      ComPtr<IPropertyStore> properties;
      if (FAILED(endpoints->Item(index, &endpoint)) || FAILED(endpoint->OpenPropertyStore(STGM_READ, &properties))) continue;
      const auto id = DeviceId(endpoint.Get());
      if (id.empty()) continue;
      auto name = Utf8(ReadText(properties.Get(), PKEY_Device_FriendlyName));
      if (name.empty()) name = "Audio output";
      const auto kind = Kind(endpoint.Get(), enumerator.Get(), properties.Get());
      bool isActive = id == activeId;
      bluetooth = bluetooth || kind == "bluetooth";
      devices.emplace_back(EncodableMap{
        {EncodableValue("address"), EncodableValue(Utf8(id))},
        {EncodableValue("name"), EncodableValue(name)},
        {EncodableValue("kind"), EncodableValue(kind)},
        {EncodableValue("isActive"), EncodableValue(isActive)},
      });
      if (isActive) outputs.emplace_back(name);
    }
    result->Success(EncodableValue(EncodableMap{
      {EncodableValue("devices"), EncodableValue(devices)},
      {EncodableValue("outputs"), EncodableValue(outputs)},
      {EncodableValue("bluetoothOn"), EncodableValue(bluetooth)},
    }));
  });
  return channel;
}

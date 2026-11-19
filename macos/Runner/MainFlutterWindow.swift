import Cocoa
import FlutterMacOS
import CoreAudio

class MainFlutterWindow: NSWindow {
  private var audioDevicesChannel: FlutterMethodChannel?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    audioDevicesChannel = FlutterMethodChannel(
      name: "listenfy/bluetooth_audio", binaryMessenger: flutterViewController.engine.binaryMessenger)
    audioDevicesChannel?.setMethodCallHandler { [weak self] call, result in
      if call.method == "getAudioDevices" {
        do { result(try self?.audioOutputs()) }
        catch { result(FlutterError(code: "AUDIO_OUTPUTS", message: error.localizedDescription, details: nil)) }
      } else if call.method == "openAudioSettings" {
        let urls = ["x-apple.systempreferences:com.apple.Sound-Settings.extension",
                    "x-apple.systempreferences:com.apple.preference.sound?output"]
        result(urls.contains { value in
          guard let url = URL(string: value) else { return false }
          return NSWorkspace.shared.open(url)
        })
      } else { result(FlutterMethodNotImplemented) }
    }

    super.awakeFromNib()
  }
}

extension MainFlutterWindow {
  private func uintProperty(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32 {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : 0
  }

  private func textProperty(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return "" }
    return value?.takeRetainedValue() as String? ?? ""
  }

  fileprivate func audioOutputs() throws -> [String: Any] {
    let system = AudioObjectID(kAudioObjectSystemObject)
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else {
      throw NSError(domain: "ListenfyAudio", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not enumerate audio outputs"])
    }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    if ids.isEmpty { return ["devices": [], "outputs": [], "bluetoothOn": false] }
    let status = ids.withUnsafeMutableBytes { buffer in
      AudioObjectGetPropertyData(system, &address, 0, nil, &size, buffer.baseAddress!)
    }
    guard status == noErr else { throw NSError(domain: "ListenfyAudio", code: Int(status)) }
    let active = uintProperty(system, kAudioHardwarePropertyDefaultOutputDevice)
    var devices: [[String: Any]] = []
    for id in ids {
      var output = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
      var streamSize: UInt32 = 0
      guard AudioObjectGetPropertyDataSize(id, &output, 0, nil, &streamSize) == noErr,
            streamSize > 0, uintProperty(id, kAudioDevicePropertyDeviceIsAlive) != 0 else { continue }
      let transport = uintProperty(id, kAudioDevicePropertyTransportType)
      let kind: String
      switch transport {
      case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: kind = "bluetooth"
      case kAudioDeviceTransportTypeUSB: kind = "usb"
      case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: kind = "hdmi"
      case kAudioDeviceTransportTypeBuiltIn: kind = "builtin"
      case kAudioDeviceTransportTypeAirPlay: kind = "network"
      case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate: kind = "virtual"
      default: kind = "unknown"
      }
      let name = textProperty(id, kAudioObjectPropertyName)
      let uid = textProperty(id, kAudioDevicePropertyDeviceUID)
      devices.append(["name": name.isEmpty ? "Audio output" : name,
        "address": uid.isEmpty ? String(id) : uid, "kind": kind, "isActive": id == active])
    }
    return ["devices": devices, "bluetoothOn": devices.contains { ($0["kind"] as? String) == "bluetooth" },
      "outputs": devices.filter { ($0["isActive"] as? Bool) == true }.compactMap { $0["name"] as? String }]
  }
}

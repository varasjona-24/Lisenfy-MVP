<div align="center">

# Listenfy — Music & Video Player

**A privacy-first, modular multimedia player for local audio playback and hybrid streaming, designed to run fully on-device without relying on cloud services.**

[![Flutter](https://img.shields.io/badge/Built_with-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
![Platform](https://img.shields.io/badge/platform-android-blue?style=for-the-badge)
![Offline](https://img.shields.io/badge/offline-supported-green?style=for-the-badge)

## 🧪 Status

🟡 **Actively developed multimedia player**

*Listenfy combines robust local playback with native audio processing capabilities and a privacy-centric, telemetry-free architecture.*

<br/>

## 📦 Download


- F-Droid *(coming soon)*
- Zapstore *(coming soon)*

</div>

---

## 🎯 The Vision

Many modern media players rely heavily on cloud infrastructure, user tracking, and continuous internet connections. Offline players often lack advanced multimedia processing or functional UI components.

Listenfy addresses this by providing a privacy-first hybrid player. It manages local files natively while integrating external sources via downloads. All user data, metadata scanning, and recommendation logic remain strictly on the device.

---

## 💡 What makes Listenfy different

- **Offline-First Data Processing:** No external telemetry. Recommendations and listening histories are computed purely on-device.
- **Native DSP Bridges:** Replaces standard Dart audio limitations by routing data through OpenAL via MethodChannels for advanced spatial adjustments.
- **Hardware-Responsive UI:** Visualizers are driven by real RMS energy and spectral centroids rather than generic random animations.
- **Modular Ecosystem:** Built with a Feature-First GetX architecture, cleanly separating the player engine, download managers, and UI components.

---

## ✨ Key Features

### 🎵 Core Playback & Media Management
- **Universal Media Engine:** Gapless playback for standard audio and video formats using `just_audio` and `video_player`.
- **Local Library Syncing:** Offline file indexing, metadata extraction, and directory tree navigation.
- **Download Manager:** Centralized tracking for syncing media from external sources to local storage.

### 🌐 The "Atlas" World Mode
- **Experimental map-based discovery interface:** A geographic interface for discovering local streams and frequencies.
- **Algorithmic Shuffling:** Shuffles available streams specifically to reduce repetitive station looping.

### 🎛️ Advanced Audio Processing (Experimental)
- **Spatial & 8D Audio (WIP):** Uses native DSP to pan and process stereo tracks for spatial audio output.
- **AI Vocal Extraction:** On-device pipeline to isolate backing instrumentals from local tracks.
- **Reactive Visualizer:** Spectrums bound to live FFT data running through Flutter’s `CustomPainter` at 60fps.

---

## 🏗️ Architecture & Technical Overview

Listenfy employs a modular structure using Flutter and GetX.

- **State & DI:** `GetX` handles reactive UI states and dependency injection.
- **Local Storage:** `Hive` is used for high-speed local NoSQL caching, combined with `GetStorage` for app preferences.
- **Background Playback:** Audio sessions and lockscreen controls are handled by coupling `just_audio` with `audio_service`.
- **Networking:** External metadata lookups and file streams are managed via `Dio`.

### Native Dependencies: OpenAL
Standard Dart libraries often introduce latency during complex DSP tasks. Listenfy includes an experimental bridge routing audio streams through **OpenAL via MethodChannels**. This allows spatial positioning, reverb adjustments, and direct audio manipulation on the native OS thread.

---

## ⚙️ How It Works

1. **Initialization:** On startup, the app loads local `Hive` caches and verifies read/write system permissions.
2. **Library Scan:** The `MediaRepository` indexes audio and video files found in local directories.
3. **Audio Routing:** Audio chunks are sent to the `just_audio` isolate for normal playback or through a MethodChannel to the native OpenAL engine when Spatial Audio is enabled.
4. **Visual Analysis:** For the visualizer, FFT data is synced to the playing thread and passed to a custom render pipeline.

---

## 📸 Screenshots (coming soon)

---

## 🚀 Installation & Usage

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) `3.10.x` or higher
- Android Studio / Xcode

### Build from Source

```bash
# Clone the repository
git clone https://github.com/your-username/listenfy.git
cd listenfy

# Fetch dependencies
flutter pub get

# Compile and run
flutter run --release
```

*Note: The application requires local storage and notification permissions to manage background playback.*

---

## 🛣️ Project Status & Roadmap

Listenfy is an actively developed multimedia player. Standard playback and local file management are stable. The advanced DSP elements (OpenAL, Spatial Audio, Vocal Extraction) are in active development and highly experimental.

**Upcoming Milestones:**
- [ ] Stabilize the OpenAL MethodChannel bridge for iOS.
- [ ] Improve performance for on-device karaoke vocal extraction.
- [ ] Implement reproducible builds for F-Droid submission.
- [ ] Refine the Atlas map interface for scaling large datasets.

---

## 🤝 Contributing

Contributions are welcome across UI, state management, and native DSP implementation.

1. Review the Issue Tracker.
2. Fork the repository.
3. Create a feature branch (`git checkout -b feature/issue-name`).
4. Commit using standard conventional commits.
5. Submit a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

For detailed information regarding the licenses of the third-party libraries and native components (such as OpenAL Soft) used in this project, please refer to the [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) file.

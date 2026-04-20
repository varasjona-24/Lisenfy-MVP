<div align="center">

# Listenfy

**The uncompromising, privacy-first multimedia hub for local and hybrid audio.**

[![Flutter](https://img.shields.io/badge/Built_with-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android_%7C_iOS-lightgrey?style=for-the-badge&logo=android)](#)
[![Privacy First](https://img.shields.io/badge/Privacy-Offline_First-success?style=for-the-badge)](#)

*Listenfy breaks the boundaries of standard media players by blending robust local playback with cutting-edge native audio processing, a zero-telemetry architecture, and a modular ecosystem built for power users.*

<br/>

<a href="#installation">
  <img src="https://img.shields.io/badge/⬇️_Download_Release-black?style=for-the-badge&logo=android" alt="Download Release" />
</a>
<a href="#installation">
  <img src="https://img.shields.io/badge/Get_it_on-F--Droid-black?style=for-the-badge&logo=f-droid" alt="F-Droid" />
</a>

</div>

---

## 🎯 The Vision

Modern media players have become bloated with tracking, ads, and forced cloud dependencies. Native offline players, on the other hand, often lack modern UX and advanced audio capabilities. 

**Listenfy exists to bridge this gap.** 

It is designed as a hybrid, privacy-first media powerhouse. It treats your local files as first-class citizens while seamlessly integrating remote sources and downloads, all wrapped in an ultra-premium, dynamic user interface. Whether you want a simple music session, an immersive spatial audio experience, or an impromptu karaoke night, Listenfy provides the tools without harvesting your data.

---

## ✨ Key Features

### 🎵 Core Playback & Media Management
- **Universal Media Engine:** Gapless, high-fidelity playback for both audio and video formats.
- **Smart Local Library:** Lightning-fast indexing of your local files, artist metadata pulling, and folder-based navigation.
- **Deep Offline Support:** Integrated download manager to pull and sync media from external sources directly to your device storage.

### 🎛️ Advanced Audio Processing
- **Real-Time Spatial & 8D Audio:** Transforms standard stereo tracks into immersive, dynamic soundscapes natively on your device.
- **AI Karaoke Pipeline (Experimental):** Instant vocal extraction to strip vocals from tracks and generate clean instrumentals on the fly.
- **Hardware-Reactive Visualizer:** Spectrums and particles that react vividly to RMS energy, spectral centroids, and bass onsets, rather than relying on randomized animations.

### 🌐 The "Atlas" World Mode
- **Map-Based Discovery:** A "Radio Garden"-style interactive globe that lets you discover local sounds and frequencies by exploring a virtual map.
- **True Randomization:** Dynamic shuffling algorithms prevent stale loops when exploring new regional streams.

### 🔒 Privacy by Design
- **Zero-Telemetry Ecosystem:** All recommendation engines, user profiling, and listening histories are calculated and stored entirely locally.
- **No Forced Accounts:** Full access to all features without ever needing to log in.

---

## 🏗️ Architecture & Technical Overview

Listenfy is built with scale and maintainability in mind, heavily utilizing the **Feature-First / Modular Pattern** in Flutter.

- **State Management & DI:** Powered by `GetX` for hyper-fast reactive states and precise dependency injection.
- **Data Persistence:** `Hive` provides instantaneous NoSQL local caching combined with `GetStorage` for app configurations.
- **Media Handlers:** A seamless bridge between `just_audio` and `audio_service`, guaranteeing flawless background and lockscreen playback.
- **Network Layer:** Robust REST requests and download streams handled optimally via `Dio`.

### Native Dependencies: The OpenAL Bridge
To achieve zero-latency DSP (Digital Signal Processing) and spatial audio effects, Listenfy bypasses standard Dart limitations by bridging directly into native code.
- We utilize **OpenAL via MethodChannels** to process audio streams directly at the OS level. This enables true 8D panning, pitch shifting, and reverb without choking the main UI isolate.

---

## ⚙️ How It Works

1. **Initialization:** On boot, the app establishes connections with locally stored Hive boxes and requests read/write permissions.
2. **Library Sync:** The `MediaRepository` scans designated audio directories, parsing metadata entirely offline.
3. **Audio Routing:** When play is pressed, audio chunks are sent either to the standard `just_audio` isolate or through the `MethodChannel` directly to the OpenAL native engine (if Spatial Audio is enabled).
4. **Visual Delivery:** The reactive visualizer hooks into the playing stream, analyzing the Fourier transform (FFT) data to paint dynamic 60fps graphics via Flutter's `CustomPainter`.

---

## 📸 Screenshots *(Placeholders)*

| Main Player | Atlas World Mode | Reactive Visualizer | Advanced EQ |
| :---: | :---: | :---: | :---: |
| <img src="https://via.placeholder.com/180x360/121212/FFFFFF?text=Player+UI" width="100%"/> | <img src="https://via.placeholder.com/180x360/121212/FFFFFF?text=Map+View" width="100%"/> | <img src="https://via.placeholder.com/180x360/121212/FFFFFF?text=Visualizer" width="100%"/> | <img src="https://via.placeholder.com/180x360/121212/FFFFFF?text=Equalizer" width="100%"/> |

---

## 🚀 Installation & Usage

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) `3.10.x` or higher
- Android Studio / Xcode for native compilation

### Build from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/listenfy.git
   cd listenfy/Front
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Compile and Run:**
   ```bash
   flutter run --release
   ```
   *Note: On your first run, the app will prompt for necessary storage and Bluetooth/Notification permissions to wire the background audio services correctly.*

---

## 🛣️ Project Status & Roadmap

Listenfy is currently in **Functional MVP** status. The core architecture is stable, local playback is flawless, and experimental native DSP elements are continuously being optimized.

**Upcoming Milestones:**
- [ ] Refine OpenAL MethodChannel bridging for iOS.
- [ ] Migrate full karaoke extraction pipelines to strictly on-device processing.
- [ ] Implement F-Droid specific automated build workflows.
- [ ] Expand the Atlas mapping interface with granular genre filtering.

---

## 🤝 Contributing

We welcome open-source contributions from UI designers and DSP engineers alike. 

1. Check the Issue Tracker and claim an issue.
2. Fork the repository.
3. Create your feature branch (`git checkout -b feature/AmazingUpdate`).
4. Commit your changes strictly following conventional commits.
5. Open a Pull Request for review.

---

## 📄 License

*(Insert License details here. e.g., MIT License. See the [LICENSE](LICENSE) file for more information. Privacy-first, open by default.)*

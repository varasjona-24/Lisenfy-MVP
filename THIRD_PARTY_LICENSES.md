# Third-Party Licenses

This document is a human-readable summary of notable third-party components
used by Listenfy.

It is intended as an informational notice, not as a substitute for the
original license text distributed by each dependency. For the full and
authoritative terms of use, distribution, attribution, and compliance, refer
to:

- the original repository or package page of each dependency;
- the license file shipped with that dependency;
- any platform-specific notices bundled at build time; and
- Flutter's runtime license screen when applicable.

## Scope

The list below focuses on direct dependencies and notable bundled native
components used by this project. It may not be exhaustive for every transitive
dependency pulled in by Flutter, Android, iOS, macOS, Linux, or Windows build
tooling.

## Core SDKs and Frameworks

- **Flutter Framework** — BSD 3-Clause
  https://github.com/flutter/flutter/blob/master/LICENSE
- **Dart SDK** — BSD 3-Clause
  https://github.com/dart-lang/sdk/blob/main/LICENSE

## Audio, Video, and Media Processing

- **OpenAL Soft** — LGPL-2.0-or-later
  https://github.com/kcat/openal-soft
  
  Used as a shared/dynamic library. No modifications to the original source are included.
- **just_audio** — MIT
  https://pub.dev/packages/just_audio
- **just_audio_background** — MIT
  https://pub.dev/packages/just_audio_background
- **audio_service** — MIT
  https://pub.dev/packages/audio_service
- **audio_session** — MIT
  https://pub.dev/packages/audio_session
- **video_player** — BSD 3-Clause
  https://pub.dev/packages/video_player
- **flutter_svg** — MIT
  https://pub.dev/packages/flutter_svg

## State, Storage, and Data Handling

- **GetX (`get`)** — MIT
  https://pub.dev/packages/get
- **GetStorage** — MIT
  https://pub.dev/packages/get_storage
- **Hive** — Apache License 2.0
  https://pub.dev/packages/hive
- **hive_flutter** — Apache License 2.0
  https://pub.dev/packages/hive_flutter
- **archive** — MIT
  https://pub.dev/packages/archive
- **collection** — BSD 3-Clause
  https://pub.dev/packages/collection
- **crypto** — BSD 3-Clause
  https://pub.dev/packages/crypto
- **path** — BSD 3-Clause
  https://pub.dev/packages/path
- **path_provider** — BSD 3-Clause
  https://pub.dev/packages/path_provider

## Networking and Integrations

- **Dio** — MIT
  https://pub.dev/packages/dio
- **permission_handler** — MIT
  https://pub.dev/packages/permission_handler
- **file_picker** — MIT
  https://pub.dev/packages/file_picker
- **image_cropper** — MIT
  https://pub.dev/packages/image_cropper
- **receive_sharing_intent** — MIT
  https://pub.dev/packages/receive_sharing_intent
- **app_links** — MIT
  https://pub.dev/packages/app_links
- **share_plus** — BSD 3-Clause
  https://pub.dev/packages/share_plus
- **webview_flutter** — BSD 3-Clause
  https://pub.dev/packages/webview_flutter
- **flutter_custom_tabs** — MIT
  https://pub.dev/packages/flutter_custom_tabs
- **app_settings** — MIT
  https://pub.dev/packages/app_settings

## Discovery, Nearby, and Utility Components

- **nearby_connections** — Apache License 2.0
  https://pub.dev/packages/nearby_connections
- **mobile_scanner** — MIT
  https://pub.dev/packages/mobile_scanner
- **qr_flutter** — MIT
  https://pub.dev/packages/qr_flutter
- **cupertino_icons** — MIT
  https://pub.dev/packages/cupertino_icons

## Additional Notice

Some platform integrations may also bundle or reference transitive components
through CocoaPods, Gradle dependencies, Flutter plugins, AndroidX, or system
frameworks. Those components may carry their own license terms and attribution
requirements.

If Listenfy is distributed publicly, the safest compliance approach is:

1. keep this summary file in the repository;
2. include the original license texts when required by a dependency;
3. expose Flutter's built-in license view in the app when appropriate; and
4. review transitive native dependencies before each production release.

## Disclaimer

All third-party components are used in accordance with their respective licenses.

This document is provided for informational purposes only and does not replace
the original license terms.

Users and distributors are responsible for ensuring compliance with all
applicable licenses when redistributing this software.

import 'package:get/get.dart';
import '../../../../app/services/audio_service.dart';
import '../../../../app/services/audio_waveform_service.dart';
import '../controller/audio_player_controller.dart';

class AudioPlayerBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AudioWaveformService>()) {
      Get.put(AudioWaveformService(), permanent: true);
    }
    Get.put<AudioPlayerController>(
      AudioPlayerController(audioService: Get.find<AudioService>()),
      permanent: true,
    );
  }
}

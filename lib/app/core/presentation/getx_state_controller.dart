import 'package:get/get.dart';

abstract class GetxStateController<S> extends GetxController {
  GetxStateController(S initialState) : state = initialState.obs;

  final Rx<S> state;

  void emit(S nextState) {
    state.value = nextState;
  }
}


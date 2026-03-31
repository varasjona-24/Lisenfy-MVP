enum ViewStatus {
  idle,
  loading,
  success,
  failure;

  bool get isIdle => this == ViewStatus.idle;
  bool get isLoading => this == ViewStatus.loading;
  bool get isSuccess => this == ViewStatus.success;
  bool get isFailure => this == ViewStatus.failure;
}


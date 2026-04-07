class RotateAdItemUsecase {
  const RotateAdItemUsecase();

  int call({required int currentIndex, required int total}) {
    if (total <= 0) {
      return 0;
    }
    return (currentIndex + 1) % total;
  }
}

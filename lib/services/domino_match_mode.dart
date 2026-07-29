enum DominoMatchMode {
  block,
  drawPool;

  static DominoMatchMode fromValue(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'draw' || 'draw_pool' || 'pool' => DominoMatchMode.drawPool,
      _ => DominoMatchMode.block,
    };
  }

  String get storageValue => switch (this) {
    DominoMatchMode.block => 'block',
    DominoMatchMode.drawPool => 'draw_pool',
  };

  bool get usesPool => this == DominoMatchMode.drawPool;
}

String formatDistance(num meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

String formatDuration(num seconds) {
  final mins = (seconds / 60).round();
  if (mins < 60) return '$mins min';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m == 0 ? '$h hr' : '$h hr $m min';
}

({int km, int hundreds}) splitDtdMeters(num meters) {
  final safe = meters.clamp(0, 999990).round();
  final km = safe ~/ 1000;
  final hundreds = ((safe % 1000) / 100).floor().clamp(0, 9);
  return (km: km, hundreds: hundreds);
}

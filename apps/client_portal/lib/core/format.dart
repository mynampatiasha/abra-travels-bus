/// `dd/MM/yyyy` for an ISO date or time from the API, or a dash when there is none.
String dateOf(Object? iso) {
  final time = DateTime.tryParse('$iso')?.toLocal();
  if (time == null) return '-';
  return '${time.day.toString().padLeft(2, '0')}/'
      '${time.month.toString().padLeft(2, '0')}/${time.year}';
}

/// The size of a file in words: `850 KB`, `2.3 MB`.
String sizeOf(Object? bytes) {
  final size = bytes is num ? bytes.toInt() : 0;
  if (size < 1024 * 1024) return '${(size / 1024).ceil()} KB';
  return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
}

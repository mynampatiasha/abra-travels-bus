import 'dart:typed_data';

/// Saves [text] as a file the person downloads. Only a browser can; tests and
/// other platforms record the last call instead.
String? lastDownloadName;
String? lastDownloadText;
Uint8List? lastDownloadBytes;

void downloadBytesFile(
  String filename,
  Uint8List bytes, {
  required String mimeType,
}) {
  lastDownloadName = filename;
  lastDownloadBytes = bytes;
}

void downloadTextFile(
  String filename,
  String text, {
  String mimeType = 'text/csv;charset=utf-8',
}) {
  lastDownloadName = filename;
  lastDownloadText = text;
}

/// Shows a file (a document) in a new browser tab. Browser only.
void openFileInBrowser(Uint8List bytes, String mimeType) {
  throw UnsupportedError('Files open in a browser tab on the web only.');
}

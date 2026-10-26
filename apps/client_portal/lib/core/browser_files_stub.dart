import 'dart:typed_data';

/// Saves [text] as a file the person downloads. Only a browser can; tests and
/// other platforms record the last call instead.
String? lastDownloadName;
String? lastDownloadText;

void downloadTextFile(String filename, String text) {
  lastDownloadName = filename;
  lastDownloadText = text;
}

/// Saves [bytes] as a file the person downloads. Only a browser can; tests and
/// other platforms record the last call instead.
String? lastDownloadBytesName;
Uint8List? lastDownloadBytes;

void downloadBytesFile(String filename, Uint8List bytes, String mimeType) {
  lastDownloadBytesName = filename;
  lastDownloadBytes = bytes;
}

/// Shows a file (a document) in a new browser tab. Browser only.
void openFileInBrowser(Uint8List bytes, String mimeType) {
  throw UnsupportedError('Files open in a browser tab on the web only.');
}

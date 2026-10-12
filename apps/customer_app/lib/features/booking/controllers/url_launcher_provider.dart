import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app (maps, phone). A provider, so a test can
/// replace it and see what would have been opened.
final urlLauncherProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// The link that shows [query] (a place name and address) on a map.
Uri mapSearchUri(String query) => Uri.https(
  'www.google.com',
  '/maps/search/',
  <String, String>{'api': '1', 'query': query},
);

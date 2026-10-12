import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../app/providers.dart';

/// What tapping a banner opens.
enum BannerLinkType {
  none,
  offer,
  routeSearch,
  screen,
  url;

  /// Unknown values (a type added on the backend later) open nothing.
  static BannerLinkType fromWire(String? value) => switch (value) {
    'OFFER' => offer,
    'ROUTE_SEARCH' => routeSearch,
    'SCREEN' => screen,
    'URL' => url,
    _ => none,
  };
}

/// One promotional banner at the top of Home (`GET /banners`).
@immutable
final class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    this.subtitle,
    this.buttonText,
    this.linkType = BannerLinkType.none,
    this.linkValue = '',
    this.imageUrl,
    this.desktopImageUrl,
  });

  /// Reads one banner. [imageBase] resolves a relative `imageUrl`; an image
  /// address that is not http(s) after that is dropped (the gradient is
  /// shown instead). Throws [FormatException] when id or title is missing.
  factory HomeBanner.fromJson(JsonMap json, {required Uri imageBase}) {
    final reader = JsonReader(json);
    String? text(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return HomeBanner(
      id: reader.string('id'),
      title: reader.string('title'),
      subtitle: text('subtitle'),
      buttonText: text('buttonText'),
      linkType: BannerLinkType.fromWire(text('linkType')),
      linkValue: text('linkValue') ?? '',
      imageUrl: _resolveImageUrl(text('imageUrl'), imageBase),
      desktopImageUrl: _resolveImageUrl(text('desktopImageUrl'), imageBase),
    );
  }

  final String id;
  final String title;
  final String? subtitle;
  final String? buttonText;
  final BannerLinkType linkType;

  /// OFFER: offer code or id. ROUTE_SEARCH: `fromCityId:toCityId`.
  /// SCREEN: an app route. URL: an https address. NONE: empty.
  final String linkValue;

  /// Absolute image address for phones, or null for the brand gradient.
  final Uri? imageUrl;

  /// The wide picture for tablets and desktops, or null to use [imageUrl].
  final Uri? desktopImageUrl;

  /// The picture for a wide or a narrow layout.
  Uri? imageFor({required bool isWide}) =>
      isWide ? desktopImageUrl ?? imageUrl : imageUrl;

  /// An absolute https address as it is; a relative path (`banners/{id}/
  /// image?v=1`) against [base], the API address including `api/v1/`.
  static Uri? _resolveImageUrl(String? value, Uri base) {
    if (value == null) return null;
    final parsed = Uri.tryParse(value);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed.isScheme('https') ? parsed : null;
    // A leading slash would drop `api/v1`; the contract's paths are
    // relative to it.
    final resolved = base.resolveUri(
      Uri.parse(value.startsWith('/') ? value.substring(1) : value),
    );
    return resolved.isScheme('https') || resolved.isScheme('http')
        ? resolved
        : null;
  }
}

/// Opens an https address in the device browser; false when it could not.
typedef ExternalUrlOpener = Future<bool> Function(Uri url);

/// How URL banners leave the app. The app has no URL launcher yet, so by
/// default nothing opens and the banner shows the not-built screen; the
/// bootstrap overrides this once `url_launcher` is a dependency.
final externalUrlOpenerProvider = Provider<ExternalUrlOpener>(
  (ref) =>
      (url) async => false,
);

final homeBannersRepositoryProvider = Provider<HomeBannersRepository>((ref) {
  final dependencies = ref.watch(appDependenciesProvider);
  return HomeBannersRepository(
    dependencies.apiClient,
    imageBase: dependencies.config.apiV1Url,
  );
});

/// The live banners for the top of Home, in the selected language. Loaded
/// again when the language changes and on pull-to-refresh.
final homeBannersProvider = FutureProvider<List<HomeBanner>>((ref) {
  final locale = ref.watch(appDependenciesProvider).localeController;
  void reload() => ref.invalidateSelf();
  locale.addListener(reload);
  ref.onDispose(() => locale.removeListener(reload));
  return ref.watch(homeBannersRepositoryProvider).homeTop();
});

/// The public banners endpoint (no sign-in, so guests see them too). The
/// language goes with every request as `Accept-Language` (ApiClient).
class HomeBannersRepository {
  HomeBannersRepository(this._client, {required Uri imageBase})
    : _imageBase = imageBase;

  final ApiClient _client;
  final Uri _imageBase;

  static const maxBanners = 10;

  /// Throws `AppException` when the request fails. Banners are decoration:
  /// a malformed entry is skipped rather than hiding the others.
  Future<List<HomeBanner>> homeTop() async {
    final response = await _client.get(
      'banners',
      query: const <String, Object?>{'placement': 'HOME_TOP'},
      authenticated: false,
    );
    final payload = response.data;
    if (payload is! List) return const <HomeBanner>[];
    final banners = <HomeBanner>[];
    for (final item in payload) {
      if (item is! Map) continue;
      try {
        banners.add(
          HomeBanner.fromJson(asJsonMap(item), imageBase: _imageBase),
        );
      } on FormatException {
        continue;
      }
    }
    return banners.take(maxBanners).toList();
  }
}

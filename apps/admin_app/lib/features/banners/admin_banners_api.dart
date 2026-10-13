import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../app/providers.dart';
import '../../l10n/admin_strings.dart';

/// The banner list below `/api/v1`. Listing, enable/disable and the generic
/// management page go through the catalogue repository with this path.
const bannersPath = 'admin/banners';

/// Largest image the backend accepts (1 MB, as in the demo).
const bannerImageMaxBytes = 1024 * 1024;

/// Image types the backend accepts, by file extension.
const bannerImageTypes = <String, String>{
  'jpg': 'jpeg',
  'jpeg': 'jpeg',
  'png': 'png',
  'webp': 'webp',
};

/// The two images of a banner. The customer app shows [mobile] on phones
/// and [desktop] on wider screens, falling back to [mobile] when there is no
/// [desktop] image.
enum BannerImageVariant {
  mobile(
    width: 800,
    height: 600,
    ratioText: '4:3',
    urlKey: 'imageUrl',
    labelKey: AdminStrings.bnPicturePhone,
    hintKey: AdminStrings.bannerImageMobileHint,
  ),
  desktop(
    width: 1920,
    height: 600,
    ratioText: '16:5',
    urlKey: 'desktopImageUrl',
    labelKey: AdminStrings.bnPictureDesktop,
    hintKey: AdminStrings.bannerImageDesktopHint,
  );

  const BannerImageVariant({
    required this.width,
    required this.height,
    required this.ratioText,
    required this.urlKey,
    required this.labelKey,
    required this.hintKey,
  });

  /// Recommended size in pixels.
  final int width;
  final int height;
  final String ratioText;

  /// Field of the banner that holds the image's address.
  final String urlKey;
  final String labelKey;
  final String hintKey;

  double get ratio => width / height;

  /// True when an image of this size is far enough from the recommended
  /// shape that the app will cut off a noticeable part of it.
  bool isFarFrom(int imageWidth, int imageHeight) =>
      imageHeight > 0 &&
      ((imageWidth / imageHeight) - ratio).abs() / ratio > 0.15;
}

/// Label keys of the fixed values of a banner.
abstract final class BannerLabels {
  /// The words of the demo: a banner that is on is Published, one that is
  /// off is a Draft.
  static const statuses = <String, String>{
    'INACTIVE': AdminStrings.bnStatusDraft,
    'SCHEDULED': AdminStrings.bnStatusScheduled,
    'LIVE': AdminStrings.bnStatusPublished,
    'EXPIRED': AdminStrings.bnStatusExpired,
    'ARCHIVED': AdminStrings.bnStatusArchived,
  };

  static const audiences = <String, String>{
    'ALL': AdminStrings.bnAudAll,
    'NEW_USERS': AdminStrings.bnAudNew,
    'SIGNED_IN': AdminStrings.bnAudSigned,
  };

  static const colourStyles = <String, String>{
    'NAVY_BLUE': AdminStrings.bnColourNavyBlue,
    'BLUE_SKY': AdminStrings.bnColourBlueSky,
    'GREEN_NAVY': AdminStrings.bnColourGreenNavy,
  };

  /// What the "Opens" selector offers (the demo's four).
  static const opens = <String, String>{
    'OFFER': AdminStrings.bnOptOffer,
    'ROUTE_SEARCH': AdminStrings.bnOptRoute,
    'OPERATOR': AdminStrings.bnOptOperator,
    'URL': AdminStrings.bnOptLink,
  };

  static const placements = <String, String>{
    'HOME_TOP': AdminStrings.placementHomeTop,
    'OFFERS': AdminStrings.placementOffers,
  };

  static const linkTypes = <String, String>{
    'NONE': AdminStrings.linkNone,
    'OFFER': AdminStrings.linkOffer,
    'ROUTE_SEARCH': AdminStrings.linkRouteSearch,
    'SCREEN': AdminStrings.linkScreen,
    'URL': AdminStrings.linkUrl,
  };

  /// The link types as offered in the form: the ones the customer app does
  /// not handle yet say so.
  static const linkTypeChoices = <String, String>{
    'NONE': AdminStrings.linkNone,
    'OFFER': AdminStrings.linkOfferSoon,
    'ROUTE_SEARCH': AdminStrings.linkRouteSearch,
    'SCREEN': AdminStrings.linkScreenSoon,
    'URL': AdminStrings.linkUrl,
  };

  static const linkHints = <String, String>{
    'NONE': AdminStrings.linkHintNone,
    'OFFER': AdminStrings.linkHintOffer,
    'ROUTE_SEARCH': AdminStrings.linkHintRouteSearch,
    'SCREEN': AdminStrings.linkHintScreen,
    'URL': AdminStrings.linkHintUrl,
  };

  static const languages = <String, String>{
    'ALL': AdminStrings.languageAll,
    'en': AdminStrings.languageEn,
    'hi': AdminStrings.languageHi,
    'te': AdminStrings.languageTe,
    'kn': AdminStrings.languageKn,
    'ta': AdminStrings.languageTa,
    'ml': AdminStrings.languageMl,
    'mr': AdminStrings.languageMr,
    'bn': AdminStrings.languageBn,
  };

  /// The label of [value] in [labels], or the value itself when unknown.
  static String of(
    AbraLocalizations l10n,
    Map<String, String> labels,
    Object? value,
  ) {
    final key = labels['$value'];
    return key == null ? (value?.toString() ?? '') : l10n.text(key);
  }
}

/// What to enter as the link value for the link type chosen in the form.
String? bannerLinkHintOf(JsonMap values) =>
    BannerLabels.linkHints[values['linkType']];

String bannerTitleOf(JsonMap banner) => banner['title'] as String? ?? '';

/// The local day of an ISO time from the API, or null.
DateTime? _localTimeOf(Object? iso) =>
    DateTime.tryParse('${iso ?? ''}')?.toLocal();

/// `YYYY-MM-DD` of an ISO time from the API (local day), or empty.
String bannerDayOf(Object? iso) =>
    _localTimeOf(iso)?.toIso8601String().substring(0, 10) ?? '';

/// When the banner shows: "12 Oct – 31 Oct 2026", "From 12 Oct 2026",
/// "Until 31 Oct 2026" or "Always".
String bannerScheduleOf(AbraLocalizations l10n, JsonMap banner) {
  final months = l10n.text(AdminStrings.bannerMonths).split(' ');
  String day(DateTime time, {bool withYear = true}) {
    final month = months.length == 12
        ? months[time.month - 1]
        : time.month.toString().padLeft(2, '0');
    return withYear ? '${time.day} $month ${time.year}' : '${time.day} $month';
  }

  final starts = _localTimeOf(banner['startsAt']);
  final ends = _localTimeOf(banner['endsAt']);
  if (starts != null && ends != null) {
    return '${day(starts, withYear: starts.year != ends.year)} – ${day(ends)}';
  }
  if (starts != null) {
    return l10n.text(AdminStrings.bannerScheduleFrom, <String, Object?>{
      'date': day(starts),
    });
  }
  if (ends != null) {
    return l10n.text(AdminStrings.bannerScheduleUntil, <String, Object?>{
      'date': day(ends),
    });
  }
  return l10n.text(AdminStrings.bannerScheduleAlways);
}

/// "12 Oct 2026 to 31 Oct 2026" (the demo's Runs column); "From 12 Oct 2026",
/// "Until 31 Oct 2026" or "Always" when a day is missing.
String bannerRunsOf(AbraLocalizations l10n, JsonMap banner) {
  final months = l10n.text(AdminStrings.bannerMonths).split(' ');
  String day(DateTime time) {
    final month = months.length == 12
        ? months[time.month - 1]
        : time.month.toString().padLeft(2, '0');
    return '${time.day} $month ${time.year}';
  }

  final starts = _localTimeOf(banner['startsAt']);
  final ends = _localTimeOf(banner['endsAt']);
  if (starts != null && ends != null) {
    return l10n.text(AdminStrings.bnRunsRange, <String, Object?>{
      'from': day(starts),
      'to': day(ends),
    });
  }
  if (starts != null) {
    return l10n.text(AdminStrings.bnRunsFrom, <String, Object?>{
      'date': day(starts),
    });
  }
  if (ends != null) {
    return l10n.text(AdminStrings.bnRunsUntil, <String, Object?>{
      'date': day(ends),
    });
  }
  return l10n.text(AdminStrings.bnRunsAlways);
}

/// The form or import values as the API takes them: the start and end days
/// become the start of the first day and the end of the last day, in the
/// admin's time zone, as ISO times. A cleared day stays `null`.
JsonMap bannerBody(JsonMap values) => <String, Object?>{
  ...values,
  for (final key in const <String>['startsAt', 'endsAt'])
    if (values.containsKey(key))
      key: _isoOf(values[key], endOfDay: key == 'endsAt'),
};

String? _isoOf(Object? day, {required bool endOfDay}) {
  final parsed = DateTime.tryParse('${day ?? ''}');
  if (parsed == null) return null;
  final local = DateTime(parsed.year, parsed.month, parsed.day);
  final time = endOfDay
      ? local.add(const Duration(days: 1, milliseconds: -1))
      : local;
  return time.toUtc().toIso8601String();
}

/// Why a file cannot be a banner image (a message key and its values), or
/// null when it can.
(String, Map<String, Object?>)? bannerImageProblem(String name, int size) {
  final extension = name.contains('.')
      ? name.split('.').last.toLowerCase()
      : '';
  if (!bannerImageTypes.containsKey(extension)) {
    return (AdminStrings.bannerUploadWrongType, const <String, Object?>{});
  }
  if (size > bannerImageMaxBytes) {
    return (
      AdminStrings.bannerUploadTooLarge,
      <String, Object?>{
        'size': '${(size / (1024 * 1024)).toStringAsFixed(1)} MB',
      },
    );
  }
  return null;
}

/// Width and height of a JPG, PNG or WebP image, read from its header; null
/// when the header is not understood.
(int, int)? bannerImageSizeOf(Uint8List bytes) {
  int u16be(int i) => bytes[i] << 8 | bytes[i + 1];
  int u16le(int i) => bytes[i] | bytes[i + 1] << 8;
  int u24le(int i) => bytes[i] | bytes[i + 1] << 8 | bytes[i + 2] << 16;
  int u32be(int i) => u16be(i) << 16 | u16be(i + 2);
  bool hasAt(int i, String text) =>
      bytes.length >= i + text.length &&
      String.fromCharCodes(bytes.sublist(i, i + text.length)) == text;

  // PNG: the IHDR chunk comes first.
  if (bytes.length >= 24 && hasAt(1, 'PNG') && hasAt(12, 'IHDR')) {
    return (u32be(16), u32be(20));
  }
  // JPEG: the first start-of-frame segment.
  if (bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    var i = 2;
    while (i + 9 < bytes.length) {
      if (bytes[i] != 0xFF) return null;
      final marker = bytes[i + 1];
      final isFrame =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isFrame) return (u16be(i + 7), u16be(i + 5));
      i += 2 + u16be(i + 2);
    }
    return null;
  }
  // WebP: lossy, lossless or extended.
  if (bytes.length >= 30 && hasAt(0, 'RIFF') && hasAt(8, 'WEBP')) {
    if (hasAt(12, 'VP8 ')) {
      return (u16le(26) & 0x3FFF, u16le(28) & 0x3FFF);
    }
    if (hasAt(12, 'VP8L')) {
      final b = bytes;
      return (
        1 + ((b[22] & 0x3F) << 8 | b[21]),
        1 + ((b[24] & 0x0F) << 10 | b[23] << 2 | (b[22] & 0xC0) >> 6),
      );
    }
    if (hasAt(12, 'VP8X')) return (1 + u24le(24), 1 + u24le(27));
  }
  return null;
}

final bannersApiProvider = Provider<BannersApi>((ref) {
  final dependencies = ref.watch(appDependenciesProvider);
  return BannersApi(dependencies.apiClient, dependencies.config.apiV1Url);
});

/// The banner management API (`admin/banners`). Every call carries the
/// user's token; the backend checks `banners.manage` and `banners.delete`.
class BannersApi {
  BannersApi(this._client, this._apiV1Url);

  final ApiClient _client;

  /// `<origin>/api/v1/`, against which relative image paths are resolved.
  final Uri _apiV1Url;

  Future<JsonMap> create(JsonMap values) async => (await _client.post(
    bannersPath,
    body: bannerBody(values),
  )).decodeObject((json) => json);

  /// Changes only the fields in [values].
  Future<JsonMap> update(String id, JsonMap values) async => (await _client.put(
    '$bannersPath/$id',
    body: bannerBody(values),
  )).decodeObject((json) => json);

  Future<void> delete(String id) => _client.delete('$bannersPath/$id');

  /// Publishes (true) or unpublishes (false); the dates decide whether a
  /// published banner is live or scheduled.
  Future<JsonMap> setPublished(String id, {required bool published}) async =>
      (await _client.post(
        '$bannersPath/$id/active',
        body: <String, Object?>{'active': published},
      )).decodeObject((json) => json);

  /// A draft copy of the banner, with its own copy of the images.
  Future<JsonMap> duplicate(String id) async => (await _client.post(
    '$bannersPath/$id/duplicate',
    body: const <String, Object?>{},
  )).decodeObject((json) => json);

  Future<JsonMap> archive(String id) async => (await _client.post(
    '$bannersPath/$id/archive',
    body: const <String, Object?>{},
  )).decodeObject((json) => json);

  Future<JsonMap> unarchive(String id) async => (await _client.post(
    '$bannersPath/$id/unarchive',
    body: const <String, Object?>{},
  )).decodeObject((json) => json);

  /// Moves a banner one place earlier (`up`) or later (`down`).
  Future<void> move(String id, {required bool up}) async {
    await _client.patch(
      '$bannersPath/order',
      body: <String, Object?>{'id': id, 'direction': up ? 'up' : 'down'},
    );
  }

  /// Uploads one of the banner's images and returns the banner with its new
  /// address.
  Future<JsonMap> uploadImage(
    String id,
    BannerImageVariant variant, {
    required Uint8List bytes,
    required String filename,
  }) async {
    final extension = filename.split('.').last.toLowerCase();
    final response = await _client.postForm(
      '$bannersPath/$id/image?variant=${variant.name}',
      FormData.fromMap(<String, Object?>{
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType(
            'image',
            bannerImageTypes[extension] ?? 'jpeg',
          ),
        ),
      }),
    );
    return response.decodeObject((json) => json);
  }

  /// Removes one of the banner's uploaded images; returns the banner.
  Future<JsonMap> deleteImage(String id, BannerImageVariant variant) async =>
      (await _client.delete(
        '$bannersPath/$id/image?variant=${variant.name}',
      )).decodeObject((json) => json);

  /// The address of one of the banner's images, or null when it has none.
  /// The backend gives either an absolute https address or a path below
  /// `/api/v1` (its public image endpoint).
  Uri? imageUriOf(
    JsonMap banner, [
    BannerImageVariant variant = BannerImageVariant.mobile,
  ]) {
    final value = banner[variant.urlKey] as String?;
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return null;
    if (uri.hasScheme) return uri;
    final relative = value.trim().replaceFirst(RegExp('^/+'), '');
    return _apiV1Url.resolve(relative);
  }
}

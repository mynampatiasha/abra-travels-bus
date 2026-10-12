import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/failure_text.dart';
import '../../core/format.dart';
import '../../l10n/admin_strings.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/widgets/catalogue_common.dart';
import '../catalogue/widgets/import_dialog.dart';
import '../catalogue/widgets/resource_form.dart';
import '../catalogue/widgets/resource_page.dart';
import 'admin_banners_api.dart';

/// Banners: the cards customers see sliding on the Home screen of the app.
///
/// `banners.manage` opens the page and allows everything except deleting
/// (add, edit, enable/disable, upload an image, import, export);
/// `banners.delete` adds Delete. The backend enforces the same rules.
class AdminBannersPage extends ConsumerWidget {
  const AdminBannersPage({super.key});

  static const _fields = <FieldSpec>[
    TextSpec('title', AdminStrings.fieldTitle, isRequired: true),
    TextSpec(
      'subtitle',
      AdminStrings.fieldSubtitle,
      maxLines: 2,
      clearable: true,
    ),
    TextSpec(
      'buttonText',
      AdminStrings.fieldButtonText,
      clearable: true,
      helpKey: AdminStrings.bannerButtonHelp,
    ),
    ChoiceSpec(
      'linkType',
      AdminStrings.fieldLinkType,
      BannerLabels.linkTypeChoices,
      isRequired: true,
    ),
    TextSpec(
      'linkValue',
      AdminStrings.fieldLinkValue,
      clearable: true,
      helpKeyOf: bannerLinkHintOf,
    ),
    ChoiceSpec(
      'placement',
      AdminStrings.fieldPlacement,
      BannerLabels.placements,
      isRequired: true,
    ),
    ChoiceSpec(
      'language',
      AdminStrings.fieldLanguage,
      BannerLabels.languages,
      isRequired: true,
    ),
    DateSpec('startsAt', AdminStrings.fieldStartDate),
    DateSpec('endsAt', AdminStrings.fieldEndDate),
    NumberSpec('sortOrder', AdminStrings.fieldSortOrder),
    BoolSpec('isActive', AdminStrings.fieldActive),
    TextSpec('externalImageUrl', AdminStrings.fieldImageUrl, clearable: true),
    TextSpec(
      'externalDesktopImageUrl',
      AdminStrings.fieldDesktopImageUrl,
      clearable: true,
    ),
  ];

  static const _newBanner = <String, Object?>{
    'linkType': 'NONE',
    'placement': 'HOME_TOP',
    'language': 'ALL',
    'sortOrder': 0,
    'isActive': true,
  };

  static Widget _nothing(BuildContext context, JsonMap record) =>
      const SizedBox.shrink();

  /// A column that is only written to the export.
  static ColumnSpec _exported(String labelKey, String Function(JsonMap) text) =>
      ColumnSpec(labelKey, _nothing, text: text, exportOnly: true);

  /// Edit form values from a banner: the form's fields only.
  static JsonMap _formValuesOf(JsonMap banner) => <String, Object?>{
    for (final field in _fields)
      if (banner[field.key] != null) field.key: banner[field.key],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final canManage = access.can(PermissionKeys.bannersManage);
    final canDelete = access.can(PermissionKeys.bannersDelete);
    final api = ref.read(bannersApiProvider);

    /// The add, edit and images forms: the fields (none for the images
    /// form), both images and the preview. Save writes the banner, then
    /// uploads or removes the images; an image that fails stays in the form
    /// with its reason, and saving again retries it.
    Future<bool> openForm(
      BuildContext context, {
      JsonMap? banner,
      bool imagesOnly = false,
    }) async {
      final images = BannerImagesController(api, banner);
      var current = banner;
      final saved = await showResourceForm(
        context,
        title: l10n.text(
          imagesOnly
              ? AdminStrings.bannerUploadTitle
              : banner == null
              ? AdminStrings.bannerCreateTitle
              : AdminStrings.bannerEditTitle,
        ),
        fields: imagesOnly ? const <FieldSpec>[] : _fields,
        initial: banner == null ? _newBanner : _formValuesOf(banner),
        extra: (context, values, isSaving) => BannerFormExtra(
          images: images,
          values: <String, Object?>{...?current, ...values},
          enabled: !isSaving,
        ),
        onSubmit: (values) async {
          final before = current;
          if (!imagesOnly) {
            current = before == null
                ? await api.create(values)
                : await api.update('${before['id']}', values);
          }
          if (!await images.save(current!)) {
            throw ResourceFormMessage(
              l10n.text(AdminStrings.bannerImagesPartlySaved),
            );
          }
        },
      );
      // A banner created before an image failed is in the list even when
      // the form is then closed.
      return saved || (banner == null && current != null);
    }

    Future<bool> delete(BuildContext context, JsonMap banner) async {
      final messenger = ScaffoldMessenger.of(context);
      final confirmed = await showAbraConfirmDialog(
        context,
        title: l10n.text(AdminStrings.bannerDeleteTitle, <String, Object?>{
          'name': bannerTitleOf(banner),
        }),
        message: l10n.text(AdminStrings.bannerDeleteMessage),
        confirmLabel: l10n.text(AdminStrings.actionDelete),
        isDestructive: true,
      );
      if (!confirmed) return false;
      await api.delete('${banner['id']}');
      // Every page and summary card of the list.
      ref.invalidate(resourceListProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.text(AdminStrings.bannerDeleted))),
      );
      return false;
    }

    String statusText(JsonMap r) =>
        BannerLabels.of(l10n, BannerLabels.statuses, r['status']);

    return ResourcePage(
      path: bannersPath,
      exportName: canManage ? 'banners' : null,
      stats: const <StatSpec>[
        StatSpec(
          AdminStrings.bannerStatusLive,
          <String, String>{'status': 'LIVE'},
          Icons.play_circle_outline,
          AbraColors.tealDark,
        ),
        StatSpec(
          AdminStrings.bannerStatusScheduled,
          <String, String>{'status': 'SCHEDULED'},
          Icons.schedule,
          AbraColors.blue,
        ),
        StatSpec(
          AdminStrings.bannerStatusExpired,
          <String, String>{'status': 'EXPIRED'},
          Icons.history,
          AbraColors.textSecondary,
        ),
        StatSpec(
          AdminStrings.statusInactive,
          <String, String>{'status': 'INACTIVE'},
          Icons.pause_circle_outline,
          AbraColors.navySecondary,
        ),
      ],
      filters: const <FilterSpec>[
        SearchFilter('search', AdminStrings.bannerSearch),
        ChoiceFilter('status', AdminStrings.fieldStatus, BannerLabels.statuses),
        ChoiceFilter(
          'placement',
          AdminStrings.fieldPlacement,
          BannerLabels.placements,
        ),
        ChoiceFilter(
          'language',
          AdminStrings.fieldLanguage,
          BannerLabels.languages,
        ),
        DateRangeFilter('from', AdminStrings.fieldCreated, toParam: 'to'),
      ],
      importSpec: canManage
          ? ImportSpec(
              name: 'banners',
              fields: _fields,
              sampleRow: const <String>[
                'Diwali sale',
                'Up to 25% off on every route',
                'Book now',
                'OFFER',
                'DIWALI25',
                'HOME_TOP',
                'ALL',
                '2026-10-12',
                '2026-10-31',
                '1',
                'yes',
                '',
                '',
              ],
              save: api.create,
            )
          : null,
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.fieldImage,
          (_, r) => BannerThumbnail(
            imageUri: api.imageUriOf(r),
            hasDesktopImage:
                api.imageUriOf(r, BannerImageVariant.desktop) != null,
          ),
        ),
        ColumnSpec(
          AdminStrings.fieldTitle,
          (context, r) => _TitleCell(banner: r),
          text: (r) => plainText(r['title']),
        ),
        _exported(AdminStrings.fieldSubtitle, (r) => plainText(r['subtitle'])),
        _exported(
          AdminStrings.fieldButtonText,
          (r) => plainText(r['buttonText']),
        ),
        _exported(
          AdminStrings.fieldLinkType,
          (r) => BannerLabels.of(l10n, BannerLabels.linkTypes, r['linkType']),
        ),
        _exported(
          AdminStrings.fieldLinkValue,
          (r) => plainText(r['linkValue']),
        ),
        ColumnSpec(
          AdminStrings.fieldPlacement,
          (_, r) => Text(
            BannerLabels.of(l10n, BannerLabels.placements, r['placement']),
          ),
          text: (r) =>
              BannerLabels.of(l10n, BannerLabels.placements, r['placement']),
        ),
        ColumnSpec(
          AdminStrings.fieldLanguage,
          (_, r) => Text(
            BannerLabels.of(l10n, BannerLabels.languages, r['language']),
          ),
          text: (r) =>
              BannerLabels.of(l10n, BannerLabels.languages, r['language']),
        ),
        ColumnSpec(
          AdminStrings.fieldSchedule,
          (_, r) => Text(bannerScheduleOf(l10n, r)),
        ),
        _exported(
          AdminStrings.fieldStartDate,
          (r) => bannerDayOf(r['startsAt']),
        ),
        _exported(AdminStrings.fieldEndDate, (r) => bannerDayOf(r['endsAt'])),
        ColumnSpec(
          AdminStrings.fieldSortOrder,
          (_, r) => textCell(r['sortOrder']),
          isNumeric: true,
          text: (r) => plainText(r['sortOrder']),
        ),
        ColumnSpec(
          AdminStrings.fieldStatus,
          (_, r) => BannerStatusBadge(status: '${r['status']}'),
          text: statusText,
        ),
        _exported(
          AdminStrings.exportImageUrl,
          (r) => api.imageUriOf(r)?.toString() ?? '',
        ),
        _exported(
          AdminStrings.exportDesktopImageUrl,
          (r) =>
              api.imageUriOf(r, BannerImageVariant.desktop)?.toString() ?? '',
        ),
      ],
      onCreate: canManage ? openForm : null,
      rowActions: canManage || canDelete
          ? (record) => <RowAction>[
              RowAction(AdminStrings.actionPreview, Icons.visibility_outlined, (
                context,
                record,
              ) async {
                await showBannerPreviewDialog(context, api, record);
                return false;
              }),
              if (canManage) ...<RowAction>[
                RowAction(
                  AdminStrings.actionEdit,
                  Icons.edit_outlined,
                  (context, record) => openForm(context, banner: record),
                ),
                RowAction(
                  AdminStrings.actionUploadImage,
                  Icons.add_photo_alternate_outlined,
                  (context, record) =>
                      openForm(context, banner: record, imagesOnly: true),
                ),
                activeToggleAction(
                  ref,
                  bannersPath,
                  record,
                  labelOf: bannerTitleOf,
                ),
              ],
              if (canDelete)
                RowAction(
                  AdminStrings.actionDelete,
                  Icons.delete_outline,
                  delete,
                ),
            ]
          : null,
    );
  }
}

/// Title, with the subtitle under it.
class _TitleCell extends StatelessWidget {
  const _TitleCell({required this.banner});

  final JsonMap banner;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = banner['subtitle'] as String?;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            bannerTitleOf(banner),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: AbraColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// A banner status as a badge: Live teal, Scheduled blue, Expired grey,
/// Inactive navy. The word is always shown; colour only supports it.
class BannerStatusBadge extends StatelessWidget {
  const BannerStatusBadge({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      'LIVE' => (AbraColors.tealContainer, AbraColors.tealDark),
      'SCHEDULED' => (AbraColors.blueContainer, AbraColors.blueDark),
      'EXPIRED' => (AbraColors.lightGray, AbraColors.textSecondary),
      _ => (AbraColors.navyContainer, AbraColors.navySecondary),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AbraRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AbraSpacing.md,
          vertical: AbraSpacing.xs,
        ),
        child: Text(
          BannerLabels.of(
            AbraLocalizations.of(context),
            BannerLabels.statuses,
            status,
          ),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The banner's mobile image in the table (64×36, or a placeholder), with a
/// "Desktop" chip when it also has a desktop image.
class BannerThumbnail extends StatelessWidget {
  const BannerThumbnail({
    required this.imageUri,
    this.hasDesktopImage = false,
    super.key,
  });

  final Uri? imageUri;
  final bool hasDesktopImage;

  @override
  Widget build(BuildContext context) {
    Widget placeholder(IconData icon) => Semantics(
      label: AbraLocalizations.of(context).text(AdminStrings.bannerNoImage),
      child: ColoredBox(
        color: AbraColors.lightGray,
        child: Center(
          child: Icon(icon, size: 18, color: AbraColors.textDisabled),
        ),
      ),
    );
    final uri = imageUri;
    final thumbnail = ClipRRect(
      borderRadius: AbraRadius.small,
      child: SizedBox(
        width: 64,
        height: 36,
        child: uri == null
            ? placeholder(Icons.image_outlined)
            : Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) =>
                    placeholder(Icons.broken_image_outlined),
              ),
      ),
    );
    if (!hasDesktopImage) return thumbnail;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        thumbnail,
        const SizedBox(width: AbraSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AbraColors.blueContainer,
            borderRadius: BorderRadius.circular(AbraRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AbraSpacing.sm,
              vertical: AbraSpacing.xxs,
            ),
            child: Text(
              AbraLocalizations.of(
                context,
              ).text(AdminStrings.bannerDesktopChip),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AbraColors.blueDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Picks an image file (name and bytes). Tests replace it; the browser's file
/// chooser is used otherwise.
@visibleForTesting
Future<(String, Uint8List)?> Function() pickBannerImage = _pickWithBrowser;

Future<(String, Uint8List)?> _pickWithBrowser() async {
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: bannerImageTypes.keys.toList(),
    withData: true,
  );
  final file = picked?.files.single;
  final bytes = file?.bytes;
  return file == null || bytes == null ? null : (file.name, bytes);
}

/// What is chosen for one image of the banner in the open form.
class BannerImageSlot {
  /// A file waiting to be uploaded on Save.
  Uint8List? bytes;
  String? fileName;

  /// The uploaded image is removed on Save.
  bool remove = false;

  /// Why the last chosen file was refused (message key and values).
  (String, Map<String, Object?>)? problem;

  /// Size of the waiting file when its shape is far from the recommended one.
  (int, int)? farFromRatio;

  /// Why the last upload or removal failed.
  Object? saveError;
}

/// The two images of a banner while its form is open: files chosen but not
/// yet uploaded, removals, and what went wrong per image. Nothing is sent
/// until [save]; a file that fails to upload stays here for the next try.
class BannerImagesController extends ChangeNotifier {
  BannerImagesController(this.api, this.banner);

  final BannersApi api;

  /// The banner as the server last returned it; null before it is created.
  JsonMap? banner;

  final Map<BannerImageVariant, BannerImageSlot> slots = {
    for (final variant in BannerImageVariant.values) variant: BannerImageSlot(),
  };

  bool _hasUploaded(BannerImageVariant variant) =>
      banner != null && api.imageUriOf(banner!, variant) != null;

  /// The image shown for [variant]: the waiting file, else the uploaded one.
  ImageProvider? imageOf(BannerImageVariant variant) {
    final slot = slots[variant]!;
    if (slot.bytes != null) return MemoryImage(slot.bytes!);
    if (slot.remove || banner == null) return null;
    final uri = api.imageUriOf(banner!, variant);
    return uri == null ? null : NetworkImage(uri.toString());
  }

  bool hasImage(BannerImageVariant variant) =>
      slots[variant]!.bytes != null ||
      (!slots[variant]!.remove && _hasUploaded(variant));

  /// Checks a chosen file. A refused file leaves what was there before.
  void choose(BannerImageVariant variant, String name, Uint8List bytes) {
    final slot = slots[variant]!;
    final problem = bannerImageProblem(name, bytes.length);
    slot
      ..problem = problem
      ..saveError = null;
    if (problem == null) {
      final size = bannerImageSizeOf(bytes);
      slot
        ..bytes = bytes
        ..fileName = name
        ..remove = false
        ..farFromRatio = size != null && variant.isFarFrom(size.$1, size.$2)
            ? size
            : null;
    }
    notifyListeners();
  }

  /// Drops the waiting file, or marks the uploaded image for removal.
  void removeImage(BannerImageVariant variant) {
    final slot = slots[variant]!;
    if (slot.bytes != null) {
      slot
        ..bytes = null
        ..fileName = null
        ..farFromRatio = null;
    } else if (_hasUploaded(variant)) {
      slot.remove = true;
    }
    slot
      ..problem = null
      ..saveError = null;
    notifyListeners();
  }

  /// Uploads the waiting files and makes the removals for [saved] (the
  /// banner just written). True when every one succeeded.
  Future<bool> save(JsonMap saved) async {
    banner = <String, Object?>{...?banner, ...saved};
    final id = '${banner!['id']}';
    var allDone = true;
    for (final variant in BannerImageVariant.values) {
      final slot = slots[variant]!;
      try {
        if (slot.bytes != null) {
          banner = await api.uploadImage(
            id,
            variant,
            bytes: slot.bytes!,
            filename: slot.fileName ?? 'banner.jpg',
          );
          slot
            ..bytes = null
            ..fileName = null
            ..farFromRatio = null;
        } else if (slot.remove) {
          if (_hasUploaded(variant)) {
            banner = await api.deleteImage(id, variant);
          }
          slot.remove = false;
        }
        slot.saveError = null;
      } on Object catch (error) {
        slot.saveError = error;
        allDone = false;
      }
    }
    notifyListeners();
    return allDone;
  }
}

/// Below the banner fields: both images and the preview on each device.
class BannerFormExtra extends StatelessWidget {
  const BannerFormExtra({
    required this.images,
    required this.values,
    required this.enabled,
    super.key,
  });

  final BannerImagesController images;

  /// The banner as typed so far.
  final JsonMap values;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: images,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Divider(),
          const SizedBox(height: AbraSpacing.sm),
          Text(
            l10n.text(AdminStrings.bannerImagesTitle),
            style: textTheme.titleMedium,
          ),
          Text(
            '${l10n.text(AdminStrings.bannerUploadIntro)} '
            '${l10n.text(AdminStrings.bannerImageSafeArea)}',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AbraSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final slots = <Widget>[
                for (final variant in BannerImageVariant.values)
                  _ImageSlotCard(
                    images: images,
                    variant: variant,
                    enabled: enabled,
                  ),
              ];
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    slots.first,
                    const SizedBox(height: AbraSpacing.lg),
                    slots.last,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: slots.first),
                  const SizedBox(width: AbraSpacing.lg),
                  Expanded(child: slots.last),
                ],
              );
            },
          ),
          const SizedBox(height: AbraSpacing.lg),
          Text(
            l10n.text(AdminStrings.bannerPreviewTitle),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AbraSpacing.sm),
          BannerResponsivePreview(
            banner: values,
            mobileImage: images.imageOf(BannerImageVariant.mobile),
            desktopImage: images.imageOf(BannerImageVariant.desktop),
          ),
        ],
      ),
    );
  }
}

/// One image: its recommended size, a thumbnail of that shape with the safe
/// area, what will happen on Save, and choose/replace/remove.
class _ImageSlotCard extends StatelessWidget {
  const _ImageSlotCard({
    required this.images,
    required this.variant,
    required this.enabled,
  });

  final BannerImagesController images;
  final BannerImageVariant variant;
  final bool enabled;

  Future<void> _choose() async {
    final picked = await pickBannerImage();
    if (picked != null) images.choose(variant, picked.$1, picked.$2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final slot = images.slots[variant]!;
    final image = images.imageOf(variant);
    final hasImage = images.hasImage(variant);
    final label = l10n.text(variant.labelKey);

    Widget note(String text, Color color, IconData icon) => Padding(
      padding: const EdgeInsets.only(top: AbraSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AbraSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );

    final placeholder = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.image_outlined, color: AbraColors.textDisabled),
          Text(
            l10n.text(AdminStrings.bannerNoImage),
            style: textTheme.bodySmall?.copyWith(
              color: AbraColors.textDisabled,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: textTheme.titleSmall),
          Text(
            l10n.text(variant.hintKey),
            style: textTheme.bodySmall?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
          const SizedBox(height: AbraSpacing.sm),
          AspectRatio(
            aspectRatio: variant.ratio,
            child: ClipRRect(
              borderRadius: AbraRadius.medium,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(
                    color: AbraColors.lightGray,
                    child: image == null ? placeholder : null,
                  ),
                  if (image != null)
                    Image(
                      image: image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, _) => placeholder,
                    ),
                  const CustomPaint(painter: _SafeAreaPainter()),
                ],
              ),
            ),
          ),
          if (slot.bytes != null)
            note(
              l10n.text(AdminStrings.bannerImagePending, <String, Object?>{
                'name': slot.fileName ?? '',
                'size': sizeOf(slot.bytes!.length),
              }),
              AbraColors.blueDark,
              Icons.cloud_upload_outlined,
            ),
          if (slot.remove)
            note(
              l10n.text(AdminStrings.bannerImageWillRemove),
              AbraColors.textSecondary,
              Icons.delete_outline,
            ),
          if (slot.farFromRatio case (final width, final height))
            note(
              l10n.text(AdminStrings.bannerImageRatioWarning, <String, Object?>{
                'width': width,
                'height': height,
                'ratio': variant.ratioText,
              }),
              AbraColors.orangeDark,
              Icons.warning_amber_outlined,
            ),
          if (slot.problem case (final key, final args))
            note(l10n.text(key, args), AbraColors.danger, Icons.error_outline),
          if (slot.saveError != null)
            note(
              l10n.text(AdminStrings.bannerImageUploadFailed, <String, Object?>{
                'reason': failureText(l10n, slot.saveError!),
              }),
              AbraColors.danger,
              Icons.error_outline,
            ),
          const SizedBox(height: AbraSpacing.sm),
          Wrap(
            spacing: AbraSpacing.sm,
            runSpacing: AbraSpacing.xs,
            children: <Widget>[
              AbraButton(
                label: l10n.text(
                  hasImage
                      ? AdminStrings.bannerImageReplace
                      : AdminStrings.bannerUploadChoose,
                ),
                icon: Icons.add_photo_alternate_outlined,
                variant: AbraButtonVariant.secondary,
                onPressed: enabled ? _choose : null,
              ),
              if (hasImage)
                AbraButton(
                  label: l10n.text(AdminStrings.bannerImageRemove),
                  icon: Icons.delete_outline,
                  variant: AbraButtonVariant.text,
                  onPressed: enabled ? () => images.removeImage(variant) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A dashed frame over a thumbnail: what stays visible on every screen.
class _SafeAreaPainter extends CustomPainter {
  const _SafeAreaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      size.width * 0.08,
      size.height * 0.12,
      size.width * 0.92,
      size.height * 0.88,
    );
    final paint = Paint()
      ..color = AbraColors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final shadow = Paint()
      ..color = AbraColors.navy.withValues(alpha: 0.5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 4.0;
    void dashed(Offset from, Offset to) {
      final length = (to - from).distance;
      final step = (to - from) / length;
      for (var at = 0.0; at < length; at += dash + gap) {
        final end = at + dash > length ? length : at + dash;
        final a = from + step * at;
        final b = from + step * end;
        canvas
          ..drawLine(a, b, shadow)
          ..drawLine(a, b, paint);
      }
    }

    dashed(rect.topLeft, rect.topRight);
    dashed(rect.topRight, rect.bottomRight);
    dashed(rect.bottomRight, rect.bottomLeft);
    dashed(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(_SafeAreaPainter oldDelegate) => false;
}

/// The device a preview is shown for.
enum BannerDevice { phone, tablet, desktop }

/// The banner on a phone, a tablet or a desktop, chosen with a toggle: on a
/// phone full width at 16:7 with the mobile image; wider at 4:1 with the
/// desktop image (or the mobile one when there is none), at most 1200 px.
class BannerResponsivePreview extends StatefulWidget {
  const BannerResponsivePreview({
    required this.banner,
    this.mobileImage,
    this.desktopImage,
    super.key,
  });

  final JsonMap banner;
  final ImageProvider? mobileImage;
  final ImageProvider? desktopImage;

  @override
  State<BannerResponsivePreview> createState() =>
      _BannerResponsivePreviewState();
}

class _BannerResponsivePreviewState extends State<BannerResponsivePreview> {
  var _device = BannerDevice.phone;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final banner = widget.banner;
    final hasLink = (banner['linkType'] ?? 'NONE') != 'NONE';
    final isPhone = _device == BannerDevice.phone;
    final preview = BannerPreview(
      title: bannerTitleOf(banner),
      subtitle: banner['subtitle'] as String?,
      buttonText: hasLink ? banner['buttonText'] as String? : null,
      image: isPhone
          ? widget.mobileImage
          : widget.desktopImage ?? widget.mobileImage,
      isWide: !isPhone,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SegmentedButton<BannerDevice>(
          showSelectedIcon: false,
          segments: <ButtonSegment<BannerDevice>>[
            ButtonSegment(
              value: BannerDevice.phone,
              icon: const Icon(Icons.smartphone_outlined),
              label: Text(l10n.text(AdminStrings.bannerPreviewPhone)),
            ),
            ButtonSegment(
              value: BannerDevice.tablet,
              icon: const Icon(Icons.tablet_outlined),
              label: Text(l10n.text(AdminStrings.bannerPreviewTablet)),
            ),
            ButtonSegment(
              value: BannerDevice.desktop,
              icon: const Icon(Icons.desktop_windows_outlined),
              label: Text(l10n.text(AdminStrings.bannerPreviewDesktop)),
            ),
          ],
          selected: <BannerDevice>{_device},
          onSelectionChanged: (selected) =>
              setState(() => _device = selected.single),
        ),
        const SizedBox(height: AbraSpacing.md),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: switch (_device) {
                BannerDevice.phone => 360,
                BannerDevice.tablet => 520,
                BannerDevice.desktop => 1200,
              },
            ),
            child: preview,
          ),
        ),
        const SizedBox(height: AbraSpacing.xs),
        Text(
          l10n.text(AdminStrings.bannerPreviewCaption),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// The banner as customers see it in the app: a rounded card (16:7 on a
/// phone, 4:1 wider), the image or the brand gradient, a dark shade for
/// readable text, the title and subtitle in white and the button as a white
/// pill.
class BannerPreview extends StatelessWidget {
  const BannerPreview({
    required this.title,
    this.subtitle,
    this.buttonText,
    this.image,
    this.isWide = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? buttonText;
  final ImageProvider? image;

  /// The tablet and desktop shape: 4:1, the button beside the text.
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    final buttonText = this.buttonText;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: isWide ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleLarge?.copyWith(
            color: AbraColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
          const SizedBox(height: AbraSpacing.xs),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(color: AbraColors.white),
          ),
        ],
      ],
    );
    final button = buttonText == null || buttonText.isEmpty
        ? null
        : DecoratedBox(
            decoration: BoxDecoration(
              color: AbraColors.white,
              borderRadius: BorderRadius.circular(AbraRadius.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AbraSpacing.lg,
                vertical: AbraSpacing.sm,
              ),
              child: Text(
                buttonText,
                maxLines: 1,
                style: textTheme.labelLarge?.copyWith(
                  color: AbraColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
    final content = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(child: text),
              if (button != null) ...<Widget>[
                const SizedBox(width: AbraSpacing.lg),
                button,
              ],
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              text,
              if (button != null) ...<Widget>[
                const SizedBox(height: AbraSpacing.md),
                button,
              ],
            ],
          );
    return AspectRatio(
      aspectRatio: isWide ? 4 : 16 / 7,
      child: ClipRRect(
        borderRadius: AbraRadius.large,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Also what shows while the image loads or when it cannot.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AbraColors.navy,
                    AbraColors.blue,
                    AbraColors.skyBlue,
                  ],
                ),
              ),
            ),
            if (image != null)
              Image(
                image: image!,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[Color(0xB3071E3D), Color(0x00071E3D)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AbraSpacing.lg),
              // Long text in a small card is scaled down, never cut off.
              child: LayoutBuilder(
                builder: (context, constraints) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.bottomStart,
                  child: SizedBox(width: constraints.maxWidth, child: content),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the banner as customers see it, on each device.
Future<void> showBannerPreviewDialog(
  BuildContext context,
  BannersApi api,
  JsonMap banner,
) => showDialog<void>(
  context: context,
  builder: (context) {
    final l10n = AbraLocalizations.of(context);
    ImageProvider? imageOf(BannerImageVariant variant) {
      final uri = api.imageUriOf(banner, variant);
      return uri == null ? null : NetworkImage(uri.toString());
    }

    return AlertDialog(
      title: Text(l10n.text(AdminStrings.bannerPreviewTitle)),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: BannerResponsivePreview(
            banner: banner,
            mobileImage: imageOf(BannerImageVariant.mobile),
            desktopImage: imageOf(BannerImageVariant.desktop),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.text(AbraStrings.commonClose)),
        ),
      ],
    );
  },
);

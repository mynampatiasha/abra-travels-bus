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
import '../catalogue/widgets/record_actions.dart';
import '../catalogue/widgets/resource_form.dart';
import '../catalogue/widgets/resource_page.dart';
import 'admin_banners_api.dart';

/// Banners: the cards customers see sliding on the Home screen of the app.
///
/// `banners.read` opens the page and the export; `banners.manage` adds
/// creating, editing, publishing, duplicating, archiving and moving up or
/// down; `banners.delete` adds Delete (with Undo). The backend enforces the
/// same rules. The page follows the demo: the same columns, buttons, form
/// and wording.
class AdminBannersPage extends ConsumerWidget {
  const AdminBannersPage({super.key});

  static bool _opensOffer(JsonMap values) =>
      (values['linkType'] ?? 'OFFER') == 'OFFER';
  static bool _opensRoute(JsonMap values) =>
      values['linkType'] == 'ROUTE_SEARCH';
  static bool _opensOperator(JsonMap values) =>
      values['linkType'] == 'OPERATOR';
  static bool _opensLink(JsonMap values) => values['linkType'] == 'URL';

  static const _fields = <FieldSpec>[
    TextSpec(
      'title',
      AdminStrings.fieldTitle,
      isRequired: true,
      fullWidth: true,
    ),
    TextSpec(
      'subtitle',
      AdminStrings.fieldSubtitle,
      clearable: true,
      fullWidth: true,
    ),
    ChoiceSpec(
      'colourStyle',
      AdminStrings.bnFieldColour,
      BannerLabels.colourStyles,
      isRequired: true,
    ),
    ChoiceSpec(
      'linkType',
      AdminStrings.bnFieldOpens,
      BannerLabels.opens,
      isRequired: true,
    ),
    TextSpec(
      'offerCode',
      AdminStrings.bnFieldOfferCode,
      visibleWhen: _opensOffer,
    ),
    RefSpec(
      'routeFrom',
      AdminStrings.bnFieldRouteFrom,
      'cities?active=true',
      nameOf,
      isRequired: true,
      visibleWhen: _opensRoute,
    ),
    RefSpec(
      'routeTo',
      AdminStrings.bnFieldRouteTo,
      'cities?active=true',
      nameOf,
      isRequired: true,
      visibleWhen: _opensRoute,
    ),
    RefSpec(
      'operatorId',
      AdminStrings.bnFieldOperator,
      'operators',
      operatorNameOf,
      isRequired: true,
      fullWidth: true,
      visibleWhen: _opensOperator,
    ),
    TextSpec(
      'linkUrl',
      AdminStrings.bnFieldLink,
      isRequired: true,
      fullWidth: true,
      visibleWhen: _opensLink,
    ),
    ChoiceSpec(
      'audience',
      AdminStrings.bnFieldShownTo,
      BannerLabels.audiences,
      isRequired: true,
    ),
    DateSpec('startsAt', AdminStrings.bnFieldStarts),
    DateSpec('endsAt', AdminStrings.bnFieldEnds),
    NumberSpec('sortOrder', AdminStrings.bnFieldOrder),
  ];

  /// The form fields that are sent as they are.
  static const _plainKeys = <String>[
    'title',
    'subtitle',
    'colourStyle',
    'audience',
    'startsAt',
    'endsAt',
    'sortOrder',
  ];

  /// What a new banner starts with (as in the demo: starts today, ends in two
  /// weeks, opens an offer, shown to everyone, order 5).
  static JsonMap _newBanner() {
    String day(DateTime time) => time.toIso8601String().substring(0, 10);
    final today = DateTime.now();
    return <String, Object?>{
      'colourStyle': 'NAVY_BLUE',
      'linkType': 'OFFER',
      'audience': 'ALL',
      'startsAt': day(today),
      'endsAt': day(today.add(const Duration(days: 14))),
      'sortOrder': 5,
    };
  }

  /// The form's values for an existing banner: the link value goes to the
  /// field of its kind.
  static JsonMap _formValuesOf(JsonMap banner) {
    final type = '${banner['linkType']}';
    final value = '${banner['linkValue'] ?? ''}';
    final route = type == 'ROUTE_SEARCH' ? value.split(':') : const <String>[];
    return <String, Object?>{
      for (final key in _plainKeys)
        if (banner[key] != null) key: banner[key],
      // A banner that links nowhere (or to a screen) is shown as "An offer"
      // without a code, like the demo.
      'linkType': BannerLabels.opens.containsKey(type) ? type : 'OFFER',
      'offerCode': type == 'OFFER' ? value : '',
      'routeFrom': route.length == 2 ? route.first : '',
      'routeTo': route.length == 2 ? route.last : '',
      'operatorId': type == 'OPERATOR' ? value : '',
      'linkUrl': type == 'URL' ? value : '',
    };
  }

  /// The request body for the form's [values]: the link fields become one
  /// link, and [published] decides draft or published.
  static JsonMap _bodyOf(JsonMap values, {required bool published}) {
    final type = '${values['linkType'] ?? 'OFFER'}';
    var linkType = type;
    var linkValue = '';
    switch (type) {
      case 'OFFER':
        linkValue = '${values['offerCode'] ?? ''}'.trim();
        if (linkValue.isEmpty) linkType = 'NONE';
      case 'ROUTE_SEARCH':
        linkValue = '${values['routeFrom']}:${values['routeTo']}';
      case 'OPERATOR':
        linkValue = '${values['operatorId']}';
      case 'URL':
        linkValue = '${values['linkUrl'] ?? ''}'.trim();
    }
    return <String, Object?>{
      for (final key in _plainKeys)
        if (values.containsKey(key)) key: values[key],
      'linkType': linkType,
      'linkValue': linkValue,
      'isActive': published,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final canManage = access.can(PermissionKeys.bannersManage);
    final canDelete = access.can(PermissionKeys.bannersDelete);
    final canExport = access.can(PermissionKeys.bannersExport);
    final api = ref.read(bannersApiProvider);
    final repository = ref.read(catalogueRepositoryProvider);

    void toast(String text) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));

    void reload() => ref.invalidate(resourceListProvider);

    /// The New and Edit form: Cancel, Save draft and Publish. Both buttons
    /// save the banner, then upload or remove the pictures; a picture that
    /// fails stays in the form with its reason, and saving again retries it.
    Future<bool> openForm(BuildContext context, {JsonMap? banner}) async {
      final images = BannerImagesController(api, banner);
      var current = banner;
      var outcome = '';

      Future<void> save(JsonMap values, {required bool published}) async {
        final start = '${values['startsAt'] ?? ''}';
        final end = '${values['endsAt'] ?? ''}';
        if (start.isNotEmpty && end.isNotEmpty && end.compareTo(start) < 0) {
          throw ResourceFormMessage(l10n.text(AdminStrings.bnEndBeforeStart));
        }
        final body = _bodyOf(values, published: published);
        final before = current;
        final saved = before == null
            ? await api.create(<String, Object?>{
                ...body,
                'placement': 'HOME_TOP',
                'language': 'ALL',
                'buttonText': body['linkType'] == 'OFFER'
                    ? l10n.text(AdminStrings.bnPreviewOfferButton)
                    : '',
              })
            : await api.update('${before['id']}', body);
        current = saved;
        outcome = !published
            ? 'DRAFT'
            : saved['status'] == 'SCHEDULED'
            ? 'SCHEDULED'
            : 'PUBLISHED';
        if (!await images.save(saved)) {
          throw ResourceFormMessage(
            l10n.text(AdminStrings.bannerImagesPartlySaved),
          );
        }
      }

      final saved = await showResourceForm(
        context,
        title: l10n.text(
          banner == null ? AdminStrings.bnNewTitle : AdminStrings.bnEditTitle,
        ),
        fields: _fields,
        initial: banner == null ? _newBanner() : _formValuesOf(banner),
        columns: 2,
        width: 920,
        submitLabel: l10n.text(AdminStrings.bnPublish),
        onSubmit: (values) => save(values, published: true),
        secondary: <FormAction>[
          FormAction(
            l10n.text(AdminStrings.bnSaveDraft),
            (values) => save(values, published: false),
          ),
        ],
        extra: (context, values, isSaving) =>
            BannerFormExtra(images: images, enabled: !isSaving),
        side: (context, values, isSaving) => ListenableBuilder(
          listenable: images,
          builder: (context, _) => BannerHomePreview(
            values: values,
            image: images.imageOf(BannerImageVariant.mobile),
          ),
        ),
      );
      if (saved) {
        toast(switch (outcome) {
          'SCHEDULED' => l10n.text(
            AdminStrings.bnToastScheduled,
            <String, Object?>{'date': bannerDayOf(current?['startsAt'])},
          ),
          'PUBLISHED' => l10n.text(AdminStrings.bnToastPublished),
          _ => l10n.text(AdminStrings.bnToastDraft),
        });
      }
      // A banner created before a picture failed is in the list even when
      // the form is then closed.
      return saved || (banner == null && current != null);
    }

    /// A button of a row: runs it, says what happened (with Undo when there
    /// is one) and reloads the list.
    RowAction action(
      String labelKey,
      IconData icon,
      Future<void> Function(JsonMap banner) run,
      String doneKey, {
      Future<void> Function(JsonMap banner)? undo,
    }) => RowAction(labelKey, icon, (context, banner) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await run(banner);
      } on Object catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text(failureText(l10n, error))),
        );
        return false;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.text(doneKey)),
          duration: deleteUndoTime,
          action: undo == null
              ? null
              : SnackBarAction(
                  label: l10n.text(AdminStrings.deleteUndo),
                  onPressed: () async {
                    await undo(banner);
                    reload();
                  },
                ),
        ),
      );
      return true;
    });

    String statusText(JsonMap r) =>
        BannerLabels.of(l10n, BannerLabels.statuses, r['status']);

    String opensText(JsonMap r) {
      final value = '${r['linkValue'] ?? ''}';
      return switch ('${r['linkType']}') {
        'OFFER' => l10n.text(AdminStrings.bnOpenOffer, <String, Object?>{
          'code': value,
        }),
        'ROUTE_SEARCH' => l10n.text(AdminStrings.bnOpenRoute),
        'OPERATOR' => l10n.text(AdminStrings.bnOpenOperator),
        'URL' => l10n.text(AdminStrings.bnOpenUrl),
        'SCREEN' => l10n.text(AdminStrings.bnOpenScreen),
        _ => l10n.text(AdminStrings.bnOpenNone),
      };
    }

    return ResourcePage(
      path: bannersPath,
      exportPath: canExport ? bannersPath : null,
      stats: const <StatSpec>[
        StatSpec(
          AdminStrings.bnStatusPublished,
          <String, String>{'status': 'LIVE'},
          Icons.play_circle_outline,
          AbraColors.tealDark,
        ),
        StatSpec(
          AdminStrings.bnStatusScheduled,
          <String, String>{'status': 'SCHEDULED'},
          Icons.schedule,
          AbraColors.blue,
        ),
        StatSpec(
          AdminStrings.bnStatusDraft,
          <String, String>{'status': 'INACTIVE'},
          Icons.edit_note,
          AbraColors.navySecondary,
        ),
        StatSpec(
          AdminStrings.bnStatusExpired,
          <String, String>{'status': 'EXPIRED'},
          Icons.history,
          AbraColors.textSecondary,
        ),
        StatSpec(
          AdminStrings.bnStatusArchived,
          <String, String>{'status': 'ARCHIVED'},
          Icons.inventory_2_outlined,
          AbraColors.textSecondary,
        ),
      ],
      filters: const <FilterSpec>[
        SearchFilter('search', AdminStrings.bannerSearch),
        ChoiceFilter('status', AdminStrings.bnColStatus, BannerLabels.statuses),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.bnColBanner,
          (context, r) => _TitleCell(banner: r),
          text: (r) => plainText(r['title']),
        ),
        ColumnSpec(
          AdminStrings.bnColStatus,
          (_, r) => BannerStatusBadge(status: '${r['status']}'),
          text: statusText,
        ),
        ColumnSpec(
          AdminStrings.bnColRuns,
          (_, r) => Text(bannerRunsOf(l10n, r)),
          text: (r) => bannerRunsOf(l10n, r),
        ),
        ColumnSpec(
          AdminStrings.bnColShownTo,
          (_, r) => Text(
            BannerLabels.of(l10n, BannerLabels.audiences, r['audience']),
          ),
          text: (r) =>
              BannerLabels.of(l10n, BannerLabels.audiences, r['audience']),
        ),
        ColumnSpec(
          AdminStrings.bnColOpens,
          (_, r) => Text(opensText(r)),
          text: opensText,
        ),
        ColumnSpec(
          AdminStrings.bnColOrder,
          (_, r) => Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('${r['sortOrder']}'),
              if (canManage && r['status'] != 'ARCHIVED') ...<Widget>[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: l10n.text(AdminStrings.bnMoveUp),
                  icon: const Icon(Icons.keyboard_arrow_up),
                  onPressed: () async {
                    await api.move('${r['id']}', up: true);
                    reload();
                  },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: l10n.text(AdminStrings.bnMoveDown),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () async {
                    await api.move('${r['id']}', up: false);
                    reload();
                  },
                ),
              ],
            ],
          ),
          isNumeric: true,
          text: (r) => plainText(r['sortOrder']),
        ),
      ],
      createLabelKey: AdminStrings.bnNew,
      onCreate: canManage ? (context) => openForm(context) : null,
      rowActions: canManage || canDelete
          ? (record) {
              final archived = record['status'] == 'ARCHIVED';
              final published = record['isActive'] == true;
              return <RowAction>[
                if (canManage && !archived) ...<RowAction>[
                  RowAction(
                    AdminStrings.actionEdit,
                    Icons.edit_outlined,
                    (context, record) => openForm(context, banner: record),
                  ),
                  if (published)
                    action(
                      AdminStrings.bnUnpublish,
                      Icons.visibility_off_outlined,
                      (b) => api.setPublished('${b['id']}', published: false),
                      AdminStrings.bnToastUnpublished,
                    )
                  else
                    action(
                      AdminStrings.bnPublish,
                      Icons.check_circle_outline,
                      (b) => api.setPublished('${b['id']}', published: true),
                      AdminStrings.bnToastPublished,
                    ),
                ],
                if (canManage)
                  action(
                    AdminStrings.bnDuplicate,
                    Icons.copy_outlined,
                    (b) => api.duplicate('${b['id']}'),
                    AdminStrings.bnToastDuplicated,
                  ),
                if (canManage && !archived)
                  action(
                    AdminStrings.bnArchive,
                    Icons.archive_outlined,
                    (b) => api.archive('${b['id']}'),
                    AdminStrings.bnToastArchived,
                    undo: (b) => api.unarchive('${b['id']}'),
                  ),
                if (canManage && archived)
                  action(
                    AdminStrings.bnUnarchive,
                    Icons.unarchive_outlined,
                    (b) => api.unarchive('${b['id']}'),
                    AdminStrings.bnToastUnarchived,
                  ),
                if (canDelete)
                  deleteAction(
                    repository: repository,
                    path: bannersPath,
                    nameOf: bannerTitleOf,
                  ),
              ];
            }
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

/// A banner status as a badge: Published teal, Scheduled blue, Expired and
/// Archived grey, Draft navy. The word is always shown; colour only supports it.
class BannerStatusBadge extends StatelessWidget {
  const BannerStatusBadge({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      'LIVE' => (AbraColors.tealContainer, AbraColors.tealDark),
      'SCHEDULED' => (AbraColors.blueContainer, AbraColors.blueDark),
      'EXPIRED' ||
      'ARCHIVED' => (AbraColors.lightGray, AbraColors.textSecondary),
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

/// Below the banner fields: the pictures (desktop and phone), as in the demo.
class BannerFormExtra extends StatelessWidget {
  const BannerFormExtra({
    required this.images,
    required this.enabled,
    super.key,
  });

  final BannerImagesController images;
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
            l10n.text(AdminStrings.bnPictures),
            style: textTheme.titleMedium,
          ),
          Text(
            l10n.text(AdminStrings.bnPictureHint),
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AbraSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              // Desktop first, then phone, as in the demo
              final slots = <Widget>[
                for (final variant in <BannerImageVariant>[
                  BannerImageVariant.desktop,
                  BannerImageVariant.mobile,
                ])
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
        ],
      ),
    );
  }
}

/// The banner as it looks on the customer app home screen, while it is typed
/// (the demo's "Customer app home" preview): the picture or the colour
/// style, the title and subtitle, a "View offer" button when it opens an
/// offer, and the carousel dots.
class BannerHomePreview extends StatelessWidget {
  const BannerHomePreview({required this.values, this.image, super.key});

  /// The form values as typed so far.
  final JsonMap values;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final opensOffer =
        (values['linkType'] ?? 'OFFER') == 'OFFER' &&
        '${values['offerCode'] ?? ''}'.trim().isNotEmpty;
    Widget dot({required bool active}) => Container(
      width: active ? 18 : 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: active ? AbraColors.blue : AbraColors.border,
        borderRadius: BorderRadius.circular(AbraRadius.pill),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.text(AdminStrings.bnPreviewHome),
          style: textTheme.bodySmall?.copyWith(color: AbraColors.textSecondary),
        ),
        const SizedBox(height: AbraSpacing.sm),
        BannerPreview(
          title: '${values['title'] ?? ''}'.trim().isEmpty
              ? 'Title'
              : '${values['title']}',
          subtitle: '${values['subtitle'] ?? ''}'.trim().isEmpty
              ? 'Subtitle'
              : '${values['subtitle']}',
          buttonText: opensOffer
              ? l10n.text(AdminStrings.bnPreviewOfferButton)
              : null,
          colourStyle: values['colourStyle'] as String?,
          image: image,
        ),
        const SizedBox(height: AbraSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            dot(active: true),
            dot(active: false),
            dot(active: false),
          ],
        ),
        const SizedBox(height: AbraSpacing.sm),
        Text(
          l10n.text(AdminStrings.bnPreviewCaption),
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),
      ],
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
      colourStyle: banner['colourStyle'] as String?,
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
    this.colourStyle,
    this.isWide = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? buttonText;
  final ImageProvider? image;

  /// `NAVY_BLUE` (the default), `BLUE_SKY` or `GREEN_NAVY`: the colours shown
  /// when there is no picture.
  final String? colourStyle;

  static List<Color> coloursOf(String? style) => switch (style) {
    'BLUE_SKY' => const <Color>[AbraColors.deepBlue, AbraColors.skyBlue],
    'GREEN_NAVY' => const <Color>[AbraColors.teal, AbraColors.navy],
    _ => const <Color>[AbraColors.navy, AbraColors.blue],
  };

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
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: coloursOf(colourStyle),
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

import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import 'responsive.dart';

/// How a sheet is presented on the current screen.
enum SheetPresentation {
  /// Phones: a modal bottom sheet.
  bottomSheet,

  /// Tablets and desktop: a centred dialog.
  dialog,

  /// Short screens (landscape phone, very small phones): a full-screen
  /// page, so nothing has to fit in half a screen.
  fullScreen,
}

SheetPresentation sheetPresentationOf(BuildContext context) {
  if (CustomerLayout.isShort(context)) return SheetPresentation.fullScreen;
  if (CustomerLayout.usesDialogs(context)) return SheetPresentation.dialog;
  return SheetPresentation.bottomSheet;
}

/// Shows [builder] as a bottom sheet on phones, a centred dialog on wide
/// screens and a full-screen page on short screens. Always above the app's
/// navigation (root navigator). Back, Escape, the close button and (for a
/// sheet or dialog) a tap outside close it with null.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  double maxWidth = CustomerLayout.dialogMaxWidth,
}) {
  final presentation = sheetPresentationOf(context);
  Widget wrap(BuildContext context) => _SheetPresentationScope(
    presentation: presentation,
    child: builder(context),
  );
  switch (presentation) {
    case SheetPresentation.bottomSheet:
      return showModalBottomSheet<T>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: isDismissible,
        enableDrag: isDismissible,
        showDragHandle: true,
        backgroundColor: AbraColors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AbraRadius.xl),
          ),
        ),
        builder: wrap,
      );
    case SheetPresentation.dialog:
      return showDialog<T>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: isDismissible,
        builder: (context) => Dialog(
          backgroundColor: AbraColors.white,
          insetPadding: const EdgeInsets.all(AbraSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AbraRadius.large),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: wrap(context),
          ),
        ),
      );
    case SheetPresentation.fullScreen:
      return Navigator.of(context, rootNavigator: true).push<T>(
        MaterialPageRoute<T>(
          fullscreenDialog: true,
          builder: (context) => Scaffold(
            backgroundColor: AbraColors.white,
            body: SafeArea(child: wrap(context)),
          ),
        ),
      );
  }
}

class _SheetPresentationScope extends InheritedWidget {
  const _SheetPresentationScope({
    required this.presentation,
    required super.child,
  });

  final SheetPresentation presentation;

  @override
  bool updateShouldNotify(_SheetPresentationScope oldWidget) =>
      presentation != oldWidget.presentation;
}

/// The layout inside an adaptive sheet: title with a close button, a
/// scrolling body and an optional footer that stays at the bottom (above
/// the keyboard).
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    required this.title,
    required this.body,
    this.footer,
    this.onClose,
    this.leading,
    super.key,
  });

  final String title;
  final Widget body;
  final Widget? footer;

  /// Defaults to closing the sheet.
  final VoidCallback? onClose;

  /// Before the title, for example a back button inside a two-step sheet.
  final Widget? leading;

  /// How the enclosing sheet is shown, or null outside [showAdaptiveSheet].
  static SheetPresentation? presentationOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_SheetPresentationScope>()
      ?.presentation;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final presentation = presentationOf(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final isBottomSheet = presentation == SheetPresentation.bottomSheet;
    final gutter = AbraResponsive.gutter(context);
    // A bottom sheet grows with its content up to 90 % of the screen.
    final maxHeight = presentation == SheetPresentation.fullScreen
        ? double.infinity
        : (media.size.height - keyboard) * 0.9;

    final content = Column(
      mainAxisSize: presentation == SheetPresentation.fullScreen
          ? MainAxisSize.max
          : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            leading == null ? gutter : AbraSpacing.xs,
            isBottomSheet ? 0 : AbraSpacing.sm,
            AbraSpacing.xs,
            0,
          ),
          child: Row(
            children: <Widget>[
              ?leading,
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.text(AbraStrings.commonClose),
                onPressed: onClose ?? () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Flexible(
          fit: presentation == SheetPresentation.fullScreen
              ? FlexFit.tight
              : FlexFit.loose,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              gutter,
              AbraSpacing.sm,
              gutter,
              AbraSpacing.lg,
            ),
            child: body,
          ),
        ),
        if (footer != null)
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AbraColors.white,
              border: Border(top: BorderSide(color: AbraColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  AbraSpacing.md,
                  gutter,
                  AbraSpacing.md,
                ),
                child: footer,
              ),
            ),
          ),
      ],
    );

    return Padding(
      // A bottom sheet moves up with the keyboard; dialogs and pages are
      // resized by their own route.
      padding: EdgeInsets.only(bottom: isBottomSheet ? keyboard : 0),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: content,
      ),
    );
  }
}

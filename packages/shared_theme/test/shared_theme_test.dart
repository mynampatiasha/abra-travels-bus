import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_theme/shared_theme.dart';

/// WCAG relative-luminance contrast ratio of two colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

Future<void> pumpAtWidth(
  WidgetTester tester,
  double width,
  Widget child,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AbraTheme.light(), home: child));
}

void main() {
  group('design tokens', () {
    test('brand colours match the specification', () {
      expect(AbraColors.navy, const Color(0xFF12304A));
      expect(AbraColors.blue, const Color(0xFF1677C8));
      expect(AbraColors.teal, const Color(0xFF1B8A5A));
      expect(AbraColors.orange, const Color(0xFFF28C28));
      expect(AbraColors.lightGray, const Color(0xFFF3F5F7));
      expect(AbraColors.white, const Color(0xFFFFFFFF));
    });

    test('spacing and radius scales increase', () {
      const spacing = [
        AbraSpacing.xxs,
        AbraSpacing.xs,
        AbraSpacing.sm,
        AbraSpacing.md,
        AbraSpacing.lg,
        AbraSpacing.xl,
        AbraSpacing.xxl,
        AbraSpacing.xxxl,
      ];
      const radius = [
        AbraRadius.sm,
        AbraRadius.md,
        AbraRadius.lg,
        AbraRadius.xl,
        AbraRadius.pill,
      ];
      for (final scale in [spacing, radius]) {
        for (var i = 1; i < scale.length; i++) {
          expect(scale[i], greaterThan(scale[i - 1]));
        }
      }
    });

    test('touch targets meet the 48 px accessibility minimum', () {
      expect(AbraSizes.minTouchTarget, greaterThanOrEqualTo(48));
      expect(
        AbraSizes.buttonHeight,
        greaterThanOrEqualTo(AbraSizes.minTouchTarget),
      );
    });
  });

  group('AbraTheme.light', () {
    final theme = AbraTheme.light();

    test('is Material 3 with the Abra colour roles', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, AbraColors.blue);
      expect(theme.colorScheme.secondary, AbraColors.navy);
      expect(theme.colorScheme.tertiary, AbraColors.orange);
      expect(theme.colorScheme.surface, AbraColors.white);
      expect(theme.scaffoldBackgroundColor, AbraColors.lightGray);
      expect(theme.appBarTheme.backgroundColor, AbraColors.navy);
    });

    test('text and its background meet WCAG AA contrast (4.5:1)', () {
      final scheme = theme.colorScheme;
      final pairs = <String, (Color, Color)>{
        'onPrimary/primary': (scheme.onPrimary, scheme.primary),
        'onSecondary/secondary': (scheme.onSecondary, scheme.secondary),
        'onTertiary/tertiary': (scheme.onTertiary, scheme.tertiary),
        'onError/error': (scheme.onError, scheme.error),
        'onSurface/surface': (scheme.onSurface, scheme.surface),
        'onSurfaceVariant/surface': (scheme.onSurfaceVariant, scheme.surface),
        'text/scaffold': (AbraColors.textPrimary, AbraColors.lightGray),
        'appBar': (AbraColors.white, AbraColors.navy),
      };
      pairs.forEach((name, pair) {
        expect(
          contrast(pair.$1, pair.$2),
          greaterThanOrEqualTo(4.5),
          reason: name,
        );
      });
    });

    test('status colours are readable on their containers', () {
      const status = AbraStatusColors.light;
      for (final tone in AbraStatusTone.values) {
        final pair = status.of(tone);
        expect(
          contrast(pair.foreground, pair.container),
          greaterThanOrEqualTo(4.5),
          reason: tone.name,
        );
      }
      expect(status.success.foreground, AbraColors.tealDark);
      expect(status.danger.foreground, AbraColors.danger);
    });

    test('buttons are at least 48 px high and inputs are outlined', () {
      final filled = theme.filledButtonTheme.style!.minimumSize!.resolve(
        <WidgetState>{},
      )!;
      final outlined = theme.outlinedButtonTheme.style!.minimumSize!.resolve(
        <WidgetState>{},
      )!;
      expect(filled.height, greaterThanOrEqualTo(48));
      expect(outlined.height, greaterThanOrEqualTo(48));
      expect(theme.inputDecorationTheme.border, isA<OutlineInputBorder>());
      expect(theme.inputDecorationTheme.filled, isTrue);
    });

    test('uses the given font family everywhere, or the platform font', () {
      expect(
        AbraTheme.light(
          fontFamily: 'NotoSans',
        ).textTheme.bodyMedium!.fontFamily,
        'NotoSans',
      );
      expect(
        theme.textTheme.bodyMedium!.fontFamily,
        ThemeData().textTheme.bodyMedium!.fontFamily,
      );
      expect(theme.textTheme.titleLarge!.fontWeight, FontWeight.w600);
    });

    test('status colours travel with the theme and can be interpolated', () {
      final extension = theme.extension<AbraStatusColors>()!;
      expect(extension.info.foreground, AbraColors.blueDark);
      expect(
        extension.lerp(extension, 0.5).success.foreground,
        AbraColors.tealDark,
      );
      expect(
        extension.copyWith().warning.container,
        AbraColors.orangeContainer,
      );
    });

    testWidgets(
      'AbraStatusColors.from falls back to light without the extension',
      (tester) async {
        late AbraStatusColors resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(),
            home: Builder(
              builder: (context) {
                resolved = AbraStatusColors.from(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(resolved, AbraStatusColors.light);
      },
    );
  });

  group('responsive foundation', () {
    test(
      'classifies widths: small phone, phone, large phone, tablet, desktop',
      () {
        expect(AbraBreakpoint.fromWidth(320), AbraBreakpoint.smallPhone);
        expect(AbraBreakpoint.fromWidth(359.9), AbraBreakpoint.smallPhone);
        expect(AbraBreakpoint.fromWidth(360), AbraBreakpoint.phone);
        expect(AbraBreakpoint.fromWidth(411), AbraBreakpoint.phone);
        expect(AbraBreakpoint.fromWidth(412), AbraBreakpoint.largePhone);
        expect(AbraBreakpoint.fromWidth(599), AbraBreakpoint.largePhone);
        expect(AbraBreakpoint.fromWidth(600), AbraBreakpoint.tablet);
        expect(AbraBreakpoint.fromWidth(1023), AbraBreakpoint.tablet);
        expect(AbraBreakpoint.fromWidth(1024), AbraBreakpoint.desktop);
        expect(AbraBreakpoint.fromWidth(2560), AbraBreakpoint.desktop);
        expect(AbraBreakpoint.largePhone.isPhone, isTrue);
        expect(AbraBreakpoint.tablet.isTabletOrWider, isTrue);
      },
    );

    test('ResponsiveValue falls back to the nearest smaller value', () {
      const columns = ResponsiveValue<int>(phone: 1, tablet: 2);
      expect(columns.resolve(AbraBreakpoint.smallPhone), 1);
      expect(columns.resolve(AbraBreakpoint.largePhone), 1);
      expect(columns.resolve(AbraBreakpoint.tablet), 2);
      expect(columns.resolve(AbraBreakpoint.desktop), 2);
      const all = ResponsiveValue<int>(
        smallPhone: 0,
        phone: 1,
        largePhone: 2,
        tablet: 3,
        desktop: 4,
      );
      expect(AbraBreakpoint.values.map(all.resolve), [0, 1, 2, 3, 4]);
    });

    test('page gutter grows with the width', () {
      final gutters = AbraBreakpoint.values
          .map(AbraResponsive.gutterFor)
          .toList();
      for (var i = 1; i < gutters.length; i++) {
        expect(gutters[i], greaterThanOrEqualTo(gutters[i - 1]));
      }
      expect(gutters.first, AbraSpacing.md);
      expect(gutters.last, AbraSpacing.xxl);
    });

    testWidgets('AbraPageContainer applies the gutter and caps the width', (
      tester,
    ) async {
      await pumpAtWidth(
        tester,
        1600,
        const Scaffold(
          body: AbraPageContainer(child: SizedBox.expand(key: Key('content'))),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('content'))).width,
        AbraSizes.maxContentWidth - 2 * AbraSpacing.xxl,
      );

      await pumpAtWidth(
        tester,
        360,
        const Scaffold(
          body: AbraPageContainer(child: SizedBox.expand(key: Key('content'))),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('content'))).width,
        360 - 2 * AbraSpacing.lg,
      );
    });

    testWidgets('AbraPageContainer keeps content out of system insets', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      tester.view.padding = const FakeViewPadding(top: 40, bottom: 20);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AbraTheme.light(),
          home: const Scaffold(
            body: AbraPageContainer(
              child: SizedBox.expand(key: Key('content')),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(const Key('content')));
      expect(rect.top, greaterThanOrEqualTo(40));
      expect(rect.bottom, lessThanOrEqualTo(800 - 20));
    });

    testWidgets(
      'AbraResponsiveBuilder reports the class of the available width',
      (tester) async {
        Future<AbraBreakpoint> at(double width) async {
          late AbraBreakpoint seen;
          await pumpAtWidth(
            tester,
            width,
            AbraResponsiveBuilder(
              builder: (context, breakpoint) {
                seen = breakpoint;
                return const SizedBox();
              },
            ),
          );
          return seen;
        }

        expect(await at(340), AbraBreakpoint.smallPhone);
        expect(await at(800), AbraBreakpoint.tablet);
        expect(await at(1280), AbraBreakpoint.desktop);
      },
    );
  });
}

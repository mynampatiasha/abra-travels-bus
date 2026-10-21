import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_theme/shared_theme.dart';

class HomePromoBanners extends StatelessWidget {
  const HomePromoBanners({super.key});

  static const _banners = <_BannerItem>[
    _BannerItem(
      title: 'Travel with family',
      sub: 'Save up to Rs 500 on 4+ seats',
      code: 'ABRA100',
      gradient: [Color(0xFF0B4EA2), Color(0xFF36BDF5)],
    ),
    _BannerItem(
      title: 'Festive special',
      sub: 'Flat 15% off on selected routes',
      code: 'WEEKEND15',
      gradient: [Color(0xFF12304A), Color(0xFF1677C8), Color(0xFF36BDF5)],
    ),
    _BannerItem(
      title: 'New routes',
      sub: 'Now serving Kochi',
      code: null,
      gradient: [Color(0xFF12304A), Color(0xFF1B8A5A)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.xs),
        itemCount: _banners.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final b = _banners[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (b.code != null) {
                Clipboard.setData(ClipboardData(text: b.code!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Offer code ${b.code} copied!'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              width: 270,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: b.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      b.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                    if (b.code != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          b.code!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BannerItem {
  const _BannerItem({
    required this.title,
    required this.sub,
    required this.code,
    required this.gradient,
  });

  final String title;
  final String sub;
  final String? code;
  final List<Color> gradient;
}

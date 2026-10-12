import 'package:customer_app/features/home/home_banners_repository.dart';

/// Banners without HTTP. By default there are none, so Home looks and
/// behaves as it does without banners.
class FakeHomeBannersRepository implements HomeBannersRepository {
  FakeHomeBannersRepository([this.banners = const <HomeBanner>[]]);

  /// Fails every load with [error].
  FakeHomeBannersRepository.failing(Object this.error)
    : banners = const <HomeBanner>[];

  List<HomeBanner> banners;
  Object? error;
  int calls = 0;

  @override
  Future<List<HomeBanner>> homeTop() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return banners;
  }
}

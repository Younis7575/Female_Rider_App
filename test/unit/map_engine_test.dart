import 'package:femalerider/core/config/env.dart';
import 'package:femalerider/core/location/app_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenStreetMap is used unless GOOGLE_MAPS_ENABLED=true (and a native key exists)', () async {
    final container = ProviderContainer(overrides: [
      googleMapsKeyConfiguredProvider.overrideWith((ref) async => true),
    ]);
    addTearDown(container.dispose);
    expect(Env.googleMapsEnabled, isFalse);
    expect(await container.read(mapEngineProvider.future), MapEngine.openStreetMap);
    // An interactive map is always available thanks to the OSM engine.
    expect(await container.read(mapsConfiguredProvider.future), isTrue);
  });

  test('missing native key is reported as not configured', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(googleMapsKeyConfiguredProvider.future), isFalse);
  });
}

import 'package:femalerider/core/config/env.dart';
import 'package:femalerider/core/utils/formatters.dart';
import 'package:femalerider/core/utils/polyline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fare formatting', () {
    test('formatMoney', () {
      expect(formatMoney(1250), 'PKR 1,250');
      expect(formatMoney(97.5), 'PKR 97.50');
      expect(formatMoney(0), 'PKR 0');
      expect(formatMoney(null), 'PKR 0');
      expect(formatMoney(650, currency: 'AED'), 'AED 650');
      expect(formatMoney(1250, showCurrency: false), '1,250');
    });

    test('roundFare and clampFare keep proposals on the 5-step grid within bounds', () {
      expect(roundFare(452), 450);
      expect(roundFare(453), 455);
      expect(clampFare(100, 205, 725), 205);
      expect(clampFare(9999, 205, 725), 725);
      expect(clampFare(301, 300, 1065), 300);
      expect(clampFare(203, 201, 724), 205); // min not on grid -> first grid value above min
      expect(clampFare(800, 201, 724), 720); // max not on grid -> last grid value below max
    });

    test('distance / duration / countdown', () {
      expect(formatDistance(850), '850 m');
      expect(formatDistance(9281), '9.3 km');
      expect(formatDistance(15000), '15 km');
      expect(formatDuration(20), '< 1 min');
      expect(formatDuration(1519), '25 min');
      expect(formatDuration(3900), '1 h 5 min');
      expect(formatCountdown(const Duration(seconds: 59)), '00:59');
      expect(formatCountdown(const Duration(minutes: 2, seconds: 5)), '02:05');
      expect(formatCountdown(const Duration(seconds: -3)), '00:00');
    });

    test('labels', () {
      expect(documentLabel('cnic_front'), 'CNIC (front)');
      expect(documentLabel('some_new_doc'), 'Some new doc');
      expect(humanize('cancelled_by_driver'), 'Cancelled by driver');
      expect(initials('Ayesha Khan'), 'AK');
      expect(firstName('  Sana   Malik '), 'Sana');
      expect(formatRating(0), 'New');
      expect(formatRating(4.86), '4.9');
    });
  });

  group('polyline', () {
    test('decodes the Google reference polyline', () {
      final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(pts, hasLength(3));
      expect(pts[0].lat, closeTo(38.5, 1e-5));
      expect(pts[0].lng, closeTo(-120.2, 1e-5));
      expect(pts[2].lat, closeTo(43.252, 1e-5));
      expect(pts[2].lng, closeTo(-126.453, 1e-5));
    });

    test('routePoints falls back to a straight line when polyline is null', () {
      const a = GeoPoint(24.86, 67.0);
      const b = GeoPoint(24.80, 67.03);
      expect(routePoints(null, a, b), [a, b]);
      expect(routePoints('', a, b), [a, b]);
    });

    test('distanceMeters (haversine)', () {
      final d = distanceMeters(const GeoPoint(24.8607, 67.0011), const GeoPoint(24.8021, 67.0300));
      expect(d, inInclusiveRange(7000, 7300));
    });
  });

  group('Env', () {
    test('Android emulator defaults', () {
      final e = Env.resolve(platform: EnvPlatform.android);
      expect(e.apiBaseUrl, 'http://10.0.2.2:8000');
      expect(e.apiRoot, 'http://10.0.2.2:8000/api/v1');
      expect(e.wsHost, '10.0.2.2');
      expect(e.wsPort, 8080);
      expect(e.wsScheme, 'ws');
      expect(e.isLocal, isTrue);
    });

    test('iOS simulator defaults', () {
      final e = Env.resolve(platform: EnvPlatform.ios);
      expect(e.apiBaseUrl, 'http://127.0.0.1:8000');
      expect(e.wsHost, '127.0.0.1');
    });

    test('physical device: WS host follows API host unless given', () {
      final e = Env.resolve(platform: EnvPlatform.android, apiBaseUrl: 'http://192.168.1.50:8000/');
      expect(e.apiBaseUrl, 'http://192.168.1.50:8000');
      expect(e.wsHost, '192.168.1.50');
      final p = Env.resolve(
        platform: EnvPlatform.ios,
        apiBaseUrl: 'https://api.femalerider.example',
        wsHost: 'ws.femalerider.example',
        wsPort: '443',
        wsScheme: 'wss',
        appEnv: 'production',
      );
      expect(p.wsHost, 'ws.femalerider.example');
      expect(p.wsPort, 443);
      expect(p.wsScheme, 'wss');
      expect(p.isProduction, isTrue);
      expect(p.isLocal, isFalse);
    });

    test('invalid port falls back to 8080', () {
      expect(Env.resolve(platform: EnvPlatform.android, wsPort: 'abc').wsPort, 8080);
    });
  });
}

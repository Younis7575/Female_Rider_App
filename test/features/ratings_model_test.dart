import 'package:femalerider/features/account/presentation/my_ratings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses ratings summary', () {
    final r = RatingsSummary.fromJson({
      'average': 4.5,
      'count': 2,
      'breakdown': {'5': 1, '4': 1, '3': 0, '2': 0, '1': 0},
      'items': [
        {'score': 5, 'tags': ['Safe driving'], 'comment': null, 'from': 'customer', 'from_name': 'Arifa', 'created_at': '2026-11-26T09:04:25Z'},
      ],
    });
    expect(r.average, 4.5);
    expect(r.breakdown[4], 1);
    expect(r.items.single.tags, ['Safe driving']);
    expect(r.items.single.fromName, 'Arifa');
    expect(RatingsSummary.fromJson({'count': 0, 'items': []}).average, isNull);
  });
}

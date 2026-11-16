import 'package:femalerider/features/driver/domain/driver_models.dart';
import 'package:femalerider/features/driver/presentation/widgets/guardian_fields.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/harness.dart';

void main() {
  test('guardian info parses from driver profile', () {
    final p = DriverProfile.fromJson({
      'status': 'approved',
      'guardian': {'name': 'Ayesha', 'relationship': 'Mother', 'whatsapp_masked': '+92 ••• ••321', 'alerts_enabled': true, 'configured': true},
    });
    expect(p.guardian.configured, isTrue);
    expect(p.guardian.relationship, 'Mother');
    expect(DriverProfile.fromJson({'status': 'not_submitted'}).guardian.configured, isFalse);
  });

  test('WhatsApp number validation accepts Pakistani formats', () {
    for (final ok in ['0300 1234567', '03001234567', '3001234567', '+92 300 1234567', '00923001234567']) {
      expect(GuardianFields.validNumber(ok), isTrue, reason: ok);
    }
    for (final bad in ['12345', '0300 12', 'abcdef']) {
      expect(GuardianFields.validNumber(bad), isFalse, reason: bad);
    }
  });

  testWidgets('guardian form requires name, number and consent', (tester) async {
    final c = GuardianFieldsController();
    final form = GlobalKey<FormState>();
    await pumpPlain(tester, Form(key: form, child: GuardianFields(controller: c)));
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(2));
    expect(find.text('Please confirm'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Guardian name'), 'Ayesha');
    await tester.enterText(find.widgetWithText(TextFormField, 'Guardian WhatsApp number'), '0300 1234567');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(form.currentState!.validate(), isTrue);
    await disposeTree(tester);
  });
}

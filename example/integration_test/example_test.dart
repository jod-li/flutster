import 'package:flutster/flutster.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutster_example/main.dart' as app;

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Integration testing based on API', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    FlutsterTestRecord record = FlutsterTestRecord.defaultRecord;
    String loadResult = await record.fromApi(53, tester: tester);
    if (loadResult != "Test record loaded from API") {
      debugPrint(loadResult);
      expect(false, true, reason: loadResult);
    }
    bool result = await record.playToApi(tester);
    expect(result, true, reason: "API test over with this result");
  });
}

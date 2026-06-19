import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lol/src/ui/lol_roguelite_app.dart';

void main() {
  testWidgets('shows start run button on launch', (WidgetTester tester) async {
    await tester.pumpWidget(const LolRogueliteApp());

    expect(find.text('Start Run'), findsOneWidget);
    expect(find.text('MID LANE\nROGUELITE'), findsOneWidget);
  });
}

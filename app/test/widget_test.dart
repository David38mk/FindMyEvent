import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:findmyevent/features/age_gate/age_gate_screen.dart';
import 'package:findmyevent/features/map/map_screen.dart';
import 'package:findmyevent/main.dart';

void main() {
  testWidgets('app boots to map when age already confirmed', (tester) async {
    SharedPreferences.setMockInitialValues({'age_confirmed_18': true});
    await tester.pumpWidget(const ProviderScope(child: FindMyEventApp()));
    // No pumpAndSettle: tile layer retries network fetches in tests and would
    // never settle. A few frames are enough for the async prefs read + build.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(MapScreen), findsOneWidget);
  });

  testWidgets('app shows age gate first on a fresh device, then the map',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: FindMyEventApp()));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AgeGateScreen), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);

    await tester.tap(find.text('I am 18 or older'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(MapScreen), findsOneWidget);
  });
}

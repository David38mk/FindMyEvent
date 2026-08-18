import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:findmyevent/features/map/map_screen.dart';
import 'package:findmyevent/main.dart';

void main() {
  testWidgets('app boots to map placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FindMyEventApp()));
    // No pumpAndSettle: tile layer retries network fetches in tests and would
    // never settle. Two frames are enough for the first build.
    await tester.pump();
    await tester.pump();

    expect(find.byType(MapScreen), findsOneWidget);
  });
}

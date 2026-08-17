import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:findmyevent/features/map/map_screen.dart';
import 'package:findmyevent/main.dart';

void main() {
  testWidgets('app boots to map placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FindMyEventApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MapScreen), findsOneWidget);
  });
}

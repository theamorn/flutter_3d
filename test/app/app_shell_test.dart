import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/app/app_shell.dart';
import 'package:flutter_3d/app/initial_tab.dart';
import 'package:flutter_3d/home/home_page.dart';
import 'package:flutter_3d/ui/booking_page.dart';

/// Stands in for a 3D tab: records each time its state is created, and
/// shows whether its subtree may tick.
class _Scene3d extends StatefulWidget {
  const _Scene3d(this.name, this.created);
  final String name;
  final List<String> created;
  @override
  State<_Scene3d> createState() => _Scene3dState();
}

class _Scene3dState extends State<_Scene3d> {
  @override
  void initState() {
    super.initState();
    widget.created.add(widget.name);
  }

  @override
  Widget build(BuildContext context) =>
      Text('${widget.name} ticking=${TickerMode.valuesOf(context).enabled}');
}

Widget _shell(List<String> created, {AppTab initialTab = AppTab.home}) =>
    MaterialApp(
      home: AppShell(
        initialTab: initialTab,
        homeBuilder: (onTakeTour) => HomePage(
          onTakeTour: onTakeTour,
          backdrop: (_, _) => const ColoredBox(color: Colors.blue),
        ),
        hotelBuilder: (_) => _Scene3d('hotel', created),
        islandBuilder: (_) => _Scene3d('island', created),
      ),
    );

void main() {
  test('a debug launch opens on its demo, and the hotel wins a tie', () {
    expect(pickInitialTab(hotelDebug: false, islandDebug: false), AppTab.home);
    expect(pickInitialTab(hotelDebug: true, islandDebug: false), AppTab.hotel);
    expect(pickInitialTab(hotelDebug: false, islandDebug: true), AppTab.island);
    expect(pickInitialTab(hotelDebug: true, islandDebug: true), AppTab.hotel);
  });

  testWidgets('opens on Home, with the three tabs and no 3D scene built', (
    tester,
  ) async {
    final created = <String>[];
    await tester.pumpWidget(_shell(created));
    expect(find.text(kHotelName), findsOneWidget);
    for (final label in ['Home', 'Home Demo', 'Island Demo']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(created, isEmpty);
  });

  testWidgets(
    'each 3D tab is built once, ticks only while selected, and keeps its state',
    (tester) async {
      final created = <String>[];
      await tester.pumpWidget(_shell(created));
      Future<void> go(String label) async {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await go('Home Demo');
      expect(find.text('hotel ticking=true'), findsOneWidget);
      await go('Island Demo');
      expect(find.text('island ticking=true'), findsOneWidget);
      expect(
        find.text('hotel ticking=false', skipOffstage: false),
        findsOneWidget,
      );
      for (var round = 0; round < 3; round++) {
        await go('Home Demo');
        await go('Home');
        await go('Island Demo');
      }
      expect(created, ['hotel', 'island']);

      await go('Home');
      expect(
        find.text('hotel ticking=false', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('island ticking=false', skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets('Take the 3D tour opens Home Demo', (tester) async {
    final created = <String>[];
    await tester.pumpWidget(_shell(created));
    await tester.tap(find.text('Take the 3D tour'));
    await tester.pumpAndSettle();
    expect(find.text('hotel ticking=true'), findsOneWidget);
    expect(created, ['hotel']);
  });

  testWidgets('a debug launch builds only its own demo', (tester) async {
    final created = <String>[];
    await tester.pumpWidget(_shell(created, initialTab: AppTab.island));
    expect(find.text('island ticking=true'), findsOneWidget);
    expect(created, ['island']);
  });

  testWidgets('booking from Home and going back leaves Home selected', (
    tester,
  ) async {
    final created = <String>[];
    await tester.pumpWidget(_shell(created));
    final book = find.byKey(const Key('book-familyRoom'));
    await tester.scrollUntilVisible(book, 200);
    await tester.tap(book);
    await tester.pumpAndSettle();
    expect(find.byType(BookingPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(BookingPage), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppTab.home.index,
    );
    expect(created, isEmpty);
  });
}

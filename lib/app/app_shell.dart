import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' show releaseTransientRenderTargets;

import '../home/home_page.dart';
import '../island/scene_app.dart';
import '../ui/hotel_page.dart';
import 'initial_tab.dart';

typedef HomeBuilder = Widget Function(VoidCallback onTakeTour);

Widget _realHome(VoidCallback onTakeTour) => HomePage(onTakeTour: onTakeTour);
Widget _realHotel(BuildContext _) => const HotelPage();
Widget _realIsland(BuildContext _) =>
    Theme(data: kIslandTheme, child: const IslandSceneScreen());

/// A hidden 3D tab keeps its scene, but its pooled render targets (scene
/// colour, depth, shadow atlas, post chain) are dropped; they reallocate on
/// the next frame that needs them (flutter_scene 0.24).
void releaseHiddenTab(AppTab hidden) {
  if (hidden == AppTab.home) return;
  final bytes = releaseTransientRenderTargets();
  debugPrint(
    'app shell: ${hidden.name} hidden, released '
    '${(bytes / 1048576).toStringAsFixed(1)} MB',
  );
}

/// Home, Home Demo and Island Demo. A 3D tab is built on its first visit and
/// kept. Every tab sits under `TickerMode(enabled: selected)`, so a hidden
/// scene stops rendering and keeps its state. This is the pause both demos
/// already rely on; `SceneView(autoTick:)` is a trap (docs/island/06-island-scene.md).
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialTab = kInitialTab,
    this.homeBuilder = _realHome,
    this.hotelBuilder = _realHotel,
    this.islandBuilder = _realIsland,
    this.onTabHidden = releaseHiddenTab,
  });

  final AppTab initialTab;
  final HomeBuilder homeBuilder;
  final WidgetBuilder hotelBuilder, islandBuilder;

  /// Called once each time [AppTab] stops being the selected tab.
  final void Function(AppTab hidden) onTabHidden;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppTab _tab = widget.initialTab;
  late final Set<AppTab> _visited = {widget.initialTab};

  void _select(AppTab tab) {
    if (tab != _tab) widget.onTabHidden(_tab);
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  Widget _slot(AppTab tab, WidgetBuilder build) => TickerMode(
    enabled: tab == _tab,
    child: _visited.contains(tab) ? Builder(builder: build) : const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          _slot(AppTab.home, (_) => widget.homeBuilder(() => _select(AppTab.hotel))),
          _slot(AppTab.hotel, widget.hotelBuilder),
          _slot(AppTab.island, widget.islandBuilder),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => _select(AppTab.values[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.hotel_outlined),
            selectedIcon: Icon(Icons.hotel),
            label: 'Home Demo',
          ),
          NavigationDestination(
            icon: Icon(Icons.beach_access_outlined),
            selectedIcon: Icon(Icons.beach_access),
            label: 'Island Demo',
          ),
        ],
      ),
    );
  }
}

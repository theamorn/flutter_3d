/// The app's tabs, in bottom-bar order.
enum AppTab { home, hotel, island }

/// The tab the app opens on. A debug launch meant for one demo opens on it,
/// so the capture scripts and perf probes need no taps. The hotel wins if
/// both kinds of define are set.
AppTab pickInitialTab({required bool hotelDebug, required bool islandDebug}) =>
    hotelDebug
    ? AppTab.hotel
    : (islandDebug ? AppTab.island : AppTab.home);

/// Any hotel debug define: the perf probe, the tour, a preset, the
/// lightning hold, naive props.
const bool _hotelDebug =
    bool.hasEnvironment('HOTEL_PERF') ||
    bool.hasEnvironment('HOTEL_TOUR') ||
    bool.hasEnvironment('HOTEL_PRESET') ||
    bool.hasEnvironment('HOLD_LIGHTNING') ||
    bool.hasEnvironment('NAIVE_PROPS');

/// Any island debug define (see lib/island/scene_app.dart).
const bool _islandDebug =
    bool.hasEnvironment('SCENE_AUTO_DEMO') ||
    bool.hasEnvironment('SCENE_QUALITY') ||
    bool.hasEnvironment('SCENE_TOUR') ||
    bool.hasEnvironment('SCENE_TOUR_MODES') ||
    bool.hasEnvironment('SCENE_RAIN') ||
    bool.hasEnvironment('SCENE_LIGHTNING_HOLD') ||
    bool.hasEnvironment('SCENE_FRAME_STATS') ||
    bool.hasEnvironment('SCENE_ABLATION');

const AppTab kInitialTab = _hotelDebug
    ? AppTab.hotel
    : (_islandDebug ? AppTab.island : AppTab.home);

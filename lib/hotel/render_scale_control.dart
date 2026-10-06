/// Tracks the current render-scale owner across independent feature chains.
/// A late unmount must not reset a successor's scale or adaptive controller.
class RenderScaleControl {
  String? _owner;
  double scale = 1.0;
  bool adaptive = false;

  void selectFixed(String owner, double value) {
    _owner = owner;
    scale = value;
    adaptive = false;
  }

  void selectAuto(String owner) {
    _owner = owner;
    scale = 1.0;
    adaptive = true;
  }

  bool release(String owner) {
    if (_owner != owner) return false;
    _owner = null;
    scale = 1.0;
    adaptive = false;
    return true;
  }
}

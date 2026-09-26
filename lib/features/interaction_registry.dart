import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';

class Interactable {
  Interactable({required this.node, required this.label, required this.onTap});

  /// Raycast target; Task 11 marks it raycastable.
  final Node node;

  /// Shown in the crosshair tooltip, e.g. "Turn on lamp".
  final String label;
  final void Function() onTap;
}

class InteractionRegistry extends ChangeNotifier {
  final List<Interactable> _items = [];
  Iterable<Interactable> get all => _items;

  void register(Interactable i) {
    _items.add(i);
    notifyListeners();
  }

  void unregister(Interactable i) {
    _items.remove(i);
    notifyListeners();
  }

  /// Walks up parents to find a registered node.
  Interactable? forNode(Node n) {
    Node? cur = n;
    while (cur != null) {
      for (final i in _items) {
        if (identical(i.node, cur)) return i;
      }
      cur = cur.parent;
    }
    return null;
  }
}

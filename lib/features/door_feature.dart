// STUB, replaced by Task 17.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class DoorFeature extends HotelFeature {
  @override
  String get id => 'door';
  @override
  String get label => 'Connecting door';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}

class PortalCullingFeature extends HotelFeature {
  @override
  String get id => 'portal_culling';
  @override
  String get label => "Hide the room you can't see";
  @override
  CostTier get tier => CostTier.free;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}

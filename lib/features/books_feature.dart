// STUB, replaced by Task 25.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class BooksFeature extends HotelFeature {
  @override
  String get id => 'books';
  @override
  String get label => 'Pokémon books';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}

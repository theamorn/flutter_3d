import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/booking.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/entrance_zone.dart';
import '../ui/booking_page.dart';
import 'player_feature.dart';

class EntranceFeature extends HotelFeature {
  @override
  String get id => 'entrance';
  @override
  String get label => 'Entrance "Book now"';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;

  static final ValueNotifier<bool> showBookNow = ValueNotifier(false);
  static final GlobalKey scenePreviewKey = GlobalKey();
  static bool _doorOpenAtEntry = false;
  static bool _bookingInProgress = false;
  static bool _suppressUntilExit = false;

  final EntranceZone _zone = EntranceZone();

  @override
  Future<void> mount(HotelContext ctx) async {
    _zone.inside = false;
    _suppressUntilExit = false;
    _bookingInProgress = false;
    showBookNow.value = false;
  }

  @override
  void unmount(HotelContext ctx) {
    _zone.inside = false;
    showBookNow.value = false;
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final wasInside = _zone.inside;
    final inside = _zone.update(ctx.playerXZ);
    if (!wasInside && inside) _doorOpenAtEntry = ctx.doorOpen.value;
    if (!inside) _suppressUntilExit = false;
    showBookNow.value = inside && !_suppressUntilExit && !_bookingInProgress;
  }

  static Future<ui.Image?> _capturePreview() async {
    try {
      final boundary = scenePreviewKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.hasSize) return null;
      return await boundary.toImage(pixelRatio: 1);
    } catch (_) {
      // On an unsupported renderer, the booking page uses its gradient header.
      return null;
    }
  }

  static Future<void> onBookNow(BuildContext context, HotelContext ctx) async {
    if (_bookingInProgress || !showBookNow.value) return;
    _bookingInProgress = true;
    showBookNow.value = false;
    PlayerFeature.stick.value = Offset.zero;
    PlayerFeature.pendingLook = Offset.zero;
    final preview = await _capturePreview();
    if (!context.mounted) {
      preview?.dispose();
      _bookingInProgress = false;
      return;
    }
    final now = DateTime.now();
    final quote = BookingQuote(
      option: _doorOpenAtEntry
          ? RoomOption.familySuiteConnected
          : RoomOption.familyRoom,
      checkIn: DateTime(now.year, now.month, now.day + 1),
      nights: 2,
      adults: 2,
      children: 2,
    );
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookingPage(initial: quote, preview: preview),
        ),
      );
    } finally {
      ctx.playerXZ.y += 0.6;
      _suppressUntilExit = true;
      _bookingInProgress = false;
      showBookNow.value = false;
      PlayerFeature.stick.value = Offset.zero;
      PlayerFeature.pendingLook = Offset.zero;
    }
  }

  /// Flutter control layered above the time slider.
  static Widget overlay(HotelContext ctx) => Positioned(
    left: 16,
    right: 16,
    bottom: 90,
    child: Center(
      child: ValueListenableBuilder<bool>(
        valueListenable: showBookNow,
        builder: (context, visible, _) => IgnorePointer(
          ignoring: !visible,
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 1.5),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: FilledButton.icon(
                onPressed: () => onBookNow(context, ctx),
                icon: const Icon(Icons.hotel),
                label: const Text('Book now'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

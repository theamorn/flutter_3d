# Stac + Firebase Realtime Database + 3D/Shader Integration Plan (Step 1: `flutter_3d`)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate `stac` (Server-Driven UI) with custom 3D turntable and GPU shader `StacParser`s streamed in real time from Firebase Realtime Database into `flutter_3d`, sending interactive 3D/shader state and promo discounts back to the host page, structured inside a self-contained `lib/stac/` module ready to copy into `flutter-inapp-ios`.

**Architecture:** A self-contained `lib/stac/` directory provides (1) `StacHostBridge` for two-way state/value updates from Stac widgets back to the host (Flutter `HomePage` now, Native `MethodChannel` in Step 2), (2) `Stac3dTurntableParser`, `StacShaderBoxParser`, and `StacSendToHostActionParser` registered with `Stac.initialize`, and (3) `FirebaseStacClient` streaming live JSON from Firebase Realtime Database via REST + Server-Sent Events (`text/event-stream`).

**Tech Stack:** Flutter 3.47.7 (FVM), `stac: ^1.6.0`, `stac_framework: ^1.0.0`, `http: ^1.2.0`, `flutter_scene`, Fragment Shaders (`water.glsl`, `sky.glsl`).

**Spec:** Conversation design approved 2026-10-30.

## Global Constraints

- Use `fvm flutter` for all CLI commands (`fvm flutter pub get`, `fvm flutter test`, `fvm flutter analyze`).
- Keep all Stac code inside `lib/stac/` so it can be copied into `flutter-inapp-ios/flutter_module/lib/stac/` in Step 2.
- All existing tests in `test/home/home_page_test.dart` (including `320x568` small-phone overflow test and room price constant assertions) must remain 100% passing.

## Review Focus

- `320x568` small-phone viewport must not overflow horizontally when rendering Stac JSON cards or interactive option chips.
- `tester.pumpAndSettle()` in widget tests must not hang on open HTTP streams or infinite periodic timers.
- Malformed or partial Firebase SSE `put` events (`data: null` or keep-alive newlines) must be ignored cleanly without throwing unhandled stream exceptions.

---

### Task 1: Add `stac` Dependency and Build `StacHostBridge` + Firebase RTDB SSE Parser

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/stac/stac_host_bridge.dart`
- Create: `lib/stac/firebase_stac_client.dart`
- Test: `test/stac/firebase_stac_client_test.dart`

**Interfaces:**
- Produces:
  - `StacHostSelection` (`edition`, `discountPercent`, `promoCode`, `waveLevel`, `yawDegrees`, `applyDiscountThb(int)`)
  - `StacHostBridge` (`ValueNotifier<StacHostSelection?>`, `updateFromMap(Map<String, dynamic>)`, `reset()`)
  - `FirebaseStacClient` (`parseSseChunk(String)`, `watchJson()`, `putJson()`)
  - `kDefaultStac3dCardJson`, `kDefaultStacShaderCardJson`

- [x] **Step 1: Add `stac` and `stac_framework` to `pubspec.yaml` and run `fvm flutter pub get`**
- [x] **Step 2: Write failing unit tests in `test/stac/firebase_stac_client_test.dart` for `StacHostBridge` and Firebase RTDB SSE frame parsing (`event: put` with root and nested JSON payloads, `data: null` handling, and THB discount calculation)**
- [x] **Step 3: Run `fvm flutter test test/stac/firebase_stac_client_test.dart` and watch it fail**
- [x] **Step 4: Implement `lib/stac/stac_host_bridge.dart` and `lib/stac/firebase_stac_client.dart`**
- [x] **Step 5: Run `fvm flutter test test/stac/firebase_stac_client_test.dart` and verify it passes**

---

### Task 2: Implement Custom `StacParser`s (`interactive_3d_turntable`, `interactive_shader_box`) and `StacActionParser` (`send_to_host`)

**Files:**
- Create: `lib/stac/stac_gpu_parsers.dart`
- Test: `test/stac/stac_gpu_parsers_test.dart`

**Interfaces:**
- Consumes: `StacHostBridge`, `ShaderBackdrop`, `BackdropBuilder`
- Produces:
  - `ensureStacInitialized({BackdropBuilder? backdropBuilder})`
  - `Stac3dTurntableParser` (`type: 'interactive_3d_turntable'`)
  - `StacShaderBoxParser` (`type: 'interactive_shader_box'`)
  - `StacSendToHostActionParser` (`actionType: 'send_to_host'`)

- [x] **Step 1: Write failing widget tests in `test/stac/stac_gpu_parsers_test.dart` verifying `Stac.fromJson` renders `interactive_3d_turntable` and `interactive_shader_box`, supports dragging/tapping to update 3D yaw, edition, and wave level, and dispatches values back to `StacHostBridge`**
- [x] **Step 2: Run `fvm flutter test test/stac/stac_gpu_parsers_test.dart` and watch it fail**
- [x] **Step 3: Implement `lib/stac/stac_gpu_parsers.dart`**
- [x] **Step 4: Run `fvm flutter test test/stac/stac_gpu_parsers_test.dart` and verify all tests pass**

---

### Task 3: Integrate `StacLiveSection` into `HomePage` (`lib/home/home_page.dart`)

**Files:**
- Create: `lib/stac/stac_live_section.dart`
- Modify: `lib/main.dart`
- Modify: `lib/home/home_page.dart`
- Modify: `test/home/home_page_test.dart`

**Interfaces:**
- Consumes: `ensureStacInitialized`, `FirebaseStacClient`, `StacHostBridge`, `Stac3dTurntableParser`, `StacShaderBoxParser`
- Produces: `StacLiveSection` embedded in `HomePage`, updating host promo banner and room booking discounts when the user interacts with the Stac 3D/Shader card.

- [x] **Step 1: Write failing widget tests in `test/home/home_page_test.dart` verifying that `HomePage` renders the Stac live card, updates the host state when the Stac 3D/shader widget is interacted with, and passes the small-phone `320x568` overflow check**
- [x] **Step 2: Run `fvm flutter test test/home/home_page_test.dart` and watch the new test fail**
- [x] **Step 3: Implement `lib/stac/stac_live_section.dart` and wire into `lib/home/home_page.dart` and `lib/main.dart`**
- [x] **Step 4: Run `fvm flutter test test/home/home_page_test.dart` and `fvm flutter analyze` to verify all tests pass with zero warnings**

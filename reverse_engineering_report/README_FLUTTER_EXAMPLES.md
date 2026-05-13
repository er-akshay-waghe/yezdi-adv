# Flutter Examples (Cluster Navigation BLE Writes)

These examples mirror the APK behavior for navigation writes only.

Library used below: `flutter_blue_plus` (any BLE library is fine if behavior matches).

## 1) UUID Constants

```dart
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

final Guid tbtServiceUuid = Guid("d6328aea-d630-4a83-b51b-1da8e8da8200");
final Guid tbtCharUuid    = Guid("d6328aea-d630-4a83-b51b-1da8e8da8210");
final Guid dtmCharUuid    = Guid("d6328aea-d630-4a83-b51b-1da8e8da8220");
final Guid dtdCharUuid    = Guid("d6328aea-d630-4a83-b51b-1da8e8da8230");

final Guid protectionServiceUuid = Guid("d6328aea-d630-4a83-b51b-1da8e8da8600");
final Guid clusterPcodeCharUuid  = Guid("d6328aea-d630-4a83-b51b-1da8e8da8610");
final Guid mobilePcodeCharUuid   = Guid("d6328aea-d630-4a83-b51b-1da8e8da8620");
```

## 2) Encoding Helpers (matches `IntToByteArray`)

```dart
List<int> u16le(int v) => [v & 0xFF, (v >> 8) & 0xFF];

/// DTD = [km_low, km_high, hundred_meter_digit]
List<int> encodeDtd(int dtdKm, int dtdM) {
  return [dtdKm & 0xFF, (dtdKm >> 8) & 0xFF, dtdM & 0xFF];
}
```

## 3) Write Order (must stay sequential)

```dart
Future<void> sendNavPacket({
  required BluetoothDevice device,
  required int signal,   // 1 byte
  required int dtmMeters, // 2-byte LE
  required int dtdKm,     // low/high in first two bytes
  required int dtdM,      // third byte (0..9)
}) async {
  final services = await device.discoverServices();
  final tbtService = services.firstWhere((s) => s.uuid == tbtServiceUuid);

  final tbtChar = tbtService.characteristics.firstWhere((c) => c.uuid == tbtCharUuid);
  final dtmChar = tbtService.characteristics.firstWhere((c) => c.uuid == dtmCharUuid);
  final dtdChar = tbtService.characteristics.firstWhere((c) => c.uuid == dtdCharUuid);

  final signalBytes = <int>[signal & 0xFF];
  final dtmBytes = u16le(dtmMeters);
  final dtdBytes = encodeDtd(dtdKm, dtdM);

  // APK behavior: write with response, in strict order
  await tbtChar.write(signalBytes, withoutResponse: false);
  await dtmChar.write(dtmBytes, withoutResponse: false);
  await dtdChar.write(dtdBytes, withoutResponse: false);
}
```

## 4) LEFT / RIGHT Example Calls

```dart
// LEFT turn example (common IDs 0/13 -> signal 5)
await sendNavPacket(
  device: device,
  signal: 5,
  dtmMeters: 350, // -> [94,1]
  dtdKm: 12,
  dtdM: 3,        // -> [12,0,3]
);

// RIGHT turn example (common IDs 3/14 -> signal 3)
await sendNavPacket(
  device: device,
  signal: 3,
  dtmMeters: 200, // -> [200,0]
  dtdKm: 4,
  dtdM: 7,        // -> [4,0,7]
);
```

## 5) Start/Stop Signals

```dart
const int navStartedSignal = 100;
const int navStoppedSignal = 41; // also cancelled
const int reroutingSignal  = 40;
const int destinationSignal = 36; // maneuver ID 8
```

## 6) Auth Gate (Needed Before Reliable Nav Writes)

The APK performs a challenge-response flow on service `...8600`:

1. Subscribe/read challenge from `...8610`
2. Match challenge bytes against app `REQUEST_CODES`
3. Write matched response bytes to `...8620`

Skeleton:

```dart
Future<void> performProtectionHandshake(BluetoothDevice device) async {
  // 1) discover protection chars
  // 2) enable notifications on ...8610
  // 3) read/receive challenge bytes
  // 4) lookup response from your extracted REQUEST_CODES/RESPONSE_CODES map
  // 5) write response to ...8620 (with response)
}
```

If this step is skipped, cluster may reject or ignore writes depending on firmware/bond state.

## 7) Practical Notes

- Use bonded device + write-with-response.
- Keep write cadence moderate; do not flood.
- Mirror APK rounding logic for DTM/DTD upstream if you want identical cluster behavior.

## Evidence

- Nav write sequence: [index.android.bundle.dec.js](E:/cyezdiapp/index.android.bundle.dec.js:543127)  
- DTM/DTD encoding: [index.android.bundle.dec.js](E:/cyezdiapp/index.android.bundle.dec.js:542751)  
- Protection flow: [index.android.bundle.dec.js](E:/cyezdiapp/index.android.bundle.dec.js:590631)


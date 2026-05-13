# Yezdi Adventure BLE Reverse Engineering Report

Package: `com.jawa_ble`  
Scope: BLE communication, navigation protocol, instrument cluster communication only.

## 1) Executive Summary

The app sends turn-by-turn (TBT) data to the cluster over **service `...8200`** using **three sequential writes**:

1. `TBT_CHAR_UUID (...8210)` -> 1 byte turn signal code  
2. `DTM_CHAR_UUID (...8220)` -> 2 bytes distance-to-maneuver (little-endian)  
3. `DTD_CHAR_UUID (...8230)` -> 3 bytes distance-to-destination payload

Before stable operation, the app performs a challenge-response protection step on **service `...8600`**:

- Notify/read challenge from `CLUSTER_PCODE_CHAR_UUID (...8610)`
- Write response to `MOBILE_PCODE_CHAR_UUID (...8620)`

No checksum/CRC or payload encryption is used in nav packet construction.

---

## 2) BLE Architecture (Observed)

```text
Phone App (React Native + Hermes)
  |
  |  Native bridge: react-native-ble-manager (it.innove.BleManager)
  v
BLE GATT
  |
  +-- Protection Service (...8600)
  |     +-- Cluster PCode Char (...8610) [notify/read challenge]
  |     +-- Mobile  PCode Char (...8620) [write response]
  |
  +-- Notification Service (...8100)
  |     +-- Notification Char (...8110) [write call/message states]
  |
  +-- TBT Service (...8200)
        +-- TBT Char (...8210) [write signal]
        +-- DTM Char (...8220) [write 2-byte DTM]
        +-- DTD Char (...8230) [write 3-byte DTD]
```

---

## 3) Protocol Flow Diagram

```text
[Scan for ...8100] -> [Connect] -> [CreateBond] -> [RetrieveServices]
                                      |
                                      v
                         [Start Notify on ...8610]
                                      |
                                      v
                           [Read/Receive challenge]
                                      |
                                      v
                      [Lookup REQUEST_CODES -> RESPONSE_CODES]
                                      |
                                      v
                       [Write response to ...8620]
                                      |
                                      v
                        [Connection usable for nav writes]
                                      |
                                      v
                NavigationEvent(NAVIGATION_STATE, DTM, DTD_KM, DTD_M)
                                      |
                                      v
                  GetTBTSignal(NAVIGATION_STATE) -> signal byte
                                      |
                                      v
            Write ...8210(signal), ...8220(DTM2), ...8230(DTD3)
```

---

## 4) UUID Tables

Detailed tables are in [README_UUID_TABLES.md](./README_UUID_TABLES.md).

Navigation-critical UUIDs:

- Service: `d6328aea-d630-4a83-b51b-1da8e8da8200`
- Write chars:
  - `...8210` (signal)
  - `...8220` (DTM)
  - `...8230` (DTD)
- Protection/auth:
  - Service `...8600`
  - Notify/read challenge: `...8610`
  - Write response: `...8620`

---

## 5) Packet Formats (Decoded)

### 5.1 TBT signal packet (`...8210`)

- Length: 1 byte
- Format: `[signal]`
- Source: `GetTBTSignal(NAVIGATION_STATE)`

### 5.2 DTM packet (`...8220`)

- Length: 2 bytes
- Format: little-endian integer, from `DTM` via `IntToByteArray(value, [0,0])`
- Example: `350` meters -> `0x5E 0x01` -> `[94, 1]`

### 5.3 DTD packet (`...8230`)

- Length: 3 bytes
- Format: `[km_low, km_high, hundred_meter_digit]`
- Construction:
  - First two bytes from `IntToByteArray(DTD_KM, [0,0,0])`
  - Third byte from `DTD_M` (0-9), else `0`

Example: `12.3 km` -> `DTD_KM=12`, `DTD_M=3` -> `[0x0C, 0x00, 0x03]`

---

## 6) Decoded Navigation Examples

### Example A: LEFT turn

Common left maneuver IDs in app path: `0` and `13` -> both map to signal `5`.

If:
- `signal=5`
- `DTM=350m` -> `[94,1]`
- `DTD=12.3km` -> `[12,0,3]`

Writes:
1. `...8210`: `[5]`
2. `...8220`: `[94,1]`
3. `...8230`: `[12,0,3]`

### Example B: RIGHT turn

Common right maneuver IDs in app path: `3` and `14` -> signal `3`.

If:
- `signal=3`
- `DTM=200m` -> `[200,0]`
- `DTD=4.7km` -> `[4,0,7]`

Writes:
1. `...8210`: `[3]`
2. `...8220`: `[200,0]`
3. `...8230`: `[4,0,7]`

### Notable control signals

- `NAVIGATION_STARTED` -> `100`
- `NAVIGATION_STOPPED` / `NAVIGATION_CANCELLED` -> `41`
- `RE_ROUTING_REQUEST` -> `40`
- `Maneuver ID 8` (destination) -> `36`

---

## 7) Flutter Implementation

See [README_FLUTTER_EXAMPLES.md](./README_FLUTTER_EXAMPLES.md) for full snippets.

Core behavior in Flutter should mirror app order exactly:

1. Write `signal` to `...8210`
2. Write DTM(2) to `...8220`
3. Write DTD(3) to `...8230`

---

## 8) Suspected Missing Pieces

1. Full semantic meaning of some maneuver IDs used in TBT map (`11, 12, 22, 23, 24, 25`) is not directly labeled in short-instruction resources.
2. Firmware-side expectations (timing/rate limits, retransmit policy) are not visible in APK.
3. App uses a fixed request/response lookup table for protection codes; exact cluster firmware validation logic is unknown.
4. No explicit ACK protocol for each nav packet is exposed in app-level logic.

---

## 9) Confidence Levels

| Finding | Confidence |
|---|---|
| TBT uses three writes to `...8210`, `...8220`, `...8230` | High |
| Packet field construction for DTM/DTD | High |
| `GetTBTSignal` mapping drives first byte | High |
| Protection challenge-response gate on `...8600` | High |
| No CRC/checksum in nav packet builder | High |
| No encryption in nav payload construction | High |
| Full meaning for all maneuver IDs | Medium |
| Whether every firmware revision requires same auth flow | Medium |

---

## 10) Evidence Pointers (Primary)

- Hermes enabled host: [MainApplication.java](E:/cyezdiapp/sources/com/jawa_ble/MainApplication.java:58)  
- Native BLE package present: [PackageList.java](E:/cyezdiapp/sources/com/facebook/react/PackageList.java:69)  
- Native nav event publisher (`NAVIGATION_STATE`, `DTM`, `DTD_*`): [NavigationManager.java](E:/cyezdiapp/sources/com/jawa_ble/navigation/NavigationManager.java:238)  
- UUID constants (8100/8200/8300/8400/8500/8600 and chars): [index.android.bundle.dec.js](E:/cyezdiapp/index.android.bundle.dec.js:471316)  
- `GetTBTSignal` mapping table: [index.android.bundle.dec.js](E:/cyezdiapp/index.android.bundle.dec.js:447137)  
- `IntToByteArray` logic: [index.android.bundle.dec.js](E:/cyezdiapp/index.android.bundle.dec.js:446925)  
- Nav write sequence (`_onWriteTBT`): [index.android.bundle.dec.js](E:/cyezdiapp/index.android.bundle.dec.js:543127)  
- Protection handler and response write: [index.android.bundle.dec.js](E:/cyezdiapp/index.android.bundle.dec.js:544137)  
- Protection code lookup function: [index.android.bundle.dec.js](E:/cyezdiapp/index.android.bundle.dec.js:590881)


# UUID Tables (BLE + Cluster Protocol)

## A) Services Found in App Constants

| Service | UUID | Role |
|---|---|---|
| Protection Service | `d6328aea-d630-4a83-b51b-1da8e8da8600` | Challenge-response gate before normal operation |
| Notification Service | `d6328aea-d630-4a83-b51b-1da8e8da8100` | Call/message notification channel |
| TBT Service | `d6328aea-d630-4a83-b51b-1da8e8da8200` | Turn-by-turn navigation packets |
| Network Service | `d6328aea-d630-4a83-b51b-1da8e8da8300` | Signal strength related |
| Vehicle Info Service | `d6328aea-d630-4a83-b51b-1da8e8da8400` | Vehicle telemetry |
| Clock Service | `d6328aea-d630-4a83-b51b-1da8e8da8500` | Cluster clock sync |

## B) Navigation-Critical Characteristics

| UUID | Name (from app) | Direction | Payload |
|---|---|---|---|
| `d6328aea-d630-4a83-b51b-1da8e8da8210` | `TBT_CHAR_UUID` | Write | 1-byte signal |
| `d6328aea-d630-4a83-b51b-1da8e8da8220` | `DTM_CHAR_UUID` | Write | 2-byte DTM |
| `d6328aea-d630-4a83-b51b-1da8e8da8230` | `DTD_CHAR_UUID` | Write | 3-byte DTD |

## C) Auth/Protection Characteristics

| UUID | Name (from app) | Direction | Use |
|---|---|---|---|
| `d6328aea-d630-4a83-b51b-1da8e8da8610` | `CLUSTER_PCODE_CHAR_UUID` | Notify/Read | Cluster challenge bytes |
| `d6328aea-d630-4a83-b51b-1da8e8da8620` | `MOBILE_PCODE_CHAR_UUID` | Write | Matched response bytes |

## D) Notification Characteristics (non-nav)

| UUID | Name | Direction | Notes |
|---|---|---|---|
| `d6328aea-d630-4a83-b51b-1da8e8da8110` | `NOTIFICATION_CHAR_UUID` | Write | App writes small status codes (`[2]`, `[3]`, `[4]`, `[5]`, `[7]`) |

## E) Vehicle / Misc Characteristics (for completeness)

| Service | Characteristic UUID | Name |
|---|---|---|
| `...8400` | `...8410` | `SPEED_CHAR_UUID` |
| `...8400` | `...8420` | `RPM_CHAR_UUID` |
| `...8400` | `...8430` | `FUEL_GEAR_ABS_CHAR` |
| `...8400` | `...8440` | `ODOM_METER_READING_CHAR` |
| `...8400` | `...8450` | `TRIPA_TRIPB_READING_CHAR` |
| `...8400` | `...8460` | `TT_BATTERY_CHAR` |
| `...8400` | `...8470` | `AFE_DTE_READING_CHAR` |
| `...8400` | `...8480` | `BUTTON_PRESS_STATUS_CHAR` |
| `...8300` | `...8310` | `SIGNAL_STRENGTH_CHAR_UUID` |
| `...8500` | `...8510` | `CLOCK_TIME_CHAR_UUID` |

## F) Maneuver ID -> Signal Byte (from `GetTBTSignal`)

Control states:

| Key | Signal |
|---|---|
| `NAVIGATION_STARTED` | `100` |
| `NAVIGATION_STOPPED` | `41` |
| `NAVIGATION_CANCELLED` | `41` |
| `RE_ROUTING_REQUEST` | `40` |

Maneuver ID group map:

| Maneuver IDs | Signal |
|---|---|
| `7, 21` | `1` |
| `3, 12, 14, 24, 25` | `3` |
| `0, 11, 13, 22, 23` | `5` |
| `4, 18` | `7` |
| `5, 16, 20, 75` | `9` |
| `2, 15, 19, 73, 74` | `13` |
| `41` | `17` |
| `65, 17, 6` | `19` |
| `1` | `21` |
| `71` | `24` |
| `66` | `25` |
| `70` | `26` |
| `67` | `27` |
| `69` | `28` |
| `68` | `29` |
| `72` | `39` |
| `8` | `36` |
| `36` | `40` |

## G) What These Maneuver IDs Mean

Important: these are **Mappls navigation maneuver IDs**, not BLE bytes.  
The app first receives a maneuver ID (`NAVIGATION_STATE`), then maps it to a **cluster signal byte**.

### G.1 Group-by-group meaning for your mapping

| Maneuver IDs | Signal | Practical meaning (likely) | Confidence |
|---|---:|---|---|
| `7, 21` | `1` | Continue/straight movement | High |
| `3, 12, 14, 24, 25` | `3` | Right-turn family (turn/take-right/right-variant) | High for `3,12,14`, Medium for `24,25` |
| `0, 11, 13, 22, 23` | `5` | Left-turn family (turn/take-left/left-variant) | High for `0,11,13`, Medium for `22,23` |
| `4, 18` | `7` | Sharp-right family | Medium |
| `5, 16, 20, 75` | `9` | Slight/keep/ramp-right family | High for `5,16,20,75` |
| `2, 15, 19, 73, 74` | `13` | Slight/keep/ramp-left family | High for `2,15,19,73,74` |
| `41` | `17` | U-turn | High |
| `65, 17, 6` | `19` | Roundabout early-exit / left-sharp / left-u-turn bucket | Medium |
| `1` | `21` | Sharp-left | High |
| `71` | `24` | Roundabout exit bucket (7th or greater) | High |
| `66` | `25` | Roundabout 2nd-exit bucket | High |
| `70` | `26` | Roundabout 6th-exit bucket | High |
| `67` | `27` | Roundabout 3rd-exit bucket | High |
| `69` | `28` | Roundabout 5th-exit bucket | High |
| `68` | `29` | Roundabout 4th-exit bucket / roundabout-center bucket | Medium |
| `72` | `39` | Enter roundabout / rotary | High |
| `8` | `36` | Destination/arrive | High |
| `36` | `40` | Ferry/ramp-class instruction bucket | Medium |

### G.2 Why some IDs look "missing" or unclear

- IDs like `22, 23, 24, 25` are not explicitly labeled in local short-instruction JSON files.
- The app still handles them by bucketing into left/right cluster icons (via `GetTBTSignal`).
- So those are likely API-side maneuver variants that this app normalizes for the cluster.

### G.3 Useful base ID references from local SDK code

From `TurnTypeConstants` and local instruction resources:

- `0/1/2` = left / sharp-left / slight-left
- `3/4/5` = right / sharp-right / slight-right
- `6` = U-turn
- `7/21` = continue/straight
- `8` = destination
- `11/13` = left-at / left-at-end
- `12/14` = right-at / right-at-end
- `15/19` = left-fork/keep-left style
- `16/20` = right-fork/keep-right style
- `41` = right U-turn
- `65..71` = roundabout exit ordinal buckets (1st..7th+)
- `72` = roundabout/rotary entry
- `73/74/75` = ramp classes (`take ramp`, `left ramp`, `right ramp`)

## H) LEFT/RIGHT Interpretation (Most Likely)

From short-instruction resources:

- Left-like IDs: `0`, `13` (turn left), `2/15/19` (slight/keep left)
- Right-like IDs: `3`, `14` (turn right), `5/16/20` (slight/keep right)

Corresponding cluster signal bytes used by this app:

- Typical LEFT turn -> signal `5`
- Typical RIGHT turn -> signal `3`

## Evidence

- UUID constants: [index.android.bundle.dec.js](E:/cyezdiapp/index.android.bundle.dec.js:471316)  
- Signal map table: [index.android.bundle.dec.js](E:/cyezdiapp/index.android.bundle.dec.js:447137)  
- Short instruction IDs: [mappls-directions-en_short_instructions.json](E:/cyezdiapp/resources/translations/mappls-directions-en_short_instructions.json:30)  
- Turn-type constants: [TurnTypeConstants.java](E:/cyezdiapp/sources/com/mappls/sdk/navigation/router/TurnTypeConstants.java:5)  
- Roundabout exit bucketing: [NavigationUtils.java](E:/cyezdiapp/sources/com/mappls/sdk/navigation/util/NavigationUtils.java:26)

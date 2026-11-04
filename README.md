# LiveWire + LG Extended Electricity Adapter


A compatibility mod for **Project Zomboid Build 42.21**. It lets **LiveWire** keep its normal inverter coverage when **LG Extended Electricity (LGEE)**'s generator-range takeover is enabled.

The adapter works alongside both mods; it does not replace or modify them.

## Requirements

- Project Zomboid Build 42.21
- LiveWire (`batman_LiveWire`)
- LG Extended Electricity (`LGExtendedElectricity`)

## Installation

1. Install LiveWire and LG Extended Electricity.
2. Subscribe to the [LiveWire + LG Extended Electricity Adapter on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3833576038) (Workshop ID: `3833576038`). Its Mod ID is `LiveWireLGEEAdapter`.
3. Enable **LiveWire + LG Extended Electricity Adapter** in the Mods menu, along with both required mods.

The adapter declares both dependencies in its mod metadata. In multiplayer, enable it on the server and clients, and configure sandbox options on the server.

## Sandbox settings

When LGEE's generator-range takeover is active, the adapter provides a LiveWire horizontal range override:

| Setting | Range | Default (`0`) |
| --- | ---: | --- |
| LiveWire power range override | `0`–`100` tiles | 20 tiles |

Set the value to `0` to use the 20-tile default, or set a positive value to override the horizontal range. Vertical reach remains at the default of 3 floors while LGEE's takeover is active; there is no vertical override setting. When takeover is inactive, LiveWire's original range settings are left unchanged.

## What to expect

- LiveWire inverters retain radius-based coverage; this does not extend an inverter's power to an entire building.
- Coverage is handled automatically. You do not need to craft, place, or wire LGEE relays for LiveWire.
- The adapter contributes coverage through LGEE's relay system and avoids squares that are missing or already contain a generator.
- If the required LGEE coverage APIs are unavailable, the adapter warns in the log and leaves LiveWire's original range behavior in place.

## Troubleshooting

- Confirm that all three mods are enabled and that their mod IDs match the requirements above.
- If the overrides have no effect, check that LGEE's generator-range takeover is enabled and review the game log for `[LiveWireLGEEAdapter]` warnings.
- If the adapter reports unsupported coverage APIs, update LGEE to a version compatible with Build 42.21.

# LiveWire + LG Extended Electricity Adapter


A compatibility mod for **Project Zomboid Build 42.21**. It lets **LiveWire** keep its normal inverter coverage when **LG Extended Electricity (LGEE)**'s generator-range takeover is enabled.

The adapter works alongside both mods; it does not replace or modify them.

## Requirements

- Project Zomboid Build 42.21
- LiveWire (`batman_LiveWire`)
- LG Extended Electricity (`LGExtendedElectricity`)

## Installation

1. Install LiveWire and LG Extended Electricity.
2. Copy the `LiveWireLGExtendedAdapter` mod folder into your Project Zomboid `mods` directory. Keep the `42.21` subfolder intact so the path is `mods/LiveWireLGExtendedAdapter/42.21/mod.info`.
3. Enable **LiveWire + LG Extended Electricity Adapter** in the Mods menu, along with both required mods.

The adapter declares both dependencies in its mod metadata. In multiplayer, enable it on the server and clients, and configure sandbox options on the server.

## Sandbox settings

When LGEE's generator-range takeover is active, the adapter provides two independent LiveWire overrides:

| Setting | Range | Default (`0`) |
| --- | ---: | --- |
| LiveWire power range override | `0`–`100` tiles | 20 tiles |
| LiveWire vertical range override (floors) | `0`–`15` floors | 3 floors |

Set either value to `0` to use that range's default; set a positive value to override it. The horizontal and vertical settings can be adjusted independently. When takeover is inactive, LiveWire's original range settings are left unchanged.

## What to expect

- LiveWire inverters retain radius-based coverage; this does not extend an inverter's power to an entire building.
- Coverage is handled automatically. You do not need to craft, place, or wire LGEE relays for LiveWire.
- The adapter contributes coverage through LGEE's relay system and avoids squares that are missing or already contain a generator.
- If the required LGEE coverage APIs are unavailable, the adapter warns in the log and leaves LiveWire's original range behavior in place.

## Troubleshooting

- Confirm that all three mods are enabled and that their mod IDs match the requirements above.
- If the overrides have no effect, check that LGEE's generator-range takeover is enabled and review the game log for `[LiveWireLGEEAdapter]` warnings.
- If the adapter reports unsupported coverage APIs, update LGEE to a version compatible with Build 42.21.

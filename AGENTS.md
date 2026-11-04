# Project Guidelines

## Project scope

- This repository contains a standalone Project Zomboid Build 42.21 compatibility mod for LiveWire (`batman_LiveWire`) and LG Extended Electricity (`LGExtendedElectricity`).
- Keep all integration code and metadata inside this adapter. Do not edit or require patches to either upstream mod.
- Preserve the adapter's own mod ID, Lua namespace, and declared dependency IDs.
- Keep shipped files focused on the adapter; do not add unrelated example-mod scripts or assets.

## Compatibility behavior

- Without LGEE's generator-range takeover, preserve LiveWire's original behavior and range functions.
- When takeover is active and the required LGEE APIs are available, use LiveWire's configured horizontal radius and vertical range. The adapter's `0` sandbox overrides mean the vanilla defaults: 20 tiles and 3 floors. Positive values override each range independently.
- Do not change the global vanilla generator radius to work around LGEE's takeover, and do not turn LiveWire's radius-based coverage into whole-building coverage.
- Check required APIs before wrapping functions. If integration APIs are missing or unsupported, log a useful warning and retain the original LiveWire behavior.

## LGEE relay integration

- Let LGEE own relay reconciliation, persistence, synchronization, and cleanup. Add LiveWire coverage only to LGEE's in-progress relay diff through its supported APIs.
- Do not mutate `LGEE.relays`, call `LGEE.setRelays()` directly, or add/remove engine registrations outside LGEE's diff lifecycle.
- Plan coverage from LiveWire's active anchor state and use LGEE's coverage planners. Only include real squares that do not already contain a generator.
- Keep overlapping LiveWire inverters and LGEE relays functional; removing or changing one source must not remove coverage still contributed by another.
- Suppress LiveWire's direct anchor application only while takeover and the necessary integration APIs are verified. Preserve its normal path otherwise.
- Handle authority, anchor lifecycle, range changes, chunk loads, and sweeps without mutating a relay diff after advancement begins.

## Validation

- For behavior changes, verify fallback behavior with the adapter disabled, takeover inactive, and required APIs unavailable.
- Verify takeover behavior at horizontal and vertical coverage boundaries, including independent overrides and `0` defaults.
- Check inverter activation, deactivation, movement/removal, overlapping coverage, generator collisions, chunk reload, and multiplayer authority where applicable.
- Update the README when installation, supported versions, settings, or user-visible behavior changes.
- Run applicable project checks. If the repository has no automated test or build command for the mod, state what could not be verified and provide focused manual verification steps.

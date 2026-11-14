# RomM 5.4.1 in a lab: what the API really does, and the save-sync design it forces

**Status:** investigation, nothing implemented. Two runs (2026-11-13) of RomM 5.4.1 + MariaDB 11.4 in Docker, bound to
localhost, with a library of random bytes under game-like names (no real game), no metadata provider, two simulated
devices and a second `viewer` account. Read with [remote-catalogue-plan.md](remote-catalogue-plan.md) (the plan) and
[romm-behaviour.md](romm-behaviour.md) (what players are promised). Where this file and the plan differ, this file is
newer.

## 1. Pairing

- `POST /api/auth/device/init` (no auth; device identifier, name, client, platform, version, requested scopes) →
  8-character `user_code`, `verification_path_complete` = `/pair/device?user_code=…`, `expires_in` 600, `interval` 5.
- Polling `POST /api/auth/device/token`: `400 authorization_pending` until approved, `slow_down` when faster than
  `interval`, `access_denied` after a refusal, then `200` with `access_token`, `device_id`, granted `scopes`,
  `expires_at: null`. A second poll after success: `expired_token` (one-shot).
- The device is registered at approval (`/api/devices`, `sync_mode: api`): no separate device call.
- Scopes to ask: `me.read platforms.read roms.read roms.user.read roms.user.write assets.read assets.write devices.read
  devices.write firmware.read`. The approval page may grant fewer; read what comes back and turn off what is missing.
- A `viewer` account holds all of these, sees every game, and only its own saves.
- RomM 5.5 (development branch): a token naming another device than its own is refused (`403`).

## 2. Catalogue

- Platforms: `slug` (stable, IGDB-derived) + `ss_id`. Read: `psx` 57, `ps2` 58, `psp` 61, `ngc` 13, `gba` 12, `gb` 9,
  `gbc` 10, `nes` 3, `snes` 4, `n64` 14, `nds` 15, `dc` 23, `saturn` 22, `sms` 2, `genesis` 1, `3do` 29, `switch` 225,
  `psvita` 62, `wonderswan` 45. Never `fs_slug` (the admin's folder name).
- **Two folders of one console** (`genesis/` and `megadrive/`, `sms/` and `mastersystem/`) are **two platforms with
  the same `slug`**: map slug → console many-to-one and merge.
- An unknown folder (`ws/`) comes back with `slug` = folder name, no ids, `is_identified=false`: an unknown console.
- `GET /api/roms?platform_ids=…&limit=200&with_char_index=false&with_filter_values=false&order_by=id`: ~2.4 KB per game
  (88 fields); a 2 002-game console is 5 MB, ~1 s on a PC. **`files` is empty in lists**: per-file data (id, name,
  size, md5) only from `GET /api/roms/{id}`.
- `updated_after=` works; `GET /api/roms/identifiers` lists every visible id (9 KB for 2 026 games): deletions are a
  set difference.
- Loose multi-disc files (`… (Disc 1).chd`, `… (Disc 2).chd`) are separate games with empty `sibling_roms` when no
  metadata provider matched them: group them with the scan's disc rule.

## 3. Covers

- `path_cover_small` / `path_cover_large` are static files under `/assets/romm/resources/roms/<platform>/<rom>/cover/`,
  served **without the token**, `Cache-Control: immutable`, versioned by `?ts=<date time>` **with an unencoded space**:
  percent-encode before requesting. Small = 0.4 of large (240×320 for a 600×800 upload). Format as stored.
- RomM fetches covers itself from the providers its owner configured; a client needs no source of its own.

## 4. Downloads

- Single file: `GET /api/roms/{id}/content/{name}` served by nginx with `Content-Length`, `ETag`, `Last-Modified`,
  `Accept-Ranges`; `206` on a range; a 30 MB file resumed byte-identical. The name in the URL is not checked. No
  token: `401`.
- **Multi-file games without zip:** `…/content/{name}?file_ids=<file id>` serves one file of the game with length and
  ranges. Download each into `<console folder>/<game name>/`. RomM's zip path (first answer streamed with
  `Content-Length: 0`, cached afterwards, stored entries, an `.m3u` added) is not needed.
- `202 Retry-After` only exists for `?format=` conversions.
- BIOS: `GET /api/firmware?platform_id=` (file name, size, md5, `is_verified`), content served like a game.
- Scans: `POST /api/tasks/scan` (scope `tasks.run`, one at a time, `409` while one runs) or the live channel RomM's web page uses.

## 5. Save sync: what RomM does

Two devices A and B, one game, slot `autosave`:

| Scenario | RomM's `negotiate` answer | Effect if followed |
|---|---|---|
| A uploads, B has nothing | B: `download` | right |
| B uploads, A unchanged | A: `download` ("no sync history") | right, by luck of A's file time |
| A played offline, B uploaded meanwhile, A's file time **older** than its last sync | `download` | A's progress overwritten |
| Same, A's file time **newer** | `upload` | B's progress buried |
| A uploads anyway with `device_id` | `409 Slot has a newer save since your last sync` | right: the reliable guard |
| A uploads with `overwrite=true`, then B (still on its version) negotiates | `upload` | B buries A's choice |

The real conflict is never reported. Cause (`handler/sync/comparison.py`): every upload is a new save row; the
device's baseline points at the old row, so on the new head the device has "no sync history" and the decision falls
back to comparing clocks.

Other facts:
- **`device_id` must be passed explicitly on upload and download.** Only `negotiate` infers it from the token. An
  upload without it gets no `409` check and records no baseline, silently.
- Downloads are `optimistic=true` by default (the server records "this device has it" before a byte lands): use
  `optimistic=false`, write, verify, then `POST /api/saves/{id}/downloaded`.
- `GET /api/saves?rom_ids=…&slot=autosave`: every version (~0.9 KB each, no paging, not in time order), each with
  `content_hash`, `updated_at`, `origin_device_id`, `device_syncs`. `GET /api/saves/summary?rom_id=`: count and head
  per slot. `GET /api/saves/identifiers`: every save id (a new id = a new version somewhere).
- `negotiate` with no client saves returns nothing for games already synced: not a listing.
- Play sessions sent in `POST /api/sync/sessions/{id}/complete` are stored; the game's `last_played` updates.
- RomM stores the md5 the client sends; identical bytes, same hash.
- Deleting saves on the web page (`POST /api/saves/delete`) leaves no tombstone: delete the head and the previous
  version becomes head; delete all and the slot is empty; in both cases RomM tells a device still holding the save to
  upload it again.
- RomM's browser player saves to slot `autosave`, `emulator` = the EmulatorJS core id (`mgba`, `snes9x`,
  `pcsx_rearmed`, `mupen64plus_next`…), file `<rom>.srm`.

## 6. Save sync: the design this forces

Cartouche decides; RomM stores, lists and refuses.

- **Base** per (server game, slot): the version id and hash last agreed with the server.
- **Decision** (pure function, property-tested): `local changed` = local hash ≠ base hash; `head changed` = newest
  version's id or hash ≠ base. Neither: nothing. Local only: push. Head only: pull. Both: conflict (unless local = head).
  No base and local ≠ head: conflict, never a silent overwrite.
- **Push:** `POST /api/saves?rom_id&slot&emulator&device_id&content_hash`. `409`: list again, decide again. Success:
  new base = returned id and hash.
- **Pull:** copy the local save aside, `GET /api/saves/{id}/content?optimistic=false&device_id=…`, write to a temporary
  file, check md5, rename over, `POST …/downloaded`. New base = that version.
- **Conflict:** the player picks, with device (`origin_device_id` → device name), date and play time on each side;
  without a choice, this device's save is played and pushed with `overwrite=true`; the other stays in RomM's history.
- **Deletions on the server:** head moved back to an older version and local unchanged = a rollback, pull it (local
  copy kept aside). Slot emptied and local unchanged = removed: keep the local save, drop the base, push again only once
  it changes.
- **Other emulators' versions:** a table of format families with pure converters — raw battery (GB, GBC, GBA, NES,
  SNES, Mega Drive, Master System; libretro `.srm` is the raw file), PS1 card image (rename), DS (DeSmuME `.dsv`
  trailer), N64 (libretro's combined `.srm` vs separate `.eep/.sra/.fla`: split or join). PS2, PSP, GameCube, Wii, 3DS,
  Switch: within one emulator family only. A version that cannot be converted is never pulled over a local save.
- **Memory cards** game by game: a card is read as one save folder per game serial; each game is its own unit (a zip
  of its folder on RomM: RomM hashes a zip by its sorted entries, so a rebuilt zip matches). Folders that changed during
  a session belong to the game Cartouche launched; RomM's `save_target` (read from uncompressed game binaries) is a
  second key; unmatched folders stay local. PCSX2-style folder cards (offered by ARMSX2) need no format decoding; PS2
  file cards follow the public PS2 memory card file-system description (ECC, FAT): writes only with the emulator
  closed, a copy first, a read-back after.
- **When:** check when the shelf settles on a game (no wait at launch), push on return once the save stops changing,
  re-check at every resume and launch (late writers), library-wide change check with `GET /api/saves/identifiers`.
- **Play sessions:** `negotiate` + `complete` only to carry them.
- **Formal model:** a `saves` zone (prefetch vs launch, return vs late write, resume, offline, two devices, a conflict
  chosen while the server moved again).

## 7. Still to check (needs a real server or a device)

- Real covers from a metadata provider (format, weight); RomM reached over a tailnet (`tailscale serve` HTTPS and plain
  HTTP), and how fast "unreachable" shows when the tunnel is down.
- On an Android handheld: where each emulator keeps its saves, persisted write grants on Dolphin's and RetroArch's
  document providers, real PS1/PS2 cards, parsing a 5 MB page, md5 of a 4 GB file.

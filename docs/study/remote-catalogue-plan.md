# A RomM server on the shelf: feasibility and a first technical plan

**Status:** investigation. Nothing here is implemented. It follows [the study](remote-catalogue.md), corrects it
where a primary source disagreed, and turns it into a first technical plan with the decisions it needs. Sources were
read on 2026-11-12: RomM's repository and documentation (5.4.1 stable, 5.5.0-alpha.1), ROMarr, ROMarrNG, SeerrNG.

**Newer:** [romm-lab-findings.md](romm-lab-findings.md) (RomM 5.4.1 run in a lab, 2026-11-13) supersedes this plan
where they differ: multi-file games download file by file (no zip), save sync is decided by Cartouche (RomM's own
answer falls back to clocks), and save sync plus BIOS ship with the first release of RomM support.
[romm-behaviour.md](romm-behaviour.md) lists what players are promised.

Scope decided: **RomM only.** The *arr half (ROMarr, ROMarrNG, SeerrNG) is kept as a note at the end, not a target.

## 1. The need

The library lives on a self-hosted RomM. The handheld is a window onto it:

1. **See** the server's games for each supported console, including the ones not on the device.
2. **Get** one with a press: it downloads in the background, keeps going while another game is played, and once it
   lands it is an ordinary game (its disc or cartridge, its label, it launches).

What matters more than the API:

- **A game that is not on the device is a new kind of thing.** Today a `Game` cannot exist without a local file
  (`NonEmptyList<Disc>`, each with a `ListedFile`), and every rule that launches, labels or groups a game leans on it.
- **The download target is the hard part, not the HTTP.** Cartouche never writes into a game folder (INV-02, read-only
  grants on the picked folders).
- **The shelf may be a better home than a new page.** The ring, the shelf, search and filters already scale to
  thousands of games; a remote game could be one more kind of shelf entry. Not decided (D1).

## 2. Corrections to the study

| Study | Checked fact | Consequence |
|---|---|---|
| ROMarr publishes an integration API | It is the fork **ROMarrNG** that has `POST/GET /api/v1/integration/requests` (idempotent on `externalRequestId`, `X-Api-Key`); upstream ROMarr has none. The fork is young, one maintainer | Requests stay out of scope |
| Log in with `POST /api/token` or Basic | RomM has **client tokens** (`rmm_…`, scoped, revocable, no expiry by default) and an RFC 8628 **device flow** (`/api/auth/device/init`, poll `/api/auth/device/token`, the code approved in RomM's web page), merged in June 2026; older servers: an 8-digit code made in the web page, exchanged by `POST /api/client-tokens/exchange` | No password and no long token typed on a handheld |
| Download one file with progress | Multi-file games (cue/bin, several discs) come as **one zip**: streamed without `Content-Length`, or a cached zip (resumable, with a length) after the server prepares it (`202 Retry-After`, minutes for large games); single files are a redirect served by the web server, Range support unverified | A HEAD first, a "server is preparing" state, streamed extraction, a hash check per file |
| A card with genre, players, date, rating, summary | Cartouche only shows data it knows for sure | **Decided: no third-party metadata** (D4) |
| A box front per game | Box art is not needed to start | **Decided: one template box per console, nothing printed on it for now** (D2) |
| The plugin's HTTP client fits | The `Http` port has no headers (`Fetch.kt`), files are capped at 16 MiB, Godot cannot cancel a download | A separate transfer path; headers on the port |
| Covers come with the list | True, but the list is heavy: about fourteen provider metadata blocks per game, and the `with_*` indexes default on | Small pages, indexes off, `updated_after` for changes, a compact local copy |

Also found: RomM's own Android client exists (Argosy, GPL-3.0). Cartouche's case is its shelf; nothing is taken from
that code.

## 3. Decisions

**Decided**

- **D2. A game not on the device is drawn as a box:** one template box per format (DVD keep case for PS2, GameCube,
  Wii, Xbox, Xbox 360; jewel case for PS1; card box for cartridges), nothing printed on it for now. Local games keep
  their discs and cartridges. This narrows the project's earlier choice of disc scans only, never box art, to games
  on the device.
- **D4. No third-party metadata:** title, region, size, number of discs, where the game is.
- **Scope: RomM only.**
- **D3. A download is written into the console's own folder,** not into a second folder: a player keeps one tree.
  At the first download for a console, Cartouche asks for write access and opens the system picker on that folder;
  players who never download change nothing. A console with several folders: the first one, or chosen at download.
- **D9. Every console of the server is listed** (`GET /api/platforms`, those holding at least one game). The ones
  Cartouche cannot take yet are greyed, each with its own message when tried: a console Cartouche does not support
  yet, or a supported console not added on the device (add it first). Only their games are never downloadable.

**Open**

| | What it changes | Options | Leaning |
|---|---|---|---|
| D1 | Where server games appear | (a) on the console's shelf with the local games, a filter choosing "on the device / on the server / all"; (b) a separate page per console | open |
| D5 | Plain HTTP to a home server | Android blocks cleartext by default; a network config can allow it by domain name but not by IP range | see §4.9 |
| D7 | Downloads while playing | A multi-GB download must survive the emulator taking the screen; Android then shows a notification for as long as it runs | a foreground download, one game at a time, a queue |
| D10 | A server game no player of that console opens (say a `.chd`) | shown greyed and not downloadable, or hidden | greyed, with the reason |
| D11 | A downloaded game counts as new (dot and +N) | yes / no | yes |

Out of scope, noted: save and state sync (RomM has a device sync protocol), BIOS from the server (`/api/firmware`),
several servers.

## 4. Technical design

### 4.1 Layers

- **Core (`kotlin/core`, pure), a new `remote` package:** `ServerAddress` (a parsed URL), `RommPlatform`, `RommRom`,
  `RommFile` read tolerantly; the platform mapping; the server's snapshot; the shelf entries; matching a server game to
  a local one; the transfer state machine; request descriptions (method, path, query, headers as values) and response
  parsing. No IO.
- **Plugin (`kotlin/android`):** HTTP with headers, the transfer service, writing through SAF, the token's storage,
  the snapshot file, the wire.
- **Godot:** the box, the pairing page, the download state on a game, the filter. Nothing about the server is decided
  there.
- Requests described as values in the core keep a desktop build open: only the IO differs there.

### 4.2 Types (sketch, names to settle)

```kotlin
@JvmInline value class RemoteRomId(val value: Long)
data class RemoteGame(id: RemoteRomId, platform: PlatformId, title: String, regions, sizeBytes: Long,
                      files: NonEmptyList<RemoteFile>, playable: Playable)
sealed interface ShelfEntry {
  data class Here(val game: Game) : ShelfEntry          // today's only case
  data class OnServer(val game: RemoteGame) : ShelfEntry
  data class Arriving(val game: RemoteGame, val transfer: Transfer) : ShelfEntry
}
sealed interface Transfer { Queued; Preparing(retryAt); Running(bytes, total: Option<Long>); Verifying;
                            Placing; Stopped(reason, resumeAt: Option<Long>); Failed(TransferFailure) }
```

`Game` is untouched, so every rule that needs a file keeps its guarantee. If D1 picks the shelf, the shelf, search
and filters move from `Game` to `ShelfEntry`: the widest change of the plan, to map before deciding.

### 4.3 Platform mapping

Data, in `profiles.json` per platform: `"romm": ["ps2"]` (RomM's canonical `slug`), RomM's `ss_id` against our
`screenScraperSystem` as a fallback. Never `fs_slug`, which is the server's folder name. A new console adds one line.
Unmapped platforms are kept as "not in Cartouche", never downloadable (D9).

### 4.4 Catalogue

- `GET /api/platforms`, then `GET /api/roms` per mapped platform: pages of 200, every `with_*` index off,
  `with_files=true`, ordered by id. Field names checked against the instance's `/openapi.json`; fixtures recorded
  from several RomM versions, since the API moves every few weeks.
- Stored compact (`remote/catalogue.json`, versioned JSON): id, title, platform, size, files (name, size, CRC, SHA-1),
  `updated_at`. Never the provider blocks.
- Refreshed when the app comes back to the screen, next to the folders' re-read: `updated_after` for changes; when the
  server's `total` differs, a sweep of ids finds deletions. Offline, the snapshot stays and downloads are off.
- With no server paired: no work and no file read at start.

### 4.5 Matching server and device

- A downloaded game: a record written when it is placed (server id ↔ written documents, sizes, hashes).
- A game copied by hand: platform + file name + size. Local files are never hashed (a 4 GB image per game at scan time
  is out of the question on a handheld).
- Property tests: each game listed once, a local game never hidden, an unsupported console never listed.

### 4.6 Transfers

- **HTTP:** headers on the `Http` port. A separate `Transfer` port streams to an `OutputStream` with no cap: HEAD for
  the size when given; `Range: bytes=n-` to resume, accepted only on `206` with a matching `Content-Range`, else from
  zero; `202 Retry-After` becomes `Preparing`; `Authorization` is dropped on a redirect to another origin.
- **Service:** one foreground service (`dataSync`: Android 14 needs the type and its permission, Android 15 caps it at
  six hours a day, `onTimeout` stops at the current offset). One game at a time, a queue persisted
  (`remote/queue.json`) and picked up again at start, a notification with progress and cancel; the download still runs
  if notifications are refused. WorkManager is not used: one more dependency, and it would still need a foreground
  service for multi-GB files.
- **Writing (D3):** into the console's folder (write access asked at its first download), first as `<name>.part`, which the scan skips. Bytes through
  `openOutputStream(uri, "wa")` so a stop can resume. Check: size, then CRC32 against the server's `crc_hash` (cheap
  on a weak CPU; SHA-1 of 4 GB is not). Then `renameDocument` to the final name. An existing name is never
  overwritten. Free space read from the document root first, a plain message when it is short.
- **Zip:** extracted while streaming into `<platform>/<game>/`, each entry as `.part` then renamed together; entry
  names cleaned (no `..`, no absolute path); each file checked against its own hash. A streamed zip cannot resume: a
  stop restarts it, unless the server offers the cached zip with a length. The scan already groups a sub-folder (m3u,
  cue, discs).
- **Landing:** a re-read of that one console; the game becomes `Here`, its label looked up as for any game.
- **To Godot:** a `TransferChange` wire type, paced at 10 Hz like the art progress; `download` and `cancel` answered
  on `answered`.

### 4.7 Pairing

- The address typed with the existing pad keyboard (`GamepadKeyboard`, which needs `: / . -` and digits), parsed by
  `ServerAddress`.
- `GET /api/heartbeat` for the version, then the device flow (show the code and the web page's address, poll every
  `interval`, handle `slow_down`, `expired_token`, `access_denied`), or the 8-digit code on older servers.
- Scopes asked: `me.read platforms.read roms.read` (no write, no saves).
- Leaving the pairing page stops the poll.

### 4.8 The token

- Stored in app-private storage, encrypted with an Android Keystore key (AES-GCM, not exportable), the file excluded
  from backups. Sent only as `Authorization: Bearer` to the paired origin. Never in a URL, a trace or the wire to
  Godot, which only knows "paired / not paired / refused".
- A `401`: "to pair again", downloads stopped, catalogue kept.

### 4.9 Network

- Home servers are often plain `http://` on a LAN address. Android allows cleartext per domain name, not per IP range:
  an address like `192.168.x.y` needs cleartext allowed in general.
- Over a private overlay network such as Tailscale, traffic is already encrypted by the tunnel. Its HTTPS (`tailscale
  serve`, a real certificate on the machine's `ts.net` name) needs nothing special in the app; plain HTTP to the
  `ts.net` name can be allowed by domain. When the tunnel is off on the handheld, the server is simply unreachable:
  a plain message, the snapshot kept.
- A self-signed certificate (accept its fingerprint once) is a later step.
- A login proxy in front of RomM (forward auth) is likely to refuse an API client; not supported.

### 4.10 Invariants (wording to agree)

- INV-02 reworded: Cartouche only adds files it downloaded into a game folder, after the player gave write access to
  that folder; it never modifies, overwrites or deletes a file there.
- A partial or unverified download is never a game of the library.
- A download never overwrites or deletes a file Cartouche did not create.
- INV-19 extended: the server token is stored encrypted in private storage only, sent only as a header to the paired
  server, never in a URL, trace or wire.
- Each game is listed once; a game on the device is never hidden.
- A server game of a console Cartouche does not support, or has not added, is never downloaded.

### 4.11 Tests

- Core: property tests (parsing never throws on any JSON, fixtures from several RomM versions; matching; the
  entries; the transfer machine), an example per decision.
- Plugin: Robolectric with the fake documents provider for writing, renaming and the free-space refusal; a local JDK
  `HttpServer` (no dependency) for Range, 206/200, 202, redirects, 401, zip, a cut body.
- The order of events in a transfer (pause and resume, the process killed while writing, cancel during the rename,
  a folder re-read while a `.part` exists, the same game asked twice, the server deleting it) is checked as a model
  before the code, like the launch and the art downloads.
- A real RomM in Docker with freely redistributable homebrew only, for the desktop run and the device.
- Measured on a device: a snapshot of 10 000 server games (load time, memory), a shelf with 2 000 boxes, throughput
  and CPU while downloading, cold start with and without a server.

## 5. Order

1. **Server games as entries, no network:** `ShelfEntry` (or the page, per D1) with a fake snapshot from the desktop
   stand-in, the template box.
2. **Pairing and catalogue, read-only:** address, device flow, token, sync, offline states.
3. **Download:** the write access asked per console folder, the service, the queue, resume, zip, verification, landing.

The first two can be seen before any file is written.

## 6. Feasibility

| Part | Verdict | Why |
|---|---|---|
| Pairing without a keyboard | feasible, low risk | device flow and 8-digit code exist; the pad keyboard exists |
| Catalogue, read-only | feasible, low risk | paged, incremental; the risk is API drift |
| Server games among local ones | feasible, the largest change | `Game` needs a file: a new entry type across shelf, search, filters |
| Template box per console | feasible, model work | one mesh per format, no art |
| One-file downloads | feasible, medium risk | a write grant per console folder, a foreground service; resume depends on Range |
| Multi-file downloads | feasible, the riskiest | streamed zip with no length, server preparation in minutes, restart on stop |
| Network | no blocker | cleartext policy and overlay networks covered in §4.9 |

## 7. To check on a real RomM (Docker, homebrew)

| Question | How |
|---|---|
| Absolute URL of a cover, and whether it needs the token (for later box art) | fetch `path_cover_small` under the assets prefix, with and without the header |
| Range on a single file | a ranged request on `/content/{file}`, expect 206 |
| Zip: length, compression, the 202 wait | download a cue/bin game twice |
| First RomM version with the device flow | `/api/heartbeat`, release notes, a try |
| `slug` of the twelve supported consoles | `GET /api/platforms`, one folder each |
| Size of a 200-game page with indexes off | measure |
| HTTPS through `tailscale serve`, plain HTTP on the tailnet name, the tunnel off | from an Android handheld |

## Note: requests through an *arr stack

Not planned. If it comes back: ROMarrNG's integration route behind one port; the catalogue of games not owned taken
from the reference title lists the app already embeds (twelve consoles, names an indexer search matches well), minus
what the server holds; no IGDB, no SeerrNG.

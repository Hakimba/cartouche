# Asking the home server for a game: an *arr behind RomM (study and first plan)

**Status:** investigation, nothing implemented; R1–R4 decided on 2026-11-15 (§7). Builds on RomM support
([remote-catalogue-plan.md](remote-catalogue-plan.md), [romm-lab-findings.md](romm-lab-findings.md)): this feature
only adds "ask for a game"; browsing and downloading stay RomM's. Sources read on 2026-11-14 (shallow clones):
BlizzHacker/romarr 1.9.3, snapetech-org/ROMarrNG 0.14.21, snapetech-org/seerrng, Doezer/Questarr, JeremiahM37/gamarr,
RiDDiX/RetroArr, gamarr-app/Gamarr. ROMarr 1.9.3 and ROMarrNG 0.14.21 were then run next to the lab RomM 5.4.1 (§8).

## 1. The need

From the handheld, on a console, the player sees games they do not have, asks the home server for one, follows the
request, and once the game is in RomM it comes down to the handheld like any RomM game. The handheld never talks to an
indexer or a download client.

```
Cartouche ──request──► acquisition service ──► indexers / download client ──► RomM's library folder
    ▲                         │ status                                        │ rescan
    └──── download (RomM) ◄───┴──────────────── RomM ◄─────────────────────────┘
```

## 2. What exists

| Project | What it is today | Retro consoles | RomM | Client API | Requests and status | Licence | Notes |
|---|---|---|---|---|---|---|---|
| **ROMarr** (upstream) | ROM acquisition: indexers (Prowlarr, Torznab, Newznab…) → download client → DAT check → import → RomM rescan | yes, ~78 platforms, aliases accept RomM slugs | imports into RomM's layout, asks RomM to scan that folder | `/api/v1/integration/info`, `POST/GET /requests`, `GET /requests/current`; `X-Api-Key`, `Bearer` or `?apikey=` | searching → dispatching → downloading → available, or failed / cancelled | MIT | very fast moving (4 releases on 2026-11-13); one owner key; its author also ships a RomM player app ("Cartridge", Windows and Xbox) that uses this same contract |
| **ROMarrNG** | diverging fork of ROMarr | yes | same, but see §8 (scan) | upstream routes + `ping`, `catalog/*`, `requests/{id}`, `/cancel`, `/retry`, `/assets`; **a second key limited to the integration routes**; OpenAPI served | accepted → searching → dispatching → downloading → available, failed / cancelled; failure codes; allowed actions per request | MIT | one main author, started 2026-10-21 |
| **SeerrNG** | Seerr fork: requests for many media; games are forwarded to ROMarr(NG) (retro) or Questarr(NG) (PC) | through ROMarrNG | indirect | `/api/v1/request/software/*`; service key acts as user 1; per-user keys cannot reach game routes, so a player-scoped client needs a login session | pending → approved → searching → downloading → importing → available; declined / failed / cancelled; approvals, quotas | MIT | worth it only for a household with approvals |
| Questarr | PC games *arr (IGDB) | mostly PC | folder + rescan | scoped `qsr_` keys, `POST games/request` | wanted / owned… | GPL-3.0 | out of scope (PC) |
| gamarr (Go) | indexer search + own request queue | PC + retro | folder placement only | `/api/requests`, one admin key | pending → … → completed | MIT | no catalogue, no DAT check |
| RetroArr, Gamarr | Radarr-style library managers | some | none | no request object | — | MIT / GPL-3.0 | out of scope |

**Target: ROMarr's integration contract**, the common ground of ROMarr and ROMarrNG. It is the only one built for
retro ROMs, checked against DATs, landing in RomM's own layout and triggering RomM's scan: exactly the loop above.
ROMarrNG's extras are used when its `info` answer says so. SeerrNG stays optional; the others are out of scope.

## 3. The contract Cartouche would use (read in the code, then run)

Common to ROMarr and ROMarrNG:

```text
GET  /api/v1/integration/info              name, version (+ apiVersion, capabilities on NG)
POST /api/v1/integration/requests          {name, platform, externalRequestId}  -> 202 + the request
GET  /api/v1/integration/requests          every request made through the integration
GET  /api/v1/integration/requests/current  the latest one
auth: X-Api-Key header (never ?apikey=)
request view: {request_id, name, platform, status, assets[], error}   (NG: more fields, no assets[])
```

ROMarrNG only, detected by `capabilities` in `info`:

```text
GET  /api/v1/integration/requests/{id}         one request: status, stage, percent, failureCode, failureMessage,
                                               deliverable, actions {retry, cancel, cancelReason}
POST /api/v1/integration/requests/{id}/cancel  while searching; refused once a download client has it
POST /api/v1/integration/requests/{id}/retry   after a failure
GET  /api/v1/integration/requests/{id}/assets  file names, sizes, DAT verification
```

- `externalRequestId` (≤ 64 characters) makes a repeated POST return the same request, never a second download:
  Cartouche sends its own id and can always re-send after a lost answer.
- No field for region, language or version: those come from the owner's settings in ROMarr. But the name is matched
  word by word (read in `selection.py`: every word of more than two letters of the request must be in the release's
  title), so a name with its region (`Super Metroid (Europe)`) only accepts European releases; a two-letter language tag
  (`Fr`) is ignored, a full word (`France`) is not. The scorer also lowers releases it reads as not English or fan-translated, whatever the
  request says. Cartouche can therefore send the region the player picked inside the name.
- `platform` is the RomM slug Cartouche already maps (`nes`, `gbc`, `psx`, `genesis`…); an unknown one fails at once
  with `unknown platform`.
- `available` means imported under the library root. ROMarr lists the files as paths inside its container
  (`/roms/nes/Lab Quest (World).nes`); NG gives file names on `/assets`. Either way the **file name** finds the game in
  RomM (`fs_name`, on the RomM platform of that slug).
- No push to clients (notifications go to the owner's phone): Cartouche reads the state while a request is open and
  the app is in front, and once at each return to the app.

## 4. Where "games I don't have" come from

| Source | What it gives | Cost | Fit |
|---|---|---|---|
| **Cartouche's reference lists** (`app/data/titles/`, already shipped: every Redump or No-Intro dump per console, one line per dump, so regions, revisions, demos and betas each count) | the exact dump names ROMarr's DAT check uses | nothing new | best for **matching** the name sent |
| **Cartouche's art extracts** (`app/data/art/`, from the LaunchBox dump: one line per game, its names and disc/cartridge label scans) | one entry per game, with the label | nothing new | the label on a card |
| ROMarrNG's DAT catalogue (`catalog/dat/*`) | No-Intro/Redump names: exactly what ROMarr matches and verifies | NG only, needs DAT files loaded on the server (none by default: "No DAT catalog is loaded") | best for **matching** when present |
| IGDB through ROMarrNG, shown by SeerrNG | per game: title, summary, cover, release date, genres, rating, developers, screenshots, videos (read in SeerrNG's `SoftwareCatalogGame` and ROMarrNG's IGDB fields) | ROMarrNG + Twitch keys on the server; SeerrNG only displays what ROMarrNG returns | same kind of data as LaunchBox below, behind two services |

**The visual catalogue (what a Seerr-like page needs) is already in the LaunchBox database Cartouche builds its lists
from.** `Metadata.xml` (LaunchBox's public metadata dump, 108 MB zipped, 2026-10-12) gives per game an overview, release
date, developer, publisher, genres, community rating, max players, a video link, and images by type: box front and
back, 3D box, cartridge, gameplay and title screenshots, clear logo, background fanart. Images are served without a
key from LaunchBox's image host (the one the label scans already come from). Coverage measured on that dump:

| Console | Games | Overview | Box front | Gameplay screenshot | Clear logo | Background | Video |
|---|---|---|---|---|---|---|---|
| NES | 3 845 | 95 % | 69 % | 85 % | 78 % | 27 % | 56 % |
| SNES | 2 959 | 97 % | 78 % | 95 % | 85 % | 58 % | 42 % |
| N64 | 804 | 98 % | 70 % | 83 % | 84 % | 46 % | 69 % |
| Game Boy | 1 609 | 93 % | 85 % | 82 % | 83 % | 27 % | 35 % |
| Game Boy Color | 1 571 | 94 % | 81 % | 85 % | 78 % | 23 % | 32 % |
| Game Boy Advance | 2 369 | 98 % | 88 % | 83 % | 82 % | 31 % | 35 % |
| DS | 4 576 | 97 % | 97 % | 44 % | 64 % | 19 % | 23 % |
| GameCube | 811 | 98 % | 94 % | 45 % | 90 % | 54 % | 54 % |
| Wii | 2 297 | 98 % | 95 % | 51 % | 91 % | 28 % | 41 % |
| Switch | 6 636 | 98 % | 63 % | 56 % | 59 % | 31 % | 47 % |
| PlayStation | 4 650 | 94 % | 97 % | 68 % | 87 % | 34 % | 27 % |
| PlayStation 2 | 4 784 | 98 % | 98 % | 48 % | 67 % | 28 % | 42 % |
| PSP | 2 041 | 95 % | 97 % | 51 % | 61 % | 26 % | 34 % |
| PS Vita | 1 190 | 88 % | 96 % | 63 % | 52 % | 29 % | 28 % |
| Master System | 555 | 95 % | 78 % | 93 % | 86 % | 41 % | 60 % |
| Mega Drive | 2 141 | 91 % | 62 % | 91 % | 80 % | 35 % | 47 % |
| Dreamcast | 914 | 90 % | 96 % | 49 % | 86 % | 43 % | 43 % |

A game is counted once whatever the number of regional images. Images are full resolution with no thumbnail
variant (box fronts 300–800 KB): the page fetches them on demand and keeps a small cache.

LaunchBox counts games, the reference lists count dumps (PlayStation: 4 650 games, 10 086 Redump lines). The page
shows LaunchBox's games; the request sends the matching dump name (LaunchBox's `Files.xml` and the art-matching rules
the app already has tie a game to its dump names).

Proposal: the catalogue page is built from LaunchBox's data (text extract per console shipped or fetched once,
images on demand), minus the player's games, with each game marked "in RomM" (download), "asked" (follow) or nothing
(ask); a game RomM already has is never asked (§8). The name sent is the list's; when NG has a DAT catalogue, the
DAT name. SeerrNG brings nothing visual on top; it stays the optional route for approvals and quotas.

## 5. Design sketch

- **Settings:** a second server row "Requests" (address + key, and a "Test" button like RomM's row), next to RomM. No pairing flow on either service: the
  key is typed with the pad keyboard or pasted once. Stored like RomM's token (encrypted, private, header only).
- **Which key:** on ROMarrNG, its integration-only key (it opens the request routes and nothing else: settings,
  indexers and queue answer `401`). On upstream ROMarr, the only key is the owner key; the settings say so plainly.
- **Page (D1: separate from the shelf):** an entry kind next to `OnServer` / `Arriving`: `Asked(title, console, state)`, drawn with the game's
  label from Cartouche's lists. States shown: searching, downloading on the server, waiting for RomM, ready to download
  (or downloading here), not found (with the reason; NG: "try again"), cancelled (NG: "cancel" while searching).
- **Before asking:** the game must not already be in RomM (by name on that console) and must not already be asked by
  this player (open request for the same name and console). The server does not prevent either (§8).
- **Arrival:** when a request turns `available`, Cartouche re-reads RomM's games of that console until the file name
  appears, then marks it "ready" or downloads it (R3). If it does not appear, the entry says "on the server, waiting for
  RomM's scan"; RomM's own "rescan on file change" option or its nightly scan brings it.
- **Also arrival without the server saying so:** a request that failed, then found later by ROMarr's own Wanted search,
  is not marked `available` (the later download is not linked to the request): any asked game that shows up in RomM
  counts as arrived.
- **Stuck:** a request still `downloading` after a long time (6 h) is shown as "stuck on the server" with its date; a
  new request for the same game is offered only after the player confirms.
- **Core:** the request view parsed tolerantly (two shapes, unknown fields ignored); the state as a pure function of
  (server view, RomM catalogue, time); matching by console and file name.
- **Formal model:** a `requests` zone (poll vs app pause/resume, a POST whose answer is lost, the same game asked twice,
  a request turning available before RomM lists the game, the server forgetting a request).
- **Tests:** recorded fixtures of both servers' answers (the lab answers of §8); a local fake server for the plugin.

## 6. Risks

- Both ROMarr and its fork release several times a week and upstream's answer carries no contract version: stay on the
  smallest surface (4 routes + NG's 3 when announced), parse tolerantly, keep fixtures per version.
- ROMarr's single owner key on a handheld (none on NG with its integration key).
- ROMarrNG 0.14.21 does not get RomM 5.4.1 to scan (§8): with NG, an asked game waits for RomM's own scan.

## 7. Decisions (2026-11-15)

| | What it changes | Decided |
|---|---|---|
| R1 | Which service the handheld talks to | the common ROMarr contract; ROMarrNG's extras (cancel, retry, per-request state, limited key) when its `info` announces them; SeerrNG as a second, optional route for households with approvals |
| R2 | Where the missing-games list comes from | Cartouche's per-console lists to browse; the DAT name to ask when ROMarrNG has a DAT catalogue |
| R3 | When an asked game reaches RomM | a setting; default "mark ready", "download it automatically" as the option |
| R4 | The key on the handheld | the owner's own key (the feature is for one's own home server); NG's integration key is suggested when available |

Server games and asked games live on their **own page**, not on the console's shelf (D1 of the RomM plan): the shelf
sketch of §5 becomes that page's entries. Order of work: technical plan finished, then visual prototypes (a design
artifact, then the real pages and animations in the dev tools), then the backend.

## 8. Lab results (2026-11-14)

Setup: RomM 5.4.1 (lab of [romm-lab-findings.md](romm-lab-findings.md)) with a dedicated admin account for the
acquisition service; ROMarr 1.9.3, then ROMarrNG 0.14.21, in Docker on RomM's network; a local stand-in playing a
Newznab indexer and a SABnzbd client (a "download" writes random bytes under the release's name after 8 s; search
answers delayed 0, 2 or 12 s). No real release, no real download.

| Case | ROMarr 1.9.3 | ROMarrNG 0.14.21 |
|---|---|---|
| POST, new game | answers **after** the search (12 s with a 12 s indexer), already `downloading`; `searching` readable meanwhile on `/current` | answers at once (`searching`), search in the background |
| Download → `available` | ~40 s (8 s download + the import sweep), file under `/roms/<slug>/` | ~40 s, `deliverable: true`, `rommPlacement.placed: true` |
| RomM sees the game | `POST /api/tasks/scan` for that folder right after the import; game listed **3 s after** `available` | scan refused (`/api/tasks/run/scan` 404, `scan_library` 400): the game is in the folder but **not in RomM** until RomM scans |
| Same `externalRequestId` again | same request, no new search | same |
| Same game, new id, game already in RomM | **downloads it again**; the import fails (file exists); the request stays `downloading` forever, also after a restart | `available` at once, `deliverable: false`, nothing downloaded |
| Same game asked twice while downloading | two downloads | not run |
| No release | `failed`, error "no usable release among 0 result(s)"; the title goes on ROMarr's Wanted list | `failed`, `failureCode: NO_RELEASE_FOUND`, `actions.retry: true` |
| Unknown platform | `failed`, "unknown platform: 'atari9000'" | not run |
| Cancel | no route | while searching: `cancelled`, nothing handed to the client; after hand-off: refused with `cancelReason` |
| Retry | no route | `409` while not failed; allowed after a failure |
| Restart of the service | requests kept | not run |
| Keys | owner key by header, Bearer or `?apikey=`; wrong key `401` | integration key: integration routes only, header only (`?apikey=` refused); settings and queue `401` |
| `info` | `{name: "Cartridge (ROMarr)", version, supports_*}` | adds `apiVersion: 1`, `capabilities` (cancel, retry, catalogue, DAT catalogue…); `ping` adds `requestContractVersion: 2` |

Still to check with real services: real indexer search times, a real archive (zip, 7z, multi-disc) through import,
DAT verification with loaded DATs, RomM's "rescan on file change" option as the fix for NG's missing scan.

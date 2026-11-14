# Asking the home server for a game: an *arr behind RomM (study and first plan)

**Status:** investigation, nothing implemented, no decision taken yet. Builds on RomM support
([remote-catalogue-plan.md](remote-catalogue-plan.md), [romm-lab-findings.md](romm-lab-findings.md)): this feature
only adds "ask for a game"; browsing and downloading stay RomM's. Sources read on 2026-11-14 (shallow clones, code
only, nothing run): BlizzHacker/romarr 1.9.3, snapetech-org/ROMarrNG, snapetech-org/seerrng, Doezer/Questarr,
JeremiahM37/gamarr, RiDDiX/RetroArr, gamarr-app/Gamarr.

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
| **ROMarr** (upstream) | ROM acquisition: indexers (Prowlarr, Torznab…) → download client → DAT check → import → RomM rescan | yes, ~78 platforms, aliases accept RomM slugs | imports into RomM's layout, runs RomM's scan task | `/api/v1/integration/info`, `POST/GET /requests`, `GET /requests/current`; `X-Api-Key` or `Bearer` | searching → dispatching → downloading → available, or failed / cancelled | MIT | very fast moving (4 releases on 2026-11-13); one owner key, no per-user identity |
| **ROMarrNG** | diverging fork of ROMarr | yes | same | upstream routes + `ping`, `catalog/*` (IGDB with keys, DAT without keys, no covers), `library/lookup`, `requests/{id}`, `/cancel`, `/retry`, `/assets`; OpenAPI served | accepted → searching → dispatching → downloading → available, failed / cancelled | MIT | one main author, started 2026-10-21 |
| **SeerrNG** | Seerr fork: requests for many media; games are forwarded to ROMarr(NG) (retro) or Questarr(NG) (PC) | through ROMarrNG | indirect | `/api/v1/request/software/*` (catalogue, create, status, cancel, retry); service key acts as user 1; **per-user keys cannot reach game routes**, so a player-scoped client needs a login session | pending → approved → searching → downloading → importing → available; declined / failed / cancelled; approvals, quotas | MIT | many notification channels; worth it only for a household with approvals |
| Questarr | PC games *arr (IGDB) | mostly PC | folder + rescan | scoped `qsr_` keys, `POST games/request` | wanted / owned… | GPL-3.0 | out of scope (PC) |
| gamarr (Go) | indexer search + own request queue | PC + retro | folder placement only | `/api/requests`, one admin key | pending → … → completed | MIT | no catalogue, no DAT check |
| RetroArr, Gamarr | Radarr-style library managers | some | none | no request object | — | MIT / GPL-3.0 | out of scope |

**Target: ROMarr's integration contract.** It is the only one built for retro ROMs, checked against DATs, landing
in RomM's own layout and triggering RomM's scan: exactly the loop above. SeerrNG stays optional (a household with
approvals); the others are out of scope.

## 3. The contract Cartouche would use (read in the code)

Common to ROMarr and ROMarrNG:

```text
GET  /api/v1/integration/info              name, version, supports_*            (detect the service)
POST /api/v1/integration/requests          {name, platform, externalRequestId}  -> 202 + the request
GET  /api/v1/integration/requests          every request this integration made
GET  /api/v1/integration/requests/current  the latest one
auth: X-Api-Key (never ?apikey=, which ROMarr also accepts)
request view: {request_id, name, platform, status, assets[], error}
```

- `externalRequestId` (≤ 64 chars) makes a retried POST the same request, not a second download: Cartouche sends its
  own id.
- `platform` is resolved by exact slug, name or alias; RomM slugs (`genesis`, `psx`, `ngc`, `dc`…) are declared
  aliases, so Cartouche sends the RomM slug it already maps.
- The POST runs the indexer search **before** answering: allow a long timeout, show "searching" at once.
- No match: status `failed`, `error` says why; ROMarr keeps the title as "wanted" and may find it later.
- `available` means imported and verified under the library root; `assets` are paths **inside ROMarr's container**.
  Cartouche then finds the game in RomM (platform + file name, after RomM's scan) and offers or starts the download.
- Upstream has no per-request route and no cancel; ROMarrNG has `requests/{id}`, `/cancel`, `/retry`, detected with
  `GET /api/integration/seerrng/v1/ping` (404 → upstream).
- No push to clients (notifications go to ntfy, Gotify, webhooks…, i.e. the owner's phone): Cartouche polls while a
  request is open and the app is in front, and once at each return to the app.

## 4. Where "games I don't have" come from

| Source | What it gives | Cost | Fit |
|---|---|---|---|
| **Cartouche's own per-console lists** (already shipped: every known game per console from the LaunchBox dump, names, regions, disc/cartridge label scans) | full list per console, with the medium's real label | nothing new; works without the server | **best for browsing**: the shelf can show an asked game with its real disc or cartridge |
| ROMarrNG's DAT catalogue (`catalog/dat/*`) | No-Intro/Redump names: exactly what ROMarr matches and verifies | NG only, no covers | best for **matching**: the requested name is the DAT name |
| IGDB through ROMarrNG or SeerrNG | modern storefront data | Twitch keys on the server | not needed for retro |

Proposal: browse with Cartouche's lists (minus the player's games, minus what RomM already has), send the name as the
lists know it; when the server is ROMarrNG, look the title up in its DAT catalogue first and send the DAT name.

## 5. Design sketch

- **Settings:** a second server row "Demandes" (address + key), separate from RomM. ROMarr has no pairing flow: the key
  is typed with the pad keyboard or pasted. Stored like RomM's token (encrypted, private, header only).
- **Security:** ROMarr's key is its owner key (settings, downloads, library). Said plainly in the settings; SeerrNG in
  front is the answer for a shared household.
- **Shelf:** a new entry kind next to `OnServer` / `Arriving`: `Asked(title, console, status)`, drawn with the game's
  label from Cartouche's lists. States shown: searching, the server downloads, arriving in RomM, ready to download,
  not found (with the reason), cancelled.
- **Arrival:** when a request turns `available`, Cartouche refreshes RomM's catalogue for that console, finds the
  game, and either marks it "ready" or downloads it (decision R3).
- **Core:** the request view parsed tolerantly; the state machine (asked → searching → … → in RomM → here) as a pure
  function; matching an `available` asset to a RomM game by platform and file name.
- **Formal model:** a `requests` zone (poll vs app pause/resume, the same game asked twice, a request turning
  available while its console is being re-read, the server forgetting a request).
- **Tests:** recorded fixtures of ROMarr and ROMarrNG answers; a local fake server for the plugin.

## 6. Risks

- Both ROMarr and its fork release several times a week and the integration answer carries no contract version:
  stay on the smallest surface (4 routes), parse tolerantly, keep fixtures per version.
- The chain import → RomM scan → `available` was not run (see §8).
- ROMarr's single owner key on a handheld.

## 7. Decisions to take

| | What it changes | Options | Recommendation |
|---|---|---|---|
| R1 | Which service the handheld talks to | ROMarr (upstream contract) / ROMarrNG / SeerrNG / several | ROMarr's contract, ROMarrNG extras when detected, SeerrNG later |
| R2 | Where the missing-games list comes from | Cartouche's per-console lists / the server's DAT catalogue / both | both: lists to browse, DAT name to ask when available |
| R3 | When an asked game reaches RomM | download it automatically / mark it "ready" | ask once in settings; default "mark ready" |
| R4 | The key on the handheld | owner key / SeerrNG login | owner key now, stated in settings |

## 8. To check by running the services

ROMarr (or ROMarrNG) next to the lab RomM, with a fake indexer and a fake download client serving one homebrew file:
the full chain to `available`, how long it takes, what `assets` look like, RomM's scan after import, a retried POST
with the same id, a failed search, cancel and retry on NG, the `info` and `ping` answers.

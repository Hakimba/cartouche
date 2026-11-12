# A remote catalogue: RomM, an *arr stack, and box art (study)

**Status:** study only. Nothing here is implemented, no screen, no setting, no request. The branch is a working base
for whoever picks the feature up; the numbers below were measured, not quoted.

## What the feature is

Two additions asked for together:

1. **RomM.** Connect a self-hosted RomM, browse its catalogue inside Cartouche, download a game to the device.
2. **An *arr stack for games.** From Cartouche, browse games the user does **not** have yet, ask the home server for
   one, and get it delivered twice: into the server's library, and onto the device.

And one display question that follows from 2: a game that is not on the device has no disc and no cartridge to show,
so it should be drawn as its **box** instead of as a medium.

## Where the app stands

- The library is local only: one or more folders per console, walked at open. There is no remote source, no account, no
  download queue, and no state for "a game that exists but is not here". Everything a game is comes from a file that
  was found.
- There is one art pipeline: a title goes to a candidate image (LaunchBox extract, ScreenScraper table by reference
  name, a serial source), the image is downloaded, then a label is cut out of it and mapped onto the disc or cartridge
  model. So the app's whole visual vocabulary is "a physical medium with a printed label".
- Only twelve platforms have both a title list and an art extract (ps2, gc, gba, nes, snes, n64, gb, gbc, psx, wii,
  xbox, xbox360). The other modelled consoles (nds, 3ds, switch, genesis, master, gamegear, tg16, atari2600, saturn,
  segacd, dreamcast, psp, psvita) have a profile and a model but no title list, so no art source reaches them today.
- The plugin already has a plain HTTP client with no dependency, typed settings, and a JSON bridge to the app. A server
  address, a token, a catalogue page and a download with progress all fit that shape: what is missing is the remote
  side, not the plumbing.

## Lead 1 — RomM's HTTP API (verified against the published contract)

Read from the OpenAPI document served by a RomM instance (version 5.4.0, 226 paths), not from prose docs.

```text
auth        POST /api/token                       form login, answers a bearer token
            HTTP Basic                            accepted on every read route
            POST /api/client-tokens               long-lived token for one device
            POST /api/auth/device/init|token      device flow, for a screen without a keyboard
browse      GET  /api/roms?search_term=&platform_ids=&limit=&offset=
            filters: matched, missing, regions, languages, genres, franchises, player_counts, favorite
            per rom: id, name, fs_name, fs_size_bytes, regions, languages, is_identified,
                     is_unidentified, has_multiple_files, url_cover, path_cover_large, screenshot_path
            detailed rom: user_saves, user_states, download_formats, and the metadata block
download    GET  /api/roms/{id}/content/{file_name}          one file, streamed from disk
            GET  /api/roms/download?rom_ids=&platform_id=    a set, or a whole platform
metadata    genres, franchises, player_count, first_release_date, average_rating, summary, companies
```

Consequences worth stating plainly:

- A RomM game needs **no scraping at all**: the covers are already stored server-side, and one list call returns them
  with the games. For feature 1 the art question disappears.
- The token is carried by a plain GET, so a download with progress, resume and a cancel button is ordinary work.
- The catalogue is rich enough for a "game you don't own" card: genre, players, date, rating, summary come with it.
- Two things are **not** verified: the exact prefix a client must put in front of the relative cover path (the absolute
  one is fine, and the instance's own web UI shows the shape), and range requests for resuming a partial file. Both
  need one afternoon against a real instance.
- A RomM release renamed the cover fields (the newer name is a single cover path plus a flag for an embedded one).
  Read the JSON tolerantly — a field that disappears must not break a client.

## Lead 2 — the *arr stack for games (it exists, and it is complete)

- **ROMarr** is the *arr of ROMs: an API shaped like the other *arr applications, keyed by a header, Prowlarr for
  indexers, qBittorrent/Transmission/Deluge/rTorrent/SABnzbd as clients, and **RomM as its library** — after an import
  it asks RomM to rescan, and RomM 5.x needs the task scope for that. It is active (hundreds of commits, live proofs
  against real daemons, Docker images).
- **SeerrNG** is the Seerr of games: a fork of Seerr that adds an emulation category, with IGDB or DAT as the catalogue
  and ROMarr as the acquisition provider. Requests, approvals, status, imported files come back to the requester.
- The important find: ROMarr already publishes an **integration API meant for a third-party client**, which is exactly
  the role Cartouche would play.

```text
POST /api/v1/integration/requests   { name, platform, externalRequestId }   -> 202
GET  /api/v1/integration/requests   list, and /current for the latest
status                              requested -> searching -> download -> imported -> available
assets                              the imported file paths, once available
auth                                X-Api-Key header
```

- So the chain for feature 2 is: Cartouche posts a request → ROMarr searches, grabs, imports into RomM's folders →
  RomM rescans → Cartouche polls until "available", then downloads the file from **RomM**, not from ROMarr. One client
  for browsing and downloading, one call for asking.
- Risk to keep in mind: SeerrNG and its providers are forks of forks maintained by one group. Pinning Cartouche to
  upstream ROMarr's integration route (which SeerrNG itself calls a "basic external-request" contract) is the safer
  half; the SeerrNG-specific handshake is optional and should not be a prerequisite.

## Lead 3 — where a box front can come from (the question that was asked)

Three sources are usable, all already known to the project. Coverage is in
[boxart-coverage.tsv](boxart-coverage.tsv): per platform, LaunchBox games with a box front, the share of those that
have a North-American-or-World one, and how many of **our own** title-list names libretro answers.

**LaunchBox Games Database** — a Box - Front image type exists for every platform above, several per game (one per
region), and the same dump the app already consumes carries them: no new source, no key, no quota, images answering
200 from the same host the disc scans come from. Per-game coverage: 99.6 % xbox360, 99.4 % xbox, 98.1 % ps2, 97.4 %
psp, 97.1 % psx and saturn, 96.5 % nds and psvita, 94.3 % gc, 94.7 % wii, 87.9 % gba, 81.1 % gbc, 78.6 % snes, 72.6 %
n64, 69.4 % nes, 62.2 % switch, 60.6 % genesis.
Its two weaknesses: the region a cover was printed for (a PS2 game has a box 98 % of the time but a North-American one
only 40 % of the time, so the region preference will fall back more often than it does for labels), and the size —
images are full resolution, 300–800 KB, with no thumbnail variant, which is heavy for a grid of twenty.

**libretro thumbnails** — a static directory tree, one folder per system, a Named_Boxarts folder inside it, one PNG
per game named exactly as the reference lists the app already uses. No key, no quota, no API, and a name match is a
direct hit rather than a search. Against our own title lists it answers 92.9 % wii, 88.5 % gba, 86.7 % psx, 84.9 %
n64, 84.7 % snes, 84.5 % gc, 72.5 % ps2, 69.8 % gb, 58.1 % gbc, 34.9 % nes, 31.4 % xbox and 0.1 % xbox360 (twelve
files for the whole platform). It is the better source for local games (nothing to search, nothing to spend) and the
worse one for browsing, where a title has to be matched rather than used verbatim.

**ScreenScraper** — the only source that gives a box **in pieces**: front, spine, back, and a flat texture made to be
mapped onto a 3D box, plus the scan it was cut from. That is what a real 3D box needs, and no other source has it.
Its cost is quota: today the app spends one image request per game it already knows; a catalogue spends one **title
search** per game, up to thirty answers each, inside the same daily allowance, with a separate allowance for searches
that come back empty. There is no developer key on this machine, so the fill rate of the box media per system was not
measured — that is the one number this study is missing.

**Leads not followed**, on purpose: TheGamesDB, IGDB and SteamGridDB all need a key and none of them gives a better
per-platform retail front than the two keyless sources above for these consoles. They stay on the shelf for modern
platforms (Switch especially, where LaunchBox covers 62 % and libretro nothing).

## Drawing a box

- A box is a new kind of picture, not a new kind of medium: the profile already describes, per platform, what its art
  is and how a label is cut from it, with a proportion and a crop. A box repeats that shape — a format with its own
  width, height and spine — so it stays data, and adding it touches no shared file.
- Two ways, and they are not the same amount of work:
  - **Flat:** show LaunchBox's already-rendered Box - 3D image as an object standing on the shelf. Cheapest by far
    (94 000 images, every platform), but it is a photograph of a box: it does not turn with the light, and it breaks
    the app's rule that what is shown is a model.
  - **Modelled:** one box mesh per format, the front cover on its face, a spine and a back when the source has them.
    Consistent with everything else in the app, and the reason ScreenScraper matters. Needs a model, three textures,
    and a decision about what to show when only the front exists.
- Whatever is chosen, the grid needs a **small** copy: the app downloads labels at most 1024 px and cuts them; a box
  front at full resolution, twenty at a time, is tens of megabytes.

## What to do first, in order

1. **RomM, read-only.** A setting for the address and a token, a catalogue page listing platforms and roms with their
   covers, and the game's card. No download yet. This alone answers the display question with real data.
2. **Download one game.** Progress, cancel, the file written where the folder scan will find it, and the game appearing
   on its console's shelf with its label — the first moment the two halves of the feature meet.
3. **Box art for remote games.** LaunchBox box fronts by title, cached on the device, shown in the catalogue page while
   the flat-versus-modelled decision is made.
4. **Ask the server.** The request call, the poll, and the state a game carries: here, on the server, asked for.
5. **Boxes modelled.** Only once the shape above is settled and a source with a spine is wired in.

## Reproducing the numbers

The two scripts measure the two keyless sources; both are read-only and write to stdout.

```console
curl -o Metadata.zip https://gamesdb.launchbox-app.com/Metadata.zip
python3 scripts/study/launchbox_box_front.py Metadata.zip > boxart.tsv
python3 scripts/study/libretro_box_art.py
```

The LaunchBox pass reads the 520 MB dump in about five minutes and needs no more than a few hundred megabytes of
memory (a streaming parser, elements cleared as they close). The libretro pass fetches one directory listing per
platform, about 2 MB each, and compares against the title lists in the repository.

## Not verified, and how to close it

| Question | How |
|---|---|
| ScreenScraper's box fill rate per system | one evening with the developer key: search 200 titles per platform, count answers carrying a box |
| RomM cover URL for the relative path, and resume | one afternoon against a real instance |
| Does a RomM-only stack satisfy the user, or is the *arr half wanted first | ask him; the two features are independent |
| Whether a box should be modelled or a photograph | two mockups, chosen by eye, before any model is made |

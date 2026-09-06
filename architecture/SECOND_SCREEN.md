# Runabout — Star Trek Second Screen

**Status:** Implemented — see README.md for setup and verification
**Date:** 2026-09-04
**Stack:** Ruby 4.0.1, Rails 8.1.3, SQLite 3.52, Hotwire, D-Bus — all verified present on this machine

---

## 1. Purpose

A Rails application that watches whatever media player is running on this
machine, works out which Star Trek episode is playing, and renders an
in-universe dashboard for it: cast, memorable quotes, and the set of
Star Trek entities that episode is tagged with — themed to the series
being watched, using the LCARS-26 kit.

The name is in-universe: a **runabout** is the small auxiliary craft that
travels alongside the ship, carrying its own cockpit and its own displays to
places the main viewscreen does not go.

Sync is **episode-level**. The app answers "what am I watching, and who and
what is in it," not "what is on screen right now."

---

## 2. What already exists

### 2.1 The media library

`/mnt/dhd/video/tv/Star Trek` — three DVD-rip boxsets:

| Series | Episode files | Container |
|---|---|---|
| The Next Generation | 176 | `.mkv` (HD) |
| Deep Space Nine | 173 | `.avi` |
| Voyager | 168 | `.avi` |

**738 video files total** — 517 episode files, 221 bonus features. Also 168
`.srt` subtitle files, which are out of scope but keep a line-level sync
upgrade path open (§13).

The naming is remarkably regular:

```
Star Trek The Next Generation Season 1 Episode 01 & 02 - Encounter at Farpoint.avi
Star Trek DS9 Season 03 Episode 11 - Past Tense (Part 1).avi
Star Trek Voyager Season 01 Episode 03 - Parallax.avi
```

Variations that matter: the series token differs per boxset (`The Next
Generation` / `DS9` / `Voyager`), season numbers are zero-padded in two of
three sets, double-episodes join with `&`, and some titles carry a
`(Part 1)` suffix.

### 2.2 The LCARS-26 kit (`LCARS-26/`)

Six static templates from TheLCARS.com over a shared asset folder. The six
stylesheets are **not** base + overrides — each is a complete standalone
sheet — but they share a **75-class common vocabulary** including
`.accordion`, `.lcars-list`, `.lcars-button`, `.panel-1`–`.panel-7`,
`.bar-1`–`.bar-10`, `.flexbox`.

Each declares its palette as CSS custom properties in `:root`:

| Theme | Character |
|---|---|
| `classic` | orange / butterscotch / african-violet — 24th century LCARS |
| `nemesis-blue` | midnight / ghost / cardinal — late-24th, darker |
| `voyager` | command-gold / andorian-blue / frost |
| `lower-decks` | hot orange, october-sunset |
| `lower-decks-padd` | as above, PADD skeleton, 14 bars |
| `picard` | structural rather than palette-driven — no color tokens in `:root` |

Each sheet ships **14 viewport breakpoints** (390px → 1500px), all
`@media (width <= N)`. **No container queries anywhere.**

The skeleton is `section.wrap-standard > div.wrap`, with a `left-frame`
fixed at `--lfw: 240px` of decorative chrome (the numbered `panel-N`
buttons) plus a `right-frame`. That furniture costs roughly 480px of
horizontal space on a wide screen.

---

## 3. Findings that shaped the design

Everything in this section was measured on this machine, not read in a
manual. Reproduction commands are in Appendix A.

### 3.1 VLC's HTTP interface is broken here

VLC 3.0.22-2 on this system links **Lua 5.5** (`liblua.so.5.5`). `math.pow`
was removed in Lua 5.3. Both status endpoints fail:

```
GET /requests/status.json → lua/intf/modules/httprequests.lua:37:
                            attempt to call a nil value (field 'pow')
GET /requests/status.xml  → identical error
```

`playlist.json` works — it does not reach that code path — but carries no
playback position. The Lua files ship precompiled (`httprequests.luac`), so
patching means recompiling and re-patching after every `pacman -Syu`.

**The VLC HTTP interface is therefore not a viable sync channel on this
machine.**

### 3.2 MPRIS over D-Bus works with zero configuration

Live capture, VLC running with no special flags and no password:

```
xesam:url       file:///…/Star.Trek.TNG.S05E25.The.Inner.Light….mkv
xesam:title     The Inner Light
Position        19612094      (µs — verified advancing at 1× real time)
mpris:length    120023000
PlaybackStatus  Playing
CanControl      true
CanSeek         true
```

No port, no password, no `--intf` flag, no `vlcrc` edit. It emits
`PropertiesChanged` and `Seeked` signals, so it is push rather than poll.
It also exposes `org.mpris.MediaPlayer2.TrackList`.

`ruby-dbus 0.25.0` is available on rubygems.

Because MPRIS is a generic freedesktop protocol, the same code works for
mpv, Jellyfin desktop clients, and anything else MPRIS-compliant.

### 3.3 One regex covers the entire library

A single pattern, run against all 738 files:

```
episode files matched: 517   (double-episodes: 9)
extras skipped:        221
UNMATCHED:             0
```

### 3.4 The rip's episode titles contain errors

| Filename says | Canon title |
|---|---|
| `The Last Post` | The Last Outpost |
| `Code of Honour` | Code of Honor |
| `The Marquis` | The Maquis |

**Consequence: match on `(series, season, episode)`, never on title.**
Title is a fuzzy confidence signal only.

### 3.5 Memory Alpha already contains the keyword mapping

`enmemoryalpha_pages_current.xml.7z` — **82 MB** (78 MiB), served from
`https://s3.amazonaws.com/wikia_xml_dumps/e/en/`, verified live. The wiki
holds 226,247 pages / 66,407 articles. Licensed **CC BY-NC** — attribution
required, non-commercial only, which this is.

Episode pages have a consistent structure. From *The Inner Light*:

```
{{sidebar episode | image | teleplay | story | director | date }}
<lead paragraph>
== Summary ==            (=== Teaser / Act One … Act Five ===)
== Memorable quotes ==
== Background information ==
== Links and references ==
   === Starring / Also starring / Guest stars / Co-star ===
   === References ===
      ==== Unreferenced material ====
```

The `References` section is the requested episode→keyword mapping,
hand-curated by editors:

```
[[ability]]; [[atmospheric condenser]]; [[Kamin]]; [[Kataan]]; [[Kataan probe]];
[[nucleonic beam]]; [[Ressik]]; [[Ressikan flute]]; [[Starfleet]]; [[talgonite]]; …
```

~80 entities for that episode. `Unreferenced material` is a separate
subsection listing things **mentioned but not seen** — a distinction worth
preserving in the model.

Memorable quotes parse cleanly:

```
"''Computer, freeze program. Computer, end program!''"
:- '''Picard''', as he finds himself as Kamin with his wife Eline tending to him
```

### 3.6 Entity articles are a reverse index

Entity pages cite the episodes that established each fact, via series
citation templates. From *Ressikan flute*:

```
…a skill that he retained after the probe finished its program. ({{TNG|The Inner Light}})
```

So episode→entity can be derived from **two independent directions** and
cross-validated: the episode's own `References` list, and every entity
article citing that episode.

### 3.7 Entity classification works fully offline

Categories are inline in the wikitext, not injected by templates:

```
Ressikan flute → [[Category:Musical instruments]]
Kamin          → [[Category:Kataan natives]], [[Category:Scientists]]
```

No API call is needed to classify an entity. The caveat is that Memory
Alpha's categories are fine-grained — thousands of them — so mapping
"Kataan natives" onto a display type of *Character* requires a rule layer
with a sensible fallback (§8.3).

### 3.8 Rendering MA prose is the genuinely hard part

Real wikitext is dense with wiki-specific templates:

```
{{aquote|When I awoke, all that was left of my life there…|[[Jean-Luc Picard]]|2369|Lessons}}
[[File:Ressikan Flute.jpg|thumb|170px|Picard's Ressikan flute]]
aboard the {{USS|Enterprise|NCC-1701-D|-D}}
{{dis|Kataan|star}} (star)
{{revname|Richard|Wagner}}
```

A generic wikitext parser will not expand `aquote`, `USS`, `dis`, `revname`
or the series citation templates. Output would be visibly broken. This
drives the hybrid strategy in §8.4.

### 3.9 IMDb's dumps are the wrong tool here

| File | Size |
|---|---|
| `title.principals.tsv.gz` | 745 MB |
| `title.akas.tsv.gz` | 489 MB |
| `name.basics.tsv.gz` | 295 MB |
| `title.basics.tsv.gz` | 216 MB |
| `title.episode.tsv.gz` | 52 MB |
| `title.ratings.tsv.gz` | 8 MB |

~1.8 GB gzipped, and **no images and no biographies** — the two things the
cast panel most wants. Memory Alpha already carries credits and performer
biographies, and TMDB carries the photographs. IMDb is not used.

---

## 4. Non-goals

- **Patching VLC's Lua.** MPRIS makes it unnecessary; the files are
  precompiled and pacman-managed.
- **Act-, scene- or subtitle-level sync.** Explicitly out of scope. §13
  records the hook.
- **Refactoring the six stylesheets** into base + theme. 14k lines of
  interdependent media queries, no payoff, high regression risk.
- **Authentication.** LAN-bound, single household.
- **Remote or multi-machine operation.**
- **An SPA.** The kit is server-rendered HTML by nature.

---

## 5. Architecture

```
VLC / mpv / any MPRIS player
      │ PropertiesChanged, Seeked  (D-Bus session bus)
      ▼
  bin/watcher ────────► PlayerState (DB, singleton)
      │                      │
      │                      └──► Turbo::StreamsChannel.broadcast
      │                                    │
      └── MPRIS method calls ◄─────────────┼──── transport / seek / volume
          (Play, Pause, SetPosition)       ▼
                                  tablet + desktop browsers
                                           ▲
  Puma ──► Runabout web ──► SQLite ────────┘
                              ▲
                              ├── rake runabout:ingest    (Memory Alpha dump)
                              ├── rake runabout:scan      (library index)
                              └── rake runabout:backfill  (TMDB + article HTML)
```

Three supervised processes under `Procfile`:

| Process | Role |
|---|---|
| `web` | Puma, port **2364** |
| `watcher` | owns the only D-Bus connection; never serves a request |
| `jobs` | Solid Queue |

Data dir `~/.lcars/second-screen/`. Rails 8 defaults give Solid Queue +
Solid Cable on SQLite, so no Redis and no second datastore.

**Why a separate watcher process.** `ruby-dbus`'s listener loop blocks. In
a Puma worker it would block a request thread, subscribe once per worker
under multi-worker Puma, and die with the web server. As its own process it
crashes in isolation and restarts cleanly.

---

## 6. Playback sync

### 6.1 Player selection

Watch the session bus for any `org.mpris.MediaPlayer2.*` name. When several
are present, prefer the one whose `PlaybackStatus` is `Playing`, tie-broken
by a configurable priority list with `vlc` first. The chosen player is
recorded in `PlayerState` so the UI can say which one it is following.

### 6.2 Signals plus reconciliation

MPRIS **does not emit `Position` during normal playback** — only on seek. So:

- **Signal-driven:** `PropertiesChanged` (metadata, status, rate, volume)
  and `Seeked` (authoritative position) update `PlayerState` immediately.
- **Client-side interpolation:** the browser advances the progress bar from
  `(position, captured_at, rate)`. No server round trip per second.
- **Reconciliation poll every 10s:** re-reads `Position` and `PlaybackStatus`
  to correct drift, and detects a player that quit without a signal or was
  restarted.

### 6.3 Control

Transport, seek and volume are MPRIS method calls (`Play`, `Pause`, `Stop`,
`Next`, `Previous`, `SetPosition`, `Volume=`) issued on the watcher's
connection via a small command queue, so the web process never touches
D-Bus. Commands are advisory: a failure surfaces as a transient notice, and
the next reconciliation restores truth. Seek scrubbing on touch commits on
release, not during drag.

### 6.4 State machine

```
   ┌──────────┐  player appears   ┌──────────┐
   │ NO_PLAYER│ ────────────────► │   IDLE   │
   └──────────┘ ◄──────────────── └──────────┘
        ▲        player vanishes        │ media loaded
        │                               ▼
        │                        ┌──────────────┐  resolved  ┌──────────┐
        └────────────────────────│  RESOLVING   │──────────► │ PLAYING  │
                                 └──────────────┘            └──────────┘
                                        │ no match                │
                                        ▼                    paused / stopped
                                 ┌──────────────┐                 │
                                 │  UNMATCHED   │◄────────────────┘
                                 └──────────────┘
```

`STANDBY` is a UI concern, not a state: whenever the app is not `PLAYING`,
the **last identified episode stays on screen** so you can keep reading its
cast and references after the credits.

---

## 7. Identification

### 7.1 Resolution order

| # | Source | Notes |
|---|---|---|
| 1 | `MatchCorrection` for this exact path | permanent; wins over everything |
| 2 | `MediaFile` row from `runabout:scan` | pre-resolved library index |
| 3 | Regex ladder → `(series, season, episode)` lookup | the 90% path |
| 4 | No match | standby + parsed filename + manual picker |

A manual override always writes a `MatchCorrection`, so the parser's
mistakes are self-healing — it never gets the same file wrong twice.

### 7.2 The pattern

Validated at 517/517 with 0 misses on the current library:

```ruby
BOXSET = /
  Star\s+Trek\s+
  (?<series>The\s+Next\s+Generation|DS9|Deep\s+Space\s+Nine|Voyager|
            TNG|Enterprise|Discovery)\s+
  Season\s+(?<season>\d{1,2})\s+
  Episode\s+(?<ep>\d{1,2})(?:\s*&\s*(?<ep2>\d{1,2}))?\s*-\s*
  (?<title>.+?)
  (?:\s*\((?:Part\s*(?<part>\d)|.+?)\))?
  \z
/xi
```

It is a **ladder**, not one pattern: `BOXSET` first, then conventional
scene patterns (`S05E25`, `5x25`), then a loose fallback. The first
pattern that yields a resolvable `(series, season, episode)` wins.

Series tokens resolve through an alias table (`DS9` → `Deep Space Nine`),
seeded, not hard-coded — adding a boxset with a different token is a data
edit.

### 7.3 Double episodes

`Episode 01 & 02` produces one viewing bound to both episode records. The
dashboard merges their entity lists, credits and quotes, and the header
shows both titles. Nine files in the current library.

### 7.4 Confidence

Every resolution carries a confidence derived from which rung matched and
how closely the parsed title fuzzy-matches the canon title. The header shows
the match and, below a threshold, invites correction. **The title never
participates in lookup** (§3.4) — only in scoring.

### 7.5 Extras

The 221 bonus features fail the ladder and land in `UNMATCHED`, showing the
parsed filename and a picker. This is deliberate: no false episode match.

---

## 8. Data layer

### 8.1 Memory Alpha ingest

**Implementation finding (2026-09-05):** The sidebar's season, episode number,
series, and air date are supplied by `Module:EpisodeData/*`, not stored inline
on most episode pages. The importer reads those data modules from the XML first,
then enriches their episode records from article pages. Combined module numbers
such as `1x01/02` supply both records for a double-length episode. No Lua is
executed. See README.md for the import and snapshot workflow.

`rake runabout:ingest` downloads the 82 MB dump, decompresses with `7z`, and
streams the XML. Per page it extracts:

| Extracted | Into |
|---|---|
| `{{sidebar episode}}` fields | `Episode` (stardate, airdate, director, writers, image) |
| lead paragraph, stripped to text | `Episode#blurb` / `Entity#gloss` |
| `=== References ===` | `EntityMention` (`seen: true`) |
| `==== Unreferenced material ====` | `EntityMention` (`seen: false`) |
| Starring / Also starring / Guest stars / Co-star | `Credit` with billing tier |
| `== Memorable quotes ==` | `Quote` with speaker + context |
| inline `[[Category:…]]` | `Entity#categories` |
| series citation templates | `EntityMention` (reverse-derived) |

**Ingest is versioned.** Each run writes rows tagged with a new `ingest_id`
and flips a pointer atomically on success. A failed or interrupted download
never leaves a half-populated database. Old ingests are pruned on the
following successful run. Refresh is manual — the dump is regenerated
nightly upstream, but nothing here needs to be current.

### 8.2 Cross-validation

Each `EntityMention` records which source vouched for it: the episode's
`References` list, an entity article's citation, or both. Agreement is the
common case; disagreement is retained rather than resolved, and the UI can
weight "confirmed by both" higher. This is cheap because both directions are
already being parsed.

### 8.3 Entity classification

MA categories are fine-grained. A seeded rule table maps category patterns
onto a small set of display types — Character, Species, Ship, Location,
Technology, Culture, Other — most specific rule wins, `Other` as fallback.
Because the rules are data, improving classification is a seed edit and a
re-run, not a code change. **Unclassified entities still display**; they
just group under Other.

### 8.4 Article content: offline-first, enriched on demand

This is the compromise that satisfies "offline database" without writing a
MediaWiki template engine (§3.8):

- **At ingest, offline, always:** the lead paragraph, stripped to clean
  text. That is the one-or-two-sentence gloss the entity panel actually
  needs, and it works forever with no network.
- **On first drill-in:** fetch MediaWiki's own rendered HTML from the API,
  sanitize it, rewrite internal links to Runabout routes, and cache it in the DB
  **permanently**. MediaWiki expands its own templates correctly, so
  fidelity is perfect and there is no parser to maintain.
- **`rake runabout:backfill`** prefetches article HTML for every entity in the
  library's episodes, so a fully offline session is a supported, prepared
  state rather than a degraded one.

### 8.5 TMDB

Used **only** for photographs: actor headshots and episode stills. Resolved
per person and per episode, stored in the DB, and included in
`runabout:backfill`. Every read goes through a null-object, so a cold cache, a
missing API key, or a dead network degrades to *no image* — never to an
error. TMDB is never on the critical path for a page render.

---

## 9. Domain model

| Model | Notes |
|---|---|
| `Series` | canon metadata, era, alias tokens, theme mapping |
| `Episode` | series, season, number, title, stardate, airdate, blurb, summary, MA page ref |
| `Person` | performer; MA page ref, biography extract, TMDB id + headshot |
| `Credit` | person ↔ episode, character name, billing tier (starring / also starring / guest / co-star / uncredited) |
| `Entity` | in-universe subject; MA page ref, gloss, categories, display type |
| `EntityMention` | episode ↔ entity; `seen` / `mentioned`, `sources[]` |
| `Quote` | episode, speaker, text, context line, ordinal |
| `MediaFile` | absolute path, resolved episode(s), confidence, kind, `scanned_at` |
| `MatchCorrection` | path → episode(s), user-authored, permanent |
| `Viewing` | episode, started_at, ended_at, furthest position |
| `PlayerState` | singleton: bus name, status, position, captured_at, rate, volume, current `MediaFile` |
| `Article` | MA page ref → cached sanitized HTML, fetched_at |

---

## 10. UI

### 10.1 Theming

`Series → theme` lives in a **seed table**, not in code:

| Series | Theme |
|---|---|
| TNG | `classic` |
| DS9 | `nemesis-blue` |
| VOY | `voyager` |
| LD | `lower-decks-padd` |
| PIC / DIS / SNW | `picard` |
| TOS / TAS / ENT | `classic` (fallback — no era theme exists in the kit) |

The theme switches the moment an episode is identified. A **pin** control
freezes the current theme until unpinned; the pin survives reloads. The
TOS/TAS/ENT gap is recorded as a known limitation (§13), not papered over.

### 10.2 One payload for every client

**All panels always render.** CSS decides density. This is the property that
keeps Turbo simple: a broadcast is a single server render delivered
identically to the tablet and the desktop, with no per-client variants and
no viewport tracking on the server.

- **Wide:** panels in a grid; the `panel-N` left-frame buttons stay
  decorative.
- **Narrow:** the kit's `panel-1`…`panel-7` buttons become **real tabs** —
  CAST / REFS / QUOTES / LOG — implemented in **pure CSS** (`:target`).
  Choosing CSS over a server-rendered tab state is what preserves the
  single-payload property, and it gives free rotation and resize handling.

The sticky now-playing header — series, episode, title, progress, transport
— sits outside the tab system and is always visible.

### 10.3 Drill-in

One Turbo Frame in two placements:

- **Wide:** opens in a dedicated right-hand detail column; the dashboard
  stays put, so you keep context.
- **Narrow:** the same frame takes the full view with a back control.

Detail is lazy: tapping a guest star or an entity is what triggers the
article fetch (§8.4), so the base payload never carries 80 articles.

### 10.4 Spoilers

Lead blurb open by default. Full act-by-act summary, background/production
notes and continuity all sit behind an explicit reveal control. The reveal
is per-episode and not remembered — the safe state is the default state.

### 10.5 Panels

| Panel | Content |
|---|---|
| Header | series, S/E, title, stardate, airdate, director, writers, sidebar image, progress, transport |
| Cast | credits grouped by billing tier, character + actor + headshot; tap → performer detail with biography and every other Trek role |
| References | entity list grouped by display type, `seen` vs `mentioned` distinguished; tap → entity article |
| Quotes | memorable quotes with speaker attribution and context |
| Log | teaser blurb; full summary behind reveal |

---

## 11. Degradation

Every external dependency has a defined, in-theme failure state. **None of
these is an error page.**

| Condition | Behaviour |
|---|---|
| D-Bus unavailable / no player | Standby with diagnostic; last episode retained |
| Player quits mid-episode | Reconciliation detects it within 10s; last episode retained |
| Filename unparseable | `UNMATCHED` — parsed filename + manual picker |
| Episode missing from MA | Header from the local episode table alone |
| No network, article not cached | Offline lead extract only, with a note |
| No TMDB key / no network | No images; layout reserves no space for them |
| Ingest never run | First-run screen pointing at `rake runabout:ingest` |
| MPRIS command rejected | Transient notice; next reconciliation restores truth |

---

## 12. Testing

- **Watcher** splits into a D-Bus adapter and a **pure state machine**. The
  state machine is tested against recorded MPRIS property payloads with no
  bus present, covering: player appears/vanishes, media change, seek,
  pause/resume, rate change, and a missed-signal reconciliation.
- **Identification** gets a fixture file of real filenames drawn from the
  library — all 9 double-episodes, a sample of extras, and every series
  token variant — as a regression test. The 517/517 result is the baseline.
- **Ingest** runs against a checked-in ~20-page XML fixture covering an
  episode page, an entity page with categories, a performer page, a
  double-episode, and a page with unreferenced material.
- **TMDB and the MA API** are stubbed at the client boundary. No test hits
  the network.
- **Degradation paths** are tested explicitly — the null-object image path
  and each row of §11 — because they are the states most likely to be seen
  and least likely to be exercised by hand.

---

## 13. Known limitations and future hooks

- **TOS, TAS and ENT have no era theme.** They predate LCARS entirely and
  the kit has nothing for them. They fall back to `classic`. Authoring two
  new stylesheets in the shared 75-class vocabulary would close this.
- **Line-level sync is deliberately unbuilt.** The 168 `.srt` files in the
  library are the hook: aligning subtitle cues to quotes and entity
  mentions would upgrade the app from episode-level to line-level without
  changing the identification or data layers.
- **Act-level sync** is similarly available — MA's summaries are already
  split into Teaser and Acts One through Five — but requires estimating act
  boundaries against runtime, which is heuristic.
- **Entity classification quality** depends on the seeded rule table and
  will start rough. It is data, so it improves without code changes.
- **Films are modelled but unlibraried.** The ingest covers all canon Trek,
  so entity and performer cross-references work franchise-wide even though
  only TNG/DS9/VOY resolve to files today.

---

## 14. Attribution

Memory Alpha content is licensed **CC BY-NC**. Any view rendering MA-derived
content must carry visible attribution and a link to the source page.
Non-commercial use only — which this is. TMDB requires the standard "this
product uses the TMDB API but is not endorsed or certified by TMDB"
acknowledgement.

---

## Appendix A — Reproducing the findings

```bash
# 3.1 — VLC HTTP interface failure
cvlc --intf http --http-host 127.0.0.1 --http-port 8099 --http-password trek <file> &
curl -s -u :trek http://127.0.0.1:8099/requests/status.json   # → math.pow error
curl -s -u :trek http://127.0.0.1:8099/requests/playlist.json # → works
ldd /usr/lib/vlc/plugins/lua/liblua_plugin.so | grep lua      # → liblua.so.5.5

# 3.2 — MPRIS
busctl --user list | grep mpris
gdbus call --session --dest org.mpris.MediaPlayer2.vlc \
  --object-path /org/mpris/MediaPlayer2 \
  --method org.freedesktop.DBus.Properties.GetAll org.mpris.MediaPlayer2.Player

# 3.3 — library survey
find "/mnt/dhd/video/tv/Star Trek" -type f \
  \( -iname '*.avi' -o -iname '*.mkv' -o -iname '*.mp4' \) -printf '%P\n' | sort

# 3.5 — Memory Alpha
curl -sI https://s3.amazonaws.com/wikia_xml_dumps/e/en/enmemoryalpha_pages_current.xml.7z
curl -s -A "<ua>" \
  "https://memory-alpha.fandom.com/api.php?action=parse&page=The%20Inner%20Light%20(episode)&prop=wikitext&format=json"
```

Note: `WebFetch`-style tooling receives HTTP 402 from Fandom. Plain `curl`
with a browser user-agent works.

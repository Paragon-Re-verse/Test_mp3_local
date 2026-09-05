# Nocturne — Local MP3 Player

A local-network MP3 player for phone (Android) and PC (Windows), built from
the Claude Design prototype in `../project/MP3 Local Player.dc.html`. Same
Flutter codebase on both platforms — no external servers, ever.

## Download (test builds)

Rebuilt automatically by [GitHub Actions](.github/workflows/build.yml) on
every push — always the latest commit, debug-signed, not for store
distribution.

- **Android**: [nocturne-player.apk](https://github.com/Paragon-Re-verse/Test_mp3_local/releases/download/test-build/nocturne-player.apk)
- **Windows**: [nocturne-player-windows.zip](https://github.com/Paragon-Re-verse/Test_mp3_local/releases/download/test-build/nocturne-player-windows.zip) — unzip and run `nocturne_player.exe` from inside the extracted folder (it needs the DLLs and `data/` folder next to it).

## What's real vs. what's a placeholder

Everything below is a real, working implementation, not a mock:

- **Library scanning**: recursively finds `.mp3` files under the chosen
  folder, reads ID3v2 tags and estimates duration by parsing MPEG frame
  headers / Xing-VBR headers (`lib/data/id3.dart`, `lib/data/mp3_duration.dart`).
- **Tag editing**: writes real ID3v2.3 tags (title/artist/album/cover) back
  to the file. Custom "tags" (labels like "Дорога"/"Вечер" used for
  filtering) aren't an ID3 concept, so they're stored in the app's own
  settings store, keyed by file path.
- **Local network layer** (`lib/network/`): a genuine UDP broadcast beacon
  for discovery, a per-device self-signed TLS certificate generated on
  first run (pure Dart, via `basic_utils`/`pointycastle` — no OpenSSL
  needed), an HTTPS control channel for pairing/commands with
  trust-on-first-use certificate pinning, and a token-gated plain-HTTP
  file server (with Range support) for streaming a track's audio bytes to
  a paired device. See `test/network/lan_pairing_test.dart` for an actual
  two-device pairing + authenticated command exchange over real sockets.
- **Audio-output handoff** ("phone as speaker"): the source device sends a
  `takeOverPlayback` command with a stream URL; the target opens that URL
  directly in its own player and the source pauses. `releasePlayback`
  hands control back.
- **UI**: every screen from the prototype (onboarding, library w/
  search+sort+tag filters, queue w/ hold-to-reorder, device
  discovery/pairing, settings incl. the custom hue-ring/triangle colour
  picker, full-screen song view, Windows 3-pane layout with the PC/Phone
  output switch) — see `test/widgets/goldens/*.png` for rendered
  screenshots of each.

### Known simplifications (documented trade-offs, not bugs)

- **Discovery protocol**: a custom lightweight UDP beacon rather than full
  mDNS/DNS-SD. Simpler to reason about and test; a real mDNS responder
  would be a reasonable follow-up if interop with other DNS-SD tooling
  ever matters.
- **Command channel trust model**: the control channel is real TLS with
  cert-pinning, but peer identity on inbound `/control` requests is
  checked via a signed-looking field in the JSON body compared against
  the pinned fingerprint, not full mutual-TLS client certificates. Good
  enough for "two devices you paired yourself on your own LAN"; mutual
  TLS would be the next hardening step.
- **Audio streaming transport**: deliberately plain HTTP (not HTTPS) so
  the receiving device's audio player doesn't need to trust the sender's
  self-signed cert. Gated by a random per-launch token embedded in the
  URL. Pairing/control/tag-sync stay on the authenticated HTTPS channel.
- **Android scoped storage**: folder picking uses the native picker
  (`file_picker`) and requests the `READ_MEDIA_AUDIO`/`READ_EXTERNAL_STORAGE`
  runtime permission, then lists the folder via `dart:io`. This works for
  common folders (e.g. `Music`) but Android's scoped storage can restrict
  raw filesystem access to arbitrary SAF-picked trees on some
  OEM/API-level combinations; a fully general fix would use a
  SAF-document-tree-aware file listing (e.g. the `shared_storage`
  package) instead of `dart:io` directly.
- **Transcoding**: the settings toggle exists (per the design) but no
  AAC transcoding pipeline is wired up yet — today the original file is
  always sent as-is.

## Building

```
flutter pub get
flutter run -d windows   # or: flutter run -d <android-device-id>
```

## Testing

```
flutter test                 # unit + widget/golden tests
flutter test --update-goldens  # after an intentional visual change
```

`test/network/lan_pairing_test.dart` and `test/network/https_smoke_test.dart`
exercise real sockets (loopback only) and need `HttpOverrides.global = null`
to opt out of `flutter_test`'s default network-blocking sandbox — see the
comments in those files.

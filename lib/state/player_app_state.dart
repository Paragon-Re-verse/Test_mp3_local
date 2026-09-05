import 'dart:async';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../audio/playback_engine.dart';
import '../data/app_store.dart';
import '../data/library_repository.dart';
import '../l10n/strings.dart';
import '../models/lan_device.dart';
import '../models/track.dart';
import '../network/control_server.dart';
import '../network/network_service.dart';
import '../theme/nocturne_theme.dart';
import 'app_screen.dart';
import 'track_draft.dart';

class PlayerAppState extends ChangeNotifier {
  final AppStore store;
  final LibraryRepository library;
  final NetworkService network;
  final bool isDesktop;
  final PlaybackEngine engine;

  PlayerAppState({
    required this.store,
    required this.library,
    required this.network,
    required this.isDesktop,
    required this.engine,
  });

  // ---- persisted / global ----
  AppScreen screen = AppScreen.onboard;
  String? folder;
  AppLang lang = AppLang.ru;
  AppThemeMode themeMode = AppThemeMode.dark;
  AccentChoice colorChoice = AccentChoice.system;
  String customHex = '#7fb2a1';
  bool transcode = true;
  String deviceName = '';
  bool netOn = true;
  List<String> allTags = [];

  // ---- library ----
  List<Track> tracks = [];
  bool scanningLibrary = false;
  String query = '';
  SortKey sortKey = SortKey.title;
  SortDir sortDir = SortDir.asc;
  bool filterOpen = false;
  List<String> tagFilter = [];

  // ---- queue / playback ----
  List<String> queueIds = [];
  int curIndex = 0;
  bool playing = false;
  Duration position = Duration.zero;
  Duration mediaDuration = Duration.zero;
  String? moveId; // track id currently in "hold to reorder" mode

  // ---- transfer / pairing ----
  bool scanningDevices = false;
  List<LanDevice> discoveredDevices = [];
  String? outgoingPairTargetId;
  LanDevice? pendingIncomingPair;
  AudioOutput output = AudioOutput.local;

  // ---- editing / sync ----
  bool editingTrack = false;
  TrackDraft? draft;
  bool syncPromptVisible = false;
  bool dontAskDraft = false;
  Set<String> dontAskDeviceIds = {};

  // ---- settings: tags ----
  String newTagDraft = '';
  String? renamingTag;
  String renameValue = '';

  // ---- settings: custom color picker ----
  bool colorPickerOpen = false;
  double pickerHue = 258;
  double pickerSat = 0.4;
  double pickerVal = 0.85;

  // ---- misc ----
  String? toastMessage;
  Timer? _toastTimer;
  Timer? _holdTimer;
  StreamSubscription? _posSub, _durSub, _playSub, _completeSub;
  StreamSubscription? _incomingPairSub, _pairAnswerSub, _commandSub, _devicesSub;

  Strings get L => Strings.forLang(lang);
  bool get dark => themeMode == AppThemeMode.dark ||
      (themeMode == AppThemeMode.system && _systemIsDark());

  bool _systemIsDark() => true; // refined by MediaQuery in the widget tree.

  Track? get current => queueIds.isEmpty ? null : trackById(queueIds[curIndex]);
  Track? trackById(String id) {
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ==================================================================
  // Init
  // ==================================================================
  Future<void> init() async {
    folder = await store.folder;
    lang = (await store.lang) == 'en' ? AppLang.en : AppLang.ru;
    final themeStr = await store.theme;
    themeMode = AppThemeMode.values.firstWhere((e) => e.name == themeStr, orElse: () => AppThemeMode.dark);
    final colorStr = await store.colorChoice;
    colorChoice = AccentChoice.values.firstWhere((e) => e.name == colorStr, orElse: () => AccentChoice.system);
    customHex = await store.customHex;
    transcode = await store.transcode;
    deviceName = await store.deviceName;
    netOn = await store.netOn;
    allTags = await store.allTags;
    dontAskDeviceIds = await store.dontAskDeviceIds;

    _posSub = engine.position.listen((d) {
      position = d;
      notifyListeners();
    });
    _durSub = engine.duration.listen((d) {
      mediaDuration = d;
      notifyListeners();
    });
    _playSub = engine.playing.listen((p) {
      playing = p;
      notifyListeners();
    });
    _completeSub = engine.completed.listen((done) {
      if (done) next();
    });

    if (folder != null) {
      screen = AppScreen.library;
      await rescanLibrary();
    }

    await network.init();
    _incomingPairSub = network.incomingPairRequests.listen(_onIncomingPairRequest);
    _pairAnswerSub = network.pairAnswers.listen(_onPairAnswer);
    _commandSub = network.remoteCommands.listen(_onRemoteCommand);
    _devicesSub = network.devices.listen((list) {
      discoveredDevices = list;
      notifyListeners();
    });
    if (network.pairedPeer != null) notifyListeners();

    if (netOn) await network.startScan();
    notifyListeners();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _holdTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _completeSub?.cancel();
    _incomingPairSub?.cancel();
    _pairAnswerSub?.cancel();
    _commandSub?.cancel();
    _devicesSub?.cancel();
    engine.dispose();
    network.dispose();
    super.dispose();
  }

  void toast(String msg) {
    _toastTimer?.cancel();
    toastMessage = msg;
    notifyListeners();
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      toastMessage = null;
      notifyListeners();
    });
  }

  // ==================================================================
  // Onboarding / folder
  // ==================================================================
  Future<void> pickFolder() async {
    await _ensureStoragePermission();
    final path = await FilePicker.getDirectoryPath(dialogTitle: L.choose);
    if (path == null) return;
    folder = path;
    await store.setFolder(path);
    screen = AppScreen.library;
    notifyListeners();
    await rescanLibrary();
  }

  /// Android scopes filesystem access behind runtime permissions; without
  /// this, recursively listing the chosen folder via dart:io can silently
  /// come back empty on API 30+ even though the folder picker succeeded.
  Future<void> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return;
    final audio = await Permission.audio.status;
    if (audio.isGranted) return;
    if (await Permission.audio.request().then((s) => s.isGranted)) return;
    await Permission.storage.request();
  }

  Future<void> rescanLibrary() async {
    if (folder == null) return;
    scanningLibrary = true;
    notifyListeners();
    tracks = await library.scan(folder!);
    scanningLibrary = false;
    notifyListeners();
  }

  // ==================================================================
  // Navigation
  // ==================================================================
  void nav(AppScreen s) {
    screen = s;
    filterOpen = false;
    if (s == AppScreen.transfer) startTransferScan();
    notifyListeners();
  }

  // ==================================================================
  // Library: search / sort / filter
  // ==================================================================
  List<Track> get visibleTracks {
    final q = query.trim().toLowerCase();
    var list = tracks.where((t) {
      final okQ = q.isEmpty || ('${t.title} ${t.artist} ${t.album}').toLowerCase().contains(q);
      final okTags = tagFilter.isEmpty || tagFilter.every((g) => t.tags.contains(g));
      return okQ && okTags;
    }).toList();
    list.sort((a, b) {
      int r;
      switch (sortKey) {
        case SortKey.duration:
          r = a.durationSeconds.compareTo(b.durationSeconds);
        case SortKey.tags:
          r = (a.tags.isNotEmpty ? a.tags.first : '').compareTo(b.tags.isNotEmpty ? b.tags.first : '');
        case SortKey.artist:
          r = a.artist.compareTo(b.artist);
        case SortKey.album:
          r = a.album.compareTo(b.album);
        case SortKey.title:
          r = a.title.compareTo(b.title);
      }
      return sortDir == SortDir.asc ? r : -r;
    });
    return list;
  }

  void setQuery(String v) {
    query = v;
    notifyListeners();
  }

  void setSortKey(SortKey k) {
    sortKey = k;
    notifyListeners();
  }

  void toggleSortDir() {
    sortDir = sortDir == SortDir.asc ? SortDir.desc : SortDir.asc;
    notifyListeners();
  }

  void toggleFilterOpen() {
    filterOpen = !filterOpen;
    notifyListeners();
  }

  void toggleTagFilter(String tag) {
    if (tagFilter.contains(tag)) {
      tagFilter = tagFilter.where((t) => t != tag).toList();
    } else {
      tagFilter = [...tagFilter, tag];
    }
    notifyListeners();
  }

  void resetFilter() {
    tagFilter = [];
    query = '';
    notifyListeners();
  }

  // ==================================================================
  // Playback / queue
  // ==================================================================
  Future<void> _playCurrent({bool autoplay = true}) async {
    final t = current;
    if (t == null) return;
    await engine.open(Uri.file(t.filePath).toString(), play: autoplay);
  }

  Future<void> play(String trackId) async {
    final i = queueIds.indexOf(trackId);
    if (i >= 0) {
      curIndex = i;
    } else {
      queueIds.insert(curIndex + (queueIds.isEmpty ? 0 : 1), trackId);
      if (queueIds.length > 1) curIndex += 1;
    }
    notifyListeners();
    await _playCurrent();
  }

  Future<void> openSong(String trackId) async {
    await play(trackId);
    screen = AppScreen.song;
    notifyListeners();
  }

  void closeSong() {
    screen = AppScreen.library;
    notifyListeners();
  }

  Future<void> toggleQ() async {
    if (output == AudioOutput.peer) {
      // Local transport is muted while a peer is playing - transport
      // commands go over the network instead.
      final peer = network.pairedPeer;
      if (peer != null) {
        await network.sendCommand(peer, 'transport', {'action': playing ? 'pause' : 'play'});
      }
      playing = !playing;
      notifyListeners();
      return;
    }
    if (engine.isPlaying) {
      await engine.pause();
    } else {
      await engine.play();
    }
  }

  Future<void> step(int delta) async {
    if (queueIds.isEmpty) return;
    curIndex = (curIndex + delta + queueIds.length) % queueIds.length;
    notifyListeners();
    await _playCurrent(autoplay: playing);
  }

  Future<void> next() => step(1);
  Future<void> prev() => step(-1);

  Future<void> seekFraction(double fraction) async {
    final t = current;
    if (t == null) return;
    final target = Duration(milliseconds: (t.durationSeconds * 1000 * fraction).round());
    await engine.seek(target);
  }

  void moveQueue(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= queueIds.length) return;
    final item = queueIds.removeAt(i);
    queueIds.insert(j, item);
    if (curIndex == i) {
      curIndex = j;
    } else if (curIndex == j) {
      curIndex = i;
    }
    notifyListeners();
  }

  void startHold(String trackId) {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 300), () {
      moveId = trackId;
      notifyListeners();
    });
  }

  void cancelHold() => _holdTimer?.cancel();

  void endMove() {
    moveId = null;
    notifyListeners();
  }

  void removeFromQueue(String trackId) {
    final idx = queueIds.indexOf(trackId);
    if (idx < 0) return;
    queueIds.removeAt(idx);
    if (curIndex >= queueIds.length) curIndex = queueIds.length - 1;
    if (curIndex < 0) curIndex = 0;
    notifyListeners();
  }

  void clearQueue() {
    queueIds = [];
    curIndex = 0;
    playing = false;
    engine.pause();
    notifyListeners();
  }

  void addAllToQueue() {
    queueIds = tracks.map((t) => t.id).toList();
    notifyListeners();
  }

  // ==================================================================
  // Transfer / pairing
  // ==================================================================
  void startTransferScan() {
    scanningDevices = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 1200), () {
      scanningDevices = false;
      notifyListeners();
    });
  }

  Future<void> rescan() async {
    startTransferScan();
  }

  Future<void> tapDevice(LanDevice device) async {
    outgoingPairTargetId = device.id;
    notifyListeners();
    await network.requestPair(device);
  }

  void _onIncomingPairRequest(IncomingPairRequest req) {
    pendingIncomingPair = req.from;
    notifyListeners();
  }

  Future<void> answerIncomingPair(bool accept) async {
    final req = pendingIncomingPair;
    if (req == null) return;
    if (accept) {
      await network.acceptIncomingPair(req);
      toast('${L.paired} · ${req.name}');
    } else {
      await network.declineIncomingPair(req);
    }
    pendingIncomingPair = null;
    notifyListeners();
  }

  void _onPairAnswer(PairAnswer answer) async {
    if (outgoingPairTargetId != answer.fromId) return;
    if (answer.accepted) {
      final device = discoveredDevices.where((d) => d.id == answer.fromId).firstOrNull;
      if (device != null) await network.confirmPairedFromAnswer(device);
      toast(L.paired);
    } else {
      toast(L.decline);
    }
    outgoingPairTargetId = null;
    notifyListeners();
  }

  LanDevice? get paired => network.pairedPeer;

  Future<void> unpair() async {
    await network.unpair();
    output = AudioOutput.local;
    notifyListeners();
  }

  // ==================================================================
  // Audio-output handoff (PC <-> phone speaker switch)
  // ==================================================================
  Future<void> setOutput(AudioOutput o) async {
    final peer = network.pairedPeer;
    if (o == AudioOutput.peer && peer == null) {
      toast('${L.transfer} → ${L.pair}');
      return;
    }
    if (o == output) return;
    final t = current;
    if (o == AudioOutput.peer) {
      final url = t == null ? null : await network.streamUrlFor(t.id);
      if (t != null && url != null) {
        await network.sendCommand(peer!, 'takeOverPlayback', {
          'trackId': t.id,
          'title': t.title,
          'artist': t.artist,
          'album': t.album,
          'positionSeconds': position.inSeconds,
          'streamUrl': url,
        });
      }
      await engine.pause();
      toast(L.playingOnPhone);
    } else {
      if (peer != null) await network.sendCommand(peer, 'releasePlayback', {});
      if (t != null) await _playCurrent(autoplay: true);
      toast(L.playingOnPc);
    }
    output = o;
    notifyListeners();
  }

  void _onRemoteCommand(RemoteCommand cmd) async {
    switch (cmd.cmd) {
      case 'takeOverPlayback':
        final url = cmd.data['streamUrl'] as String?;
        if (url == null) return;
        output = AudioOutput.peer; // we are now the speaker, peer is "remote"
        await engine.open(url, play: true);
        playing = true;
        toast('${L.nowPlaying}: ${cmd.data['title']}');
        notifyListeners();
      case 'releasePlayback':
        await engine.pause();
        playing = false;
        output = AudioOutput.local;
        notifyListeners();
      case 'transport':
        final action = cmd.data['action'] as String?;
        if (action == 'play') {
          await engine.play();
        } else if (action == 'pause') {
          await engine.pause();
        }
      case 'tagUpdate':
        final trackId = cmd.data['trackId'] as String?;
        if (trackId == null) return;
        toast('${L.sent} · ${cmd.data['title']}');
    }
  }

  // ==================================================================
  // Track editing / tag sync
  // ==================================================================
  void openEdit(String trackId) {
    final t = trackById(trackId);
    if (t == null) return;
    draft = TrackDraft(trackId: t.id, title: t.title, artist: t.artist, album: t.album, tags: List.of(t.tags));
    editingTrack = true;
    notifyListeners();
  }

  void updateDraftTitle(String v) {
    draft?.title = v;
    notifyListeners();
  }

  void updateDraftArtist(String v) {
    draft?.artist = v;
    notifyListeners();
  }

  void updateDraftAlbum(String v) {
    draft?.album = v;
    notifyListeners();
  }

  Future<void> pickDraftCover() async {
    final res = await FilePicker.pickFiles(type: FileType.image);
    final path = res?.files.single.path;
    if (path == null || draft == null) return;
    draft!.newCoverPath = path;
    notifyListeners();
  }

  void toggleDraftTag(String tag) {
    final d = draft;
    if (d == null) return;
    if (d.tags.contains(tag)) {
      d.tags.remove(tag);
    } else {
      d.tags.add(tag);
    }
    notifyListeners();
  }

  void closeEdit() {
    editingTrack = false;
    draft = null;
    notifyListeners();
  }

  Future<void> commitEdit() async {
    final d = draft;
    if (d == null) return;
    final t = trackById(d.trackId);
    if (t == null) return;

    await library.saveTrackMetadata(t, title: d.title, artist: d.artist, album: d.album, newCoverPath: d.newCoverPath);
    await library.saveTrackTags(d.trackId, d.tags);

    final idx = tracks.indexWhere((x) => x.id == d.trackId);
    if (idx >= 0) {
      tracks[idx] = tracks[idx].copyWith(
        title: d.title,
        artist: d.artist,
        album: d.album,
        tags: d.tags,
        customCoverPath: d.newCoverPath,
      );
    }
    editingTrack = false;

    final peer = network.pairedPeer;
    if (peer != null && !dontAskDeviceIds.contains(peer.id)) {
      dontAskDraft = false;
      syncPromptVisible = true;
    } else {
      toast(L.saved);
    }
    draft = null;
    notifyListeners();
  }

  void toggleDontAskDraft() {
    dontAskDraft = !dontAskDraft;
    notifyListeners();
  }

  Future<void> syncAnswer(bool yes) async {
    if (dontAskDraft) {
      final peer = network.pairedPeer;
      if (peer != null) {
        dontAskDeviceIds = {...dontAskDeviceIds, peer.id};
        await store.setDontAskDeviceIds(dontAskDeviceIds);
      }
    }
    syncPromptVisible = false;
    if (yes) {
      final peer = network.pairedPeer;
      final t = current;
      if (peer != null && t != null) {
        await network.sendCommand(peer, 'tagUpdate', {
          'trackId': t.id,
          'title': t.title,
          'artist': t.artist,
          'album': t.album,
          'tags': t.tags,
        });
      }
      toast('${L.sent} ${peer?.name ?? ''}');
    } else {
      toast(L.saved);
    }
    notifyListeners();
  }

  // ==================================================================
  // Settings
  // ==================================================================
  Future<void> setThemeMode(AppThemeMode m) async {
    themeMode = m;
    await store.setTheme(m.name);
    notifyListeners();
  }

  Future<void> setColorChoice(AccentChoice c) async {
    colorChoice = c;
    await store.setColorChoice(c.name);
    notifyListeners();
  }

  Future<void> setLang(AppLang l) async {
    lang = l;
    await store.setLang(l.name);
    notifyListeners();
  }

  Future<void> setTranscode(bool v) async {
    transcode = v;
    await store.setTranscode(v);
    notifyListeners();
  }

  Future<void> setDeviceName(String v) async {
    deviceName = v;
    await store.setDeviceName(v);
    notifyListeners();
  }

  Future<void> toggleNet() async {
    netOn = !netOn;
    await store.setNetOn(netOn);
    if (netOn) {
      await network.startScan();
    } else {
      await network.stopScan();
    }
    notifyListeners();
  }

  void restartNetwork() {
    toast('${L.restart}…');
    network.stopScan().then((_) => network.startScan());
  }

  Future<void> addTag() async {
    final v = newTagDraft.trim();
    if (v.isEmpty) return;
    allTags = [...allTags, v];
    newTagDraft = '';
    await store.setAllTags(allTags);
    notifyListeners();
  }

  void setNewTagDraft(String v) {
    newTagDraft = v;
    notifyListeners();
  }

  Future<void> deleteTag(String name) async {
    allTags = allTags.where((t) => t != name).toList();
    tagFilter = tagFilter.where((t) => t != name).toList();
    tracks = tracks.map((t) => t.copyWith(tags: t.tags.where((x) => x != name).toList())).toList();
    await store.setAllTags(allTags);
    final map = await store.trackTags;
    map.updateAll((key, v) => v.where((x) => x != name).toList());
    await store.setTrackTags(map);
    notifyListeners();
  }

  void startRenameTag(String name) {
    renamingTag = name;
    renameValue = name;
    notifyListeners();
  }

  void setRenameValue(String v) {
    renameValue = v;
    notifyListeners();
  }

  Future<void> commitRenameTag() async {
    final oldName = renamingTag;
    final newName = renameValue.trim();
    if (oldName == null || newName.isEmpty) {
      renamingTag = null;
      notifyListeners();
      return;
    }
    allTags = allTags.map((t) => t == oldName ? newName : t).toList();
    tagFilter = tagFilter.map((t) => t == oldName ? newName : t).toList();
    tracks = tracks
        .map((t) => t.copyWith(tags: t.tags.map((x) => x == oldName ? newName : x).toList()))
        .toList();
    await store.setAllTags(allTags);
    final map = await store.trackTags;
    map.updateAll((key, v) => v.map((x) => x == oldName ? newName : x).toList());
    await store.setTrackTags(map);
    renamingTag = null;
    notifyListeners();
  }

  // ==================================================================
  // Custom colour picker (ring = hue, triangle = saturation/value)
  // ==================================================================
  void openColorPicker() {
    final hsv = _hexToHsv(customHex);
    pickerHue = hsv.$1;
    pickerSat = hsv.$2;
    pickerVal = hsv.$3;
    colorPickerOpen = true;
    notifyListeners();
  }

  void closeColorPicker() {
    colorPickerOpen = false;
    notifyListeners();
  }

  void setHueFromAngle(double degrees) {
    pickerHue = degrees % 360;
    notifyListeners();
  }

  void setSatValFromTriangle(double s, double v) {
    pickerSat = s.clamp(0, 1);
    pickerVal = v.clamp(0.02, 1);
    notifyListeners();
  }

  String get pickerHex => _hsvToHex(pickerHue, pickerSat, pickerVal);
  String get pickerHueHex => _hsvToHex(pickerHue, 1, 1);

  Future<void> acceptColor() async {
    customHex = pickerHex;
    colorChoice = AccentChoice.custom;
    colorPickerOpen = false;
    await store.setCustomHex(customHex);
    await store.setColorChoice('custom');
    toast(L.saved);
    notifyListeners();
  }

  static String _hsvToHex(double h, double s, double v) {
    double f(double n) {
      final k = (n + h / 60) % 6;
      return v - v * s * [k, 4 - k, 1.0].reduce((a, b) => a < b ? a : b).clamp(0, double.infinity);
    }

    final r = (f(5) * 255).round().clamp(0, 255);
    final g = (f(3) * 255).round().clamp(0, 255);
    final b = (f(1) * 255).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }

  static (double, double, double) _hexToHsv(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6) return (258, 0.4, 0.85);
    final r = int.parse(clean.substring(0, 2), radix: 16) / 255;
    final g = int.parse(clean.substring(2, 4), radix: 16) / 255;
    final b = int.parse(clean.substring(4, 6), radix: 16) / 255;
    final mx = [r, g, b].reduce((a, c) => a > c ? a : c);
    final mn = [r, g, b].reduce((a, c) => a < c ? a : c);
    final d = mx - mn;
    double h = 0;
    if (d != 0) {
      if (mx == r) {
        h = 60 * (((g - b) / d) % 6);
      } else if (mx == g) {
        h = 60 * ((b - r) / d + 2);
      } else {
        h = 60 * ((r - g) / d + 4);
      }
    }
    if (h < 0) h += 360;
    final s = mx == 0 ? 0.0 : d / mx;
    return (h, s, mx);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

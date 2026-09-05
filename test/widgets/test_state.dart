import 'package:shared_preferences/shared_preferences.dart';

import 'package:nocturne_player/audio/fake_playback_engine.dart';
import 'package:nocturne_player/data/app_store.dart';
import 'package:nocturne_player/data/library_repository.dart';
import 'package:nocturne_player/models/track.dart';
import 'package:nocturne_player/network/network_service.dart';
import 'package:nocturne_player/state/player_app_state.dart';

/// A handful of tracks mirroring the prototype's demo library (see the
/// TRACKS array in MP3 Local Player.dc.html) so golden screenshots look
/// like the design instead of an empty state.
final sampleTracks = <Track>[
  const Track(id: '1', filePath: '/music/1.mp3', title: 'Ночной трамвай', artist: 'Кассетный сад', album: 'Полустанок', durationSeconds: 214, coverHue: 268, tags: ['Дорога', 'Вечер']),
  const Track(id: '2', filePath: '/music/2.mp3', title: 'Тихий этаж', artist: 'Мурманский свет', album: 'Полустанок', durationSeconds: 187, coverHue: 212, tags: ['Работа']),
  const Track(id: '3', filePath: '/music/3.mp3', title: 'Апрельский лёд', artist: 'Кассетный сад', album: 'Апрельский лёд', durationSeconds: 301, coverHue: 30, tags: ['Вечер']),
  const Track(id: '4', filePath: '/music/4.mp3', title: 'Пятый маршрут', artist: 'Дом на Заводской', album: 'Сборник 03', durationSeconds: 156, coverHue: 158, tags: ['Дорога', 'Бодрое']),
  const Track(id: '5', filePath: '/music/5.mp3', title: 'Сигнал занят', artist: 'Дом на Заводской', album: 'Сборник 03', durationSeconds: 243, coverHue: 340, tags: ['Работа']),
  const Track(id: '6', filePath: '/music/6.mp3', title: 'Двор без окон', artist: 'Мурманский свет', album: 'Двор без окон', durationSeconds: 268, coverHue: 190, tags: ['Вечер', 'Тихое']),
];

/// Builds a fully-wired [PlayerAppState] without calling [PlayerAppState.init]
/// (which would touch real sockets/plugins) - fields are set directly so
/// widget/golden tests exercise the exact same widget tree the app renders.
Future<PlayerAppState> buildTestState({bool isDesktop = false}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await AppStore.load(keySuffix: '-widgettest-${DateTime.now().microsecondsSinceEpoch}');
  final library = LibraryRepository(store);
  final network = NetworkService(store: store, isDesktop: isDesktop, resolveTrackPath: (_) => '');
  final state = PlayerAppState(
    store: store,
    library: library,
    network: network,
    isDesktop: isDesktop,
    engine: FakePlaybackEngine(),
  );
  state.folder = '/storage/emulated/0/Music';
  state.tracks = sampleTracks;
  state.allTags = ['Дорога', 'Вечер', 'Работа', 'Тихое', 'Бодрое'];
  state.deviceName = isDesktop ? 'DESKTOP-4KQ7' : 'Redmi-Note';
  return state;
}

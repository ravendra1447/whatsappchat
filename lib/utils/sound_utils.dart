import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundUtils {
  static final Map<String, AudioPlayer> _players = {};
  static final Map<String, Uint8List> _soundBytes = {};

  static Future<void> init() async {
    try {
      _soundBytes['send'] = await _loadAsset('assets/sounds/send.mp3');
      _soundBytes['receive'] = await _loadAsset('assets/sounds/receive.mp3');
      _soundBytes['delivered'] = await _loadAsset('assets/sounds/delivered.mp3');
      _soundBytes['read'] = await _loadAsset('assets/sounds/read.mp3');
      print("✅ All sound assets loaded successfully.");
    } catch (e) {
      print("❌ Error loading sound assets: $e");
    }
  }

  static Future<Uint8List> _loadAsset(String path) async {
    final byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
  }

  static Future<void> playSound(String soundKey) async {
    try {
      if (!_soundBytes.containsKey(soundKey)) {
        print("⚠️ Sound bytes not loaded for $soundKey. Cannot play.");
        return;
      }

      final bytes = _soundBytes[soundKey];
      if (bytes == null) {
        print("❌ Sound bytes are null for $soundKey. Cannot play.");
        return;
      }

      // 🛑 पहले existing player को dispose करें
      if (_players.containsKey(soundKey)) {
        await _players[soundKey]?.dispose();
      }

      final player = AudioPlayer();

      // ✅ Player के events handle करें
      player.onPlayerStateChanged.listen((state) {
        print('🔊 Player state: $state');
      });

      player.onLog.listen((log) {
        print('🔊 Audio log: $log');
      });

      // ✅ BytesSource के बजाय AssetSource use करें
      await player.setSource(AssetSource('sounds/${soundKey}.mp3'));
      await player.resume();

      _players[soundKey] = player;

    } catch (e) {
      print("❌ Error playing sound from $soundKey: $e");
      await _playFallbackSound(soundKey);
    }
  }

  // Fallback method
  static Future<void> _playFallbackSound(String soundKey) async {
    try {
      final player = AudioPlayer();
      // Simple beep sound के लिए
      await player.play(AssetSource('sounds/fallback.mp3'));
    } catch (e) {
      print('🔇 Fallback sound also failed: $e');
    }
  }

  static Future<void> playSendSound() async {
    await playSound('send');
  }

  static Future<void> playReceiveSound() async {
    await playSound('receive');
  }

  static Future<void> playDeliveredSound() async {
    await playSound('delivered');
  }

  static Future<void> playReadSound() async {
    await playSound('read');
  }

  static Future<void> playNotificationSound() async {
    await playReceiveSound();
  }

  static Future<void> dispose() async {
    for (var player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    print("✅ All audio players disposed.");
  }
}
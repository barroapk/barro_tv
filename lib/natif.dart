import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pont vers la partie Android de Barro Play.
class Natif {
  static const _canal = MethodChannel('barro/lecteur');

  /// Vrai quand la vidéo est en superposition (petite fenêtre flottante).
  static final pipEnCours = ValueNotifier<bool>(false);

  /// Appelé quand on ouvre une vidéo du téléphone alors que l'app tourne déjà.
  static void Function(String lien)? onOuvrir;

  static void init() {
    _canal.setMethodCallHandler((call) async {
      if (call.method == 'pip') pipEnCours.value = call.arguments == true;
      if (call.method == 'ouvrir') onOuvrir?.call(call.arguments as String);
    });
  }

  static Future<T?> _appel<T>(String methode, [Map<String, Object?>? args]) async {
    try {
      return await _canal.invokeMethod<T>(methode, args);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> lienExterne() => _appel<String>('lienExterne');
  static Future<double> luminosite() async => (await _appel<double>('luminosite')) ?? -1;
  static Future<void> setLuminosite(double v) => _appel('setLuminosite', {'v': v});
  static Future<double> volume() async => (await _appel<double>('volume')) ?? 0.5;
  static Future<void> setVolume(double v) => _appel('setVolume', {'v': v});
  static Future<void> eveil(bool v) => _appel('eveil', {'v': v});
  static Future<void> autoriserPip(bool v, [double ratio = 16 / 9]) =>
      _appel('autoriserPip', {'v': v, 'ratio': ratio});
  static Future<bool> pip(double ratio) async =>
      (await _appel<bool>('pip', {'ratio': ratio})) ?? false;
}

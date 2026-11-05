import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'main.dart';

/// Renvoie le catalogue, et `true` s'il vient de la copie gardée dans le téléphone.
Future<(String, bool)> lireCatalogue() async {
  final dir = await getApplicationSupportDirectory();
  final f = File('${dir.path}/catalogue.json');
  try {
    final r = await http
        .get(Uri.parse(lienCatalogue))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 200) {
      await f.writeAsString(r.body);
      return (r.body, false);
    }
  } catch (_) {}
  if (await f.exists()) return (await f.readAsString(), true);
  throw Exception('Hors connexion');
}

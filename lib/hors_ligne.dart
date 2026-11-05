import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'main.dart';

Future<String> lireCatalogue() async {
  final dir = await getApplicationSupportDirectory();
  final f = File('${dir.path}/catalogue.json');
  try {
    final r = await http
        .get(Uri.parse(lienCatalogue))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 200) {
      await f.writeAsString(r.body);
      return r.body;
    }
  } catch (_) {}
  if (await f.exists()) return f.readAsString();
  throw Exception('Hors connexion');
}

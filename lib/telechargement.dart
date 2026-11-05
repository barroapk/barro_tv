import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' show CTRStreamCipher, AESEngine, ParametersWithIV, KeyParameter;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main.dart';

Future<Uint8List> lireCle() async {
  const s = FlutterSecureStorage();
  var k = await s.read(key: 'cle');
  if (k == null) {
    final r = Random.secure();
    k = base64Encode(List.generate(32, (_) => r.nextInt(256)));
    await s.write(key: 'cle', value: k);
  }
  return base64Decode(k);
}

Future<File> fichierDe(Contenu c) async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/${c.id}.bk');
}

Future<void> telecharger(Contenu c, void Function(double) progres) async {
  final cle = await lireCle();
  final r = Random.secure();
  final iv = Uint8List.fromList(List.generate(16, (_) => r.nextInt(256)));
  final chiffreur = CTRStreamCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(cle), iv));

  final rep = await http.Client().send(http.Request('GET', Uri.parse(c.video)));
  if (rep.statusCode != 200) throw Exception('Erreur ${rep.statusCode}');
  final total = rep.contentLength ?? 0;

  final fin = await fichierDe(c);
  final temp = File('${fin.path}.part');
  final sink = temp.openWrite();
  sink.add(iv);
  var recu = 0;
  await for (final morceau in rep.stream) {
    sink.add(chiffreur.process(Uint8List.fromList(morceau)));
    recu += morceau.length;
    if (total > 0) progres(recu / total);
  }
  await sink.close();
  await temp.rename(fin.path);
}

class Details extends StatefulWidget {
  final Contenu c;
  const Details({super.key, required this.c});
  @override
  State<Details> createState() => _DetailsState();
}

class _DetailsState extends State<Details> {
  bool telecharge = false;
  double? progres;
  String? erreur;

  @override
  void initState() {
    super.initState();
    fichierDe(widget.c).then((f) async {
      if (await f.exists()) setState(() => telecharge = true);
    });
  }

  Future<void> lancer() async {
    setState(() { progres = 0; erreur = null; });
    try {
      await telecharger(widget.c, (p) => setState(() => progres = p));
      setState(() => telecharge = true);
    } catch (e) {
      setState(() => erreur = 'Échec : $e');
    }
    setState(() => progres = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: Text(c.titre)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: c.affiche.isEmpty
              ? Container(height: 300, color: const Color(0xFF1C1C1C),
                  child: const Icon(Icons.movie, color: rouge, size: 60))
              : Image.network(c.affiche, height: 300, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        Text(c.titre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text('Réalisateur : ${c.realisateur}', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        if (telecharge)
          const Row(children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Téléchargé'),
          ])
        else if (progres != null) ...[
          LinearProgressIndicator(value: progres, color: rouge),
          const SizedBox(height: 8),
          Text('${(progres! * 100).toStringAsFixed(0)} %'),
        ] else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: rouge, foregroundColor: Colors.white),
            onPressed: c.video.isEmpty ? null : lancer,
            icon: const Icon(Icons.download),
            label: const Text('Télécharger'),
          ),
        if (erreur != null)
          Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(erreur!, style: const TextStyle(color: rouge))),
      ]),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart'
    show CTRStreamCipher, AESEngine, ParametersWithIV, KeyParameter;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main.dart';
import 'lecteur.dart';
import 'widgets.dart';

// ---------- Chiffrement et stockage caché ----------

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

Future<bool> confirmerSuppression(BuildContext context, Contenu c) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Supprimer la vidéo ?', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text(
        '« ${c.titre} » sera retiré de ton téléphone. Tu pourras le télécharger à nouveau.',
        style: const TextStyle(color: gris, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: const Text('Annuler', style: TextStyle(color: gris)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: rouge, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(d, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  final f = await fichierDe(c);
  if (await f.exists()) await f.delete();
  return true;
}

void lire(BuildContext context, Contenu c) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => BarroPlay.film(c)));

// ---------- Page détail d'un film ----------

class Details extends StatefulWidget {
  final Contenu c;
  const Details({super.key, required this.c});

  @override
  State<Details> createState() => _DetailsState();
}

class _DetailsState extends State<Details> {
  bool telecharge = false;
  double? progres;

  @override
  void initState() {
    super.initState();
    verifier();
  }

  Future<void> verifier() async {
    final ok = await (await fichierDe(widget.c)).exists();
    if (mounted) setState(() => telecharge = ok);
  }

  Future<void> lancer() async {
    setState(() => progres = 0);
    try {
      await telecharger(widget.c, (p) {
        if (mounted) setState(() => progres = p);
      });
      if (mounted) setState(() => telecharge = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.error_outline_rounded, color: rouge),
            SizedBox(width: 12),
            Expanded(child: Text('Le téléchargement a échoué. Vérifie ta connexion et réessaie.')),
          ]),
        ));
      }
    }
    if (mounted) setState(() => progres = null);
  }

  Future<void> supprimer() async {
    final ok = await confirmerSuppression(context, widget.c);
    if (ok && mounted) setState(() => telecharge = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final h = MediaQuery.of(context).size.height * 0.55;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.black45,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: ListView(padding: EdgeInsets.zero, children: [
        SizedBox(
          height: h,
          child: Stack(fit: StackFit.expand, children: [
            Affiche(c: c, largeur: double.infinity, hauteur: h, rayon: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0x000B0B0F), fond],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Etiquette(c.type == 'serie' ? 'SÉRIE' : 'FILM'),
            const SizedBox(height: 10),
            Text(c.titre,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.1)),
            if (c.infos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(c.infos, style: const TextStyle(color: gris, fontSize: 14)),
              ),
            const SizedBox(height: 22),
            actions(c),
            if (c.resume.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('Résumé', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(c.resume,
                  style: const TextStyle(color: Color(0xFFCFCFD8), fontSize: 14, height: 1.6)),
            ],
            if (c.realisateur.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: [
                const Text('Réalisation   ', style: TextStyle(color: gris)),
                Expanded(
                  child: Text(c.realisateur, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget actions(Contenu c) {
    const vert = Color(0xFF2ECC71);
    if (progres != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: rouge),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Téléchargement en cours…',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text('${(progres! * 100).toStringAsFixed(0)} %',
                style: const TextStyle(fontWeight: FontWeight.w800, color: rouge)),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: progres, minHeight: 6, color: rouge, backgroundColor: surface2),
          ),
        ]),
      );
    }
    if (telecharge) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => lire(context, c),
          icon: const Icon(Icons.play_arrow_rounded, size: 28),
          label: const Text('Lire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.offline_pin_rounded, color: vert, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Disponible sans connexion',
                style: TextStyle(color: vert, fontWeight: FontWeight.w600)),
          ),
          TextButton.icon(
            onPressed: supprimer,
            icon: const Icon(Icons.delete_outline_rounded, color: gris, size: 20),
            label: const Text('Supprimer', style: TextStyle(color: gris)),
          ),
        ]),
      ]);
    }
    final dispo = c.video.isNotEmpty;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: rouge,
        foregroundColor: Colors.white,
        disabledBackgroundColor: surface2,
        disabledForegroundColor: gris,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: dispo ? lancer : null,
      icon: Icon(dispo ? Icons.download_rounded : Icons.schedule_rounded),
      label: Text(dispo ? 'Télécharger' : 'Bientôt disponible',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    );
  }
}

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

const vert = Color(0xFF2ECC71);

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

// ---------- Gestionnaire de téléchargements ----------

/// Téléchargements en cours, visibles partout dans l'app (id → progression 0..1).
final enCours = ValueNotifier<Map<String, double>>({});

Future<void> lancerTelechargement(Contenu c) async {
  if (enCours.value.containsKey(c.id)) return;
  void maj(double p) {
    final ancien = enCours.value[c.id] ?? -1;
    if (p - ancien >= 0.01 || p >= 1) enCours.value = {...enCours.value, c.id: p};
  }

  enCours.value = {...enCours.value, c.id: 0};
  try {
    await telecharger(c, maj);
  } finally {
    enCours.value = Map.of(enCours.value)..remove(c.id);
  }
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

/// Lecteur d'un épisode qui sait enchaîner sur l'épisode suivant téléchargé.
BarroPlay lecteurEpisode(List<Contenu> episodes, int i) => BarroPlay.film(
      episodes[i],
      suivant: () async {
        final j = i + 1;
        if (j >= episodes.length) return null;
        if (!await (await fichierDe(episodes[j])).exists()) return null;
        return lecteurEpisode(episodes, j);
      },
    );

void lireEpisode(BuildContext context, List<Contenu> episodes, int i) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => lecteurEpisode(episodes, i)));

// ---------- Page détail d'un film ou d'une série ----------

class Details extends StatefulWidget {
  final Contenu c;
  const Details({super.key, required this.c});

  @override
  State<Details> createState() => _DetailsState();
}

class _DetailsState extends State<Details> {
  final telecharges = <String>{};
  int saison = 0;
  late final List<Contenu> elements = widget.c.elements;
  late Set<String> precedents = enCours.value.keys.toSet();

  bool get estSerie => widget.c.type == 'serie';

  @override
  void initState() {
    super.initState();
    verifier();
    enCours.addListener(_surChangement);
  }

  @override
  void dispose() {
    enCours.removeListener(_surChangement);
    super.dispose();
  }

  /// Quand un téléchargement se termine, on revérifie les fichiers.
  void _surChangement() {
    final actuels = enCours.value.keys.toSet();
    if (precedents.difference(actuels).isNotEmpty) verifier();
    precedents = actuels;
  }

  Future<void> verifier() async {
    final s = <String>{};
    for (final e in elements) {
      if (await (await fichierDe(e)).exists()) s.add(e.id);
    }
    if (mounted) {
      setState(() => telecharges
        ..clear()
        ..addAll(s));
    }
  }

  Future<void> demarrer(Contenu e) async {
    try {
      await lancerTelechargement(e);
    } catch (_) {
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
  }

  Future<void> telechargerSaison(Saison s) async {
    for (final e in s.episodes) {
      final ep = Contenu.episode(widget.c, s, e);
      if (e.video.isEmpty || telecharges.contains(ep.id) || enCours.value.containsKey(ep.id)) {
        continue;
      }
      await demarrer(ep);
    }
  }

  Future<void> supprimer(Contenu e) async {
    final ok = await confirmerSuppression(context, e);
    if (ok && mounted) setState(() => telecharges.remove(e.id));
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
      body: ValueListenableBuilder<Map<String, double>>(
        valueListenable: enCours,
        builder: (context, prog, _) => ListView(padding: EdgeInsets.zero, children: [
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
              Etiquette(estSerie ? 'SÉRIE' : 'FILM'),
              const SizedBox(height: 10),
              Text(c.titre,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.1)),
              if (c.infos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(c.infos, style: const TextStyle(color: gris, fontSize: 14)),
                ),
              const SizedBox(height: 22),
              if (!estSerie) actionsFilm(c, prog),
              if (c.resume.isNotEmpty) ...[
                SizedBox(height: estSerie ? 0 : 28),
                const Text('Résumé', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(c.resume,
                    style: const TextStyle(color: Color(0xFFCFCFD8), fontSize: 14, height: 1.6)),
              ],
              if (c.realisateur.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(children: [
                  const Text('Réalisation   ', style: TextStyle(color: gris)),
                  Expanded(
                    child: Text(c.realisateur, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
              if (estSerie) ...[
                const SizedBox(height: 28),
                episodes(prog),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  // ----- Film -----

  Widget actionsFilm(Contenu c, Map<String, double> prog) {
    final p = prog[c.id];
    if (p != null) {
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
            Text('${(p * 100).toStringAsFixed(0)} %',
                style: const TextStyle(fontWeight: FontWeight.w800, color: rouge)),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: p, minHeight: 6, color: rouge, backgroundColor: surface2),
          ),
        ]),
      );
    }
    if (telecharges.contains(c.id)) {
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
            onPressed: () => supprimer(c),
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
      onPressed: dispo ? () => demarrer(c) : null,
      icon: Icon(dispo ? Icons.download_rounded : Icons.schedule_rounded),
      label: Text(dispo ? 'Télécharger' : 'Bientôt disponible',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    );
  }

  // ----- Série -----

  Widget episodes(Map<String, double> prog) {
    final c = widget.c;
    if (c.saisons.isEmpty) {
      return const Text('Les épisodes arrivent bientôt.', style: TextStyle(color: gris));
    }
    final i = saison.clamp(0, c.saisons.length - 1);
    final s = c.saisons[i];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Épisodes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var k = 0; k < c.saisons.length; k++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('Saison ${c.saisons[k].numero}'),
                selected: k == i,
                showCheckmark: false,
                selectedColor: rouge,
                backgroundColor: surface2,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                labelStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: k == i ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (_) => setState(() => saison = k),
              ),
            ),
        ]),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => telechargerSaison(s),
          icon: const Icon(Icons.download_for_offline_outlined, color: gris, size: 20),
          label: Text('Télécharger la saison ${s.numero}',
              style: const TextStyle(color: gris, fontSize: 13)),
        ),
      ),
      for (final e in s.episodes) ligneEpisode(Contenu.episode(c, s, e), e, prog),
    ]);
  }

  Widget ligneEpisode(Contenu ep, Episode e, Map<String, double> prog) {
    final index = elements.indexWhere((x) => x.id == ep.id);
    final fait = telecharges.contains(ep.id);
    final p = prog[ep.id];

    Widget action;
    if (p != null) {
      action = Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
                value: p, strokeWidth: 3, color: rouge, backgroundColor: surface2),
            Text((p * 100).toStringAsFixed(0),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    } else if (fait) {
      action = PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: gris),
        color: surface2,
        onSelected: (v) {
          if (v == 'suppr') supprimer(ep);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'suppr', child: Text('Supprimer')),
        ],
      );
    } else {
      action = IconButton(
        onPressed: e.video.isEmpty ? null : () => demarrer(ep),
        icon: Icon(
          e.video.isEmpty ? Icons.schedule_rounded : Icons.download_rounded,
          color: e.video.isEmpty ? gris : Colors.white,
        ),
      );
    }

    final sousTitre = ['Épisode ${e.numero}', if (e.duree.isNotEmpty) e.duree, if (fait) 'Téléchargé'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: fait ? () => lireEpisode(context, elements, index) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fait ? rouge : surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: fait
                    ? const Icon(Icons.play_arrow_rounded, color: Colors.white)
                    : Text('${e.numero}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    e.titre.isEmpty ? 'Épisode ${e.numero}' : e.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sousTitre.join('  •  '),
                    style: TextStyle(color: fait ? vert : gris, fontSize: 12),
                  ),
                ]),
              ),
              action,
            ]),
          ),
        ),
      ),
    );
  }
}

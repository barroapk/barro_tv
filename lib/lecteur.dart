import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart'
    show CTRStreamCipher, AESEngine, ParametersWithIV, KeyParameter;
import 'package:video_player/video_player.dart';
import 'main.dart';
import 'natif.dart';
import 'telechargement.dart';
import 'widgets.dart';

/// Déchiffre la vidéo dans une copie temporaire, effacée à la fermeture du lecteur.
Future<File> dechiffrer(Contenu c) async {
  final source = await fichierDe(c);
  final cle = await lireCle();
  final raf = await source.open();
  final iv = await raf.read(16);
  final d = CTRStreamCipher(AESEngine())
    ..init(false, ParametersWithIV(KeyParameter(cle), iv));
  final tmp = await getTemporaryDirectory();
  final sortie = File('${tmp.path}/lecture.mp4');
  final sink = sortie.openWrite();
  while (true) {
    final morceau = await raf.read(65536);
    if (morceau.isEmpty) break;
    sink.add(d.process(morceau));
  }
  await raf.close();
  await sink.close();
  return sortie;
}

/// Mémorise où l'utilisateur s'est arrêté dans chaque vidéo.
class Reprise {
  static Future<File> _fichier() async =>
      File('${(await getApplicationSupportDirectory()).path}/reprises.json');

  static Future<Map<String, dynamic>> _tout() async {
    try {
      final f = await _fichier();
      if (await f.exists()) return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  static Future<Duration> lire(String id) async =>
      Duration(milliseconds: ((await _tout())[id] as num?)?.toInt() ?? 0);

  static Future<void> ecrire(String id, Duration d) async {
    final t = await _tout();
    if (d == Duration.zero) {
      t.remove(id);
    } else {
      t[id] = d.inMilliseconds;
    }
    await (await _fichier()).writeAsString(jsonEncode(t));
  }
}

enum Cadrage { ajuste, remplir, etire }

class BarroPlay extends StatefulWidget {
  final String titre;
  final String? idReprise;
  final Future<(VideoPlayerController, File?)> Function() preparer;
  const BarroPlay({super.key, required this.titre, required this.preparer, this.idReprise});

  /// Film téléchargé et chiffré dans BARRO TV.
  factory BarroPlay.film(Contenu c) => BarroPlay(
        titre: c.titre,
        idReprise: c.id,
        preparer: () async {
          final f = await dechiffrer(c);
          return (VideoPlayerController.file(f), f);
        },
      );

  /// Vidéo du téléphone ouverte avec « Ouvrir avec Barro Play ».
  factory BarroPlay.externe(String lien) {
    final uri = Uri.parse(lien);
    var nom = 'Vidéo';
    if (uri.pathSegments.isNotEmpty) {
      nom = Uri.decodeComponent(uri.pathSegments.last).split('/').last;
      nom = nom.replaceAll(RegExp(r'\.[^.]+$'), '');
    }
    return BarroPlay(
      titre: nom,
      idReprise: 'ext:$lien',
      preparer: () async => (
        uri.scheme.startsWith('http')
            ? VideoPlayerController.networkUrl(uri)
            : VideoPlayerController.contentUri(uri),
        null,
      ),
    );
  }

  @override
  State<BarroPlay> createState() => _BarroPlayState();
}

class _BarroPlayState extends State<BarroPlay> {
  VideoPlayerController? v;
  File? temp;
  bool erreur = false, controles = true, verrou = false, paysage = true, glisseSlider = false;
  double vitesse = 1;
  Cadrage cadrage = Cadrage.ajuste;
  Timer? masquage, sauvegarde, minuteurIndic;
  double? valeurSlider;

  // Gestes
  double largeur = 1, hauteur = 1, xDoubleTap = 0;
  double luminosite = 0.5, volume = 0.5;
  bool zoneGauche = true;
  Duration debutGlisse = Duration.zero;
  Duration? cibleGlisse;
  double dxTotal = 0;

  // Indicateur central (luminosité, volume, avance…)
  IconData? indicIcone;
  String? indicTexte;
  double? indicValeur;

  Duration? repriseProposee;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Natif.eveil(true);
    Natif.pipEnCours.addListener(_maj);
    demarrer();
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  Future<void> demarrer() async {
    try {
      final (ctrl, fichier) = await widget.preparer();
      temp = fichier;
      v = ctrl;
      await ctrl.initialize();
      ctrl.addListener(_maj);
      final id = widget.idReprise;
      if (id != null) {
        final r = await Reprise.lire(id);
        if (r > const Duration(seconds: 10) &&
            r < ctrl.value.duration - const Duration(seconds: 10)) {
          await ctrl.seekTo(r);
          repriseProposee = r;
          Timer(const Duration(seconds: 6), () {
            if (mounted) setState(() => repriseProposee = null);
          });
        }
      }
      await ctrl.play();
      Natif.autoriserPip(true, ctrl.value.aspectRatio);
      sauvegarde = Timer.periodic(const Duration(seconds: 5), (_) => sauver());
      planifierMasquage();
    } catch (e) {
      erreur = true;
    }
    if (mounted) setState(() {});
    final l = await Natif.luminosite();
    luminosite = l < 0 ? 0.5 : l;
    volume = await Natif.volume();
  }

  void sauver() {
    final c = v;
    final id = widget.idReprise;
    if (c == null || id == null || !c.value.isInitialized) return;
    final pos = c.value.position;
    final dur = c.value.duration;
    final fini = dur.inMilliseconds > 0 && pos.inMilliseconds > dur.inMilliseconds * 0.95;
    Reprise.ecrire(id, fini ? Duration.zero : pos);
  }

  @override
  void dispose() {
    masquage?.cancel();
    sauvegarde?.cancel();
    minuteurIndic?.cancel();
    sauver();
    v?.removeListener(_maj);
    v?.dispose();
    temp?.delete().ignore();
    Natif.pipEnCours.removeListener(_maj);
    Natif.autoriserPip(false);
    Natif.eveil(false);
    Natif.setLuminosite(-1);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ---------- Actions ----------

  void planifierMasquage() {
    masquage?.cancel();
    masquage = Timer(const Duration(seconds: 3), () {
      if (mounted && !glisseSlider && (verrou || (v?.value.isPlaying ?? false))) {
        setState(() => controles = false);
      }
    });
  }

  void basculerControles() {
    setState(() => controles = !controles);
    if (controles) planifierMasquage();
  }

  void lecturePause() {
    final c = v!;
    c.value.isPlaying ? c.pause() : c.play();
    planifierMasquage();
  }

  void avancer(int secondes) {
    final c = v!;
    var cible = c.value.position + Duration(seconds: secondes);
    if (cible < Duration.zero) cible = Duration.zero;
    if (cible > c.value.duration) cible = c.value.duration;
    c.seekTo(cible);
    planifierMasquage();
  }

  void indicateur(IconData icone, String texte, [double? valeur]) {
    minuteurIndic?.cancel();
    setState(() {
      indicIcone = icone;
      indicTexte = texte;
      indicValeur = valeur;
    });
    minuteurIndic = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => indicTexte = null);
    });
  }

  void doubleTape() {
    final gauche = xDoubleTap < largeur / 2;
    avancer(gauche ? -10 : 10);
    indicateur(gauche ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded,
        gauche ? '- 10 secondes' : '+ 10 secondes');
  }

  void majVertical(DragUpdateDetails d) {
    final delta = -d.delta.dy / (hauteur * 0.8);
    if (zoneGauche) {
      luminosite = (luminosite + delta).clamp(0.0, 1.0).toDouble();
      Natif.setLuminosite(luminosite);
      indicateur(Icons.brightness_6_rounded, 'Luminosité', luminosite);
    } else {
      volume = (volume + delta).clamp(0.0, 1.0).toDouble();
      Natif.setVolume(volume);
      indicateur(volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, 'Volume', volume);
    }
  }

  void majHorizontal(DragUpdateDetails d) {
    final c = v!;
    dxTotal += d.delta.dx;
    final decalage = Duration(milliseconds: (dxTotal / largeur * 90000).round());
    var cible = debutGlisse + decalage;
    if (cible < Duration.zero) cible = Duration.zero;
    if (cible > c.value.duration) cible = c.value.duration;
    cibleGlisse = cible;
    final signe = dxTotal >= 0 ? '+' : '-';
    indicateur(
      dxTotal >= 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
      '$signe${fmt(Duration(milliseconds: decalage.inMilliseconds.abs()))}   →   ${fmt(cible)}',
    );
  }

  void choisirVitesse() {
    masquage?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (d) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Vitesse de lecture',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final s in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                ChoiceChip(
                  label: Text(s == 1.0 ? 'Normale' : '${s}x'),
                  selected: vitesse == s,
                  selectedColor: rouge,
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => vitesse = s);
                    v?.setPlaybackSpeed(s);
                    Navigator.pop(d);
                  },
                ),
            ]),
          ]),
        ),
      ),
    ).then((_) => planifierMasquage());
  }

  void changerCadrage() {
    final suivant = Cadrage.values[(cadrage.index + 1) % Cadrage.values.length];
    setState(() => cadrage = suivant);
    indicateur(
      Icons.aspect_ratio_rounded,
      switch (suivant) {
        Cadrage.ajuste => 'Taille d\'origine',
        Cadrage.remplir => 'Remplir l\'écran',
        Cadrage.etire => 'Étirer',
      },
    );
    planifierMasquage();
  }

  Future<void> reduire() async {
    final ok = await Natif.pip(v?.value.aspectRatio ?? 16 / 9);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La superposition n\'est pas disponible sur ce téléphone.'),
      ));
    }
  }

  void basculerOrientation() {
    paysage = !paysage;
    SystemChrome.setPreferredOrientations(paysage
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
    setState(() {});
    planifierMasquage();
  }

  void verrouiller(bool oui) {
    setState(() {
      verrou = oui;
      controles = true;
    });
    planifierMasquage();
  }

  String fmt(Duration d) {
    String deux(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = deux(d.inMinutes.remainder(60));
    final s = deux(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ---------- Affichage ----------

  @override
  Widget build(BuildContext context) {
    final c = v;
    if (erreur) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: EtatVide(
          icone: Icons.error_outline_rounded,
          titre: 'Lecture impossible',
          message: 'Cette vidéo ne peut pas être lue. Elle est peut-être endommagée.',
          bouton: 'Retour',
          onBouton: () => Navigator.pop(context),
        ),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: rouge),
            SizedBox(height: 16),
            Text('Préparation de la vidéo…', style: TextStyle(color: gris)),
          ]),
        ),
      );
    }
    if (Natif.pipEnCours.value) {
      return Scaffold(backgroundColor: Colors.black, body: video(c));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, k) {
        largeur = k.maxWidth;
        hauteur = k.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: basculerControles,
          onDoubleTapDown: verrou ? null : (d) => xDoubleTap = d.localPosition.dx,
          onDoubleTap: verrou ? null : doubleTape,
          onVerticalDragStart:
              verrou ? null : (d) => zoneGauche = d.localPosition.dx < largeur / 2,
          onVerticalDragUpdate: verrou ? null : majVertical,
          onHorizontalDragStart: verrou
              ? null
              : (_) {
                  debutGlisse = c.value.position;
                  dxTotal = 0;
                },
          onHorizontalDragUpdate: verrou ? null : majHorizontal,
          onHorizontalDragEnd: verrou
              ? null
              : (_) {
                  if (cibleGlisse != null) c.seekTo(cibleGlisse!);
                  cibleGlisse = null;
                },
          child: Stack(children: [
            video(c),
            AnimatedOpacity(
              opacity: controles ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !controles,
                child: verrou ? coucheVerrou() : surcouche(c),
              ),
            ),
            if (repriseProposee != null && !verrou)
              Positioned(left: 24, bottom: 76, child: SafeArea(child: carteReprise())),
            if (indicTexte != null) IgnorePointer(child: Center(child: carteIndicateur())),
          ]),
        );
      }),
    );
  }

  Widget video(VideoPlayerController c) {
    final t = c.value.size;
    final w = t.width == 0 ? 16.0 : t.width;
    final h = t.height == 0 ? 9.0 : t.height;
    final fit = switch (cadrage) {
      Cadrage.ajuste => BoxFit.contain,
      Cadrage.remplir => BoxFit.cover,
      Cadrage.etire => BoxFit.fill,
    };
    return SizedBox.expand(
      child: ClipRect(
        child: FittedBox(fit: fit, child: SizedBox(width: w, height: h, child: VideoPlayer(c))),
      ),
    );
  }

  Widget bouton(IconData icone, VoidCallback action, {double taille = 24}) => IconButton(
        onPressed: action,
        iconSize: taille,
        icon: Icon(icone, color: Colors.white),
      );

  Widget surcouche(VideoPlayerController c) {
    final dur = c.value.duration;
    final maxi = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
    final valeur = (glisseSlider && valeurSlider != null)
        ? valeurSlider!
        : c.value.position.inMilliseconds.toDouble();
    final pos = Duration(milliseconds: valeur.round());

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3000000), Color(0x26000000), Color(0x26000000), Color(0xCC000000)],
          stops: [0, 0.3, 0.7, 1],
        ),
      ),
      child: SafeArea(
        child: Stack(children: [
          // Barre du haut
          Positioned(
            top: 4,
            left: 4,
            right: 4,
            child: Row(children: [
              bouton(Icons.arrow_back_rounded, () => Navigator.pop(context)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(widget.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: choisirVitesse,
                child: Text(vitesse == 1 ? '1x' : '${vitesse}x',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              bouton(Icons.aspect_ratio_rounded, changerCadrage),
              bouton(Icons.picture_in_picture_alt_rounded, reduire),
              bouton(Icons.lock_open_rounded, () => verrouiller(true)),
            ]),
          ),
          // Commandes centrales
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              bouton(Icons.replay_10_rounded, () => avancer(-10), taille: 38),
              const SizedBox(width: 40),
              GestureDetector(
                onTap: lecturePause,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 46,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 40),
              bouton(Icons.forward_10_rounded, () => avancer(10), taille: 38),
            ]),
          ),
          // Barre du bas
          Positioned(
            left: 16,
            right: 4,
            bottom: 2,
            child: Row(children: [
              Text(fmt(pos), style: const TextStyle(fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: rouge,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: rouge,
                    overlayColor: rouge.withValues(alpha: 0.25),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxi,
                    value: valeur.clamp(0.0, maxi).toDouble(),
                    onChangeStart: (x) {
                      masquage?.cancel();
                      setState(() {
                        glisseSlider = true;
                        valeurSlider = x;
                      });
                    },
                    onChanged: (x) => setState(() => valeurSlider = x),
                    onChangeEnd: (x) {
                      c.seekTo(Duration(milliseconds: x.round()));
                      setState(() => glisseSlider = false);
                      planifierMasquage();
                    },
                  ),
                ),
              ),
              Text(fmt(dur), style: const TextStyle(fontSize: 12)),
              bouton(paysage ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  basculerOrientation),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget coucheVerrou() {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              iconSize: 28,
              icon: const Icon(Icons.lock_rounded, color: Colors.white),
              onPressed: () => verrouiller(false),
            ),
          ),
        ),
      ),
    );
  }

  Widget carteIndicateur() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(indicIcone, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(indicTexte!, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (indicValeur != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: indicValeur,
                minHeight: 5,
                color: rouge,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget carteReprise() {
    return Material(
      color: surface.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.history_rounded, color: rouge, size: 20),
          const SizedBox(width: 8),
          Text('Reprise à ${fmt(repriseProposee!)}'),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () {
              v?.seekTo(Duration.zero);
              setState(() => repriseProposee = null);
            },
            child: const Text('Recommencer',
                style: TextStyle(color: rouge, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}


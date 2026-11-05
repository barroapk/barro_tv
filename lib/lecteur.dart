import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart'
    show CTRStreamCipher, AESEngine, ParametersWithIV, KeyParameter;
import 'package:video_player/video_player.dart';
import 'main.dart';
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

class BarroPlay extends StatefulWidget {
  final Contenu c;
  const BarroPlay({super.key, required this.c});

  @override
  State<BarroPlay> createState() => _BarroPlayState();
}

class _BarroPlayState extends State<BarroPlay> {
  VideoPlayerController? ctrl;
  File? temp;
  bool erreur = false;
  bool controles = true;
  Timer? masquage;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    demarrer();
  }

  Future<void> demarrer() async {
    try {
      temp = await dechiffrer(widget.c);
      ctrl = VideoPlayerController.file(temp!);
      await ctrl!.initialize();
      ctrl!.addListener(() {
        if (mounted) setState(() {});
      });
      ctrl!.play();
      planifierMasquage();
    } catch (e) {
      erreur = true;
    }
    if (mounted) setState(() {});
  }

  void planifierMasquage() {
    masquage?.cancel();
    masquage = Timer(const Duration(seconds: 3), () {
      if (mounted && (ctrl?.value.isPlaying ?? false)) setState(() => controles = false);
    });
  }

  void basculerControles() {
    setState(() => controles = !controles);
    if (controles) planifierMasquage();
  }

  void lecturePause() {
    final v = ctrl!;
    v.value.isPlaying ? v.pause() : v.play();
    planifierMasquage();
  }

  void avancer(int secondes) {
    final v = ctrl!;
    v.seekTo(v.value.position + Duration(seconds: secondes));
    planifierMasquage();
  }

  String duree(Duration d) {
    String deux(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = deux(d.inMinutes.remainder(60));
    final s = deux(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    masquage?.cancel();
    ctrl?.dispose();
    temp?.delete().ignore();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ctrl;
    Widget corps;
    if (erreur) {
      corps = EtatVide(
        icone: Icons.error_outline_rounded,
        titre: 'Lecture impossible',
        message: 'Cette vidéo semble endommagée. Supprime-la puis télécharge-la à nouveau.',
        bouton: 'Retour',
        onBouton: () => Navigator.pop(context),
      );
    } else if (v == null || !v.value.isInitialized) {
      corps = const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: rouge),
          SizedBox(height: 16),
          Text('Préparation de la vidéo…', style: TextStyle(color: gris)),
        ]),
      );
    } else {
      corps = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: basculerControles,
        child: Stack(children: [
          Center(child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v))),
          AnimatedOpacity(
            opacity: controles ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(ignoring: !controles, child: surcouche(v)),
          ),
        ]),
      );
    }
    return Scaffold(backgroundColor: Colors.black, body: corps);
  }

  Widget surcouche(VideoPlayerController v) {
    return Container(
      color: Colors.black45,
      child: Stack(children: [
        Positioned(
          top: 12,
          left: 12,
          right: 24,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.c.titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              iconSize: 40,
              icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
              onPressed: () => avancer(-10),
            ),
            const SizedBox(width: 36),
            IconButton(
              iconSize: 68,
              icon: Icon(
                v.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                color: Colors.white,
              ),
              onPressed: lecturePause,
            ),
            const SizedBox(width: 36),
            IconButton(
              iconSize: 40,
              icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
              onPressed: () => avancer(10),
            ),
          ]),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 16,
          child: Row(children: [
            Text(duree(v.value.position), style: const TextStyle(fontSize: 12)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: VideoProgressIndicator(
                  v,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  colors: const VideoProgressColors(
                    playedColor: rouge,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            ),
            Text(duree(v.value.duration), style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

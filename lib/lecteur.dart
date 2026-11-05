import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart'
    show CTRStreamCipher, AESEngine, ParametersWithIV, KeyParameter;
import 'package:video_player/video_player.dart';
import 'main.dart';
import 'telechargement.dart';

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
  String? erreur;

  @override
  void initState() {
    super.initState();
    demarrer();
  }

  Future<void> demarrer() async {
    try {
      temp = await dechiffrer(widget.c);
      ctrl = VideoPlayerController.file(temp!);
      await ctrl!.initialize();
      ctrl!.play();
      ctrl!.addListener(() => setState(() {}));
    } catch (e) {
      erreur = 'Lecture impossible : $e';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ctrl?.dispose();
    temp?.delete().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ctrl;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.c.titre)),
      body: Center(
        child: erreur != null
            ? Text(erreur!, style: const TextStyle(color: rouge))
            : (v == null || !v.value.isInitialized)
                ? const CircularProgressIndicator()
                : GestureDetector(
                    onTap: () => v.value.isPlaying ? v.pause() : v.play(),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AspectRatio(
                          aspectRatio: v.value.aspectRatio,
                          child: VideoPlayer(v)),
                      VideoProgressIndicator(v,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(playedColor: rouge)),
                      const SizedBox(height: 12),
                      Icon(v.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 40),
                    ]),
                  ),
      ),
    );
  }
}

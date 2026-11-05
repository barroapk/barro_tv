import 'package:flutter/material.dart';
import 'main.dart';
import 'telechargement.dart';
import 'widgets.dart';

class MoiPage extends StatefulWidget {
  final List<Contenu> tous;
  const MoiPage({super.key, required this.tous});

  @override
  State<MoiPage> createState() => _MoiPageState();
}

class _MoiPageState extends State<MoiPage> {
  int? octets;
  int nombre = 0;

  @override
  void initState() {
    super.initState();
    calculer();
  }

  Future<void> calculer() async {
    var total = 0;
    var n = 0;
    for (final c in widget.tous) {
      final f = await fichierDe(c);
      if (await f.exists()) {
        total += await f.length();
        n++;
      }
    }
    if (mounted) {
      setState(() {
        octets = total;
        nombre = n;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 32, 20, 24), children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surface,
              boxShadow: [BoxShadow(color: rouge.withValues(alpha: 0.25), blurRadius: 40)],
            ),
            child: Image.asset('assets/logo.png', height: 64),
          ),
        ),
        const SizedBox(height: 18),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('BARRO',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
          Text(' TV', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: rouge)),
        ]),
        const SizedBox(height: 6),
        const Text('Tes films et séries, partout, même sans Internet.',
            textAlign: TextAlign.center, style: TextStyle(color: gris)),
        const SizedBox(height: 32),
        section('MES VIDÉOS', [
          tuile(Icons.download_done_rounded, 'Vidéos téléchargées', '$nombre'),
          tuile(Icons.sd_storage_outlined, 'Espace utilisé', octets == null ? '…' : taille(octets!)),
          tuile(Icons.lock_outline_rounded, 'Protection', 'Chiffrées'),
        ]),
        const SizedBox(height: 20),
        section('APPLICATION', [
          tuile(Icons.movie_outlined, 'Titres au catalogue', '${widget.tous.length}'),
          tuile(Icons.info_outline_rounded, 'Version', '1.0.0'),
          tuile(Icons.business_outlined, 'Éditeur', 'KOUNADIA SERVICE'),
        ]),
      ]),
    );
  }

  Widget section(String titre, List<Widget> enfants) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 8),
        child: Text(titre,
            style: const TextStyle(
                color: gris, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ),
      Container(
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          for (var i = 0; i < enfants.length; i++) ...[
            enfants[i],
            if (i < enfants.length - 1)
              Divider(height: 1, indent: 56, color: Colors.white.withValues(alpha: 0.06)),
          ],
        ]),
      ),
    ]);
  }

  Widget tuile(IconData icone, String titre, String valeur) {
    return ListTile(
      leading: Icon(icone, color: rouge),
      title: Text(titre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: Text(valeur, style: const TextStyle(color: gris, fontSize: 13)),
    );
  }
}

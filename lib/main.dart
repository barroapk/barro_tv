import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'telechargement.dart';

const lienCatalogue =
    'https://raw.githubusercontent.com/barroapk/kd-res-07/main/d.json';
const rouge = Color(0xFFE50914);

void main() => runApp(const BarroTV());

class BarroTV extends StatelessWidget {
  const BarroTV({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BARRO TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: rouge),
      ),
      home: const Accueil(),
    );
  }
}

class Contenu {
  final String id, titre, realisateur, affiche, video;
  Contenu.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        titre = j['titre'] ?? '',
        realisateur = j['realisateur'] ?? '',
        affiche = j['affiche'] ?? '',
        video = j['video'] ?? '';
}

class Accueil extends StatefulWidget {
  const Accueil({super.key});
  @override
  State<Accueil> createState() => _AccueilState();
}

class _AccueilState extends State<Accueil> {
  List<Contenu> tous = [];
  String recherche = '';
  bool chargement = true;
  String? erreur;

  @override
  void initState() {
    super.initState();
    charger();
  }

  Future<void> charger() async {
    setState(() { chargement = true; erreur = null; });
    try {
      final r = await http.get(Uri.parse(lienCatalogue));
      final data = jsonDecode(r.body);
      tous = (data['contenus'] as List)
          .map((e) => Contenu.fromJson(e))
          .toList();
    } catch (e) {
      erreur = 'Impossible de charger le catalogue';
    }
    setState(() => chargement = false);
  }

  @override
  Widget build(BuildContext context) {
    final liste = tous
        .where((c) => c.titre.toLowerCase().contains(recherche.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('BARRO TV',
            style: TextStyle(color: rouge, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            onChanged: (v) => setState(() => recherche = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un film, une série...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFF1C1C1C),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: corps(liste)),
        ]),
      ),
    );
  }

  Widget corps(List<Contenu> liste) {
    if (chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (erreur != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(erreur!),
          TextButton(onPressed: charger, child: const Text('Réessayer')),
        ]),
      );
    }
    if (liste.isEmpty) {
      return const Center(child: Text('Aucun contenu pour le moment'));
    }
    return RefreshIndicator(
      onRefresh: charger,
      child: GridView.builder(
        itemCount: liste.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.55,
            crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemBuilder: (_, i) => GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Details(c: liste[i]))), child: carte(liste[i])),
      ),
    );
  }

  Widget carte(Contenu c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: c.affiche.isEmpty
              ? Container(
                  color: const Color(0xFF1C1C1C),
                  child: const Center(child: Icon(Icons.movie, color: rouge)))
              : Image.network(c.affiche,
                  fit: BoxFit.cover, width: double.infinity),
        ),
      ),
      const SizedBox(height: 6),
      Text(c.titre, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
    ]);
  }
}

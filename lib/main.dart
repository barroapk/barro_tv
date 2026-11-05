import 'dart:convert';
import 'package:flutter/material.dart';
import 'hors_ligne.dart';
import 'telechargement.dart';

const lienCatalogue =
    'https://raw.githubusercontent.com/barroapk/kd-res-07/main/d.json';
const rouge = Color(0xFFE50914);
const fond = Color(0xFF0B0B0F);
const surface = Color(0xFF17171F);

void main() => runApp(const BarroTV());

class Contenu {
  final String id, titre, realisateur, affiche, video;
  Contenu.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        titre = j['titre'] ?? '',
        realisateur = j['realisateur'] ?? '',
        affiche = j['affiche'] ?? '',
        video = j['video'] ?? '';
}

Future<void> ouvrir(BuildContext context, Contenu c) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => Details(c: c)));

// ---------- LOGO ----------
class LogoBarroTV extends StatelessWidget {
  final double taille;
  const LogoBarroTV({super.key, this.taille = 22});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: EdgeInsets.all(taille * 0.15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF4D4D), rouge, Color(0xFF8B0000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(taille * 0.35),
          boxShadow: [
            BoxShadow(color: rouge.withValues(alpha: 0.5), blurRadius: taille * 0.6)
          ],
        ),
        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: taille),
      ),
      SizedBox(width: taille * 0.4),
      Text('BARRO',
          style: TextStyle(
              fontSize: taille,
              fontWeight: FontWeight.w900,
              letterSpacing: taille * 0.12,
              color: Colors.white)),
      Text('TV',
          style: TextStyle(
              fontSize: taille, fontWeight: FontWeight.w900, color: rouge)),
    ]);
  }
}

// ---------- APP ----------
class BarroTV extends StatelessWidget {
  const BarroTV({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BARRO TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fond,
        colorScheme: const ColorScheme.dark(primary: rouge, surface: surface),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: rouge.withValues(alpha: 0.25),
        ),
      ),
      home: const Racine(),
    );
  }
}

class Racine extends StatefulWidget {
  const Racine({super.key});
  @override
  State<Racine> createState() => _RacineState();
}

class _RacineState extends State<Racine> {
  int index = 0;
  List<Contenu> tous = [];
  bool chargement = true;
  String? erreur;

  @override
  void initState() {
    super.initState();
    charger();
  }

  Future<void> charger() async {
    setState(() {
      chargement = true;
      erreur = null;
    });
    try {
      final data = jsonDecode(await lireCatalogue());
      tous = (data['contenus'] as List).map((e) => Contenu.fromJson(e)).toList();
    } catch (e) {
      erreur = 'Impossible de charger le catalogue';
    }
    if (mounted) setState(() => chargement = false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AccueilPage(tous: tous, chargement: chargement, erreur: erreur, onRefresh: charger),
      RecherchePage(tous: tous),
      TelechargementsPage(tous: tous),
      const ProfilPage(),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Recherche'),
          NavigationDestination(
              icon: Icon(Icons.download_outlined),
              selectedIcon: Icon(Icons.download_done),
              label: 'Téléchargements'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// ---------- ÉLÉMENTS ----------
class Affiche extends StatelessWidget {
  final Contenu c;
  final double? largeur, hauteur;
  final double rayon;
  const Affiche({super.key, required this.c, this.largeur, this.hauteur, this.rayon = 12});
  @override
  Widget build(BuildContext context) {
    final vide = Container(
      width: largeur,
      height: hauteur,
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF3A0A10), surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)),
      child: const Center(child: Icon(Icons.movie_creation_outlined, color: rouge, size: 36)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayon),
      child: c.affiche.isEmpty
          ? vide
          : Image.network(c.affiche,
              width: largeur, height: hauteur, fit: BoxFit.cover,
              errorBuilder: (a, b, d) => vide),
    );
  }
}

class CarteFilm extends StatelessWidget {
  final Contenu c;
  final double largeur;
  const CarteFilm({super.key, required this.c, this.largeur = 120});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ouvrir(context, c),
      child: SizedBox(
        width: largeur,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Affiche(c: c, largeur: largeur, hauteur: largeur * 1.5),
          const SizedBox(height: 6),
          Text(c.titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class Rangee extends StatelessWidget {
  final String titre;
  final List<Contenu> liste;
  const Rangee({super.key, required this.titre, required this.liste});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Text(titre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: liste.length,
          separatorBuilder: (a, b) => const SizedBox(width: 12),
          itemBuilder: (a, i) => CarteFilm(c: liste[i]),
        ),
      ),
    ]);
  }
}

// ---------- ACCUEIL ----------
class AccueilPage extends StatelessWidget {
  final List<Contenu> tous;
  final bool chargement;
  final String? erreur;
  final Future<void> Function() onRefresh;
  const AccueilPage(
      {super.key, required this.tous, required this.chargement, this.erreur, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (chargement) return const Center(child: CircularProgressIndicator());
    if (erreur != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(erreur!),
          TextButton(onPressed: onRefresh, child: const Text('Réessayer')),
        ]),
      );
    }
    if (tous.isEmpty) return const Center(child: Text('Aucun contenu pour le moment'));
    final vedette = tous.first;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(padding: EdgeInsets.zero, children: [
        Stack(children: [
          Affiche(c: vedette, largeur: double.infinity, hauteur: 460, rayon: 0),
          Container(
            height: 460,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent, fond],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 16,
            child: SafeArea(
                child: Padding(padding: EdgeInsets.only(top: 8), child: LogoBarroTV())),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: rouge, borderRadius: BorderRadius.circular(6)),
                child: const Text('À LA UNE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Text(vedette.titre,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              Text(vedette.realisateur, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => ouvrir(context, vedette),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Regarder', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        ]),
        Rangee(titre: 'Nouveautés', liste: tous.reversed.toList()),
        Rangee(titre: 'Tout le catalogue', liste: tous),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ---------- RECHERCHE ----------
class RecherchePage extends StatefulWidget {
  final List<Contenu> tous;
  const RecherchePage({super.key, required this.tous});
  @override
  State<RecherchePage> createState() => _RechercheState();
}

class _RechercheState extends State<RecherchePage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final m = q.toLowerCase();
    final liste = widget.tous
        .where((c) =>
            c.titre.toLowerCase().contains(m) || c.realisateur.toLowerCase().contains(m))
        .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Rechercher', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: 'Film, série, réalisateur...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: liste.isEmpty
                ? const Center(child: Text('Aucun résultat', style: TextStyle(color: Colors.grey)))
                : GridView.builder(
                    itemCount: liste.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12),
                    itemBuilder: (a, i) => LayoutBuilder(
                        builder: (b, k) => CarteFilm(c: liste[i], largeur: k.maxWidth)),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ---------- TÉLÉCHARGEMENTS ----------
class TelechargementsPage extends StatefulWidget {
  final List<Contenu> tous;
  const TelechargementsPage({super.key, required this.tous});
  @override
  State<TelechargementsPage> createState() => _TelechargementsState();
}

class _TelechargementsState extends State<TelechargementsPage> {
  late Future<List<Contenu>> futur;

  @override
  void initState() {
    super.initState();
    futur = trouver();
  }

  Future<List<Contenu>> trouver() async {
    final res = <Contenu>[];
    for (final c in widget.tous) {
      if (await (await fichierDe(c)).exists()) res.add(c);
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Téléchargements',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const Text('Disponibles même sans connexion', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Contenu>>(
              future: futur,
              builder: (context, s) {
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final l = s.data!;
                if (l.isEmpty) {
                  return const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.download_for_offline_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Aucune vidéo téléchargée', style: TextStyle(color: Colors.grey)),
                    ]),
                  );
                }
                return ListView.separated(
                  itemCount: l.length,
                  separatorBuilder: (a, b) => const SizedBox(height: 12),
                  itemBuilder: (a, i) {
                    final c = l[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await ouvrir(context, c);
                        setState(() => futur = trouver());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: surface, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          Affiche(c: c, largeur: 70, hauteur: 100),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.titre,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(c.realisateur, style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 8),
                              const Row(children: [
                                Icon(Icons.offline_pin, color: Colors.green, size: 16),
                                SizedBox(width: 4),
                                Text('Hors connexion',
                                    style: TextStyle(color: Colors.green, fontSize: 12)),
                              ]),
                            ]),
                          ),
                          const Icon(Icons.play_circle_fill, color: rouge, size: 40),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------- PROFIL ----------
class ProfilPage extends StatelessWidget {
  const ProfilPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LogoBarroTV(taille: 34),
          SizedBox(height: 16),
          Text('Films et séries, même hors connexion', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 32),
          Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
          Text('Une création KOUNADIA SERVICE',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ),
    );
  }
}

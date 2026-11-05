import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'accueil.dart';
import 'hors_ligne.dart';
import 'mes_telechargements.dart';
import 'moi.dart';

const lienCatalogue =
    'https://raw.githubusercontent.com/barroapk/kd-res-07/main/d.json';

// Couleurs de BARRO TV
const rouge = Color(0xFFE50914);
const fond = Color(0xFF0B0B0F);
const surface = Color(0xFF16161D);
const surface2 = Color(0xFF22222C);
const gris = Color(0xFF9A9AA8);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const BarroTV());
}

class Contenu {
  final String id, titre, type, genre, annee, duree, resume, realisateur, affiche, video;

  Contenu.fromJson(Map<String, dynamic> j)
      : id = '${j['id'] ?? ''}',
        titre = '${j['titre'] ?? ''}',
        type = '${j['type'] ?? 'film'}',
        genre = '${j['genre'] ?? ''}',
        annee = '${j['annee'] ?? ''}',
        duree = '${j['duree'] ?? ''}',
        resume = '${j['resume'] ?? ''}',
        realisateur = '${j['realisateur'] ?? ''}',
        affiche = '${j['affiche'] ?? ''}',
        video = '${j['video'] ?? ''}';

  String get infos => [annee, genre, duree].where((s) => s.isNotEmpty).join('  •  ');
}

class BarroTV extends StatelessWidget {
  const BarroTV({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BARRO TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fond,
        colorScheme: const ColorScheme.dark(
          primary: rouge,
          surface: surface,
          onSurface: Colors.white,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: surface2,
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
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
  int onglet = 0;
  int cle = 0;
  List<Contenu> tous = [];
  bool chargement = true;
  bool horsLigne = false;
  String? erreur;

  @override
  void initState() {
    super.initState();
    charger();
  }

  Future<void> charger() async {
    setState(() {
      erreur = null;
      if (tous.isEmpty) chargement = true;
    });
    try {
      final (texte, cache) = await lireCatalogue();
      final data = jsonDecode(texte);
      tous = (data['contenus'] as List)
          .map((e) => Contenu.fromJson(e as Map<String, dynamic>))
          .toList();
      horsLigne = cache;
    } catch (e) {
      erreur = 'connexion';
    }
    if (mounted) setState(() => chargement = false);
  }

  void choisir(int i) {
    setState(() {
      onglet = i;
      cle++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: onglet,
        children: [
          AccueilPage(
            tous: tous,
            chargement: chargement,
            horsLigne: horsLigne,
            erreur: erreur,
            onRefresh: charger,
          ),
          MesTelechargements(
            key: ValueKey('t$cle'),
            tous: tous,
            onExplorer: () => choisir(0),
          ),
          MoiPage(key: ValueKey('m$cle'), tous: tous),
        ],
      ),
      bottomNavigationBar: BarreNav(index: onglet, onTap: choisir),
    );
  }
}

class BarreNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const BarreNav({super.key, required this.index, required this.onTap});

  static const elements = [
    (Icons.home_rounded, Icons.home_outlined, 'Accueil'),
    (Icons.download_done_rounded, Icons.download_outlined, 'Téléchargements'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Moi'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < elements.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                            color: i == index
                                ? rouge.withValues(alpha: 0.16)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            i == index ? elements[i].$1 : elements[i].$2,
                            color: i == index ? rouge : gris,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          elements[i].$3,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                            color: i == index ? Colors.white : gris,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

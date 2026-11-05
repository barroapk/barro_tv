import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart';
import 'widgets.dart';

class AccueilPage extends StatefulWidget {
  final List<Contenu> tous;
  final bool chargement, horsLigne;
  final String? erreur;
  final Future<void> Function() onRefresh;
  const AccueilPage({
    super.key,
    required this.tous,
    required this.chargement,
    required this.horsLigne,
    this.erreur,
    required this.onRefresh,
  });

  @override
  State<AccueilPage> createState() => _AccueilState();
}

class _AccueilState extends State<AccueilPage> {
  final defil = ScrollController();
  double opacite = 0;
  int categorie = 0;
  static const categories = ['Tendance', 'Films', 'Séries'];

  @override
  void initState() {
    super.initState();
    defil.addListener(() {
      final o = (defil.offset / 260).clamp(0.0, 1.0).toDouble();
      if ((o - opacite).abs() > 0.02 || o == 0 || o == 1) setState(() => opacite = o);
    });
  }

  @override
  void dispose() {
    defil.dispose();
    super.dispose();
  }

  List<Contenu> get filtres => switch (categorie) {
        1 => widget.tous.where((c) => c.type != 'serie').toList(),
        2 => widget.tous.where((c) => c.type == 'serie').toList(),
        _ => widget.tous,
      };

  void ouvrirRecherche() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (a, b, c) => RechercheEcran(tous: widget.tous),
        transitionsBuilder: (a, anim, b, enfant) =>
            FadeTransition(opacity: anim, child: enfant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liste = filtres;
    Widget corps;
    if (widget.chargement) {
      corps = const SqueletteAccueil();
    } else if (widget.erreur != null) {
      corps = EtatVide(
        icone: Icons.wifi_off_rounded,
        titre: 'Connexion impossible',
        message: 'Vérifie ta connexion Internet, puis réessaie.',
        bouton: 'Réessayer',
        onBouton: widget.onRefresh,
      );
    } else if (liste.isEmpty) {
      corps = const EtatVide(
        icone: Icons.movie_filter_outlined,
        titre: 'Bientôt disponible',
        message: 'De nouveaux films et séries arrivent très vite sur BARRO TV.',
      );
    } else {
      corps = contenu(liste);
    }
    return Stack(children: [
      Positioned.fill(child: corps),
      Positioned(top: 0, left: 0, right: 0, child: entete()),
    ]);
  }

  Widget contenu(List<Contenu> liste) {
    final genres = <String>{for (final c in liste) if (c.genre.isNotEmpty) c.genre}.toList();
    return RefreshIndicator(
      color: rouge,
      backgroundColor: surface,
      edgeOffset: 110,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        controller: defil,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
              child: Carrousel(
                  key: ValueKey('c$categorie-${liste.length}'),
                  liste: liste.take(6).toList())),
          if (widget.horsLigne)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: surface2, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.cloud_off_rounded, size: 14, color: gris),
                      SizedBox(width: 6),
                      Text('Mode hors connexion', style: TextStyle(fontSize: 12, color: gris)),
                    ]),
                  ),
                ]),
              ),
            ),
          SliverToBoxAdapter(
              child: Rangee(titre: 'Nouveautés', liste: liste.reversed.take(12).toList())),
          for (final g in genres)
            SliverToBoxAdapter(
                child: Rangee(titre: g, liste: liste.where((c) => c.genre == g).toList())),
          SliverToBoxAdapter(child: Rangee(titre: 'Tout le catalogue', liste: liste)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  /// En-tête fixe : transparent sur l'affiche, puis opaque quand on défile.
  Widget entete() {
    final o = opacite;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xB3000000), fond, o)!,
            Color.lerp(const Color(0x00000000), fond, o)!,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Image.asset('assets/logo.png', height: 34),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: ouvrirRecherche,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Color.lerp(const Color(0x33FFFFFF), surface2, o),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(children: [
                      Icon(Icons.search_rounded, color: Colors.white70, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Rechercher un film, une série…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (_, i) {
                final sel = i == categorie;
                return GestureDetector(
                  onTap: () {
                    setState(() => categorie = i);
                    if (defil.hasClients) defil.jumpTo(0);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: sel ? 18 : 15,
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                          color: sel ? Colors.white : Colors.white60,
                        ),
                        child: Text(categories[i]),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 3,
                        width: sel ? 22 : 0,
                        decoration: BoxDecoration(
                            color: rouge, borderRadius: BorderRadius.circular(2)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Grandes affiches qui défilent toutes seules.
class Carrousel extends StatefulWidget {
  final List<Contenu> liste;
  const Carrousel({super.key, required this.liste});

  @override
  State<Carrousel> createState() => _CarrouselState();
}

class _CarrouselState extends State<Carrousel> {
  final page = PageController();
  int index = 0;
  Timer? minuteur;

  @override
  void initState() {
    super.initState();
    minuteur = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!page.hasClients || widget.liste.length < 2) return;
      page.animateToPage(
        (index + 1) % widget.liste.length,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    minuteur?.cancel();
    page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.62;
    return SizedBox(
      height: h,
      child: Stack(children: [
        PageView.builder(
          controller: page,
          itemCount: widget.liste.length,
          onPageChanged: (i) => setState(() => index = i),
          itemBuilder: (_, i) => diapo(widget.liste[i], h),
        ),
        if (widget.liste.length > 1)
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.liste.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == index ? rouge : Colors.white30,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ]),
    );
  }

  Widget diapo(Contenu c, double h) {
    return Stack(fit: StackFit.expand, children: [
      Affiche(c: c, largeur: double.infinity, hauteur: h, rayon: 0),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0x000B0B0F), Color(0xCC0B0B0F), fond],
            stops: [0, 0.45, 0.8, 1],
          ),
        ),
      ),
      Positioned(
        left: 20,
        right: 20,
        bottom: 28,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Etiquette(c.type == 'serie' ? 'SÉRIE' : 'FILM'),
          const SizedBox(height: 10),
          Text(
            c.titre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.1,
              shadows: [Shadow(blurRadius: 12, color: Colors.black54)],
            ),
          ),
          if (c.infos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(c.infos, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          const SizedBox(height: 16),
          Row(children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: const StadiumBorder(),
              ),
              onPressed: () => ouvrir(context, c),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Regarder', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: const StadiumBorder(),
              ),
              onPressed: () => ouvrir(context, c),
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              label: const Text('Infos'),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

class Rangee extends StatelessWidget {
  final String titre;
  final List<Contenu> liste;
  const Rangee({super.key, required this.titre, required this.liste});

  @override
  Widget build(BuildContext context) {
    if (liste.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 26, 4, 10),
        child: Row(children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(color: rouge, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(titre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ListeComplete(titre: titre, liste: liste)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Voir tout', style: TextStyle(color: gris, fontSize: 13)),
              Icon(Icons.chevron_right_rounded, color: gris, size: 18),
            ]),
          ),
        ]),
      ),
      SizedBox(
        height: 225,
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

class ListeComplete extends StatelessWidget {
  final String titre;
  final List<Contenu> liste;
  const ListeComplete({super.key, required this.titre, required this.liste});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: fond,
        surfaceTintColor: Colors.transparent,
        title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: GrilleFilms(liste: liste),
    );
  }
}

/// Écran de recherche plein écran (s'ouvre depuis la barre en haut).
class RechercheEcran extends StatefulWidget {
  final List<Contenu> tous;
  const RechercheEcran({super.key, required this.tous});

  @override
  State<RechercheEcran> createState() => _RechercheState();
}

class _RechercheState extends State<RechercheEcran> {
  final champ = TextEditingController();
  String q = '';

  @override
  void dispose() {
    champ.dispose();
    super.dispose();
  }

  void remplir(String texte) {
    champ.text = texte;
    setState(() => q = texte);
  }

  @override
  Widget build(BuildContext context) {
    final m = q.trim().toLowerCase();
    final res = m.isEmpty
        ? <Contenu>[]
        : widget.tous
            .where((c) =>
                c.titre.toLowerCase().contains(m) ||
                c.realisateur.toLowerCase().contains(m) ||
                c.genre.toLowerCase().contains(m))
            .toList();

    Widget corps;
    if (m.isEmpty) {
      corps = suggestions();
    } else if (res.isEmpty) {
      corps = const EtatVide(
        icone: Icons.search_off_rounded,
        titre: 'Aucun résultat',
        message: 'Essaie un autre titre, un genre ou un nom de réalisateur.',
      );
    } else {
      corps = GrilleFilms(liste: res);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: fond,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(24)),
          child: TextField(
            controller: champ,
            autofocus: true,
            textInputAction: TextInputAction.search,
            cursorColor: rouge,
            style: const TextStyle(fontSize: 15),
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: 'Film, série, réalisateur…',
              hintStyle: const TextStyle(color: gris),
              prefixIcon: const Icon(Icons.search_rounded, color: gris),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, color: gris),
                      onPressed: () => remplir(''),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      body: corps,
    );
  }

  Widget suggestions() {
    if (widget.tous.isEmpty) {
      return const EtatVide(
        icone: Icons.movie_filter_outlined,
        titre: 'Catalogue en préparation',
        message: 'Les films et séries seront bientôt disponibles.',
      );
    }
    final genres = <String>{for (final c in widget.tous) if (c.genre.isNotEmpty) c.genre}.toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (genres.isNotEmpty) ...[
        const Text('Genres', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in genres)
            ActionChip(
              label: Text(g),
              backgroundColor: surface2,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              onPressed: () => remplir(g),
            ),
        ]),
        const SizedBox(height: 28),
      ],
      const Text('Populaires sur BARRO TV',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      for (final c in widget.tous.take(8))
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => ouvrir(context, c),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Affiche(c: c, largeur: 52, hauteur: 74, rayon: 6),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (c.infos.isNotEmpty)
                    Text(c.infos, style: const TextStyle(color: gris, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.play_circle_outline_rounded, color: gris),
            ]),
          ),
        ),
    ]);
  }
}

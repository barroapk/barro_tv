import 'package:flutter/material.dart';
import 'main.dart';
import 'telechargement.dart';

Future<void> ouvrir(BuildContext context, Contenu c) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => Details(c: c)));

String taille(int o) {
  if (o >= 1 << 30) return '${(o / (1 << 30)).toStringAsFixed(1)} Go';
  if (o >= 1 << 20) return '${(o / (1 << 20)).toStringAsFixed(0)} Mo';
  return '${(o / 1024).toStringAsFixed(0)} Ko';
}

/// Affiche d'un film, avec apparition en fondu et image de secours.
class Affiche extends StatelessWidget {
  final Contenu c;
  final double? largeur, hauteur;
  final double rayon;
  const Affiche({super.key, required this.c, this.largeur, this.hauteur, this.rayon = 10});

  @override
  Widget build(BuildContext context) {
    final vide = Container(
      width: largeur,
      height: hauteur,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2B0B10), surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Opacity(opacity: 0.3, child: Image.asset('assets/logo.png', width: 36)),
      ),
    );
    Widget image = vide;
    if (c.affiche.isNotEmpty) {
      image = Image.network(
        c.affiche,
        width: largeur,
        height: hauteur,
        fit: BoxFit.cover,
        frameBuilder: (ctx, child, frame, sync) => sync
            ? child
            : Stack(fit: StackFit.passthrough, children: [
                vide,
                AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 350),
                  child: child,
                ),
              ]),
        errorBuilder: (a, b, d) => vide,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(rayon), child: image);
  }
}

class Etiquette extends StatelessWidget {
  final String texte;
  const Etiquette(this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: rouge, borderRadius: BorderRadius.circular(4)),
      child: Text(
        texte,
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.white),
      ),
    );
  }
}

class CarteFilm extends StatelessWidget {
  final Contenu c;
  final double largeur;
  const CarteFilm({super.key, required this.c, this.largeur = 118});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ouvrir(context, c),
      child: SizedBox(
        width: largeur,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              Affiche(c: c, largeur: largeur, hauteur: largeur * 1.48),
              if (c.type == 'serie')
                const Positioned(top: 6, left: 6, child: Etiquette('SÉRIE')),
            ]),
            const SizedBox(height: 8),
            Text(c.titre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (c.annee.isNotEmpty)
              Text(c.annee, style: const TextStyle(fontSize: 11, color: gris)),
          ],
        ),
      ),
    );
  }
}

class GrilleFilms extends StatelessWidget {
  final List<Contenu> liste;
  final EdgeInsets padding;
  const GrilleFilms({super.key, required this.liste, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      itemCount: liste.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (a, i) =>
          LayoutBuilder(builder: (b, k) => CarteFilm(c: liste[i], largeur: k.maxWidth)),
    );
  }
}

/// Écran soigné pour les cas « vide », « erreur », « aucun résultat ».
class EtatVide extends StatelessWidget {
  final IconData icone;
  final String titre, message;
  final String? bouton;
  final VoidCallback? onBouton;
  const EtatVide({
    super.key,
    required this.icone,
    required this.titre,
    required this.message,
    this.bouton,
    this.onBouton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rouge.withValues(alpha: 0.12),
                boxShadow: [BoxShadow(color: rouge.withValues(alpha: 0.18), blurRadius: 40)],
              ),
              child: Icon(icone, size: 44, color: rouge),
            ),
            const SizedBox(height: 24),
            Text(titre,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: gris, fontSize: 14, height: 1.5)),
            if (bouton != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: rouge,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: const StadiumBorder(),
                ),
                onPressed: onBouton,
                child: Text(bouton!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Effet de « respiration » pour les blocs de chargement.
class Pulsation extends StatefulWidget {
  final Widget child;
  const Pulsation({super.key, required this.child});

  @override
  State<Pulsation> createState() => _PulsationState();
}

class _PulsationState extends State<Pulsation> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.85).animate(a),
      child: widget.child,
    );
  }
}

Widget boite(double l, double h, [double r = 10]) => Container(
      width: l,
      height: h,
      decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(r)),
    );

class SqueletteAccueil extends StatelessWidget {
  const SqueletteAccueil({super.key});

  @override
  Widget build(BuildContext context) {
    Widget rangee() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 26, 16, 12), child: boite(150, 18, 6)),
          SizedBox(
            height: 175,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (var i = 0; i < 4; i++)
                  Padding(padding: const EdgeInsets.only(right: 12), child: boite(118, 175)),
              ],
            ),
          ),
        ]);
    return Pulsation(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          boite(double.infinity, MediaQuery.of(context).size.height * 0.62, 0),
          rangee(),
          rangee(),
        ],
      ),
    );
  }
}

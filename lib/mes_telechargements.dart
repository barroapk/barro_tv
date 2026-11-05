import 'package:flutter/material.dart';
import 'main.dart';
import 'telechargement.dart';
import 'widgets.dart';

class MesTelechargements extends StatefulWidget {
  final List<Contenu> tous;
  final VoidCallback onExplorer;
  const MesTelechargements({super.key, required this.tous, required this.onExplorer});

  @override
  State<MesTelechargements> createState() => _MesTelechargementsState();
}

class _MesTelechargementsState extends State<MesTelechargements> {
  List<(Contenu, int)>? liste;

  @override
  void initState() {
    super.initState();
    charger();
  }

  @override
  void didUpdateWidget(covariant MesTelechargements ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.tous != widget.tous) charger();
  }

  Future<void> charger() async {
    final res = <(Contenu, int)>[];
    for (final c in widget.tous.expand((x) => x.elements)) {
      final f = await fichierDe(c);
      if (await f.exists()) res.add((c, await f.length()));
    }
    if (mounted) setState(() => liste = res);
  }

  @override
  Widget build(BuildContext context) {
    final l = liste;
    if (l == null) {
      return const Center(child: CircularProgressIndicator(color: rouge));
    }
    final total = l.fold<int>(0, (a, e) => a + e.$2);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Téléchargements',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                l.isEmpty
                    ? 'Tes vidéos, même sans Internet'
                    : '${l.length} vidéo${l.length > 1 ? 's' : ''}  •  ${taille(total)}',
                style: const TextStyle(color: gris),
              ),
            ]),
          ),
        ),
        if (l.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EtatVide(
              icone: Icons.download_for_offline_outlined,
              titre: 'Aucun téléchargement',
              message: 'Télécharge un film pour le regarder partout, même sans Internet.',
              bouton: 'Découvrir le catalogue',
              onBouton: widget.onExplorer,
            ),
          )
        else ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Glisse vers la gauche pour supprimer',
                  style: TextStyle(color: Color(0xFF5E5E6B), fontSize: 12)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList.separated(
              itemCount: l.length,
              separatorBuilder: (a, b) => const SizedBox(height: 12),
              itemBuilder: (context, i) => element(l[i].$1, l[i].$2),
            ),
          ),
        ],
      ]),
    );
  }

  Widget element(Contenu c, int octets) {
    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmerSuppression(context, c),
      onDismissed: (_) => setState(() => liste!.removeWhere((e) => e.$1.id == c.id)),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
            color: rouge.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await ouvrir(context, c);
            charger();
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Affiche(c: c, largeur: 72, hauteur: 104, rayon: 10),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.titre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (c.infos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(c.infos,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: gris, fontSize: 12)),
                    ),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.offline_pin_rounded, color: Color(0xFF2ECC71), size: 16),
                    const SizedBox(width: 4),
                    Text(taille(octets), style: const TextStyle(color: gris, fontSize: 12)),
                  ]),
                ]),
              ),
              GestureDetector(
                onTap: () => lire(context, c),
                child: Container(
                  margin: const EdgeInsets.only(left: 8, right: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: rouge,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: rouge.withValues(alpha: 0.4), blurRadius: 14)],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

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
        colorScheme: const ColorScheme.dark(primary: Color(0xFFE50914)),
      ),
      home: const Accueil(),
    );
  }
}

class Accueil extends StatelessWidget {
  const Accueil({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('BARRO TV',
            style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
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
          const Expanded(
            child: Center(child: Text('Aucun contenu pour le moment')),
          ),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class MangaDetailScreen extends StatelessWidget {
  const MangaDetailScreen({super.key, required this.mangaId});

  final String mangaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Manga Detail: $mangaId')),
    );
  }
}

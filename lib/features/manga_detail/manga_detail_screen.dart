import 'package:flutter/material.dart';

class MangaDetailScreen extends StatelessWidget {
  const MangaDetailScreen({required this.mangaId, super.key});

  final String mangaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Manga Detail: $mangaId')),
    );
  }
}

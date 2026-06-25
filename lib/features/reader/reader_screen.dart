import 'package:flutter/material.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    required this.mangaId,
    required this.chapterId,
    super.key,
  });

  final String mangaId;
  final String chapterId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1C),
      body: Center(
        child: Text(
          'Reader — $mangaId · Ch. $chapterId',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

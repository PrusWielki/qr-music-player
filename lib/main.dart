import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qr_music_player/screens/home_page.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const QRMusicPlayerApp());
}

class QRMusicPlayerApp extends StatelessWidget {
  const QRMusicPlayerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Music Player',
      theme: ThemeData.dark(),
      home: const QRMusicPlayerHome(),
    );
  }
}

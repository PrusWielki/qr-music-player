import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

class QRMusicPlayerHome extends StatefulWidget {
  const QRMusicPlayerHome({super.key});
  @override
  State<QRMusicPlayerHome> createState() => QRMusicPlayerHomeState();
}

class QRMusicPlayerHomeState extends State<QRMusicPlayerHome> {
  bool _connected = false;
  bool _playing = false;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Future<void> _connectToSpotify() async {
    try {
      await SpotifySdk.connectToSpotifyRemote(
        clientId: dotenv.env['SPOTIFY_CLIENT_ID'].toString(),
        redirectUrl: dotenv.env['SPOTIFY_REDIRECT_URL'].toString(),
      );
      setState(() => _connected = true);
    } catch (e) {
      debugPrint('Error connecting: $e');
    }
  }

  Future<void> _playTrack(String url) async {
    final trackId = Uri.parse(url).pathSegments.last;
    final spotifyUri = 'spotify:track:$trackId';
    await SpotifySdk.play(spotifyUri: spotifyUri);
    setState(() => _playing = true);
  }

  Future<void> _pauseResume() async {
    if (_playing) {
      await SpotifySdk.pause();
      setState(() => _playing = false);
    } else {
      await SpotifySdk.resume();
      setState(() => _playing = true);
    }
  }

  void _scanQRCode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QRScanPage(onResult: _playTrack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Music Player')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_connected)
              ElevatedButton(
                onPressed: _connectToSpotify,
                child: const Text('Connect to Spotify'),
              )
            else ...[
              ElevatedButton(
                onPressed: _scanQRCode,
                child: const Text('Scan Card'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pauseResume,
                child: Text(_playing ? 'Pause' : 'Resume'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class QRScanPage extends StatelessWidget {
  final Function(String) onResult;
  const QRScanPage({super.key, required this.onResult});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
             if (barcode.rawValue != null) {
               onResult(barcode.rawValue!);
               Navigator.pop(context);
               break; 
             }
          }
        },
      ),
    );
  }
}

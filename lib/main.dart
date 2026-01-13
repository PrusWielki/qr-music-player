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
  bool _isLoading = false;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  Future<void> _connectToSpotify() async {
    setState(() => _isLoading = true);
    try {
      await SpotifySdk.getAccessToken(
        clientId: dotenv.env['SPOTIFY_CLIENT_ID']!,
        redirectUrl: dotenv.env['SPOTIFY_REDIRECT_URL']!,
        scope:
            'app-remote-control,user-modify-playback-state,playlist-read-private',
      );
      await SpotifySdk.connectToSpotifyRemote(
        clientId: dotenv.env['SPOTIFY_CLIENT_ID']!,
        redirectUrl: dotenv.env['SPOTIFY_REDIRECT_URL']!,
      );
      if (mounted) {
        setState(() => _connected = true);
      }
    } catch (e) {
      debugPrint('Error connecting: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error connecting: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _playTrack(String url) async {
    try {
      final trackId = Uri.parse(url).pathSegments.last;
      final spotifyUri = 'spotify:track:$trackId';
      await SpotifySdk.play(spotifyUri: spotifyUri);
      setState(() => _playing = true);
    } catch (e) {
      debugPrint('Error playing track: $e');
    }
  }

  Future<void> _pauseResume() async {
    try {
      if (_playing) {
        await SpotifySdk.pause();
        setState(() => _playing = false);
      } else {
        await SpotifySdk.resume();
        setState(() => _playing = true);
      }
    } catch (e) {
      debugPrint('Error toggling play: $e');
    }
  }

  Future<void> _seekRelative(int milliseconds) async {
    try {
      final state = await SpotifySdk.getPlayerState();
      if (state != null) {
        final currentPosition = state.playbackPosition;
        await SpotifySdk.seekTo(
          positionedMilliseconds: currentPosition + milliseconds,
        );
      }
    } catch (e) {
      debugPrint('Error seeking: $e');
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
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.black],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_connected)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFF1DB954),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF1DB954,
                              ), // Spotify Green
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: _connectToSpotify,
                            icon: const Icon(Icons.login, size: 28),
                            label: const Text(
                              'Connect to Spotify',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                  )
                else ...[
                  // Main Action: Scan
                  _buildScanButton(),
                  const SizedBox(height: 50),
                  // Player Controls
                  _buildPlayerControls(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: _scanQRCode,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1DB954), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1DB954).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.qr_code_scanner, size: 80, color: Colors.white),
            SizedBox(height: 10),
            Text(
              'SCAN CARD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCircleButton(
            icon: Icons.replay_10,
            onPressed: () => _seekRelative(-10000),
            size: 50,
          ),
          _buildCircleButton(
            icon: _playing ? Icons.pause : Icons.play_arrow,
            onPressed: _pauseResume,
            size: 70, // Bigger play/pause button
            color: const Color(0xFF1DB954),
          ),
          _buildCircleButton(
            icon: Icons.forward_10,
            onPressed: () => _seekRelative(10000),
            size: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 50,
    Color? color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color ?? Colors.white.withValues(alpha: 0.1),
      ),
      child: IconButton(
        icon: Icon(icon),
        iconSize: size * 0.5,
        color: Colors.white,
        onPressed: onPressed,
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

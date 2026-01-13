import 'package:flutter/material.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qr_music_player/screens/scan_page.dart';
import 'package:qr_music_player/widgets/player_controls.dart';
import 'package:qr_music_player/widgets/scan_button.dart';

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
    if (!url.contains('open.spotify.com')) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invalid QR Code'),
            content: Text(
              'The scanned QR code is not a valid Spotify link:\n\n$url',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
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
                              backgroundColor: const Color(0xFF1DB954),
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
                  ScanButton(onTap: _scanQRCode),
                  const SizedBox(height: 50),
                  PlayerControls(
                    isPlaying: _playing,
                    onPlayPause: _pauseResume,
                    onSeekForward: () => _seekRelative(10000),
                    onSeekBackward: () => _seekRelative(-10000),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

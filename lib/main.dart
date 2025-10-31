import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glassmorphism Music Player',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro Display',
      ),
      home: MusicPlayerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  @override
  _MusicPlayerScreenState createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _progressController;
  late Timer _visualizerTimer;
  late AudioPlayer _audioPlayer;

  bool isPlaying = false;
  bool isLoading = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;
  List<double> visualizerHeights = List.generate(20, (index) => 0.1);

  final List<Song> playlist = [
    Song(
      title: "Neon Dreams",
      artist: "Synthwave Collective",
      album: "Retro Future",
      color: Colors.purple,
      audioPath: "assets/audio/bloom.mp3",
      imagePath: "assets/images/image1.png",
    ),
    Song(
      title: "Digital Love",
      artist: "Cyber Phoenix",
      album: "Electric Hearts",
      color: Colors.pink,
      audioPath: "assets/audio/go far.mp3",
      imagePath: "assets/images/image2.png",
    ),
    Song(
      title: "Midnight City",
      artist: "Neon Lights",
      album: "Urban Glow",
      color: Colors.blue,
      audioPath: "assets/audio/read.mp3",
      imagePath: "assets/images/image3.png",
    ),
  ];

  int currentSongIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _setupAnimations();
    _startVisualizerAnimation();
  }

  void _initializeAudio() {
    _audioPlayer = AudioPlayer();

    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        isPlaying = state.playing;
        isLoading = state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });

      if (isPlaying) {
        _rotationController.repeat();
        _scaleController.forward();
      } else {
        _rotationController.stop();
        _scaleController.reverse();
      }
    });

    // Listen to position changes
    _audioPlayer.positionStream.listen((position) {
      setState(() {
        currentPosition = position;
      });
    });

    // Listen to duration changes
    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        totalDuration = duration ?? Duration.zero;
      });
    });

    // Auto play next song when current ends
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _nextSong();
      }
    });

    // Load first song
    _loadSong(0);
  }

  void _setupAnimations() {
    _rotationController = AnimationController(
      duration: Duration(seconds: 10),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _startVisualizerAnimation() {
    _visualizerTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (isPlaying) {
        setState(() {
          visualizerHeights = List.generate(20, (index) {
            return 0.1 + math.Random().nextDouble() * 0.9;
          });
        });
      } else {
        setState(() {
          visualizerHeights = List.generate(20, (index) => 0.1);
        });
      }
    });
  }

  Future<void> _loadSong(int index) async {
    try {
      setState(() {
        isLoading = true;
        currentSongIndex = index;
      });

      // Try to load from assets first, fallback to demo URL if assets don't exist
      try {
        await _audioPlayer.setAsset(playlist[index].audioPath);
      } catch (e) {
        // Fallback to a demo audio URL if asset doesn't exist
        print('Asset not found, using demo audio');
        await _audioPlayer.setUrl('https://www.soundjay.com/misc/sounds/bell-ringing-05.wav');
      }

    } catch (e) {
      print('Error loading audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading audio. Add mp3 files to assets/audio/'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _togglePlayPause() async {
    try {
      if (isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      print('Error toggling playback: $e');
    }
  }

  void _nextSong() async {
    int nextIndex = (currentSongIndex + 1) % playlist.length;
    await _loadSong(nextIndex);
  }

  void _previousSong() async {
    int prevIndex = (currentSongIndex - 1 + playlist.length) % playlist.length;
    await _loadSong(prevIndex);
  }

  void _seek(double value) {
    final position = Duration(
      milliseconds: (value * totalDuration.inMilliseconds).round(),
    );
    _audioPlayer.seek(position);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    _progressController.dispose();
    _visualizerTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = playlist[currentSongIndex];
    final progress = totalDuration.inMilliseconds > 0
        ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
        : 0.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              currentSong.color.withOpacity(0.8),
              currentSong.color.withOpacity(0.4),
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(flex: 4, child: _buildAlbumArtwork(currentSong)),
                      Flexible(flex: 1, child: _buildSongInfo(currentSong)),
                      Flexible(flex: 1, child: _buildAudioVisualizer()),
                      Flexible(flex: 1, child: _buildProgressBar(progress)),
                      Flexible(flex: 1, child: _buildControlButtons()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GlassContainer(
            size: 40,
            child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
          ),
          Text(
            "Now Playing",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          GlassContainer(
            size: 40,
            child: Icon(Icons.more_vert, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArtwork(Song song) {
    // Make album artwork responsive to screen size but more compact
    final screenSize = MediaQuery.of(context).size;
    final artworkSize = math.min(screenSize.width * 0.6, 220.0);

    return Center(
      child: AnimatedBuilder(
        animation: _rotationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationController.value * 2 * math.pi,
            child: AnimatedBuilder(
              animation: _scaleController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_scaleController.value * 0.05),
                  child: Container(
                    width: artworkSize,
                    height: artworkSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          song.color,
                          song.color.withOpacity(0.7),
                          Colors.black,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: song.color.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: artworkSize * 0.35,
                        height: artworkSize * 0.35,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.8),
                        ),
                        child: isLoading
                            ? CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                            : Icon(
                          Icons.music_note,
                          color: Colors.white,
                          size: artworkSize * 0.15,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongInfo(Song song) {
    return Column(
      children: [
        Text(
          song.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 4),
        Text(
          song.artist,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2),
        Text(
          song.album,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildAudioVisualizer() {
    return Container(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: visualizerHeights.map((height) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 100),
            width: 2.5,
            height: height * 40,
            margin: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  playlist[currentSongIndex].color,
                  Colors.white,
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.2),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: _seek,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(currentPosition),
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
              Text(
                _formatDuration(totalDuration),
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GlassContainer(
          size: 50,
          child: IconButton(
            onPressed: _previousSong,
            icon: Icon(Icons.skip_previous, color: Colors.white, size: 24),
          ),
        ),
        GlassContainer(
          size: 60,
          child: IconButton(
            onPressed: isLoading ? null : _togglePlayPause,
            icon: isLoading
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        GlassContainer(
          size: 50,
          child: IconButton(
            onPressed: _nextSong,
            icon: Icon(Icons.skip_next, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double size;

  const GlassContainer({
    Key? key,
    required this.child,
    this.size = 60,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 2),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

class Song {
  final String title;
  final String artist;
  final String album;
  final Color color;
  final String audioPath;
  final String imagePath;

  Song({
    required this.title,
    required this.artist,
    required this.album,
    required this.color,
    required this.audioPath,
    required this.imagePath,
  });
}
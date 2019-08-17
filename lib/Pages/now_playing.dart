import 'dart:math';
import 'package:flute_music_player/flute_music_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_visualizers/Visualizers/MultiWaveVisualizer.dart';
import 'package:fluttery/gestures.dart';
import 'package:fluttery_audio/fluttery_audio.dart';
import 'package:musix/my_app.dart';
import 'package:musix/song_data.dart';
import 'package:musix/theme.dart';
import 'package:flutter/services.dart';
import 'package:media_notification/media_notification.dart';

enum PlayerState { stopped, playing, paused }

class NowPlaying extends StatefulWidget {
  final Song _song;
  final SongData songData;
  final bool nowPlayTap;
  NowPlaying(this.songData, this._song, {this.nowPlayTap});
  @override
  _NowPlayingState createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> {
  MusicFinder audioPlayer;
  Duration duration;
  Duration position;
  PlayerState playerState;
  Song song;
  String status = 'hidden';
  double _progress;
  double _seekPercent;
  bool _isSeeking = false;
  final Set<AudioPlayerListener> _listeners = Set();
  get isPlaying => playerState == PlayerState.playing;
  get isPaused => playerState == PlayerState.paused;

  get durationText =>
      duration != null ? duration.toString().split('.').first : '';
  get positionText =>
      position != null ? position.toString().split('.').first : '';

  bool isMuted = false;

  bool get isSeeking => _isSeeking;

  _setIsSeeking(bool isSeeking) {
    if (isSeeking == _isSeeking) {
      return;
    }

    _isSeeking = isSeeking;

    if (_isSeeking) {
      for (AudioPlayerListener listener in _listeners) {
        listener.onSeekStarted();
      }
    } else {
      for (AudioPlayerListener listener in _listeners) {
        listener.onSeekCompleted();
      }
    }
  }
  @override
  initState() {
    super.initState();
    initPlayer();
     MediaNotification.setListener('pause', () {
      setState(() => pause(song));
    });

    MediaNotification.setListener('play', () {
      setState(() => play(song));
    });
    
    MediaNotification.setListener('next', () {
      setState(() => next(widget.songData)); 
    });

    MediaNotification.setListener('prev', () {
      prev(widget.songData);
    });

    MediaNotification.setListener('close', () {
       hide();dispose();
    });
  }

  Future<void> hide() async {
    try {
      await MediaNotification.hide();
      setState(() => status = 'hidden');
  } on PlatformException {

    }
  }

  Future<void> show(title, author) async {
    try {
      await MediaNotification.show(title: title, author: author);
      setState(() => status = 'play');
    } on PlatformException {

    }
  }

  @override
  void dispose() {
    MediaNotification.hide();
    super.dispose();
  }

  void onComplete() {
    setState(() => playerState = PlayerState.stopped);
    play(widget.songData.nextSong);
  }

  initPlayer() async {
    if (audioPlayer == null) {
      audioPlayer = widget.songData.audioPlayer;
    }
    setState(() {
      song = widget._song;
           // _progress=position.inMilliseconds.toDouble()/duration.inMilliseconds.toDouble();
      if (widget.nowPlayTap == null || widget.nowPlayTap == false) {
        if (playerState != PlayerState.stopped) {
          stop();
        }
      }
      play(song);
      //  else {
      //   widget._song;
      //   playerState = PlayerState.playing;
      // }
    });
    audioPlayer.setDurationHandler((d) => setState(() {
          duration = d;
        }));

    audioPlayer.setPositionHandler((p) => setState(() {
          position = p;
        }));

    audioPlayer.setCompletionHandler(() {
      onComplete();
      setState(() {
        position = duration;
      });
    });

    audioPlayer.setErrorHandler((msg) {
      setState(() {
        playerState = PlayerState.stopped;
        duration = new Duration(seconds: 0);
        position = new Duration(seconds: 0);
      });
    });
  }

  Future play(Song s) async {
    if (s != null) {
      final result = await audioPlayer.play(s.uri, isLocal: true);
      if (result == 1)
        setState(() {
          playerState = PlayerState.playing;
          song = s;
          show(s.title, s.artist);
          print(song.album);
        });
    }
  }

  Future pause(Song s) async {
    final result = await audioPlayer.pause();
    if (result == 1) setState(() {
      playerState = PlayerState.paused;
      song = s;
      print(s.album);
      });
  }

  Future stop() async {
    final result = await audioPlayer.stop();
    if (result == 1)
      setState(() {
        playerState = PlayerState.stopped;
        position = new Duration();
      });
  }

  Future next(SongData s) async {
    stop();
    setState(() {
      _seekPercent=0.0;
      play(s.nextSong);
    });
  }

  Future prev(SongData s) async {
    stop();
    play(s.prevSong);
  }

  Future mute(bool muted) async {
    final result = await audioPlayer.mute(muted);
    if (result == 1)
      setState(() {
        isMuted = muted;
      });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        backgroundColor: Colors.white,
        elevation: 0.0,
        leading: new IconButton(
          icon: new Icon(
            Icons.arrow_back_ios,
          ),
          color: const Color(0xFFDDDDDD),
          onPressed: (){
              Navigator.push(
          context,
          new MaterialPageRoute(
              builder: (context) => new MyApp()
            )
            );
          },
        ),
        title: new Text(''),
        actions: <Widget>[
          new IconButton(
            icon: new Icon(
              Icons.menu,
            ),
            color: const Color(0xFFDDDDDD),
            onPressed: () {},
          ),
        ],
      ),
      body: new Column(
          children: <Widget>[
           new Expanded( 
                child: new RadialSeekBar(
                  progress: position.inMilliseconds.toDouble()/duration.inMilliseconds.toDouble(),
                  seekPercent: _isSeeking ? _seekPercent : 0.0,
                  onSeekRequested: (double seekPercent){
                    setState(() { _seekPercent = seekPercent; _setIsSeeking(true);});
                    final seekSeconds= (duration.inMilliseconds * seekPercent)/1000.round();
                    audioPlayer.seek(seekSeconds);
                    print(_isSeeking);
                  },
                  song: song)
              ),
            new Container(
              width: double.infinity,
              height: 125.0,
              child: new Visualizer(
                   builder: (BuildContext context, List<int> fft) {
                      return new CustomPaint(
                          painter: new VisualizerPainter(
                          fft: fft,
                          height: 125.0,
                          color: accentColor,
                        ),
                          child: new Container(),
                      );
                      },
                ),
              ),
            new Material(
              shadowColor: const Color(0x44000000),
              color: accentColor,
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0, bottom: 50.0),
                child: Column(children: <Widget>[
                  new RichText(
                    text: new TextSpan(
                      text: '',
                      children: [
                        new TextSpan(
                          text: song.title,
                          style: new TextStyle(
                            color: Colors.white,
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4.0,
                            height: 1.5,
                          ),
                        ),
                        new TextSpan(
                          text: '\n'+song.artist,
                          style: new TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12.0,
                            letterSpacing: 3.0,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  new Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: new Row(
                      children: <Widget>[
                        new Expanded(child: new Container()),
                        new IconButton(
                          splashColor: lightAccentColor,
                          highlightColor: Colors.transparent,
                          icon: new Icon(
                            Icons.skip_previous,
                            color: Colors.white,
                            size: 35.0,
                          ),
                          onPressed: () => prev(widget.songData),
                        ),
                        new Expanded(child: new Container()),
                        new RawMaterialButton(
                          shape: new CircleBorder(),
                          fillColor: Colors.white,
                          splashColor: lightAccentColor,
                          highlightColor: lightAccentColor.withOpacity(0.5),
                          elevation: 10.0,
                          highlightElevation: 5.0,
                          onPressed: () => {isPlaying ? pause(song) : play(song)},
                          child: new Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: new Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: darkAccentColor,
                              size: 35.0,
                            ),
                          ),
                        ),
                        new Expanded(child: new Container()),
                        new IconButton(
                          splashColor: lightAccentColor,
                          highlightColor: Colors.transparent,
                          icon: new Icon(
                            Icons.skip_next,
                            color: Colors.white,
                            size: 35.0,
                          ),
                          onPressed: () => next(widget.songData),
                        ),
                        new Expanded(child: new Container()),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
    );
  }
}

class VisualizerPainter extends CustomPainter {

  final List<int> fft;
  final double height;
  final Color color;
  final Paint wavePaint;

  VisualizerPainter({
    this.fft,
    this.height,
    this.color,
  }) : wavePaint = new Paint()
    ..color = color.withOpacity(0.75)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    _renderWaves(canvas, size);
  }

  void _renderWaves(Canvas canvas, Size size) {
    // Starting from the 10th sample since the lower bins are barely audible
    final histogramLow = _createHistogram(fft, 16, 12, ((fft.length - 2) / 4).floor() + 10);
    final histogramHigh = _createHistogram(fft, 16, ((fft.length - 2) / 4).ceil() + 10, ((fft.length - 2) / 2).floor());

    _renderHistogram(canvas, size, histogramLow);
    _renderHistogram(canvas, size, histogramHigh);
  }

  void _renderHistogram(Canvas canvas, Size size, List<int> histogram) {
    if (histogram.length == 0) {
      return;
    }

    final pointsToGraph = histogram.length;
    final widthPerSample = (size.width / (pointsToGraph - 2)).floor();

    final points = new List<double>.filled(pointsToGraph * 4, 0.0);

    for (int i = 0; i < histogram.length - 1; ++i) {
      points[i * 4] = (i * widthPerSample).toDouble();
      points[i * 4 + 1] = size.height - histogram[i].toDouble();

      points[i * 4 + 2] = ((i + 1) * widthPerSample).toDouble();
      points[i * 4 + 3] = size.height - (histogram[i + 1].toDouble());
    }

    Path path = new Path();
    path.moveTo(0.0, size.height);
    path.lineTo(points[0], points[1]);
    for (int i = 2; i < points.length - 4; i += 2) {
      path.cubicTo(
          points[i - 2] + 10.0, points[i - 1],
          points[i] - 10.0, points [i + 1],
          points[i], points[i + 1]
      );
    }
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, wavePaint);
  }

  List<int> _createHistogram(List<int> samples, int bucketCount, [int start, int end]) {
    if (start == end) {
      return const [];
    }

    // Make sure we're not starting in the middle of an imaginary pair!
    assert(start > 1 && start % 2 == 0);

    start = start ?? 0;
    end = end ?? samples.length - 1;
    final sampleCount = end - start + 1;

    final samplesPerBucket = (sampleCount / bucketCount).floor();
    if (samplesPerBucket == 0) {
      return const [];
    }

    final actualSampleCount = sampleCount - (sampleCount % samplesPerBucket);
    List<double> histogram = new List<double>.filled(bucketCount + 1, 0.0);

    for (int i = start; i <= start + actualSampleCount; ++i) {
      if ((i - start) % 2 == 1) {
        continue;
      }

      // Calculate the magnitude of the FFT result for the bin while removing
      // the phase correlation information by calculating the raw magnitude
      double magnitude = sqrt((pow(samples[i], 2) + pow(samples[i + 1], 2)));
      // Convert the raw magnitude to Decibels Full Scale (dBFS) assuming an 8 bit value
      // and clamp it to get rid of astronomically small numbers and -Infinity when array is empty.
      // We are assuming the values are already normalized
      double magnitudeDb = (10 * (log(magnitude / 256) / ln10));
      int bucketIndex = ((i - start) / samplesPerBucket).floor();
      histogram[bucketIndex] += (magnitudeDb == -double.infinity) ? 0 : magnitudeDb;
    }

    // Average the bins, round the results and return an inverted dB scale
    return histogram.map((double d) {
      return (-10 * d / samplesPerBucket).round();
    }).toList();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }

}

class RadialSeekBar extends StatefulWidget {
 
 final Song song;
 final double seekPercent;
 final double progress;
 final Function(double) onSeekRequested;

 RadialSeekBar({
    
    @required this.song,
    this.seekPercent = 0.0,
    this.progress, 
    this.onSeekRequested,  
  });

  

  @override
  _RadialSeekBarState createState() => _RadialSeekBarState();
}

class _RadialSeekBarState extends State<RadialSeekBar> {
  PolarCoord _startDragCord;
  double _startDragPercent;
  double _progress;
  double _currentDragPercent;
   void _onDragStart(PolarCoord coord){
      _startDragCord = coord;
      _startDragPercent = _progress;
  }

  @override
  void initState() {
    super.initState();
    _progress = widget.progress;
  }

  @override
  void didUpdateWidget(RadialSeekBar oldWidget) {
    
    super.didUpdateWidget(oldWidget);
    _progress = widget.progress;
  }
  void _onDragUpdate(PolarCoord coord){
    final dragAngle = coord.angle - _startDragCord.angle;
    final dragPercent = dragAngle/ (2 * pi);

    setState(() => _currentDragPercent = (_startDragPercent + dragPercent) % 1.0 );

  }

  void _onDragEnd(){

    if (widget.onSeekRequested != null){
      widget.onSeekRequested(_currentDragPercent);
    }    
    setState(() {
     _currentDragPercent = null;
     _startDragCord = null;
     _startDragPercent = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    double thumbposition = _progress;
    if(_currentDragPercent != null){
      thumbposition =_currentDragPercent;  
    }
    else if( widget.seekPercent ==  null){
      thumbposition = widget.seekPercent;
    }
    else{
      thumbposition=_progress;
    }
    return new RadialDragGestureDetector(
      onRadialDragStart: _onDragStart,
      onRadialDragUpdate: _onDragUpdate,
      onRadialDragEnd: _onDragEnd,
      child: Container(
        color: Colors.white,
        width: double.infinity,
        height: double.infinity,
        child: new Center(
        child: Container(
          width: 140.0,
          height: 140.0,
          child: new RadialProgressBar(
            trackColor: new Color(0xFFDDDDDD),
            progressPercent: _progress,
            thumbPosition: thumbposition,
            progressColor: accentColor,
            thumbColor: lightAccentColor ,
            innerPadding: const EdgeInsets.all(10.0),
            child: new ClipOval(
                clipper: new CircleClipper(),
                child: new Image.asset(
                  widget.song.albumArt !=null ? widget.song.albumArt : 'assets/images/music_symbol.png' ,
                  fit: BoxFit.cover,)
            ),
          ),
        ),
      )
                ),
    );
  }
}

class RadialProgressBar extends StatefulWidget {

  final double trackWidth;
  final Color trackColor;
  final double progressWidth;
  final double progressPercent;
  final Color progressColor;
  final double thumbSize;
  final Color thumbColor;
  final double thumbPosition;
  final Widget child;
  final EdgeInsets innerPadding;
  final EdgeInsets outerPadding;

  RadialProgressBar({
    this.trackWidth = 3.0,
    this.trackColor= Colors.grey,
    this.progressWidth= 5.0,
    this.progressColor=Colors.black,
    this.thumbColor=Colors.black,
    this.thumbSize= 10.0,
    this.progressPercent=0.0,
    this.thumbPosition=0.0,
    this.child,
    this.innerPadding=const EdgeInsets.all(0.0),
    this.outerPadding=const EdgeInsets.all(0.0),
});
  @override
  _RadialProgressBarState createState() => _RadialProgressBarState();
}

class _RadialProgressBarState extends State<RadialProgressBar> {
 
 EdgeInsets _insetsForPainter(){
     final outerThickness = max(widget.trackWidth,max(widget.progressWidth,widget.thumbSize))/2;
     return new EdgeInsets.all(outerThickness);

 }
 
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.outerPadding,
      child: new CustomPaint(

        foregroundPainter: new RadialSeekBarPainter(
          trackWidth: widget.trackWidth,
          trackColor: widget.trackColor,
          progressWidth: widget.progressWidth,
          progressColor: widget.progressColor,
          progressPercent: widget.progressPercent,
          thumbColor: widget.thumbColor,
          thumbSize: widget.thumbSize,
          thumbPositon: widget.thumbPosition
        ),
        child: new Padding(
           padding: _insetsForPainter()+widget.innerPadding,
           child: widget.child,
         ),
      ),
    );
  }
}

class RadialSeekBarPainter extends CustomPainter{

  final double trackWidth;
  final Paint trackPaint;
  final double progressWidth;
  final double progressPercent;
  final Paint progressPaint;
  final double thumbSize;
  final Paint thumbPaint;
  final double thumbPositon;

  RadialSeekBarPainter({
    @required this.trackWidth,
    @required trackColor= Colors.grey,
    @required this.progressWidth,
    @required progressColor=Colors.black,
    @required thumbColor=Colors.black,
    @required this.thumbSize,
    @required this.progressPercent,
    @required this.thumbPositon,
  }) : trackPaint = new Paint()
        ..color =  trackColor
        ..style =  PaintingStyle.stroke
        ..strokeWidth =  trackWidth,
       progressPaint = new Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = progressWidth
        ..strokeCap = StrokeCap.round,
       thumbPaint =  new Paint()
        ..color =  thumbColor
        ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {

    final outerThickness = max(trackWidth,max(progressWidth,thumbSize)); 
    Size constraintedSize = new Size(size.width-outerThickness, size.height-outerThickness);

    final centre = new Offset(size.width/2, size.height/2);
    final radius =  min(constraintedSize.width,constraintedSize.height)/2;
    canvas.drawCircle(centre, radius, trackPaint);

    final progressAngle =  2 * pi * progressPercent;
    canvas.drawArc( new Rect.fromCircle(
          center: centre,
          radius: radius,
        ),
        -pi/2,
        progressAngle,
        false,
        progressPaint);
    final thumbAngle = 2 * pi * thumbPositon - (pi / 2);
    final thumbX = cos(thumbAngle) * radius;
    final thumbY = sin(thumbAngle) * radius;
    final thumbCenter = new Offset(thumbX, thumbY) + centre;
    final thumbRadius = thumbSize / 2.0;
    canvas.drawCircle(
      thumbCenter,
      thumbRadius,
      thumbPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {

    return true;
  }

}


class CircleClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return new Rect.fromCircle(
      center: new Offset(size.width / 2, size.height / 2),
      radius: min(size.width, size.height) / 2,
    );
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}
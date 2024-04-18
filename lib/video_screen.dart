import 'dart:developer';
import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:camera/camera.dart';

import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:video_compress/video_compress.dart';

class VideoScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const VideoScreen(this.cameras, {super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late CameraController controller;
  bool isCapturing = false;
  bool _isRecording = false;
  String _videoPath = '';
  int _selectedCameraIndex = 0;
  bool _isFrontCamera = false;
  bool _isFlashOn = false;
  Offset? _focusPoint;
  double _currentZoom = 1.0;
  File? _capturedVideo;
  MediaInfo? compressedVideoInfo;
  AssetsAudioPlayer audioPlayer = AssetsAudioPlayer();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    controller = CameraController(widget.cameras[0], ResolutionPreset.veryHigh);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _toggleFlashLight() {
    if (_isFlashOn) {
      controller.setFlashMode(FlashMode.off);
      setState(() {
        _isFlashOn = false;
        log("flash off");
      });
    } else {
      controller.setFlashMode(FlashMode.torch);
      setState(() {
        _isFlashOn = true;
        log("flash on");
      });
    }
  }

  void zoomCamera(double value) {
    setState(() {
      _currentZoom = value;
      controller.setZoomLevel(value);
    });
  }

  Future<void> _setFocusPoint(Offset point) async {
    if (controller != null && controller.value.isInitialized) {
      try {
        final double x = point.dx.clamp(0.0, 1.0);
        final double y = point.dy.clamp(0.0, 1.0);
        await controller.setFocusPoint(Offset(x, y));
        await controller.setFocusMode(FocusMode.auto);
        setState(() {
          _focusPoint = Offset(x, y);
        });
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          _focusPoint = null;
        });
      } catch (e) {
        log("Failed to set focus: $e");
      }
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopVideoRecording();
    } else {
      _startVideoRecording();
    }
  }

  void _startVideoRecording() async {
    if (!controller.value.isRecordingVideo) {
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      try {
        await controller.initialize();
        await controller.startVideoRecording();
        setState(() {
          _isRecording = true;
          _videoPath = path;
          audioPlayer.open(Audio("sfx/start-13691.mp3"));
          audioPlayer.play();
        });
      } catch (e) {
        log('$e');
        return;
      }
    }
  }

  void _stopVideoRecording() async {
    if (controller.value.isRecordingVideo) {
      try {
        final XFile videoFile = await controller.stopVideoRecording();

        setState(() {
          _isRecording = false;
        });
        if (_videoPath.isNotEmpty) {
          final File file = File(videoFile.path);
          await file.copy(_videoPath);
          final MediaInfo? compressedVideoPath =
              await VideoCompress.compressVideo(
            file.path,
            quality: VideoQuality.Res640x480Quality,
            deleteOrigin: true,
            includeAudio: false,
          );
          print("compressedVideoPath: ${compressedVideoPath?.path}");
          await GallerySaver.saveVideo(compressedVideoPath!.path!);
          audioPlayer.open(Audio("sfx/stop-13692.mp3"));
          audioPlayer.play();
        }
      } catch (e) {
        log('$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(body: LayoutBuilder(builder: ((context, constraints) {
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: GestureDetector(
                          onTap: () {
                            _toggleFlashLight();
                          },
                          child: _isFlashOn == false
                              ? const Icon(
                                  Icons.flash_off,
                                  color: Colors.white,
                                )
                              : const Icon(
                                  Icons.flash_on,
                                  color: Colors.white,
                                )),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text(
                        "CITYSURVEY by CITYDATA",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              top: 50,
              bottom: _isFrontCamera == false ? 0 : 150,
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: GestureDetector(
                    onTapDown: (TapDownDetails details) {
                      final Offset tapPosition = details.localPosition;
                      final Offset relativeTapPosition = Offset(
                        tapPosition.dx / constraints.maxWidth,
                        tapPosition.dy / constraints.maxHeight,
                      );
                      _setFocusPoint(relativeTapPosition);
                    },
                    child: CameraPreview(controller)),
              ),
            ),
            Positioned(
              top: 50,
              right: 10,
              child: SfSlider.vertical(
                  max: 5.0,
                  min: 1.0,
                  activeColor: Colors.white,
                  value: _currentZoom,
                  onChanged: (dynamic value) {
                    setState(() {
                      zoomCamera(value);
                    });
                  }),
            ),
            if (_focusPoint != null)
              Positioned.fill(
                top: 50,
                child: Align(
                  alignment: Alignment(
                      _focusPoint!.dx * 2 - 1, _focusPoint!.dy * 2 - 1),
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color:
                      _isFrontCamera == false ? Colors.black45 : Colors.black,
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                              child: Center(
                                  child: Text(
                            "Video",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          )))
                        ],
                      ),
                    ),
                    Expanded(
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                            child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      _toggleRecording();
                                    },
                                    child: Center(
                                      child: Container(
                                        height: 70,
                                        width: 70,
                                        decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(50),
                                            border: Border.all(
                                                width: 4,
                                                color: Colors.white,
                                                style: BorderStyle.solid)),
                                        child: _isRecording == false
                                            ? const Icon(
                                                Icons.play_arrow,
                                                color: Color.fromARGB(
                                                    255, 255, 23, 7),
                                                size: 40,
                                              )
                                            : const Icon(
                                                Icons.stop,
                                                color: Color.fromARGB(
                                                    255, 255, 23, 7),
                                                size: 40,
                                              ),
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ],
                        ))
                      ],
                    ))
                  ],
                ),
              ),
            ),
          ],
        );
      }))),
    );
  }
}

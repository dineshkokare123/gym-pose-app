import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';
import '../services/pose_detector_service.dart';
import '../utils/camera_utils.dart';
import '../logic/workout_counter.dart';
import 'pose_painter.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;
  final PoseDetectorService _poseDetectorService = PoseDetectorService();
  WorkoutType _workoutType = WorkoutType.squat;
  late WorkoutCounter _workoutCounter;
  List<Pose> _poses = [];
  int _reps = 0;
  CameraImage? _cameraImage;

  bool _isPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    _workoutCounter = WorkoutCounter(_workoutType);
    _initializeCamera();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('AppLifecycleState: $state');
    if (state == AppLifecycleState.resumed) {
      if (!_isCameraInitialized && _isPermissionDenied) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    debugPrint('Requesting camera permission...');
    
    // Check current status first
    final currentStatus = await Permission.camera.status;
    debugPrint('Current permission status: $currentStatus');
    
    if (currentStatus.isDenied) {
      debugPrint('Permission is denied, requesting...');
      final status = await Permission.camera.request();
      debugPrint('Permission request result: $status');
      
      if (!status.isGranted) {
        debugPrint('Permission not granted after request');
        setState(() {
          _isPermissionDenied = true;
        });
        return;
      }
    } else if (currentStatus.isPermanentlyDenied) {
      debugPrint('Permission permanently denied');
      setState(() {
        _isPermissionDenied = true;
      });
      return;
    } else if (!currentStatus.isGranted) {
      debugPrint('Permission status: $currentStatus');
      setState(() {
        _isPermissionDenied = true;
      });
      return;
    }
    
    // Permission is granted, initialize camera
    debugPrint('Permission granted, initializing camera...');
    setState(() {
      _isPermissionDenied = false;
    });
    
    if (cameras.isEmpty) {
      debugPrint('No cameras found');
      return;
    }
    
    // Use front camera if available
    final cameraIndex = cameras.indexWhere(
      (c) => c.lensDirection == _cameraLensDirection,
    );
    
    final camera = cameraIndex != -1 ? cameras[cameraIndex] : cameras.first;

    // Dispose of the old controller if it exists
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
      _startImageStream();
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
    }
  }

  void _startImageStream() {
    _controller!.startImageStream((image) async {
      if (!mounted) return;
      _cameraImage = image;
      
      final inputImage = _processCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetectorService.processImage(inputImage);
      
      if (poses.isNotEmpty) {
        _workoutCounter.checkPose(poses.first);
      }

      if (mounted) {
        setState(() {
          _poses = poses;
          _reps = _workoutCounter.counter;
        });
      }
    });
  }

  void _onCameraSwitch() {
    setState(() {
      _isCameraInitialized = false;
      _cameraLensDirection = _cameraLensDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
    });
    _initializeCamera();
  }

  InputImageRotation _currentRotation = InputImageRotation.rotation0deg;

  InputImage? _processCameraImage(CameraImage image) {
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
    _currentRotation = rotation;

    return inputImageFromCameraImage(
      image: image,
      camera: camera,
      sensorOrientation: sensorOrientation,
      deviceOrientation: AppDeviceOrientation.portraitUp,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _poseDetectorService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isPermissionDenied) ...[
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Camera Permission Denied',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '1. Open Settings\n2. Tap Privacy & Security\n3. Tap Camera\n4. Enable "Gym Pose App"',
                    textAlign: TextAlign.left,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: openAppSettings,
                  child: const Text('Open Settings'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _initializeCamera,
                  child: const Text('Check Again'),
                ),
              ] else ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text('Initializing Camera...'),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          if (_cameraImage != null && _poses.isNotEmpty)
            CustomPaint(
              painter: PosePainter(
                _poses,
                Size(_cameraImage!.width.toDouble(), _cameraImage!.height.toDouble()),
                _currentRotation,
              ),
            ),
          Positioned(
            top: 50,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<WorkoutType>(
                    value: _workoutType,
                    dropdownColor: Colors.black87,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    underline: Container(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    onChanged: (WorkoutType? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _workoutType = newValue;
                          _workoutCounter = WorkoutCounter(_workoutType);
                          _reps = 0;
                        });
                      }
                    },
                    items: WorkoutType.values.map<DropdownMenuItem<WorkoutType>>((WorkoutType value) {
                      return DropdownMenuItem<WorkoutType>(
                        value: value,
                        child: Text(value.name.toUpperCase()),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_workoutType.name.toUpperCase()}: $_reps',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 50,
            right: 20,
            child: InkWell(
              onTap: _onCameraSwitch,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Platform.isIOS ? Icons.flip_camera_ios : Icons.flip_camera_android,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

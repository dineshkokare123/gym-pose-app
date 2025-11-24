import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../utils/camera_utils.dart';

class PoseDetectorService {
  late final PoseDetector _poseDetector;
  bool _isBusy = false;

  PoseDetectorService() {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base, // Base is faster, Accurate is more precise
    );
    _poseDetector = PoseDetector(options: options);
  }

  Future<List<Pose>> processImage(InputImage inputImage) async {
    if (_isBusy) return [];
    _isBusy = true;
    try {
      final poses = await _poseDetector.processImage(inputImage);
      return poses;
    } catch (e) {
      debugPrint('Error processing image: $e');
      return [];
    } finally {
      _isBusy = false;
    }
  }

  void close() {
    _poseDetector.close();
  }
}

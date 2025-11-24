import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum WorkoutType { squat, pushup, lunge, jumpingJack, crunch, deadlift, plank, overheadPress, highKnees }

class WorkoutCounter {
  int counter = 0;
  bool _isDown = false; // Used for Squat, Pushup, Lunge, Crunch, Deadlift, Overhead Press
  bool _isHandsUp = false; // Used for Jumping Jack
  bool _isPlank = false; // Used for Plank
  int _plankDuration = 0; // Seconds for plank
  DateTime? _plankStartTime;
  final WorkoutType type;

  WorkoutCounter(this.type);

  void checkPose(Pose pose) {
    switch (type) {
      case WorkoutType.squat:
        _checkSquat(pose);
        break;
      case WorkoutType.pushup:
        _checkPushup(pose);
        break;
      case WorkoutType.lunge:
        _checkLunge(pose);
        break;
      case WorkoutType.jumpingJack:
        _checkJumpingJack(pose);
        break;
      case WorkoutType.crunch:
        _checkCrunch(pose);
        break;
      case WorkoutType.deadlift:
        _checkDeadlift(pose);
        break;
      case WorkoutType.plank:
        _checkPlank(pose);
        break;
      case WorkoutType.overheadPress:
        _checkOverheadPress(pose);
        break;
      case WorkoutType.highKnees:
        _checkHighKnees(pose);
        break;
    }
  }

  void _checkSquat(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    // Check visibility
    if (leftHip != null && leftKnee != null && leftAnkle != null &&
        leftHip.likelihood > 0.5 && leftKnee.likelihood > 0.5 && leftAnkle.likelihood > 0.5) {
      final angle = _calculateAngle(leftHip, leftKnee, leftAnkle);
      _updateCounterStandard(angle, downThreshold: 90, upThreshold: 160);
    } else if (rightHip != null && rightKnee != null && rightAnkle != null &&
        rightHip.likelihood > 0.5 && rightKnee.likelihood > 0.5 && rightAnkle.likelihood > 0.5) {
       final angle = _calculateAngle(rightHip, rightKnee, rightAnkle);
      _updateCounterStandard(angle, downThreshold: 90, upThreshold: 160);
    }
  }

  void _checkPushup(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftShoulder != null && leftElbow != null && leftWrist != null &&
        leftShoulder.likelihood > 0.5 && leftElbow.likelihood > 0.5 && leftWrist.likelihood > 0.5) {
      final angle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
      _updateCounterStandard(angle, downThreshold: 90, upThreshold: 160);
    } else if (rightShoulder != null && rightElbow != null && rightWrist != null &&
        rightShoulder.likelihood > 0.5 && rightElbow.likelihood > 0.5 && rightWrist.likelihood > 0.5) {
      final angle = _calculateAngle(rightShoulder, rightElbow, rightWrist);
      _updateCounterStandard(angle, downThreshold: 90, upThreshold: 160);
    }
  }

  void _checkLunge(Pose pose) {
    _checkSquat(pose); 
  }

  void _checkCrunch(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

    if (leftShoulder != null && leftHip != null && leftKnee != null &&
        leftShoulder.likelihood > 0.5 && leftHip.likelihood > 0.5 && leftKnee.likelihood > 0.5) {
      final angle = _calculateAngle(leftShoulder, leftHip, leftKnee);
      _updateCounterInverted(angle, curlThreshold: 100, flatThreshold: 150);
    } else if (rightShoulder != null && rightHip != null && rightKnee != null &&
        rightShoulder.likelihood > 0.5 && rightHip.likelihood > 0.5 && rightKnee.likelihood > 0.5) {
      final angle = _calculateAngle(rightShoulder, rightHip, rightKnee);
      _updateCounterInverted(angle, curlThreshold: 100, flatThreshold: 150);
    }
  }

  void _checkJumpingJack(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftShoulder != null && leftHip != null && leftWrist != null &&
        rightShoulder != null && rightHip != null && rightWrist != null) {
        
        bool handsUp = leftWrist.y < leftShoulder.y && rightWrist.y < rightShoulder.y;
        bool handsDown = leftWrist.y > leftHip.y && rightWrist.y > rightHip.y;

        if (handsUp) {
          _isHandsUp = true;
        } else if (handsDown && _isHandsUp) {
          counter++;
          _isHandsUp = false;
        }
    }
  }

  void _checkDeadlift(Pose pose) {
    // Hip hinge: Angle between shoulder, hip, and knee.
    // Standing: ~180. Bent over: < 130?
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

    if (leftShoulder != null && leftHip != null && leftKnee != null &&
        leftShoulder.likelihood > 0.5 && leftHip.likelihood > 0.5 && leftKnee.likelihood > 0.5) {
      final angle = _calculateAngle(leftShoulder, leftHip, leftKnee);
      _updateCounterStandard(angle, downThreshold: 130, upThreshold: 160);
    } else if (rightShoulder != null && rightHip != null && rightKnee != null &&
        rightShoulder.likelihood > 0.5 && rightHip.likelihood > 0.5 && rightKnee.likelihood > 0.5) {
      final angle = _calculateAngle(rightShoulder, rightHip, rightKnee);
      _updateCounterStandard(angle, downThreshold: 130, upThreshold: 160);
    }
  }

  void _checkPlank(Pose pose) {
    // Plank is a static hold. We check if the body is straight (shoulder, hip, ankle ~ 180)
    // and horizontal.
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    bool isStraight = false;

    if (leftShoulder != null && leftHip != null && leftAnkle != null &&
        leftShoulder.likelihood > 0.5 && leftHip.likelihood > 0.5 && leftAnkle.likelihood > 0.5) {
      final angle = _calculateAngle(leftShoulder, leftHip, leftAnkle);
      if (angle > 160 && angle < 200) isStraight = true;
    } else if (rightShoulder != null && rightHip != null && rightAnkle != null &&
        rightShoulder.likelihood > 0.5 && rightHip.likelihood > 0.5 && rightAnkle.likelihood > 0.5) {
      final angle = _calculateAngle(rightShoulder, rightHip, rightAnkle);
      if (angle > 160 && angle < 200) isStraight = true;
    }

    if (isStraight) {
      if (!_isPlank) {
        _isPlank = true;
        _plankStartTime = DateTime.now();
      } else {
        // Update duration
        final duration = DateTime.now().difference(_plankStartTime!);
        counter = duration.inSeconds;
      }
    } else {
      _isPlank = false;
      _plankStartTime = null;
    }
  }

  void _checkOverheadPress(Pose pose) {
    // Arms start at shoulder level (elbow bent < 90?) and go up (elbow straight 180)
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftShoulder != null && leftElbow != null && leftWrist != null &&
        rightShoulder != null && rightElbow != null && rightWrist != null) {
      
      final leftAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
      final rightAngle = _calculateAngle(rightShoulder, rightElbow, rightWrist);

      // Down: Elbows bent, hands near shoulders. Angle ~ 70-90?
      // Up: Elbows extended. Angle > 160.
      
      // Using average angle for simplicity or requiring both
      if (leftAngle < 100 && rightAngle < 100) {
        _isDown = true; // "Down" position for press is starting position
      } else if (leftAngle > 160 && rightAngle > 160 && _isDown) {
        counter++;
        _isDown = false;
      }
    }
  }

  void _checkHighKnees(Pose pose) {
    // Knee should go above hip level.
    // Y increases downwards. So knee.y < hip.y means knee is higher.
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];

    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

    if (leftHip != null && leftKnee != null && rightHip != null && rightKnee != null) {
      bool leftUp = leftKnee.y < leftHip.y;
      bool rightUp = rightKnee.y < rightHip.y;

      // Count every time a knee goes up? Or pairs?
      // Let's count individual steps.
      // Need a state to track which leg was up or if we are in "standing" state.
      
      // Simple logic: if either knee is up and we weren't just up...
      // This is tricky for alternating legs.
      // Let's just check if *any* knee is up, set a flag, then wait for both to be down?
      // Or better: Left Up -> Count, wait for Left Down. Right Up -> Count, wait for Right Down.
      // But we have a single counter.
      
      // Let's use _isDown to mean "Both legs down".
      bool bothDown = leftKnee.y > leftHip.y && rightKnee.y > rightHip.y;
      
      if ((leftUp || rightUp) && _isDown) {
        counter++;
        _isDown = false;
      } else if (bothDown) {
        _isDown = true;
      }
    }
  }

  void _updateCounterStandard(double angle, {required double downThreshold, required double upThreshold}) {
    if (angle < downThreshold) {
      _isDown = true;
    } else if (angle > upThreshold && _isDown) {
      counter++;
      _isDown = false;
    }
  }

  void _updateCounterInverted(double angle, {required double curlThreshold, required double flatThreshold}) {
    // For crunch: Start flat (180), curl in (< 90)
    if (angle < curlThreshold) {
      _isDown = true; // "Down" here means curled state
    } else if (angle > flatThreshold && _isDown) {
      counter++;
      _isDown = false;
    }
  }

  double _calculateAngle(PoseLandmark first, PoseLandmark middle, PoseLandmark last) {
    double radians = math.atan2(last.y - middle.y, last.x - middle.x) -
        math.atan2(first.y - middle.y, first.x - middle.x);
    double angle = (radians * 180.0 / math.pi).abs();

    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
  }
}

import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

InputImage? inputImageFromCameraImage({
  required CameraImage image,
  required CameraDescription camera,
  required int sensorOrientation,
  required AppDeviceOrientation deviceOrientation,
}) {
  final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
  if (rotation == null) return null;

  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  // Validate format depending on platform
  if (format == null ||
      (Platform.isAndroid && format != InputImageFormat.nv21) ||
      (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      // Handle other formats if necessary
  }

  // Concatenate planes
  final WriteBuffer allBytes = WriteBuffer();
  for (final Plane plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
  }
  final Uint8List bytes = allBytes.done().buffer.asUint8List();

  final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

  final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.yuv420;

  // ML Kit 0.11.0+ uses InputImageMetadata
  final metadata = InputImageMetadata(
    size: imageSize,
    rotation: rotation,
    format: inputImageFormat,
    bytesPerRow: image.planes[0].bytesPerRow, 
  );

  return InputImage.fromBytes(bytes: bytes, metadata: metadata);
}

enum AppDeviceOrientation {
  portraitUp,
  landscapeLeft,
  portraitDown,
  landscapeRight,
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_detect/dectator_view.dart';
import 'package:image_detect/labelDetector.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MaterialApp(home: ImageLabelView(),));
}

class ImageLabelView extends StatefulWidget {
  @override
  State<ImageLabelView> createState() => _ImageLabelViewState();
}

class _ImageLabelViewState extends State<ImageLabelView> {
  late ImageLabeler _imageLabeler;
  bool _canProcess = false;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;

  @override
  void initState() {
    super.initState();
    _initializeLabeler();
  }

  @override
  void dispose() {
    _canProcess = false;
    _imageLabeler.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetectorView(
      title: 'Image Labeler',
      customPaint: _customPaint,
      text: _text,
      onImage: _processImage,
    );
  }

  void _initializeLabeler() async {
    const path = 'assets/ml/object_labeler.tflite';
    final modelPath = await getAssetPath(path);
    final options = LocalLabelerOptions(modelPath: modelPath);
    _imageLabeler = ImageLabeler(options: options);
    _canProcess = true;
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess || _isBusy) return;

    _isBusy = true;
    setState(() {
      _text = '';
    });

    final labels = await _imageLabeler.processImage(inputImage);

    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = LabelDetectorPainter(labels);
      _customPaint = CustomPaint(painter: painter);
    } else {
      String text = 'Labels found: ${labels.length}\n\n';
      for (final label in labels) {
        text += 'Label: ${label.label}\n';

        // Check if the label corresponds to a mobile device
        if (label.label.toLowerCase().contains('mobile') ||
            label.label.toLowerCase().contains('phone')) {
          // Navigate to another page when a mobile device is detected
          Navigator.push(
            this.context,
            MaterialPageRoute(
              builder: (context) => DetectedDevicePage(label: label.label),
            ),
          );
          break; // Exit the loop after navigation
        }
      }
      _text = text;
      _customPaint = null;
    }
    _isBusy = false;

    if (mounted) {
      setState(() {});
    }
  }
}

// Example of the new page you navigate to when a mobile device is detected
class DetectedDevicePage extends StatelessWidget {
  final String label;

  DetectedDevicePage({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detected Device'),
      ),
      body: Center(
        child: Text(
          'Detected: $label',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

Future<String> getAssetPath(String asset) async {
  final path = await getLocalPath(asset);
  await Directory(dirname(path)).create(recursive: true);
  final file = File(path);
  if (!await file.exists()) {
    final byteData = await rootBundle.load(asset);
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
  }
  return file.path;
}

Future<String> getLocalPath(String path) async {
  return '${(await getApplicationSupportDirectory()).path}/$path';
}

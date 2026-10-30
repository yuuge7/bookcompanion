import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class CoverCropScreen extends StatefulWidget {
  const CoverCropScreen({super.key, required this.path});
  final String path;
  @override
  State<CoverCropScreen> createState() => _CoverCropScreenState();
}

class _CoverCropScreenState extends State<CoverCropScreen> {
  final _boundary = GlobalKey();
  bool _busy = false;
  String? _error;
  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await precacheImage(FileImage(File(widget.path)), context);
      await WidgetsBinding.instance.endOfFrame;
      final image =
          await (_boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final temporary = await getTemporaryDirectory();
      final file = File(
        '${temporary.path}/cover-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.pop(context, file.path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not crop this image. Try another photo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crop cover')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pinch to zoom. Drag to frame the cover.'),
              const SizedBox(height: 20),
              RepaintBoundary(
                key: _boundary,
                child: SizedBox(
                  width: 240,
                  height: 360,
                  child: ClipRect(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Image.file(
                        File(widget.path),
                        width: 240,
                        height: 360,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) Text(_error!),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Use cover'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

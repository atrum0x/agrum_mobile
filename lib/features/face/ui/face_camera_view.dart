import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// The live camera, cropped to fill its box, with a darkened backdrop and an oval to put the face in.
class FaceCameraView extends StatelessWidget {
  const FaceCameraView({super.key, required this.controller, required this.borderColor});

  final CameraController controller;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              double cameraAspectRatio = controller.value.aspectRatio;
              if (cameraAspectRatio <= 0) cameraAspectRatio = 1.0;
              if (MediaQuery.of(context).orientation == Orientation.portrait) {
                cameraAspectRatio = 1 / cameraAspectRatio;
              }
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(width: 1000, height: 1000 / cameraAspectRatio, child: CameraPreview(controller)),
                ),
              );
            },
          ),
        ),
        IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _FaceOvalPainter(borderColor))),
      ],
    );
  }
}

class _FaceOvalPainter extends CustomPainter {
  _FaceOvalPainter(this.borderColor);

  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 55% of width matches the min/max face width ratios; faces are ~1.35 times taller than wide
    final ovalWidth = size.width * 0.55;
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: ovalWidth,
      height: ovalWidth * 1.35,
    );
    final backdrop = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(ovalRect),
    );
    canvas.drawPath(backdrop, Paint()..color = const Color(0x88000000));
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceOvalPainter oldDelegate) => oldDelegate.borderColor != borderColor;
}

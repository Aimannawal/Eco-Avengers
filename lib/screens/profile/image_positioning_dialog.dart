import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

/// Dialog for positioning and cropping profile images with circular crop overlay
class ImagePositioningDialog extends StatefulWidget {
  final File imageFile;

  const ImagePositioningDialog({
    super.key,
    required this.imageFile,
  });

  @override
  State<ImagePositioningDialog> createState() => _ImagePositioningDialogState();
}

class _ImagePositioningDialogState extends State<ImagePositioningDialog> {
  final TransformationController _controller = TransformationController();
  bool _isProcessing = false;
  ui.Image? _uiImage;
  double _imageAspectRatio = 1.0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _uiImage?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _uiImage = frame.image;
      _imageAspectRatio = frame.image.width / frame.image.height;
    });
  }

  Future<File?> _cropAndSave() async {
    setState(() => _isProcessing = true);

    try {
      // Load original image using image package
      final bytes = await widget.imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

      // Get transformation matrix values
      final matrix = _controller.value;
      final scale = matrix.getMaxScaleOnAxis();
      final translateX = matrix.getTranslation().x;
      final translateY = matrix.getTranslation().y;

      // Get widget and crop dimensions
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return null;
      
      final screenWidth = renderBox.size.width;
      final screenHeight = renderBox.size.height;
      final cropSize = 280.0;
      final cropRadius = cropSize / 2;

      // Calculate how BoxFit.contain positions the image initially
      final screenAspect = screenWidth / screenHeight;
      double initialImageWidth, initialImageHeight;
      double imageOffsetX, imageOffsetY;

      if (_imageAspectRatio > screenAspect) {
        // Image is wider - fit by width
        initialImageWidth = screenWidth;
        initialImageHeight = screenWidth / _imageAspectRatio;
        imageOffsetX = 0;
        imageOffsetY = (screenHeight - initialImageHeight) / 2;
      } else {
        // Image is taller or same - fit by height
        initialImageHeight = screenHeight;
        initialImageWidth = screenHeight * _imageAspectRatio;
        imageOffsetX = (screenWidth - initialImageWidth) / 2;
        imageOffsetY = 0;
      }

      // Apply transformation to initial image bounds
      final transformedImageWidth = initialImageWidth * scale;
      final transformedImageHeight = initialImageHeight * scale;
      final transformedImageX = imageOffsetX * scale + translateX;
      final transformedImageY = imageOffsetY * scale + translateY;

      // Calculate crop circle position in screen coordinates
      final cropCenterX = screenWidth / 2;
      final cropCenterY = screenHeight / 2;
      final cropLeft = cropCenterX - cropRadius;
      final cropTop = cropCenterY - cropRadius;

      // Convert crop position from screen to image coordinates
      final cropLeftInImage = (cropLeft - transformedImageX) / transformedImageWidth * originalImage.width;
      final cropTopInImage = (cropTop - transformedImageY) / transformedImageHeight * originalImage.height;
      final cropSizeInImage = (cropSize / transformedImageWidth * originalImage.width).toInt();

      // Ensure crop area is within bounds
      final left = cropLeftInImage.clamp(0, originalImage.width - cropSizeInImage).toInt();
      final top = cropTopInImage.clamp(0, originalImage.height - cropSizeInImage).toInt();
      final size = cropSizeInImage.clamp(1, originalImage.width.toDouble()).toInt();

      // Crop to square
      final cropped = img.copyCrop(
        originalImage,
        x: left,
        y: top,
        width: size,
        height: size,
      );

      // Resize to 400x400 for profile use
      final resized = img.copyResize(cropped, width: 400, height: 400);

      // Apply circular mask
      final circular = _makeCircular(resized);

      // Save to temp file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(img.encodePng(circular));

      return tempFile;
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return null;
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  img.Image _makeCircular(img.Image source) {
    final size = source.width;
    final center = size / 2;
    final radius = size / 2;

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = x - center;
        final dy = y - center;
        final distance = (dx * dx + dy * dy).toDouble();
        
        if (distance > radius * radius) {
          source.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        }
      }
    }
    return source;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        children: [
          // Image viewer with pan/zoom
          if (_uiImage != null)
            InteractiveViewer(
              transformationController: _controller,
              minScale: 0.5,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              child: Center(
                child: Image.file(
                  widget.imageFile,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          
          // Proper overlay: bright inside circle, subtle dark outside
          IgnorePointer(
            child: CustomPaint(
              painter: _OverlayPainter(),
              child: Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Container(
                      color: Colors.transparent,
                      child: CustomPaint(
                        painter: _GridPainter(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Professional instructions with gesture icons
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pan_tool_rounded, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Geser & Zoom',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.zoom_out_map_rounded, color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ),
          ),

          // Action buttons
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  _buildActionButton(
                    onTap: _isProcessing ? null : () => Navigator.of(context).pop(null),
                    icon: Icons.close_rounded,
                    label: 'Batal',
                    color: const Color(0xFFEB5757),
                  ),
                  
                  // Confirm button
                  _buildActionButton(
                    onTap: _isProcessing ? null : () async {
                      final cropped = await _cropAndSave();
                      if (mounted) {
                        Navigator.of(context).pop(cropped);
                      }
                    },
                    icon: _isProcessing ? Icons.hourglass_empty_rounded : Icons.check_rounded,
                    label: _isProcessing ? 'Proses...' : 'Konfirmasi',
                    color: const Color(0xFF4CAF50),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onTap,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey : color,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for drawing alignment grid inside crop circle
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw rule of thirds grid lines
    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;

    // Vertical lines
    canvas.drawLine(
      Offset(thirdWidth, 0),
      Offset(thirdWidth, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(thirdWidth * 2, 0),
      Offset(thirdWidth * 2, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, thirdHeight),
      Offset(size.width, thirdHeight),
      paint,
    );
    canvas.drawLine(
      Offset(0, thirdHeight * 2),
      Offset(size.width, thirdHeight * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for overlay that darkens area outside crop circle only
class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.2) // Very light darkness outside
      ..style = PaintingStyle.fill;

    // Create path that fills everything EXCEPT the circle (evenOdd rule)
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: 140, // Half of 280px crop size
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'dart:math' as math;

class GmodLoadingScreen extends StatefulWidget {
  final double progress;
  final String status;

  const GmodLoadingScreen({
    super.key,
    required this.progress,
    required this.status,
  });

  @override
  State<GmodLoadingScreen> createState() => _GmodLoadingScreenState();
}

class _GmodLoadingScreenState extends State<GmodLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101216),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF171B21),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A303A)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              const Text(
                'MRO ENGINE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD9DEE7),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 34),

              // Rotating loader icon
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * math.pi,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFD9DEE7),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: CustomPaint(painter: _LoadingIconPainter()),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Status text
              Text(
                widget.status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9DA6B5),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 18),

              // Progress bar container
              Container(
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D222B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A303A), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    children: [
                      // Progress fill
                      FractionallySizedBox(
                        widthFactor: widget.progress.clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9DEE7),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Percentage text
                      Center(
                        child: Text(
                          '${(widget.progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: widget.progress > 0.5
                                ? const Color(0xFF101216)
                                : const Color(0xFF9DA6B5),
                            letterSpacing: 0.8,
                            shadows: widget.progress > 0.5
                                ? [
                                    const Shadow(
                                      color: Color(0x80000000),
                                      blurRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Additional info text
              Text(
                'Please wait while we load the MRO database',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFF8A94A4),
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD9DEE7)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw segments (like a gear)
    for (var i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      final x = center.dx + radius * 0.6 * math.cos(angle);
      final y = center.dy + radius * 0.6 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), radius * 0.15, paint);
    }

    // Draw center circle
    canvas.drawCircle(center, radius * 0.25, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

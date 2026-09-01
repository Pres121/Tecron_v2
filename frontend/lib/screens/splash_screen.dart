import "dart:math" as math;

import "package:flutter/material.dart";

import "../services/app_state.dart";
import "auth_screen.dart";
import "dashboard_screen.dart";
import "../theme/app_theme.dart";

/// Premium splash screen with animated background, hero illustration,
/// and Apple/Tesla-inspired design language.
class SplashScreen extends StatefulWidget {
  final AppState appState;

  const SplashScreen({super.key, required this.appState});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _particleController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  late final Animation<double> _logoFade;

  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Main animation controller for content
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _fadeIn = CurvedAnimation(parent: _mainController, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutCubic),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Particle animation controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Initialize particles
    _initParticles();

    // Check if already authenticated (handles Web redirect landing at root)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuthStatus());
  }

  void _checkAuthStatus() {
    if (!mounted) return;
    if (widget.appState.isAuthenticated) {
      debugPrint("[SplashScreen] User authenticated, auto-navigating to dashboard...");
      _navigateToDashboard();
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: DashboardScreen(appState: widget.appState),
          );
        },
      ),
    );
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < 20; i++) {
      _particles.add(Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2 + 1,
        speed: _random.nextDouble() * 0.5 + 0.2,
        opacity: _random.nextDouble() * 0.5 + 0.2,
      ));
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: AuthScreen(appState: widget.appState),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B0F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated background layers
          _buildAnimatedBackground(),

          // Floating particles
          _buildParticles(),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  // Logo section with fade-in
                  FadeTransition(
                    opacity: _logoFade,
                    child: _buildLogo(),
                  ),

                  const SizedBox(height: 20),

                  // Hero illustration with floating animation
          Expanded(
            child: _buildHeroIllustration(),
          ),

                  const SizedBox(height: 24),

                  // Bottom content with slide-up animation
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (context, child) => Opacity(
                      opacity: _fadeIn.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideUp.value),
                        child: child,
                      ),
                    ),
                    child: _buildBottomContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Base dark background
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.3),
              radius: 1.2,
              colors: [
                Color(0xFF0F1419),
                Color(0xFF090B0F),
              ],
            ),
          ),
        ),

        // Primary glowing orb (top center)
        AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            return Align(
              alignment: const Alignment(0.0, -0.35),
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF22C55E).withValues(alpha: 0.25),
                      const Color(0xFF22C55E).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            );
          },
        ),

        // Secondary accent orb (bottom right)
        AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            return Align(
              alignment: const Alignment(0.7, 0.6),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF34D399).withValues(alpha: 0.15),
                      const Color(0xFF34D399).withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            );
          },
        ),

        // Neural network lines (subtle)
        CustomPaint(
          size: Size.infinite,
          painter: NeuralNetworkPainter(),
        ),
      ],
    );
  }

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: ParticlesPainter(
            particles: _particles,
            progress: _particleController.value,
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        // Glassmorphism logo container
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFF34D399)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.bolt_rounded,
            color: AppColors.textPrimary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          "TECRON",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
            color: AppColors.textPrimary.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroIllustration() {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFF22C55E).withValues(alpha: 0.15),
              Colors.transparent,
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer rotating ring
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _particleController.value * 2 * math.pi,
                  child: CustomPaint(
                    size: const Size(240, 240),
                    painter: ChargingRingPainter(
                      progress: _particleController.value,
                    ),
                  ),
                );
              },
            ),

            // Inner glowing core
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF22C55E).withValues(alpha: 0.3),
                    const Color(0xFF22C55E).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),

            // Central battery icon
            Icon(
              Icons.battery_charging_full_rounded,
              size: 64,
              color: AppColors.textPrimary.withValues(alpha: 0.95),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headline
        const Text(
          "Charge Smarter.\nPowered by Intelligence.",
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.8,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 16),

        // Subtitle
        const Text(
          "Predict your phone's maximum charging power using verified device data and intelligent AI estimation.",
                        style: TextStyle(
                            fontSize: 14.5,
                            height: 1.6,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.2,
                          ),
        ),

        const SizedBox(height: 24),

        // Feature chips
        _buildFeatureChips(),

        const SizedBox(height: 28),

        // CTA Button
        _buildCTAButton(),

        const SizedBox(height: 24),

        // Page indicator
        _buildPageIndicator(),
      ],
    );
  }

  Widget _buildFeatureChips() {
    final features = [
      {"icon": Icons.bolt_rounded, "label": "Instant Watt Prediction"},
      {"icon": Icons.shield_rounded, "label": "Battery Protection"},
      {"icon": Icons.phone_iphone_rounded, "label": "10,000+ Devices"},
    ];

    return Row(
      children: [
        for (int i = 0; i < features.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _FeatureChip(
              icon: features[i]["icon"] as IconData,
              label: features[i]["label"] as String,
              delay: i * 100,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCTAButton() {
    return GestureDetector(
      onTapDown: (_) => _mainController.animateTo(0.95, duration: const Duration(milliseconds: 100)),
      onTapUp: (_) => _mainController.animateTo(1.0, duration: const Duration(milliseconds: 100)),
      onTapCancel: () => _mainController.animateTo(1.0, duration: const Duration(milliseconds: 100)),
      child: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return Transform.scale(
            scale: _mainController.value,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF34D399)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _navigateToAuth,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Start Charging Smarter",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageIndicator() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PageDot(isActive: true),
        SizedBox(width: 8),
        _PageDot(isActive: false),
        SizedBox(width: 8),
        _PageDot(isActive: false),
      ],
    );
  }
}

/// Feature chip with glassmorphism effect
class _FeatureChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final int delay;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.delay,
  });

  @override
  State<_FeatureChip> createState() => _FeatureChipState();
}

class _FeatureChipState extends State<_FeatureChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideUp = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Staggered animation
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeIn.value,
          child: Transform.translate(
            offset: Offset(0, _slideUp.value),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D23).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              size: 16,
              color: const Color(0xFF22C55E),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page indicator dot
class _PageDot extends StatelessWidget {
  final bool isActive;

  const _PageDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF22C55E) : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Particle model for background animation
class Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

/// Custom painter for floating particles
class ParticlesPainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  ParticlesPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      // Animate particle upward
      final animatedY = (particle.y - progress * particle.speed) % 1.0;
      final x = particle.x * size.width;
      final y = animatedY * size.height;

      // Fade based on position
      final fadeOpacity = animatedY < 0.1 ? animatedY * 10 : 1.0;

      paint.color = const Color(0xFF22C55E).withValues(alpha: particle.opacity * fadeOpacity);

      canvas.drawCircle(Offset(x, y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom painter for neural network lines
class NeuralNetworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.1);

    final random = math.Random(42);
    final points = <Offset>[];

    // Generate random points
    for (int i = 0; i < 15; i++) {
      points.add(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
      );
    }

    // Draw connections
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final distance = (points[i] - points[j]).distance;
        if (distance < size.width * 0.3) {
          final opacity = (1 - distance / (size.width * 0.3)) * 0.15;
          paint.color = const Color(0xFF22C55E).withValues(alpha: opacity);
          canvas.drawLine(points[i], points[j], paint);
        }
      }
    }

    // Draw nodes
    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (var point in points) {
      nodePaint.color = const Color(0xFF22C55E).withValues(alpha: 0.2);
      canvas.drawCircle(point, 2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for animated charging ring
class ChargingRingPainter extends CustomPainter {
  final double progress;

  ChargingRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // Outer ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.3);

    canvas.drawCircle(center, radius, ringPaint);

    // Animated arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = const LinearGradient(
        colors: [Color(0xFF22C55E), Color(0xFF34D399)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // Glowing dot at arc end
    final dotX = center.dx + radius * math.cos(startAngle + sweepAngle);
    final dotY = center.dy + radius * math.sin(startAngle + sweepAngle);

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF34D399)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

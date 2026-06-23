// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/dependency_providers.dart';
import '../../core/themes/colors/colors.semantic.dart';

class StatusBadge extends ConsumerStatefulWidget {
  const StatusBadge({super.key});

  @override
  ConsumerState<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends ConsumerState<StatusBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar el estado reactivo del servidor
    final status = ref.watch(serverStatusProvider);
    final isActive = status == ServerStatus.active;

    if (isActive) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
    }

    final semanticColors = Theme.of(context).extension<CmpSemanticColor>();
    final badgeColor = isActive
        ? (semanticColors?.positiveLabel ?? const Color(0xFF10B981))
        : (semanticColors?.neutralLabel ?? Colors.grey.shade500);
    final badgeLabel = isActive ? 'ACTIVO' : 'INACTIVO';

    return FBadge(
      variant: isActive ? FBadgeVariant.outline : FBadgeVariant.secondary,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Opacity(
                opacity: isActive ? _animation.value : 1.0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: badgeColor,
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            badgeLabel,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size;
  final bool isDark;
  final double borderWidth;
  final double? fontSize;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.initials = 'RD',
    this.size = 44,
    this.isDark = true,
    this.borderWidth = 1.5,
    this.fontSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveFontSize = fontSize ?? (size * 0.36);
    final displayInitials = initials.trim().isNotEmpty ? initials.trim() : 'RD';

    Widget fallbackWidget = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          displayInitials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: effectiveFontSize,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );

    Widget avatarContent;
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      avatarContent = ClipOval(
        child: Image.network(
          imageUrl!.trim(),
          key: ValueKey(imageUrl!.trim()),
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallbackWidget;
          },
          errorBuilder: (context, error, stackTrace) {
            return fallbackWidget;
          },
        ),
      );
    } else {
      avatarContent = fallbackWidget;
    }

    Widget container = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.35 : 0.85),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: avatarContent,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}

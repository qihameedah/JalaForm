// lib/widgets/animated_card.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double elevation;
  final double borderRadius;
  final bool animate;
  final Duration delay;
  final Duration duration;
  final EdgeInsetsGeometry margin;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.elevation = 0,
    this.borderRadius = 16,
    this.animate = true,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 350),
    this.margin = EdgeInsets.zero,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    if (widget.animate) {
      Future.delayed(widget.delay, () {
        if (mounted) {
          setState(() {
            _isVisible = true;
          });
          _controller.forward();
        }
      });
    } else {
      _isVisible = true;
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedVisibility(
      visible: _isVisible,
      duration: widget.duration,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            margin: widget.margin,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.color ?? Colors.white,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    boxShadow: widget.elevation > 0
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: widget.elevation * 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: InkWell(
                      onTap: widget.onTap,
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      splashFactory: InkRipple.splashFactory,
                      highlightColor: Colors.grey.withOpacity(0.05),
                      splashColor: Colors.grey.withOpacity(0.05),
                      child: Padding(
                        padding: widget.padding,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

// A button that animates on hover/tap
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final double height;
  final double width;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isLoading;

  const AnimatedButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color,
    this.textColor,
    this.height = 50,
    this.width = double.infinity, // This is causing the problem
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.isLoading = false,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = widget.color ?? theme.primaryColor;
    final textColor = widget.textColor ?? Colors.white;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      onTap: widget.isLoading ? null : widget.onPressed,
      child: MouseRegion(
        onEnter: (_) {
          setState(() {
            _isHovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            _isHovered = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.height,
          width: widget.width, // This will now be null when not specified
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.isLoading
                ? buttonColor.withOpacity(0.7)
                : _isPressed
                    ? buttonColor.withOpacity(0.8)
                    : _isHovered
                        ? buttonColor.withOpacity(0.9)
                        : buttonColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _isHovered && !_isPressed && !widget.isLoading
                ? [
                    BoxShadow(
                      color: buttonColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: buttonColor.withAlpha(51), // 0.2 * 255 ≈ 51
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
            border: Border.all(
              color: buttonColor.withAlpha(26), // 0.1 * 255 ≈ 26
              width: 1,
            ),
          ),
          transform: _isPressed
              ? (Matrix4.identity()..scale(0.98))
              : _isHovered
                  ? (Matrix4.identity()..scale(1.02))
                  : Matrix4.identity(),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                : DefaultTextStyle(
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    child: widget.child,
                  ),
          ),
        ),
      ),
    );
  }
}

// Custom loading indicator with animation
class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final String? message;

  const LoadingIndicator({
    super.key,
    this.size = 40,
    this.color,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final loadingColor = color ?? Theme.of(context).primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(loadingColor),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}

// Form item container with animation
class AnimatedFormItem extends StatelessWidget {
  final Widget child;
  final String label;
  final String? helperText;
  final bool isRequired;
  final Animation<double> animation;

  const AnimatedFormItem({
    super.key,
    required this.child,
    required this.label,
    this.helperText,
    this.isRequired = false,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return FadeSlideTransition(
      animation: animation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
          if (helperText != null) ...[
            const SizedBox(height: 4),
            Text(
              helperText!,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
          const SizedBox(height: 8),
          child,
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

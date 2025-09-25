// // lib/widgets/enhanced_ui_components.dart

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'dart:math' as math;
// import '../theme/app_theme.dart';

// // Enhanced Button Components
// class EnhancedButton extends StatefulWidget {
//   final String text;
//   final VoidCallback? onPressed;
//   final IconData? icon;
//   final ButtonStyle style;
//   final bool isLoading;
//   final bool isFullWidth;
//   final ButtonSize size;

//   const EnhancedButton({
//     super.key,
//     required this.text,
//     this.onPressed,
//     this.icon,
//     this.style = ButtonStyle.primary,
//     this.isLoading = false,
//     this.isFullWidth = false,
//     this.size = ButtonSize.medium,
//   });

//   @override
//   State<EnhancedButton> createState() => _EnhancedButtonState();
// }

// class _EnhancedButtonState extends State<EnhancedButton>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _scaleAnimation;
//   late Animation<double> _rotationAnimation;
//   bool _isPressed = false;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: AppTheme.fastAnimation,
//       vsync: this,
//     );

//     _scaleAnimation = Tween<double>(
//       begin: 1.0,
//       end: 0.95,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: AppTheme.easeInOutCurve,
//     ));

//     _rotationAnimation = Tween<double>(
//       begin: 0.0,
//       end: 2.0,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.linear,
//     ));
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   ButtonStyle get _buttonStyle => widget.style;
//   ButtonSize get _buttonSize => widget.size;

//   Color get _backgroundColor {
//     switch (_buttonStyle) {
//       case ButtonStyle.primary:
//         return AppTheme.primaryColor;
//       case ButtonStyle.secondary:
//         return AppTheme.accentColor;
//       case ButtonStyle.success:
//         return AppTheme.successColor;
//       case ButtonStyle.warning:
//         return AppTheme.warningColor;
//       case ButtonStyle.error:
//         return AppTheme.errorColor;
//       case ButtonStyle.outline:
//         return Colors.transparent;
//       case ButtonStyle.ghost:
//         return Colors.transparent;
//     }
//   }

//   Color get _foregroundColor {
//     switch (_buttonStyle) {
//       case ButtonStyle.outline:
//       case ButtonStyle.ghost:
//         return AppTheme.primaryColor;
//       default:
//         return Colors.white;
//     }
//   }

//   EdgeInsets get _padding {
//     switch (_buttonSize) {
//       case ButtonSize.small:
//         return const EdgeInsets.symmetric(
//           horizontal: AppTheme.spacing3,
//           vertical: AppTheme.spacing2,
//         );
//       case ButtonSize.medium:
//         return const EdgeInsets.symmetric(
//           horizontal: AppTheme.spacing4,
//           vertical: AppTheme.spacing3,
//         );
//       case ButtonSize.large:
//         return const EdgeInsets.symmetric(
//           horizontal: AppTheme.spacing6,
//           vertical: AppTheme.spacing4,
//         );
//     }
//   }

//   double get _fontSize {
//     switch (_buttonSize) {
//       case ButtonSize.small:
//         return 12;
//       case ButtonSize.medium:
//         return 14;
//       case ButtonSize.large:
//         return 16;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     Widget buttonChild = Row(
//       mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         if (widget.isLoading)
//           AnimatedBuilder(
//             animation: _rotationAnimation,
//             builder: (context, child) {
//               return RotationTransition(
//                 turns: _rotationAnimation,
//                 child: Icon(
//                   Icons.refresh_rounded,
//                   color: _foregroundColor,
//                   size: _fontSize + 2,
//                 ),
//               );
//             },
//           )
//         else if (widget.icon != null)
//           Icon(
//             widget.icon!,
//             color: _foregroundColor,
//             size: _fontSize + 2,
//           ),
//         if ((widget.icon != null || widget.isLoading) && widget.text.isNotEmpty)
//           const SizedBox(width: AppTheme.spacing2),
//         if (widget.text.isNotEmpty)
//           Text(
//             widget.text,
//             style: TextStyle(
//               color: _foregroundColor,
//               fontSize: _fontSize,
//               fontWeight: FontWeight.w700,
//               letterSpacing: 0.2,
//             ),
//           ),
//       ],
//     );

//     return AnimatedBuilder(
//       animation: _scaleAnimation,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: _scaleAnimation.value,
//           child: GestureDetector(
//             onTapDown: widget.onPressed != null && !widget.isLoading
//                 ? (_) {
//                     setState(() => _isPressed = true);
//                     _animationController.forward();
//                     HapticFeedback.selectionClick();
//                   }
//                 : null,
//             onTapUp: widget.onPressed != null && !widget.isLoading
//                 ? (_) {
//                     setState(() => _isPressed = false);
//                     _animationController.reverse();
//                     widget.onPressed?.call();
//                   }
//                 : null,
//             onTapCancel: () {
//               setState(() => _isPressed = false);
//               _animationController.reverse();
//             },
//             child: Container(
//               width: widget.isFullWidth ? double.infinity : null,
//               padding: _padding,
//               decoration: BoxDecoration(
//                 gradient: _buttonStyle == ButtonStyle.primary ||
//                         _buttonStyle == ButtonStyle.secondary
//                     ? (_buttonStyle == ButtonStyle.primary
//                         ? AppTheme.primaryGradient
//                         : AppTheme.accentGradient)
//                     : null,
//                 color: _buttonStyle != ButtonStyle.primary &&
//                         _buttonStyle != ButtonStyle.secondary
//                     ? _backgroundColor
//                     : null,
//                 borderRadius: BorderRadius.circular(AppTheme.radiusLg),
//                 border: _buttonStyle == ButtonStyle.outline
//                     ? Border.all(
//                         color: AppTheme.primaryColor,
//                         width: 2,
//                       )
//                     : null,
//                 boxShadow: _buttonStyle != ButtonStyle.outline &&
//                         _buttonStyle != ButtonStyle.ghost &&
//                         !widget.isLoading
//                     ? [
//                         BoxShadow(
//                           color: _backgroundColor.withOpacity(0.3),
//                           blurRadius: 8,
//                           offset: const Offset(0, 2),
//                         ),
//                       ]
//                     : [],
//               ),
//               child: widget.isLoading
//                   ? Center(
//                       child: SizedBox(
//                         width: _fontSize + 2,
//                         height: _fontSize + 2,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2,
//                           valueColor:
//                               AlwaysStoppedAnimation<Color>(_foregroundColor),
//                         ),
//                       ),
//                     )
//                   : buttonChild,
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// enum ButtonStyle { primary, secondary, success, warning, error, outline, ghost }

// enum ButtonSize { small, medium, large }

// // Enhanced Card Component
// class EnhancedCard extends StatefulWidget {
//   final Widget child;
//   final EdgeInsets? padding;
//   final Color? backgroundColor;
//   final double? borderRadius;
//   final List<BoxShadow>? boxShadow;
//   final Border? border;
//   final VoidCallback? onTap;
//   final bool isInteractive;
//   final bool showHoverEffect;

//   const EnhancedCard({
//     super.key,
//     required this.child,
//     this.padding,
//     this.backgroundColor,
//     this.borderRadius,
//     this.boxShadow,
//     this.border,
//     this.onTap,
//     this.isInteractive = false,
//     this.showHoverEffect = true,
//   });

//   @override
//   State<EnhancedCard> createState() => _EnhancedCardState();
// }

// class _EnhancedCardState extends State<EnhancedCard>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _scaleAnimation;
//   late Animation<double> _elevationAnimation;
//   bool _isHovered = false;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: AppTheme.defaultAnimation,
//       vsync: this,
//     );

//     _scaleAnimation = Tween<double>(
//       begin: 1.0,
//       end: 1.02,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: AppTheme.easeInOutCurve,
//     ));

//     _elevationAnimation = Tween<double>(
//       begin: 1.0,
//       end: 1.5,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: AppTheme.easeInOutCurve,
//     ));
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MouseRegion(
//       onEnter: widget.showHoverEffect &&
//               (widget.isInteractive || widget.onTap != null)
//           ? (_) {
//               setState(() => _isHovered = true);
//               _animationController.forward();
//             }
//           : null,
//       onExit: widget.showHoverEffect &&
//               (widget.isInteractive || widget.onTap != null)
//           ? (_) {
//               setState(() => _isHovered = false);
//               _animationController.reverse();
//             }
//           : null,
//       child: AnimatedBuilder(
//         animation: _animationController,
//         builder: (context, child) {
//           return Transform.scale(
//             scale: _scaleAnimation.value,
//             child: Container(
//               padding:
//                   widget.padding ?? const EdgeInsets.all(AppTheme.spacing4),
//               decoration: BoxDecoration(
//                 color: widget.backgroundColor ?? AppTheme.surfaceColor,
//                 borderRadius: BorderRadius.circular(
//                   widget.borderRadius ?? AppTheme.radiusXl,
//                 ),
//                 border: widget.border ??
//                     Border.all(
//                       color: AppTheme.neutral200,
//                       width: 1,
//                     ),
//                 boxShadow: widget.boxShadow ??
//                     [
//                       for (final shadow in AppTheme.mediumShadow)
//                         BoxShadow(
//                           color: shadow.color,
//                           blurRadius:
//                               shadow.blurRadius * _elevationAnimation.value,
//                           offset: shadow.offset * _elevationAnimation.value,
//                           spreadRadius: shadow.spreadRadius,
//                         ),
//                     ],
//               ),
//               child: Material(
//                 color: Colors.transparent,
//                 child: widget.onTap != null
//                     ? InkWell(
//                         onTap: widget.onTap,
//                         borderRadius: BorderRadius.circular(
//                           widget.borderRadius ?? AppTheme.radiusXl,
//                         ),
//                         child: widget.child,
//                       )
//                     : widget.child,
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// // Enhanced Input Field
// class EnhancedTextField extends StatefulWidget {
//   final TextEditingController? controller;
//   final String? label;
//   final String? hint;
//   final IconData? prefixIcon;
//   final IconData? suffixIcon;
//   final VoidCallback? onSuffixPressed;
//   final bool obscureText;
//   final TextInputType? keyboardType;
//   final String? Function(String?)? validator;
//   final Function(String)? onChanged;
//   final Function(String)? onSubmitted;
//   final int maxLines;
//   final bool enabled;
//   final bool readOnly;
//   final FocusNode? focusNode;
//   final InputFieldStyle style;

//   const EnhancedTextField({
//     super.key,
//     this.controller,
//     this.label,
//     this.hint,
//     this.prefixIcon,
//     this.suffixIcon,
//     this.onSuffixPressed,
//     this.obscureText = false,
//     this.keyboardType,
//     this.validator,
//     this.onChanged,
//     this.onSubmitted,
//     this.maxLines = 1,
//     this.enabled = true,
//     this.readOnly = false,
//     this.focusNode,
//     this.style = InputFieldStyle.outlined,
//   });

//   @override
//   State<EnhancedTextField> createState() => _EnhancedTextFieldState();
// }

// class _EnhancedTextFieldState extends State<EnhancedTextField>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _scaleAnimation;
//   late Animation<Color?> _borderColorAnimation;
//   late FocusNode _focusNode;
//   bool _isFocused = false;

//   @override
//   void initState() {
//     super.initState();
//     _focusNode = widget.focusNode ?? FocusNode();

//     _animationController = AnimationController(
//       duration: AppTheme.defaultAnimation,
//       vsync: this,
//     );

//     _scaleAnimation = Tween<double>(
//       begin: 1.0,
//       end: 1.02,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: AppTheme.easeInOutCurve,
//     ));

//     _borderColorAnimation = ColorTween(
//       begin: AppTheme.neutral300,
//       end: AppTheme.primaryColor,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: AppTheme.easeInOutCurve,
//     ));

//     _focusNode.addListener(() {
//       setState(() {
//         _isFocused = _focusNode.hasFocus;
//       });

//       if (_isFocused) {
//         _animationController.forward();
//       } else {
//         _animationController.reverse();
//       }
//     });
//   }

//   @override
//   void dispose() {
//     if (widget.focusNode == null) {
//       _focusNode.dispose();
//     }
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         if (widget.label != null) ...[
//           Padding(
//             padding: const EdgeInsets.only(bottom: AppTheme.spacing2),
//             child: Text(
//               widget.label!,
//               style: Theme.of(context).textTheme.labelLarge?.copyWith(
//                     fontWeight: FontWeight.w600,
//                     color: _isFocused
//                         ? AppTheme.primaryColor
//                         : AppTheme.textSecondaryColor,
//                   ),
//             ),
//           ),
//         ],
//         AnimatedBuilder(
//           animation: _animationController,
//           builder: (context, child) {
//             return Transform.scale(
//               scale: _scaleAnimation.value,
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: widget.style == InputFieldStyle.filled
//                       ? AppTheme.neutral100
//                       : AppTheme.surfaceColor,
//                   borderRadius: BorderRadius.circular(AppTheme.radiusLg),
//                   border: widget.style == InputFieldStyle.outlined
//                       ? Border.all(
//                           color: _borderColorAnimation.value ??
//                               AppTheme.neutral300,
//                           width: _isFocused ? 2 : 1,
//                         )
//                       : null,
//                   boxShadow:
//                       _isFocused && widget.style == InputFieldStyle.outlined
//                           ? [
//                               BoxShadow(
//                                 color: AppTheme.primaryColor.withOpacity(0.1),
//                                 blurRadius: 8,
//                                 offset: const Offset(0, 2),
//                               ),
//                             ]
//                           : widget.style == InputFieldStyle.elevated
//                               ? AppTheme.softShadow
//                               : [],
//                 ),
//                 child: TextFormField(
//                   controller: widget.controller,
//                   focusNode: _focusNode,
//                   obscureText: widget.obscureText,
//                   keyboardType: widget.keyboardType,
//                   validator: widget.validator,
//                   onChanged: widget.onChanged,
//                   onFieldSubmitted: widget.onSubmitted,
//                   maxLines: widget.maxLines,
//                   enabled: widget.enabled,
//                   readOnly: widget.readOnly,
//                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                         fontWeight: FontWeight.w500,
//                       ),
//                   decoration: InputDecoration(
//                     hintText: widget.hint,
//                     hintStyle: TextStyle(
//                       color: AppTheme.textTertiaryColor,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     prefixIcon: widget.prefixIcon != null
//                         ? Padding(
//                             padding: const EdgeInsets.all(AppTheme.spacing4),
//                             child: Icon(
//                               widget.prefixIcon!,
//                               color: _isFocused
//                                   ? AppTheme.primaryColor
//                                   : AppTheme.textTertiaryColor,
//                               size: 20,
//                             ),
//                           )
//                         : null,
//                     suffixIcon: widget.suffixIcon != null
//                         ? IconButton(
//                             onPressed: widget.onSuffixPressed,
//                             icon: Icon(
//                               widget.suffixIcon!,
//                               color: AppTheme.textTertiaryColor,
//                               size: 20,
//                             ),
//                           )
//                         : null,
//                     border: InputBorder.none,
//                     contentPadding: EdgeInsets.symmetric(
//                       horizontal:
//                           widget.prefixIcon == null ? AppTheme.spacing4 : 0,
//                       vertical: widget.maxLines > 1
//                           ? AppTheme.spacing4
//                           : AppTheme.spacing4,
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
// }

// enum InputFieldStyle { outlined, filled, elevated }

// // Enhanced Loading Indicator
// class EnhancedLoadingIndicator extends StatefulWidget {
//   final double size;
//   final Color? color;
//   final LoadingStyle style;
//   final String? message;

//   const EnhancedLoadingIndicator({
//     super.key,
//     this.size = 40,
//     this.color,
//     this.style = LoadingStyle.circular,
//     this.message,
//   });

//   @override
//   State<EnhancedLoadingIndicator> createState() =>
//       _EnhancedLoadingIndicatorState();
// }

// class _EnhancedLoadingIndicatorState extends State<EnhancedLoadingIndicator>
//     with TickerProviderStateMixin {
//   late AnimationController _rotationController;
//   late AnimationController _pulseController;
//   late AnimationController _bounceController;
//   late Animation<double> _rotationAnimation;
//   late Animation<double> _pulseAnimation;
//   late Animation<double> _bounceAnimation;

//   @override
//   void initState() {
//     super.initState();

//     _rotationController = AnimationController(
//       duration: const Duration(milliseconds: 1500),
//       vsync: this,
//     );

//     _pulseController = AnimationController(
//       duration: const Duration(milliseconds: 1000),
//       vsync: this,
//     );

//     _bounceController = AnimationController(
//       duration: const Duration(milliseconds: 1200),
//       vsync: this,
//     );

//     _rotationAnimation = Tween<double>(
//       begin: 0.0,
//       end: 2.0,
//     ).animate(CurvedAnimation(
//       parent: _rotationController,
//       curve: Curves.linear,
//     ));

//     _pulseAnimation = Tween<double>(
//       begin: 0.8,
//       end: 1.2,
//     ).animate(CurvedAnimation(
//       parent: _pulseController,
//       curve: Curves.easeInOut,
//     ));

//     _bounceAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _bounceController,
//       curve: Curves.elasticOut,
//     ));

//     _startAnimations();
//   }

//   void _startAnimations() {
//     switch (widget.style) {
//       case LoadingStyle.circular:
//         _rotationController.repeat();
//         break;
//       case LoadingStyle.pulse:
//         _pulseController.repeat(reverse: true);
//         break;
//       case LoadingStyle.bounce:
//         _bounceController.repeat();
//         break;
//       case LoadingStyle.dots:
//         _rotationController.repeat();
//         break;
//     }
//   }

//   @override
//   void dispose() {
//     _rotationController.dispose();
//     _pulseController.dispose();
//     _bounceController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final color = widget.color ?? AppTheme.primaryColor;

//     Widget loadingWidget;

//     switch (widget.style) {
//       case LoadingStyle.circular:
//         loadingWidget = AnimatedBuilder(
//           animation: _rotationAnimation,
//           builder: (context, child) {
//             return RotationTransition(
//               turns: _rotationAnimation,
//               child: Container(
//                 width: widget.size,
//                 height: widget.size,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   border: Border.all(
//                     color: color.withOpacity(0.2),
//                     width: 3,
//                   ),
//                 ),
//                 child: Stack(
//                   children: [
//                     Positioned(
//                       top: 0,
//                       left: 0,
//                       right: 0,
//                       child: Container(
//                         height: 3,
//                         decoration: BoxDecoration(
//                           color: color,
//                           borderRadius: BorderRadius.circular(1.5),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//         break;

//       case LoadingStyle.pulse:
//         loadingWidget = AnimatedBuilder(
//           animation: _pulseAnimation,
//           builder: (context, child) {
//             return Transform.scale(
//               scale: _pulseAnimation.value,
//               child: Container(
//                 width: widget.size,
//                 height: widget.size,
//                 decoration: BoxDecoration(
//                   color: color,
//                   shape: BoxShape.circle,
//                 ),
//               ),
//             );
//           },
//         );
//         break;

//       case LoadingStyle.bounce:
//         loadingWidget = AnimatedBuilder(
//           animation: _bounceAnimation,
//           builder: (context, child) {
//             return Transform.translate(
//               offset: Offset(0, -10 * _bounceAnimation.value),
//               child: Container(
//                 width: widget.size,
//                 height: widget.size,
//                 decoration: BoxDecoration(
//                   color: color,
//                   shape: BoxShape.circle,
//                 ),
//               ),
//             );
//           },
//         );
//         break;

//       case LoadingStyle.dots:
//         loadingWidget = AnimatedBuilder(
//           animation: _rotationAnimation,
//           builder: (context, child) {
//             return Row(
//               mainAxisSize: MainAxisSize.min,
//               children: List.generate(3, (index) {
//                 final delay = index * 0.3;
//                 final animation = Tween<double>(
//                   begin: 0.0,
//                   end: 1.0,
//                 ).animate(CurvedAnimation(
//                   parent: _rotationController,
//                   curve: Interval(
//                     delay,
//                     (delay + 0.3).clamp(0.0, 1.0),
//                     curve: Curves.easeInOut,
//                   ),
//                 ));

//                 return Container(
//                   margin: EdgeInsets.symmetric(horizontal: widget.size * 0.05),
//                   child: Transform.scale(
//                     scale: 0.5 + (0.5 * animation.value),
//                     child: Container(
//                       width: widget.size * 0.2,
//                       height: widget.size * 0.2,
//                       decoration: BoxDecoration(
//                         color: color.withOpacity(0.5 + (0.5 * animation.value)),
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                   ),
//                 );
//               }),
//             );
//           },
//         );
//         break;
//     }

//     if (widget.message != null) {
//       return Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           loadingWidget,
//           const SizedBox(height: AppTheme.spacing4),
//           Text(
//             widget.message!,
//             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                   color: AppTheme.textSecondaryColor,
//                   fontWeight: FontWeight.w500,
//                 ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       );
//     }

//     return loadingWidget;
//   }
// }

// enum LoadingStyle { circular, pulse, bounce, dots }

// // Enhanced Progress Indicator
// class EnhancedProgressIndicator extends StatefulWidget {
//   final double value;
//   final double height;
//   final Color? backgroundColor;
//   final Gradient? gradient;
//   final String? label;
//   final bool showPercentage;
//   final bool animated;

//   const EnhancedProgressIndicator({
//     super.key,
//     required this.value,
//     this.height = 8,
//     this.backgroundColor,
//     this.gradient,
//     this.label,
//     this.showPercentage = false,
//     this.animated = true,
//   });

//   @override
//   State<EnhancedProgressIndicator> createState() =>
//       _EnhancedProgressIndicatorState();
// }

// class _EnhancedProgressIndicatorState extends State<EnhancedProgressIndicator>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _progressAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: AppTheme.slowAnimation,
//       vsync: this,
//     );

//     _progressAnimation = Tween<double>(
//       begin: 0.0,
//       end: widget.value,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: AppTheme.easeOutCurve,
//     ));

//     if (widget.animated) {
//       _animationController.forward();
//     }
//   }

//   @override
//   void didUpdateWidget(EnhancedProgressIndicator oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.value != widget.value) {
//       _progressAnimation = Tween<double>(
//         begin: oldWidget.value,
//         end: widget.value,
//       ).animate(CurvedAnimation(
//         parent: _animationController,
//         curve: AppTheme.easeOutCurve,
//       ));

//       _animationController.reset();
//       if (widget.animated) {
//         _animationController.forward();
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         if (widget.label != null || widget.showPercentage)
//           Padding(
//             padding: const EdgeInsets.only(bottom: AppTheme.spacing2),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 if (widget.label != null)
//                   Text(
//                     widget.label!,
//                     style: Theme.of(context).textTheme.labelMedium?.copyWith(
//                           fontWeight: FontWeight.w600,
//                         ),
//                   ),
//                 if (widget.showPercentage)
//                   AnimatedBuilder(
//                     animation: widget.animated
//                         ? _progressAnimation
//                         : AlwaysStoppedAnimation(widget.value),
//                     builder: (context, child) {
//                       final value = widget.animated
//                           ? _progressAnimation.value
//                           : widget.value;
//                       return Text(
//                         '${(value * 100).round()}%',
//                         style:
//                             Theme.of(context).textTheme.labelMedium?.copyWith(
//                                   fontWeight: FontWeight.w700,
//                                   color: AppTheme.primaryColor,
//                                 ),
//                       );
//                     },
//                   ),
//               ],
//             ),
//           ),
//         Container(
//           height: widget.height,
//           decoration: BoxDecoration(
//             color: widget.backgroundColor ?? AppTheme.neutral200,
//             borderRadius: BorderRadius.circular(widget.height / 2),
//           ),
//           child: AnimatedBuilder(
//             animation: widget.animated
//                 ? _progressAnimation
//                 : AlwaysStoppedAnimation(widget.value),
//             builder: (context, child) {
//               final value =
//                   widget.animated ? _progressAnimation.value : widget.value;
//               return FractionallySizedBox(
//                 alignment: Alignment.centerLeft,
//                 widthFactor: value.clamp(0.0, 1.0),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     gradient: widget.gradient ?? AppTheme.primaryGradient,
//                     borderRadius: BorderRadius.circular(widget.height / 2),
//                     boxShadow: [
//                       BoxShadow(
//                         color: AppTheme.primaryColor.withOpacity(0.3),
//                         blurRadius: 4,
//                         offset: const Offset(0, 1),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }

// // Enhanced Badge Component
// class EnhancedBadge extends StatelessWidget {
//   final String text;
//   final Color? backgroundColor;
//   final Color? textColor;
//   final BadgeStyle style;
//   final BadgeSize size;
//   final IconData? icon;

//   const EnhancedBadge({
//     super.key,
//     required this.text,
//     this.backgroundColor,
//     this.textColor,
//     this.style = BadgeStyle.filled,
//     this.size = BadgeSize.medium,
//     this.icon,
//   });

//   @override
//   Widget build(BuildContext context) {
//     Color effectiveBackgroundColor;
//     Color effectiveTextColor;

//     switch (style) {
//       case BadgeStyle.filled:
//         effectiveBackgroundColor = backgroundColor ?? AppTheme.primaryColor;
//         effectiveTextColor = textColor ?? Colors.white;
//         break;
//       case BadgeStyle.outlined:
//         effectiveBackgroundColor = Colors.transparent;
//         effectiveTextColor =
//             textColor ?? backgroundColor ?? AppTheme.primaryColor;
//         break;
//       case BadgeStyle.soft:
//         effectiveBackgroundColor =
//             (backgroundColor ?? AppTheme.primaryColor).withOpacity(0.1);
//         effectiveTextColor =
//             textColor ?? backgroundColor ?? AppTheme.primaryColor;
//         break;
//     }

//     EdgeInsets padding;
//     double fontSize;

//     switch (size) {
//       case BadgeSize.small:
//         padding = const EdgeInsets.symmetric(
//             horizontal: AppTheme.spacing2, vertical: 2);
//         fontSize = 10;
//         break;
//       case BadgeSize.medium:
//         padding = const EdgeInsets.symmetric(
//             horizontal: AppTheme.spacing3, vertical: AppTheme.spacing1);
//         fontSize = 12;
//         break;
//       case BadgeSize.large:
//         padding = const EdgeInsets.symmetric(
//             horizontal: AppTheme.spacing4, vertical: AppTheme.spacing2);
//         fontSize = 14;
//         break;
//     }

//     return Container(
//       padding: padding,
//       decoration: BoxDecoration(
//         color: effectiveBackgroundColor,
//         borderRadius: BorderRadius.circular(AppTheme.radiusLg),
//         border: style == BadgeStyle.outlined
//             ? Border.all(
//                 color: effectiveTextColor,
//                 width: 1,
//               )
//             : null,
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           if (icon != null) ...[
//             Icon(
//               icon!,
//               color: effectiveTextColor,
//               size: fontSize + 2,
//             ),
//             const SizedBox(width: 4),
//           ],
//           Text(
//             text,
//             style: TextStyle(
//               color: effectiveTextColor,
//               fontSize: fontSize,
//               fontWeight: FontWeight.w700,
//               letterSpacing: 0.3,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// enum BadgeStyle { filled, outlined, soft }

// enum BadgeSize { small, medium, large }

// // Enhanced Avatar Component
// class EnhancedAvatar extends StatelessWidget {
//   final String? imageUrl;
//   final String? name;
//   final double size;
//   final Color? backgroundColor;
//   final Color? textColor;
//   final VoidCallback? onTap;
//   final bool showOnlineIndicator;
//   final bool isOnline;

//   const EnhancedAvatar({
//     super.key,
//     this.imageUrl,
//     this.name,
//     this.size = 40,
//     this.backgroundColor,
//     this.textColor,
//     this.onTap,
//     this.showOnlineIndicator = false,
//     this.isOnline = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final initials = _getInitials(name ?? 'U');
//     final effectiveBackgroundColor = backgroundColor ?? AppTheme.primaryColor;
//     final effectiveTextColor = textColor ?? Colors.white;

//     Widget avatar = Container(
//       width: size,
//       height: size,
//       decoration: BoxDecoration(
//         color: effectiveBackgroundColor,
//         shape: BoxShape.circle,
//         boxShadow: AppTheme.softShadow,
//       ),
//       child: imageUrl != null
//           ? ClipOval(
//               child: Image.network(
//                 imageUrl!,
//                 width: size,
//                 height: size,
//                 fit: BoxFit.cover,
//                 errorBuilder: (context, error, stackTrace) {
//                   return _buildInitialsAvatar(initials, effectiveTextColor);
//                 },
//               ),
//             )
//           : _buildInitialsAvatar(initials, effectiveTextColor),
//     );

//     if (showOnlineIndicator) {
//       avatar = Stack(
//         children: [
//           avatar,
//           Positioned(
//             right: 0,
//             bottom: 0,
//             child: Container(
//               width: size * 0.25,
//               height: size * 0.25,
//               decoration: BoxDecoration(
//                 color: isOnline ? AppTheme.successColor : AppTheme.neutral400,
//                 shape: BoxShape.circle,
//                 border: Border.all(
//                   color: AppTheme.surfaceColor,
//                   width: 2,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       );
//     }

//     if (onTap != null) {
//       avatar = Material(
//         color: Colors.transparent,
//         shape: const CircleBorder(),
//         child: InkWell(
//           onTap: onTap,
//           customBorder: const CircleBorder(),
//           child: avatar,
//         ),
//       );
//     }

//     return avatar;
//   }

//   Widget _buildInitialsAvatar(String initials, Color textColor) {
//     return Center(
//       child: Text(
//         initials,
//         style: TextStyle(
//           color: textColor,
//           fontSize: size * 0.4,
//           fontWeight: FontWeight.w700,
//         ),
//       ),
//     );
//   }

//   String _getInitials(String name) {
//     final words = name.trim().split(' ');
//     if (words.isEmpty) return 'U';
//     if (words.length == 1) return words[0][0].toUpperCase();
//     return '${words[0][0]}${words[1][0]}'.toUpperCase();
//   }
// }

// // Enhanced Divider Component
// class EnhancedDivider extends StatelessWidget {
//   final String? text;
//   final double thickness;
//   final Color? color;
//   final double indent;
//   final double endIndent;

//   const EnhancedDivider({
//     super.key,
//     this.text,
//     this.thickness = 1,
//     this.color,
//     this.indent = 0,
//     this.endIndent = 0,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final effectiveColor = color ?? AppTheme.neutral300;

//     if (text != null) {
//       return Row(
//         children: [
//           if (indent > 0) SizedBox(width: indent),
//           Expanded(
//             child: Container(
//               height: thickness,
//               color: effectiveColor,
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
//             child: Text(
//               text!,
//               style: Theme.of(context).textTheme.labelMedium?.copyWith(
//                     color: AppTheme.textTertiaryColor,
//                     fontWeight: FontWeight.w600,
//                   ),
//             ),
//           ),
//           Expanded(
//             child: Container(
//               height: thickness,
//               color: effectiveColor,
//             ),
//           ),
//           if (endIndent > 0) SizedBox(width: endIndent),
//         ],
//       );
//     }

//     return Container(
//       height: thickness,
//       margin: EdgeInsets.only(left: indent, right: endIndent),
//       color: effectiveColor,
//     );
//   }
// }

// // Enhanced Tooltip Component
// class EnhancedTooltip extends StatefulWidget {
//   final Widget child;
//   final String message;
//   final TooltipDirection direction;
//   final Color? backgroundColor;
//   final Color? textColor;
//   final double? fontSize;

//   const EnhancedTooltip({
//     super.key,
//     required this.child,
//     required this.message,
//     this.direction = TooltipDirection.top,
//     this.backgroundColor,
//     this.textColor,
//     this.fontSize,
//   });

//   @override
//   State<EnhancedTooltip> createState() => _EnhancedTooltipState();
// }

// class _EnhancedTooltipState extends State<EnhancedTooltip>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _scaleAnimation;
//   late Animation<double> _opacityAnimation;
//   OverlayEntry? _overlayEntry;
//   bool _isVisible = false;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: AppTheme.fastAnimation,
//       vsync: this,
//     );

//     _scaleAnimation = Tween<double>(
//       begin: 0.8,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: AppTheme.easeOutCurve,
//     ));

//     _opacityAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: AppTheme.easeInOutCurve,
//     ));
//   }

//   @override
//   void dispose() {
//     _hideTooltip();
//     _animationController.dispose();
//     super.dispose();
//   }

//   void _showTooltip() {
//     if (_isVisible) return;

//     _isVisible = true;
//     _overlayEntry = _createOverlayEntry();
//     Overlay.of(context).insert(_overlayEntry!);
//     _animationController.forward();

//     // Auto hide after 3 seconds
//     Future.delayed(const Duration(seconds: 3), () {
//       if (_isVisible) _hideTooltip();
//     });
//   }

//   void _hideTooltip() {
//     if (!_isVisible) return;

//     _isVisible = false;
//     _animationController.reverse().then((_) {
//       _overlayEntry?.remove();
//       _overlayEntry = null;
//     });
//   }

//   OverlayEntry _createOverlayEntry() {
//     final renderBox = context.findRenderObject() as RenderBox;
//     final size = renderBox.size;
//     final offset = renderBox.localToGlobal(Offset.zero);

//     return OverlayEntry(
//       builder: (context) => Positioned(
//         left: offset.dx + (size.width / 2) - 75, // Center the tooltip
//         top: widget.direction == TooltipDirection.top
//             ? offset.dy - 50
//             : offset.dy + size.height + 10,
//         child: AnimatedBuilder(
//           animation: _animationController,
//           builder: (context, child) {
//             return Transform.scale(
//               scale: _scaleAnimation.value,
//               child: Opacity(
//                 opacity: _opacityAnimation.value,
//                 child: Material(
//                   color: Colors.transparent,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: AppTheme.spacing3,
//                       vertical: AppTheme.spacing2,
//                     ),
//                     decoration: BoxDecoration(
//                       color: widget.backgroundColor ?? AppTheme.neutral800,
//                       borderRadius: BorderRadius.circular(AppTheme.radiusMd),
//                       boxShadow: AppTheme.mediumShadow,
//                     ),
//                     constraints: const BoxConstraints(maxWidth: 150),
//                     child: Text(
//                       widget.message,
//                       style: TextStyle(
//                         color: widget.textColor ?? Colors.white,
//                         fontSize: widget.fontSize ?? 12,
//                         fontWeight: FontWeight.w500,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: _showTooltip,
//       onLongPress: _showTooltip,
//       child: MouseRegion(
//         onEnter: (_) => _showTooltip(),
//         onExit: (_) => _hideTooltip(),
//         child: widget.child,
//       ),
//     );
//   }
// }

// enum TooltipDirection { top, bottom, left, right }

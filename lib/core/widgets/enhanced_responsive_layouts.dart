// // lib/widgets/enhanced_responsive_layouts.dart

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:jala_form/widgets/enhanced_ui_components.dart';
// import 'dart:math' as math;
// import '../theme/app_theme.dart';

// // Enhanced Responsive Grid
// class EnhancedResponsiveGrid extends StatelessWidget {
//   final List<Widget> children;
//   final double spacing;
//   final double runSpacing;
//   final int? mobileColumns;
//   final int? tabletColumns;
//   final int? desktopColumns;
//   final double? childAspectRatio;
//   final bool shrinkWrap;
//   final ScrollPhysics? physics;

//   const EnhancedResponsiveGrid({
//     super.key,
//     required this.children,
//     this.spacing = AppTheme.spacing4,
//     this.runSpacing = AppTheme.spacing4,
//     this.mobileColumns,
//     this.tabletColumns,
//     this.desktopColumns,
//     this.childAspectRatio,
//     this.shrinkWrap = false,
//     this.physics,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         int columns;

//         if (AppTheme.isDesktop(context)) {
//           columns = desktopColumns ?? 3;
//         } else if (AppTheme.isTablet(context)) {
//           columns = tabletColumns ?? 2;
//         } else {
//           columns = mobileColumns ?? 1;
//         }

//         return GridView.builder(
//           shrinkWrap: shrinkWrap,
//           physics: physics,
//           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: columns,
//             crossAxisSpacing: spacing,
//             mainAxisSpacing: runSpacing,
//             childAspectRatio: childAspectRatio ?? 1.0,
//           ),
//           itemCount: children.length,
//           itemBuilder: (context, index) => children[index],
//         );
//       },
//     );
//   }
// }

// // Enhanced Responsive Row
// class EnhancedResponsiveRow extends StatelessWidget {
//   final List<Widget> children;
//   final MainAxisAlignment mainAxisAlignment;
//   final CrossAxisAlignment crossAxisAlignment;
//   final bool wrapOnMobile;
//   final double spacing;

//   const EnhancedResponsiveRow({
//     super.key,
//     required this.children,
//     this.mainAxisAlignment = MainAxisAlignment.start,
//     this.crossAxisAlignment = CrossAxisAlignment.center,
//     this.wrapOnMobile = true,
//     this.spacing = AppTheme.spacing4,
//   });

//   @override
//   Widget build(BuildContext context) {
//     if (wrapOnMobile && AppTheme.isMobile(context)) {
//       return Column(
//         crossAxisAlignment: crossAxisAlignment == CrossAxisAlignment.center
//             ? CrossAxisAlignment.center
//             : CrossAxisAlignment.start,
//         children: children
//             .expand((child) => [child, SizedBox(height: spacing)])
//             .take(children.length * 2 - 1)
//             .toList(),
//       );
//     }

//     return Row(
//       mainAxisAlignment: mainAxisAlignment,
//       crossAxisAlignment: crossAxisAlignment,
//       children: children
//           .expand((child) => [child, SizedBox(width: spacing)])
//           .take(children.length * 2 - 1)
//           .toList(),
//     );
//   }
// }

// // Enhanced Animated List Item
// class EnhancedAnimatedListItem extends StatefulWidget {
//   final Widget child;
//   final int index;
//   final Duration delay;
//   final Duration duration;
//   final Curve curve;
//   final AnimationType animationType;

//   const EnhancedAnimatedListItem({
//     super.key,
//     required this.child,
//     required this.index,
//     this.delay = const Duration(milliseconds: 100),
//     this.duration = AppTheme.slowAnimation,
//     this.curve = AppTheme.easeOutCurve,
//     this.animationType = AnimationType.slideUp,
//   });

//   @override
//   State<EnhancedAnimatedListItem> createState() =>
//       _EnhancedAnimatedListItemState();
// }

// class _EnhancedAnimatedListItemState extends State<EnhancedAnimatedListItem>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: widget.duration,
//       vsync: this,
//     );

//     _fadeAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: widget.curve,
//     ));

//     switch (widget.animationType) {
//       case AnimationType.slideUp:
//         _slideAnimation = Tween<Offset>(
//           begin: const Offset(0, 0.5),
//           end: Offset.zero,
//         ).animate(CurvedAnimation(
//           parent: _animationController,
//           curve: widget.curve,
//         ));
//         break;
//       case AnimationType.slideDown:
//         _slideAnimation = Tween<Offset>(
//           begin: const Offset(0, -0.5),
//           end: Offset.zero,
//         ).animate(CurvedAnimation(
//           parent: _animationController,
//           curve: widget.curve,
//         ));
//         break;
//       case AnimationType.slideLeft:
//         _slideAnimation = Tween<Offset>(
//           begin: const Offset(0.5, 0),
//           end: Offset.zero,
//         ).animate(CurvedAnimation(
//           parent: _animationController,
//           curve: widget.curve,
//         ));
//         break;
//       case AnimationType.slideRight:
//         _slideAnimation = Tween<Offset>(
//           begin: const Offset(-0.5, 0),
//           end: Offset.zero,
//         ).animate(CurvedAnimation(
//           parent: _animationController,
//           curve: widget.curve,
//         ));
//         break;
//       case AnimationType.scale:
//         _scaleAnimation = Tween<double>(
//           begin: 0.0,
//           end: 1.0,
//         ).animate(CurvedAnimation(
//           parent: _animationController,
//           curve: widget.curve,
//         ));
//         break;
//     }

//     _startAnimation();
//   }

//   void _startAnimation() async {
//     await Future.delayed(widget.delay * widget.index);
//     if (mounted) {
//       _animationController.forward();
//     }
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     switch (widget.animationType) {
//       case AnimationType.slideUp:
//       case AnimationType.slideDown:
//       case AnimationType.slideLeft:
//       case AnimationType.slideRight:
//         return SlideTransition(
//           position: _slideAnimation,
//           child: FadeTransition(
//             opacity: _fadeAnimation,
//             child: widget.child,
//           ),
//         );
//       case AnimationType.scale:
//         return ScaleTransition(
//           scale: _scaleAnimation,
//           child: FadeTransition(
//             opacity: _fadeAnimation,
//             child: widget.child,
//           ),
//         );
//     }
//   }
// }

// enum AnimationType { slideUp, slideDown, slideLeft, slideRight, scale }

// // Enhanced Page Transition
// class EnhancedPageTransition extends PageRouteBuilder {
//   final Widget child;
//   final PageTransitionType transitionType;
//   final Duration duration;
//   final Curve curve;

//   EnhancedPageTransition({
//     required this.child,
//     this.transitionType = PageTransitionType.slideRight,
//     this.duration = AppTheme.defaultAnimation,
//     this.curve = AppTheme.easeInOutCurve,
//   }) : super(
//           pageBuilder: (context, animation, secondaryAnimation) => child,
//           transitionDuration: duration,
//           reverseTransitionDuration: duration,
//           transitionsBuilder: (context, animation, secondaryAnimation, child) {
//             return _buildTransition(
//               child,
//               animation,
//               secondaryAnimation,
//               transitionType,
//               curve,
//             );
//           },
//         );

//   static Widget _buildTransition(
//     Widget child,
//     Animation<double> animation,
//     Animation<double> secondaryAnimation,
//     PageTransitionType type,
//     Curve curve,
//   ) {
//     final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

//     switch (type) {
//       case PageTransitionType.slideRight:
//         return SlideTransition(
//           position: Tween<Offset>(
//             begin: const Offset(1.0, 0.0),
//             end: Offset.zero,
//           ).animate(curvedAnimation),
//           child: child,
//         );
//       case PageTransitionType.slideLeft:
//         return SlideTransition(
//           position: Tween<Offset>(
//             begin: const Offset(-1.0, 0.0),
//             end: Offset.zero,
//           ).animate(curvedAnimation),
//           child: child,
//         );
//       case PageTransitionType.slideUp:
//         return SlideTransition(
//           position: Tween<Offset>(
//             begin: const Offset(0.0, 1.0),
//             end: Offset.zero,
//           ).animate(curvedAnimation),
//           child: child,
//         );
//       case PageTransitionType.slideDown:
//         return SlideTransition(
//           position: Tween<Offset>(
//             begin: const Offset(0.0, -1.0),
//             end: Offset.zero,
//           ).animate(curvedAnimation),
//           child: child,
//         );
//       case PageTransitionType.fade:
//         return FadeTransition(
//           opacity: curvedAnimation,
//           child: child,
//         );
//       case PageTransitionType.scale:
//         return ScaleTransition(
//           scale: Tween<double>(
//             begin: 0.0,
//             end: 1.0,
//           ).animate(curvedAnimation),
//           child: child,
//         );
//       case PageTransitionType.rotation:
//         return RotationTransition(
//           turns: Tween<double>(
//             begin: 0.0,
//             end: 1.0,
//           ).animate(curvedAnimation),
//           child: child,
//         );
//     }
//   }
// }

// enum PageTransitionType {
//   slideRight,
//   slideLeft,
//   slideUp,
//   slideDown,
//   fade,
//   scale,
//   rotation,
// }

// // Enhanced Parallax Effect
// class EnhancedParallaxWidget extends StatefulWidget {
//   final Widget child;
//   final double speed;
//   final Axis direction;

//   const EnhancedParallaxWidget({
//     super.key,
//     required this.child,
//     this.speed = 0.5,
//     this.direction = Axis.vertical,
//   });

//   @override
//   State<EnhancedParallaxWidget> createState() => _EnhancedParallaxWidgetState();
// }

// class _EnhancedParallaxWidgetState extends State<EnhancedParallaxWidget> {
//   final GlobalKey _widgetKey = GlobalKey();
//   double _offset = 0.0;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _updateOffset();
//     });
//   }

//   void _updateOffset() {
//     if (!mounted) return;

//     final RenderBox? renderBox =
//         _widgetKey.currentContext?.findRenderObject() as RenderBox?;
//     if (renderBox != null) {
//       final position = renderBox.localToGlobal(Offset.zero);
//       final screenHeight = MediaQuery.of(context).size.height;
//       final screenWidth = MediaQuery.of(context).size.width;

//       double newOffset;
//       if (widget.direction == Axis.vertical) {
//         newOffset = (position.dy - screenHeight / 2) * widget.speed;
//       } else {
//         newOffset = (position.dx - screenWidth / 2) * widget.speed;
//       }

//       if (newOffset != _offset) {
//         setState(() {
//           _offset = newOffset;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return NotificationListener<ScrollNotification>(
//       onNotification: (notification) {
//         _updateOffset();
//         return false;
//       },
//       child: Transform.translate(
//         key: _widgetKey,
//         offset: widget.direction == Axis.vertical
//             ? Offset(0, _offset)
//             : Offset(_offset, 0),
//         child: widget.child,
//       ),
//     );
//   }
// }

// // Enhanced Pull to Refresh
// class EnhancedPullToRefresh extends StatefulWidget {
//   final Widget child;
//   final Future<void> Function() onRefresh;
//   final Color? color;
//   final double displacement;

//   const EnhancedPullToRefresh({
//     super.key,
//     required this.child,
//     required this.onRefresh,
//     this.color,
//     this.displacement = 40.0,
//   });

//   @override
//   State<EnhancedPullToRefresh> createState() => _EnhancedPullToRefreshState();
// }

// class _EnhancedPullToRefreshState extends State<EnhancedPullToRefresh>
//     with TickerProviderStateMixin {
//   late AnimationController _scaleController;
//   late AnimationController _rotationController;
//   late Animation<double> _scaleAnimation;
//   late Animation<double> _rotationAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _scaleController = AnimationController(
//       duration: AppTheme.defaultAnimation,
//       vsync: this,
//     );
//     _rotationController = AnimationController(
//       duration: const Duration(milliseconds: 1000),
//       vsync: this,
//     );

//     _scaleAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _scaleController,
//       curve: AppTheme.elasticCurve,
//     ));

//     _rotationAnimation = Tween<double>(
//       begin: 0.0,
//       end: 2.0,
//     ).animate(CurvedAnimation(
//       parent: _rotationController,
//       curve: Curves.linear,
//     ));
//   }

//   @override
//   void dispose() {
//     _scaleController.dispose();
//     _rotationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return RefreshIndicator(
//       onRefresh: () async {
//         _scaleController.forward();
//         _rotationController.repeat();
//         HapticFeedback.mediumImpact();

//         try {
//           await widget.onRefresh();
//         } finally {
//           _rotationController.stop();
//           _rotationController.reset();
//           _scaleController.reverse();
//         }
//       },
//       color: widget.color ?? AppTheme.primaryColor,
//       displacement: widget.displacement,
//       child: widget.child,
//     );
//   }
// }

// // Enhanced Swipe to Dismiss
// class EnhancedSwipeToDismiss extends StatefulWidget {
//   final Widget child;
//   final VoidCallback? onDismissed;
//   final VoidCallback? onConfirmDismiss;
//   final Color? backgroundColor;
//   final Widget? dismissIcon;
//   final String? dismissText;
//   final SwipeDirection direction;

//   const EnhancedSwipeToDismiss({
//     super.key,
//     required this.child,
//     this.onDismissed,
//     this.onConfirmDismiss,
//     this.backgroundColor,
//     this.dismissIcon,
//     this.dismissText,
//     this.direction = SwipeDirection.endToStart,
//   });

//   @override
//   State<EnhancedSwipeToDismiss> createState() => _EnhancedSwipeToDismissState();
// }

// class _EnhancedSwipeToDismissState extends State<EnhancedSwipeToDismiss>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _slideAnimation;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: AppTheme.defaultAnimation,
//       vsync: this,
//     );

//     _slideAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: AppTheme.easeInOutCurve,
//     ));

//     _scaleAnimation = Tween<double>(
//       begin: 1.0,
//       end: 0.8,
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
//     return Dismissible(
//       key: UniqueKey(),
//       direction: _getDismissDirection(),
//       confirmDismiss: (_) async {
//         if (widget.onConfirmDismiss != null) {
//           widget.onConfirmDismiss!();
//           return await _showConfirmDialog();
//         }
//         return true;
//       },
//       onDismissed: (_) {
//         HapticFeedback.heavyImpact();
//         widget.onDismissed?.call();
//       },
//       background: _buildDismissBackground(),
//       child: AnimatedBuilder(
//         animation: _animationController,
//         builder: (context, child) {
//           return Transform.scale(
//             scale: _scaleAnimation.value,
//             child: widget.child,
//           );
//         },
//       ),
//     );
//   }

//   DismissDirection _getDismissDirection() {
//     switch (widget.direction) {
//       case SwipeDirection.startToEnd:
//         return DismissDirection.startToEnd;
//       case SwipeDirection.endToStart:
//         return DismissDirection.endToStart;
//       case SwipeDirection.horizontal:
//         return DismissDirection.horizontal;
//       case SwipeDirection.vertical:
//         return DismissDirection.vertical;
//     }
//   }

//   Widget _buildDismissBackground() {
//     return Container(
//       color: widget.backgroundColor ?? AppTheme.errorColor,
//       child: Align(
//         alignment: widget.direction == SwipeDirection.startToEnd
//             ? Alignment.centerLeft
//             : Alignment.centerRight,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing6),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               widget.dismissIcon ??
//                   Icon(
//                     Icons.delete_rounded,
//                     color: Colors.white,
//                     size: 32,
//                   ),
//               if (widget.dismissText != null) ...[
//                 const SizedBox(height: AppTheme.spacing2),
//                 Text(
//                   widget.dismissText!,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Future<bool> _showConfirmDialog() async {
//     return await showDialog<bool>(
//           context: context,
//           builder: (context) => AlertDialog(
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(AppTheme.radius2xl),
//             ),
//             title: const Text('Confirm Delete'),
//             content: const Text('Are you sure you want to delete this item?'),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context, false),
//                 child: const Text('Cancel'),
//               ),
//               ElevatedButton(
//                 onPressed: () => Navigator.pop(context, true),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: AppTheme.errorColor,
//                   foregroundColor: Colors.white,
//                 ),
//                 child: const Text('Delete'),
//               ),
//             ],
//           ),
//         ) ??
//         false;
//   }
// }

// enum SwipeDirection { startToEnd, endToStart, horizontal, vertical }

// // Enhanced Floating Action Button
// class EnhancedFloatingActionButton extends StatefulWidget {
//   final VoidCallback? onPressed;
//   final Widget child;
//   final Color? backgroundColor;
//   final Color? foregroundColor;
//   final double? elevation;
//   final String? tooltip;
//   final bool mini;
//   final FloatingActionButtonLocation? location;

//   const EnhancedFloatingActionButton({
//     super.key,
//     this.onPressed,
//     required this.child,
//     this.backgroundColor,
//     this.foregroundColor,
//     this.elevation,
//     this.tooltip,
//     this.mini = false,
//     this.location,
//   });

//   @override
//   State<EnhancedFloatingActionButton> createState() =>
//       _EnhancedFloatingActionButtonState();
// }

// class _EnhancedFloatingActionButtonState
//     extends State<EnhancedFloatingActionButton>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _scaleAnimation;
//   late Animation<double> _rotationAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: AppTheme.defaultAnimation,
//       vsync: this,
//     );

//     _scaleAnimation = Tween<double>(
//       begin: 1.0,
//       end: 0.9,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: AppTheme.easeInOutCurve,
//     ));

//     _rotationAnimation = Tween<double>(
//       begin: 0.0,
//       end: 0.1,
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
//     return AnimatedBuilder(
//       animation: _animationController,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: _scaleAnimation.value,
//           child: RotationTransition(
//             turns: _rotationAnimation,
//             child: FloatingActionButton(
//               onPressed: widget.onPressed != null
//                   ? () {
//                       _animationController.forward().then((_) {
//                         _animationController.reverse();
//                       });
//                       HapticFeedback.lightImpact();
//                       widget.onPressed!();
//                     }
//                   : null,
//               backgroundColor: widget.backgroundColor ?? AppTheme.primaryColor,
//               foregroundColor: widget.foregroundColor ?? Colors.white,
//               elevation: widget.elevation ?? 6,
//               tooltip: widget.tooltip,
//               mini: widget.mini,
//               child: widget.child,
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// // Enhanced Bottom Sheet
// class EnhancedBottomSheet {
//   static Future<T?> show<T>({
//     required BuildContext context,
//     required Widget child,
//     bool isScrollControlled = true,
//     bool enableDrag = true,
//     bool showDragHandle = true,
//     Color? backgroundColor,
//     double? maxHeight,
//     String? title,
//   }) {
//     return showModalBottomSheet<T>(
//       context: context,
//       isScrollControlled: isScrollControlled,
//       enableDrag: enableDrag,
//       backgroundColor: Colors.transparent,
//       builder: (context) => _EnhancedBottomSheetContent(
//         child: child,
//         backgroundColor: backgroundColor,
//         maxHeight: maxHeight,
//         title: title,
//         showDragHandle: showDragHandle,
//       ),
//     );
//   }
// }

// class _EnhancedBottomSheetContent extends StatefulWidget {
//   final Widget child;
//   final Color? backgroundColor;
//   final double? maxHeight;
//   final String? title;
//   final bool showDragHandle;

//   const _EnhancedBottomSheetContent({
//     required this.child,
//     this.backgroundColor,
//     this.maxHeight,
//     this.title,
//     this.showDragHandle = true,
//   });

//   @override
//   State<_EnhancedBottomSheetContent> createState() =>
//       _EnhancedBottomSheetContentState();
// }

// class _EnhancedBottomSheetContentState
//     extends State<_EnhancedBottomSheetContent>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _slideAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: AppTheme.defaultAnimation,
//       vsync: this,
//     );

//     _slideAnimation = Tween<double>(
//       begin: 1.0,
//       end: 0.0,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: AppTheme.easeOutCurve,
//     ));

//     _animationController.forward();
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenHeight = MediaQuery.of(context).size.height;
//     final maxHeight = widget.maxHeight ?? screenHeight * 0.9;

//     return AnimatedBuilder(
//       animation: _slideAnimation,
//       builder: (context, child) {
//         return Transform.translate(
//           offset: Offset(0, screenHeight * _slideAnimation.value),
//           child: Container(
//             constraints: BoxConstraints(
//               maxHeight: maxHeight,
//             ),
//             margin: const EdgeInsets.only(
//               left: AppTheme.spacing4,
//               right: AppTheme.spacing4,
//               bottom: AppTheme.spacing4,
//             ),
//             decoration: BoxDecoration(
//               color: widget.backgroundColor ?? AppTheme.surfaceColor,
//               borderRadius: BorderRadius.circular(AppTheme.radius2xl),
//               boxShadow: AppTheme.strongShadow,
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 if (widget.showDragHandle) ...[
//                   const SizedBox(height: AppTheme.spacing3),
//                   Container(
//                     width: 40,
//                     height: 4,
//                     decoration: BoxDecoration(
//                       color: AppTheme.neutral300,
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//                 ],
//                 if (widget.title != null) ...[
//                   const SizedBox(height: AppTheme.spacing4),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: AppTheme.spacing6,
//                     ),
//                     child: Text(
//                       widget.title!,
//                       style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                             fontWeight: FontWeight.w700,
//                           ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                   const SizedBox(height: AppTheme.spacing4),
//                   const EnhancedDivider(),
//                 ],
//                 Flexible(
//                   child: widget.child,
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// // Enhanced Context Menu
// class EnhancedContextMenu extends StatefulWidget {
//   final Widget child;
//   final List<ContextMenuItem> menuItems;
//   final Color? backgroundColor;

//   const EnhancedContextMenu({
//     super.key,
//     required this.child,
//     required this.menuItems,
//     this.backgroundColor,
//   });

//   @override
//   State<EnhancedContextMenu> createState() => _EnhancedContextMenuState();
// }

// class _EnhancedContextMenuState extends State<EnhancedContextMenu> {
//   OverlayEntry? _overlayEntry;

//   void _showContextMenu(TapDownDetails details) {
//     _hideContextMenu();

//     _overlayEntry = OverlayEntry(
//       builder: (context) => _ContextMenuOverlay(
//         position: details.globalPosition,
//         menuItems: widget.menuItems,
//         backgroundColor: widget.backgroundColor,
//         onDismiss: _hideContextMenu,
//       ),
//     );

//     Overlay.of(context).insert(_overlayEntry!);
//   }

//   void _hideContextMenu() {
//     _overlayEntry?.remove();
//     _overlayEntry = null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onSecondaryTapDown: _showContextMenu,
//       onLongPressStart: (details) => _showContextMenu(
//         TapDownDetails(globalPosition: details.globalPosition),
//       ),
//       child: widget.child,
//     );
//   }
// }

// class _ContextMenuOverlay extends StatefulWidget {
//   final Offset position;
//   final List<ContextMenuItem> menuItems;
//   final Color? backgroundColor;
//   final VoidCallback onDismiss;

//   const _ContextMenuOverlay({
//     required this.position,
//     required this.menuItems,
//     this.backgroundColor,
//     required this.onDismiss,
//   });

//   @override
//   State<_ContextMenuOverlay> createState() => _ContextMenuOverlayState();
// }

// class _ContextMenuOverlayState extends State<_ContextMenuOverlay>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _scaleAnimation;
//   late Animation<double> _opacityAnimation;

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

//     _animationController.forward();
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: widget.onDismiss,
//       child: Container(
//         color: Colors.transparent,
//         child: Stack(
//           children: [
//             Positioned(
//               left: widget.position.dx,
//               top: widget.position.dy,
//               child: AnimatedBuilder(
//                 animation: _animationController,
//                 builder: (context, child) {
//                   return Transform.scale(
//                     scale: _scaleAnimation.value,
//                     child: Opacity(
//                       opacity: _opacityAnimation.value,
//                       child: Material(
//                         color: Colors.transparent,
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color:
//                                 widget.backgroundColor ?? AppTheme.surfaceColor,
//                             borderRadius:
//                                 BorderRadius.circular(AppTheme.radiusLg),
//                             boxShadow: AppTheme.strongShadow,
//                           ),
//                           child: IntrinsicWidth(
//                             child: Column(
//                               mainAxisSize: MainAxisSize.min,
//                               children: widget.menuItems.map((item) {
//                                 return _ContextMenuItemWidget(
//                                   item: item,
//                                   onTap: () {
//                                     widget.onDismiss();
//                                     item.onPressed();
//                                   },
//                                 );
//                               }).toList(),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _ContextMenuItemWidget extends StatelessWidget {
//   final ContextMenuItem item;
//   final VoidCallback onTap;

//   const _ContextMenuItemWidget({
//     required this.item,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(
//             horizontal: AppTheme.spacing4,
//             vertical: AppTheme.spacing3,
//           ),
//           child: Row(
//             children: [
//               if (item.icon != null) ...[
//                 Icon(
//                   item.icon!,
//                   color: item.color ?? AppTheme.textPrimaryColor,
//                   size: 18,
//                 ),
//                 const SizedBox(width: AppTheme.spacing3),
//               ],
//               Text(
//                 item.title,
//                 style: TextStyle(
//                   color: item.color ?? AppTheme.textPrimaryColor,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class ContextMenuItem {
//   final String title;
//   final IconData? icon;
//   final Color? color;
//   final VoidCallback onPressed;

//   const ContextMenuItem({
//     required this.title,
//     this.icon,
//     this.color,
//     required this.onPressed,
//   });
// }

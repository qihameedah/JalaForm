// // lib/widgets/enhanced_navigation_components.dart

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'dart:math' as math;
// import '../theme/app_theme.dart';

// // Enhanced Tab Bar Component
// class EnhancedTabBar extends StatefulWidget {
//   final List<EnhancedTab> tabs;
//   final int initialIndex;
//   final Function(int)? onTabChanged;
//   final Color? backgroundColor;
//   final Color? indicatorColor;
//   final TabBarStyle style;
//   final bool isScrollable;
//   final EdgeInsets? padding;

//   const EnhancedTabBar({
//     super.key,
//     required this.tabs,
//     this.initialIndex = 0,
//     this.onTabChanged,
//     this.backgroundColor,
//     this.indicatorColor,
//     this.style = TabBarStyle.pills,
//     this.isScrollable = false,
//     this.padding,
//   });

//   @override
//   State<EnhancedTabBar> createState() => _EnhancedTabBarState();
// }

// class _EnhancedTabBarState extends State<EnhancedTabBar>
//     with TickerProviderStateMixin {
//   late AnimationController _animationController;
//   late AnimationController _indicatorController;
//   late Animation<double> _indicatorAnimation;
//   late PageController _pageController;

//   int _currentIndex = 0;
//   double _indicatorPosition = 0.0;
//   double _indicatorWidth = 0.0;

//   @override
//   void initState() {
//     super.initState();
//     _currentIndex = widget.initialIndex;

//     _animationController = AnimationController(
//       duration: AppTheme.defaultAnimation,
//       vsync: this,
//     );

//     _indicatorController = AnimationController(
//       duration: AppTheme.defaultAnimation,
//       vsync: this,
//     );

//     _indicatorAnimation = CurvedAnimation(
//       parent: _indicatorController,
//       curve: AppTheme.easeInOutCurve,
//     );

//     _pageController = PageController(initialPage: widget.initialIndex);

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _updateIndicator();
//     });
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     _indicatorController.dispose();
//     _pageController.dispose();
//     super.dispose();
//   }

//   void _updateIndicator() {
//     if (mounted) {
//       final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
//       if (renderBox != null) {
//         final width = renderBox.size.width;
//         final tabWidth = width / widget.tabs.length;

//         setState(() {
//           _indicatorPosition = _currentIndex * tabWidth;
//           _indicatorWidth = tabWidth;
//         });
//       }
//     }
//   }

//   void _onTabTapped(int index) {
//     if (_currentIndex != index) {
//       setState(() {
//         _currentIndex = index;
//       });

//       _updateIndicator();
//       _indicatorController.forward().then((_) {
//         _indicatorController.reverse();
//       });

//       _pageController.animateToPage(
//         index,
//         duration: AppTheme.defaultAnimation,
//         curve: AppTheme.easeInOutCurve,
//       );

//       widget.onTabChanged?.call(index);
//       HapticFeedback.selectionClick();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         _buildTabBar(),
//         Expanded(
//           child: PageView.builder(
//             controller: _pageController,
//             onPageChanged: (index) {
//               setState(() {
//                 _currentIndex = index;
//               });
//               _updateIndicator();
//               widget.onTabChanged?.call(index);
//             },
//             itemCount: widget.tabs.length,
//             itemBuilder: (context, index) {
//               return widget.tabs[index].content;
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTabBar() {
//     switch (widget.style) {
//       case TabBarStyle.pills:
//         return _buildPillsTabBar();
//       case TabBarStyle.underline:
//         return _buildUnderlineTabBar();
//       case TabBarStyle.segmented:
//         return _buildSegmentedTabBar();
//       case TabBarStyle.floating:
//         return _buildFloatingTabBar();
//     }
//   }

//   Widget _buildPillsTabBar() {
//     return Container(
//       margin: widget.padding ?? const EdgeInsets.all(AppTheme.spacing4),
//       padding: const EdgeInsets.all(AppTheme.spacing1),
//       decoration: BoxDecoration(
//         color: widget.backgroundColor ?? AppTheme.neutral100,
//         borderRadius: BorderRadius.circular(AppTheme.radiusXl),
//         boxShadow: AppTheme.softShadow,
//       ),
//       child: Row(
//         children: List.generate(widget.tabs.length, (index) {
//           final tab = widget.tabs[index];
//           final isSelected = _currentIndex == index;

//           return Expanded(
//             child: GestureDetector(
//               onTap: () => _onTabTapped(index),
//               child: AnimatedContainer(
//                 duration: AppTheme.defaultAnimation,
//                 curve: AppTheme.easeInOutCurve,
//                 padding: const EdgeInsets.symmetric(
//                   vertical: AppTheme.spacing3,
//                   horizontal: AppTheme.spacing4,
//                 ),
//                 decoration: BoxDecoration(
//                   color: isSelected
//                       ? widget.indicatorColor ?? AppTheme.primaryColor
//                       : Colors.transparent,
//                   borderRadius: BorderRadius.circular(AppTheme.radiusXl),
//                   boxShadow: isSelected
//                       ? [
//                           BoxShadow(
//                             color:
//                                 (widget.indicatorColor ?? AppTheme.primaryColor)
//                                     .withOpacity(0.3),
//                             blurRadius: 8,
//                             offset: const Offset(0, 2),
//                           ),
//                         ]
//                       : [],
//                 ),
//                 child: _buildTabContent(tab, isSelected),
//               ),
//             ),
//           );
//         }),
//       ),
//     );
//   }

//   Widget _buildUnderlineTabBar() {
//     return Container(
//       decoration: BoxDecoration(
//         color: widget.backgroundColor ?? AppTheme.surfaceColor,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 1,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Row(
//             children: List.generate(widget.tabs.length, (index) {
//               final tab = widget.tabs[index];
//               final isSelected = _currentIndex == index;

//               return Expanded(
//                 child: GestureDetector(
//                   onTap: () => _onTabTapped(index),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       vertical: AppTheme.spacing4,
//                       horizontal: AppTheme.spacing3,
//                     ),
//                     child: _buildTabContent(tab, isSelected),
//                   ),
//                 ),
//               );
//             }),
//           ),
//           AnimatedBuilder(
//             animation: _indicatorAnimation,
//             builder: (context, child) {
//               return AnimatedContainer(
//                 duration: AppTheme.defaultAnimation,
//                 curve: AppTheme.easeInOutCurve,
//                 margin: EdgeInsets.only(left: _indicatorPosition),
//                 width: _indicatorWidth,
//                 height: 3,
//                 decoration: BoxDecoration(
//                   color: widget.indicatorColor ?? AppTheme.primaryColor,
//                   borderRadius: BorderRadius.circular(1.5),
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSegmentedTabBar() {
//     return Container(
//       margin: widget.padding ?? const EdgeInsets.all(AppTheme.spacing4),
//       decoration: BoxDecoration(
//         color: widget.backgroundColor ?? AppTheme.neutral100,
//         borderRadius: BorderRadius.circular(AppTheme.radiusLg),
//         border: Border.all(
//           color: AppTheme.neutral300,
//           width: 1,
//         ),
//       ),
//       child: Row(
//         children: List.generate(widget.tabs.length, (index) {
//           final tab = widget.tabs[index];
//           final isSelected = _currentIndex == index;
//           final isFirst = index == 0;
//           final isLast = index == widget.tabs.length - 1;

//           return Expanded(
//             child: GestureDetector(
//               onTap: () => _onTabTapped(index),
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                   vertical: AppTheme.spacing3,
//                   horizontal: AppTheme.spacing4,
//                 ),
//                 decoration: BoxDecoration(
//                   color: isSelected
//                       ? widget.indicatorColor ?? AppTheme.primaryColor
//                       : Colors.transparent,
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(isFirst ? AppTheme.radiusLg : 0),
//                     bottomLeft:
//                         Radius.circular(isFirst ? AppTheme.radiusLg : 0),
//                     topRight: Radius.circular(isLast ? AppTheme.radiusLg : 0),
//                     bottomRight:
//                         Radius.circular(isLast ? AppTheme.radiusLg : 0),
//                   ),
//                   border: !isLast
//                       ? Border(
//                           right: BorderSide(
//                             color: AppTheme.neutral300,
//                             width: 1,
//                           ),
//                         )
//                       : null,
//                 ),
//                 child: _buildTabContent(tab, isSelected),
//               ),
//             ),
//           );
//         }),
//       ),
//     );
//   }

//   Widget _buildFloatingTabBar() {
//     return Container(
//       margin: widget.padding ?? const EdgeInsets.all(AppTheme.spacing4),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           children: List.generate(widget.tabs.length, (index) {
//             final tab = widget.tabs[index];
//             final isSelected = _currentIndex == index;

//             return Padding(
//               padding: EdgeInsets.only(
//                 right: index < widget.tabs.length - 1 ? AppTheme.spacing3 : 0,
//               ),
//               child: GestureDetector(
//                 onTap: () => _onTabTapped(index),
//                 child: AnimatedContainer(
//                   duration: AppTheme.defaultAnimation,
//                   curve: AppTheme.easeInOutCurve,
//                   padding: const EdgeInsets.symmetric(
//                     vertical: AppTheme.spacing3,
//                     horizontal: AppTheme.spacing5,
//                   ),
//                   decoration: BoxDecoration(
//                     color: isSelected
//                         ? widget.indicatorColor ?? AppTheme.primaryColor
//                         : AppTheme.surfaceColor,
//                     borderRadius: BorderRadius.circular(AppTheme.radiusXl),
//                     border: Border.all(
//                       color: isSelected
//                           ? widget.indicatorColor ?? AppTheme.primaryColor
//                           : AppTheme.neutral300,
//                       width: 1,
//                     ),
//                     boxShadow: isSelected
//                         ? [
//                             BoxShadow(
//                               color: (widget.indicatorColor ??
//                                       AppTheme.primaryColor)
//                                   .withOpacity(0.3),
//                               blurRadius: 8,
//                               offset: const Offset(0, 2),
//                             ),
//                           ]
//                         : AppTheme.softShadow,
//                   ),
//                   child: _buildTabContent(tab, isSelected),
//                 ),
//               ),
//             );
//           }),
//         ),
//       ),
//     );
//   }

//   Widget _buildTabContent(EnhancedTab tab, bool isSelected) {
//     final textColor = isSelected
//         ? (widget.style == TabBarStyle.pills ||
//                 widget.style == TabBarStyle.segmented ||
//                 widget.style == TabBarStyle.floating
//             ? Colors.white
//             : widget.indicatorColor ?? AppTheme.primaryColor)
//         : AppTheme.textSecondaryColor;

//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         if (tab.icon != null) ...[
//           AnimatedSwitcher(
//             duration: AppTheme.fastAnimation,
//             child: Icon(
//               isSelected && tab.selectedIcon != null
//                   ? tab.selectedIcon!
//                   : tab.icon!,
//               key: ValueKey(isSelected),
//               color: textColor,
//               size: 18,
//             ),
//           ),
//           if (tab.label.isNotEmpty) const SizedBox(width: AppTheme.spacing2),
//         ],
//         if (tab.label.isNotEmpty)
//           AnimatedDefaultTextStyle(
//             duration: AppTheme.defaultAnimation,
//             style: TextStyle(
//               color: textColor,
//               fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
//               fontSize: 14,
//               letterSpacing: 0.2,
//             ),
//             child: Text(tab.label),
//           ),
//         if (tab.badge != null && tab.badge! > 0) ...[
//           const SizedBox(width: AppTheme.spacing2),
//           AnimatedContainer(
//             duration: AppTheme.defaultAnimation,
//             padding: const EdgeInsets.symmetric(
//               horizontal: AppTheme.spacing2,
//               vertical: 2,
//             ),
//             decoration: BoxDecoration(
//               color: isSelected
//                   ? Colors.white.withOpacity(0.2)
//                   : AppTheme.errorColor,
//               borderRadius: BorderRadius.circular(AppTheme.radiusMd),
//             ),
//             child: Text(
//               tab.badge.toString(),
//               style: TextStyle(
//                 color: isSelected ? Colors.white : Colors.white,
//                 fontSize: 10,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//           ),
//         ],
//       ],
//     );
//   }
// }

// class EnhancedTab {
//   final String label;
//   final IconData? icon;
//   final IconData? selectedIcon;
//   final Widget content;
//   final int? badge;

//   const EnhancedTab({
//     required this.label,
//     this.icon,
//     this.selectedIcon,
//     required this.content,
//     this.badge,
//   });
// }

// enum TabBarStyle { pills, underline, segmented, floating }

// // Enhanced Bottom Navigation Bar
// class EnhancedBottomNavigationBar extends StatefulWidget {
//   final List<EnhancedBottomNavItem> items;
//   final int currentIndex;
//   final Function(int) onTap;
//   final Color? backgroundColor;
//   final Color? selectedItemColor;
//   final Color? unselectedItemColor;
//   final BottomNavStyle style;
//   final bool showLabels;

//   const EnhancedBottomNavigationBar({
//     super.key,
//     required this.items,
//     required this.currentIndex,
//     required this.onTap,
//     this.backgroundColor,
//     this.selectedItemColor,
//     this.unselectedItemColor,
//     this.style = BottomNavStyle.shifting,
//     this.showLabels = true,
//   });

//   @override
//   State<EnhancedBottomNavigationBar> createState() =>
//       _EnhancedBottomNavigationBarState();
// }

// class _EnhancedBottomNavigationBarState
//     extends State<EnhancedBottomNavigationBar> with TickerProviderStateMixin {
//   late List<AnimationController> _animationControllers;
//   late List<Animation<double>> _scaleAnimations;
//   late List<Animation<Offset>> _slideAnimations;

//   @override
//   void initState() {
//     super.initState();
//     _initializeAnimations();
//   }

//   void _initializeAnimations() {
//     _animationControllers = List.generate(
//       widget.items.length,
//       (index) => AnimationController(
//         duration: AppTheme.defaultAnimation,
//         vsync: this,
//       ),
//     );

//     _scaleAnimations = _animationControllers.map((controller) {
//       return Tween<double>(
//         begin: 1.0,
//         end: 1.2,
//       ).animate(CurvedAnimation(
//         parent: controller,
//         curve: AppTheme.elasticCurve,
//       ));
//     }).toList();

//     _slideAnimations = _animationControllers.map((controller) {
//       return Tween<Offset>(
//         begin: Offset.zero,
//         end: const Offset(0, -0.1),
//       ).animate(CurvedAnimation(
//         parent: controller,
//         curve: AppTheme.easeOutCurve,
//       ));
//     }).toList();

//     // Animate the initially selected item
//     if (widget.currentIndex < _animationControllers.length) {
//       _animationControllers[widget.currentIndex].forward();
//     }
//   }

//   @override
//   void didUpdateWidget(EnhancedBottomNavigationBar oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.currentIndex != widget.currentIndex) {
//       // Reset previous animation
//       if (oldWidget.currentIndex < _animationControllers.length) {
//         _animationControllers[oldWidget.currentIndex].reverse();
//       }
//       // Start new animation
//       if (widget.currentIndex < _animationControllers.length) {
//         _animationControllers[widget.currentIndex].forward();
//       }
//     }
//   }

//   @override
//   void dispose() {
//     for (final controller in _animationControllers) {
//       controller.dispose();
//     }
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     switch (widget.style) {
//       case BottomNavStyle.fixed:
//         return _buildFixedBottomNav();
//       case BottomNavStyle.shifting:
//         return _buildShiftingBottomNav();
//       case BottomNavStyle.floating:
//         return _buildFloatingBottomNav();
//     }
//   }

//   Widget _buildFixedBottomNav() {
//     return Container(
//       height: AppTheme.responsiveValue(
//         context,
//         mobile: 80,
//         tablet: 85,
//         desktop: 90,
//       ),
//       decoration: BoxDecoration(
//         color: widget.backgroundColor ?? AppTheme.surfaceColor,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 20,
//             offset: const Offset(0, -5),
//           ),
//         ],
//       ),
//       child: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: List.generate(widget.items.length, (index) {
//               return _buildNavItem(index, widget.items[index]);
//             }),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildShiftingBottomNav() {
//     return Container(
//       height: AppTheme.responsiveValue(
//         context,
//         mobile: 80,
//         tablet: 85,
//         desktop: 90,
//       ),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [
//             widget.backgroundColor ?? AppTheme.surfaceColor,
//             (widget.backgroundColor ?? AppTheme.surfaceColor).withOpacity(0.95),
//           ],
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 20,
//             offset: const Offset(0, -5),
//           ),
//         ],
//       ),
//       child: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
//           child: Row(
//             children: List.generate(widget.items.length, (index) {
//               final isSelected = index == widget.currentIndex;
//               return Expanded(
//                 flex: isSelected ? 2 : 1,
//                 child: _buildNavItem(index, widget.items[index]),
//               );
//             }),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildFloatingBottomNav() {
//     return Padding(
//       padding: const EdgeInsets.all(AppTheme.spacing4),
//       child: Container(
//         height: 70,
//         decoration: BoxDecoration(
//           color: widget.backgroundColor ?? AppTheme.surfaceColor,
//           borderRadius: BorderRadius.circular(AppTheme.radius3xl),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.15),
//               blurRadius: 25,
//               offset: const Offset(0, 8),
//             ),
//           ],
//         ),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing6),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: List.generate(widget.items.length, (index) {
//               return _buildNavItem(index, widget.items[index]);
//             }),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildNavItem(int index, EnhancedBottomNavItem item) {
//     final isSelected = index == widget.currentIndex;
//     final selectedColor = widget.selectedItemColor ?? AppTheme.primaryColor;
//     final unselectedColor =
//         widget.unselectedItemColor ?? AppTheme.textTertiaryColor;

//     return GestureDetector(
//       onTap: () {
//         widget.onTap(index);
//         HapticFeedback.lightImpact();
//       },
//       child: AnimatedBuilder(
//         animation: Listenable.merge([
//           _scaleAnimations[index],
//           _slideAnimations[index],
//         ]),
//         builder: (context, child) {
//           return Transform.scale(
//             scale: _scaleAnimations[index].value,
//             child: SlideTransition(
//               position: _slideAnimations[index],
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                   vertical: AppTheme.spacing2,
//                   horizontal: AppTheme.spacing3,
//                 ),
//                 decoration: BoxDecoration(
//                   color: isSelected && widget.style == BottomNavStyle.floating
//                       ? selectedColor.withOpacity(0.1)
//                       : Colors.transparent,
//                   borderRadius: BorderRadius.circular(AppTheme.radiusXl),
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Stack(
//                       clipBehavior: Clip.none,
//                       children: [
//                         AnimatedSwitcher(
//                           duration: AppTheme.fastAnimation,
//                           child: Icon(
//                             isSelected && item.selectedIcon != null
//                                 ? item.selectedIcon!
//                                 : item.icon,
//                             key: ValueKey(isSelected),
//                             color: isSelected ? selectedColor : unselectedColor,
//                             size: AppTheme.responsiveValue(
//                               context,
//                               mobile: 24,
//                               tablet: 26,
//                               desktop: 28,
//                             ),
//                           ),
//                         ),
//                         if (item.badge != null && item.badge! > 0)
//                           Positioned(
//                             right: -8,
//                             top: -8,
//                             child: AnimatedContainer(
//                               duration: AppTheme.defaultAnimation,
//                               padding: const EdgeInsets.all(4),
//                               decoration: BoxDecoration(
//                                 color: AppTheme.errorColor,
//                                 shape: BoxShape.circle,
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppTheme.errorColor.withOpacity(0.3),
//                                     blurRadius: 8,
//                                     offset: const Offset(0, 2),
//                                   ),
//                                 ],
//                               ),
//                               constraints: const BoxConstraints(
//                                 minWidth: 18,
//                                 minHeight: 18,
//                               ),
//                               child: Text(
//                                 item.badge! > 99
//                                     ? '99+'
//                                     : item.badge.toString(),
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.w700,
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                     if (widget.showLabels && item.label.isNotEmpty) ...[
//                       const SizedBox(height: AppTheme.spacing1),
//                       AnimatedDefaultTextStyle(
//                         duration: AppTheme.defaultAnimation,
//                         style: TextStyle(
//                           fontSize: AppTheme.responsiveValue(
//                             context,
//                             mobile: 11,
//                             tablet: 12,
//                             desktop: 13,
//                           ),
//                           fontWeight:
//                               isSelected ? FontWeight.w700 : FontWeight.w500,
//                           color: isSelected ? selectedColor : unselectedColor,
//                           letterSpacing: 0.1,
//                         ),
//                         child: Text(
//                           item.label,
//                           textAlign: TextAlign.center,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// class EnhancedBottomNavItem {
//   final String label;
//   final IconData icon;
//   final IconData? selectedIcon;
//   final int? badge;

//   const EnhancedBottomNavItem({
//     required this.label,
//     required this.icon,
//     this.selectedIcon,
//     this.badge,
//   });
// }

// enum BottomNavStyle { fixed, shifting, floating }

// // Enhanced Drawer Component
// class EnhancedDrawer extends StatefulWidget {
//   final List<EnhancedDrawerItem> items;
//   final Widget? header;
//   final Widget? footer;
//   final Function(int)? onItemTapped;
//   final Color? backgroundColor;
//   final double? width;

//   const EnhancedDrawer({
//     super.key,
//     required this.items,
//     this.header,
//     this.footer,
//     this.onItemTapped,
//     this.backgroundColor,
//     this.width,
//   });

//   @override
//   State<EnhancedDrawer> createState() => _EnhancedDrawerState();
// }

// class _EnhancedDrawerState extends State<EnhancedDrawer>
//     with TickerProviderStateMixin {
//   late AnimationController _slideController;
//   late AnimationController _staggerController;
//   late Animation<Offset> _slideAnimation;
//   late List<Animation<double>> _itemAnimations;

//   @override
//   void initState() {
//     super.initState();

//     _slideController = AnimationController(
//       duration: AppTheme.slowAnimation,
//       vsync: this,
//     );

//     _staggerController = AnimationController(
//       duration: AppTheme.verySlowAnimation,
//       vsync: this,
//     );

//     _slideAnimation = Tween<Offset>(
//       begin: const Offset(-1.0, 0.0),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(
//       parent: _slideController,
//       curve: AppTheme.easeOutCurve,
//     ));

//     _itemAnimations = List.generate(
//       widget.items.length,
//       (index) => Tween<double>(
//         begin: 0.0,
//         end: 1.0,
//       ).animate(CurvedAnimation(
//         parent: _staggerController,
//         curve: Interval(
//           (index * 0.1).clamp(0.0, 0.8),
//           ((index * 0.1) + 0.3).clamp(0.3, 1.0),
//           curve: AppTheme.easeOutCurve,
//         ),
//       )),
//     );

//     _slideController.forward();
//     _staggerController.forward();
//   }

//   @override
//   void dispose() {
//     _slideController.dispose();
//     _staggerController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final drawerWidth = widget.width ??
//         AppTheme.responsiveValue(
//           context,
//           mobile: 280,
//           tablet: 320,
//           desktop: 350,
//         );

//     return SlideTransition(
//       position: _slideAnimation,
//       child: Container(
//         width: drawerWidth,
//         height: MediaQuery.of(context).size.height,
//         decoration: BoxDecoration(
//           color: widget.backgroundColor ?? AppTheme.surfaceColor,
//           boxShadow: AppTheme.strongShadow,
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               if (widget.header != null) ...[
//                 widget.header!,
//                 const EnhancedDivider(),
//               ],
//               Expanded(
//                 child: SingleChildScrollView(
//                   padding:
//                       const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
//                   child: Column(
//                     children: List.generate(
//                       widget.items.length,
//                       (index) => _buildDrawerItem(index, widget.items[index]),
//                     ),
//                   ),
//                 ),
//               ),
//               if (widget.footer != null) ...[
//                 const EnhancedDivider(),
//                 widget.footer!,
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildDrawerItem(int index, EnhancedDrawerItem item) {
//     return AnimatedBuilder(
//       animation: _itemAnimations[index],
//       builder: (context, child) {
//         return Transform.translate(
//           offset: Offset(50 * (1 - _itemAnimations[index].value), 0),
//           child: Opacity(
//             opacity: _itemAnimations[index].value,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(
//                 horizontal: AppTheme.spacing4,
//                 vertical: AppTheme.spacing1,
//               ),
//               child: Material(
//                 color: Colors.transparent,
//                 borderRadius: BorderRadius.circular(AppTheme.radiusLg),
//                 child: InkWell(
//                   onTap: () {
//                     widget.onItemTapped?.call(index);
//                     Navigator.pop(context);
//                     HapticFeedback.selectionClick();
//                   },
//                   borderRadius: BorderRadius.circular(AppTheme.radiusLg),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: AppTheme.spacing4,
//                       vertical: AppTheme.spacing4,
//                     ),
//                     child: Row(
//                       children: [
//                         if (item.icon != null) ...[
//                           Container(
//                             width: 40,
//                             height: 40,
//                             decoration: BoxDecoration(
//                               color: item.iconColor?.withOpacity(0.1) ??
//                                   AppTheme.primaryColor.withOpacity(0.1),
//                               borderRadius:
//                                   BorderRadius.circular(AppTheme.radiusLg),
//                             ),
//                             child: Icon(
//                               item.icon!,
//                               color: item.iconColor ?? AppTheme.primaryColor,
//                               size: 20,
//                             ),
//                           ),
//                           const SizedBox(width: AppTheme.spacing4),
//                         ],
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 item.title,
//                                 style: Theme.of(context)
//                                     .textTheme
//                                     .titleSmall
//                                     ?.copyWith(
//                                       fontWeight: FontWeight.w600,
//                                       color: AppTheme.textPrimaryColor,
//                                     ),
//                               ),
//                               if (item.subtitle != null) ...[
//                                 const SizedBox(height: 2),
//                                 Text(
//                                   item.subtitle!,
//                                   style: Theme.of(context)
//                                       .textTheme
//                                       .bodySmall
//                                       ?.copyWith(
//                                         color: AppTheme.textSecondaryColor,
//                                       ),
//                                 ),
//                               ],
//                             ],
//                           ),
//                         ),
//                         if (item.trailing != null) ...[
//                           const SizedBox(width: AppTheme.spacing2),
//                           item.trailing!,
//                         ],
//                         if (item.badge != null && item.badge! > 0) ...[
//                           const SizedBox(width: AppTheme.spacing2),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: AppTheme.spacing2,
//                               vertical: 2,
//                             ),
//                             decoration: BoxDecoration(
//                               color: AppTheme.errorColor,
//                               borderRadius:
//                                   BorderRadius.circular(AppTheme.radiusMd),
//                             ),
//                             child: Text(
//                               item.badge.toString(),
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                           ),
//                         ],
//                         Icon(
//                           Icons.chevron_right_rounded,
//                           color: AppTheme.textTertiaryColor,
//                           size: 20,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// class EnhancedDrawerItem {
//   final String title;
//   final String? subtitle;
//   final IconData? icon;
//   final Color? iconColor;
//   final Widget? trailing;
//   final int? badge;

//   const EnhancedDrawerItem({
//     required this.title,
//     this.subtitle,
//     this.icon,
//     this.iconColor,
//     this.trailing,
//     this.badge,
//   });
// }

// // Enhanced Breadcrumb Component
// class EnhancedBreadcrumb extends StatelessWidget {
//   final List<BreadcrumbItem> items;
//   final Widget? separator;
//   final MainAxisAlignment alignment;
//   final TextStyle? textStyle;
//   final TextStyle? activeTextStyle;

//   const EnhancedBreadcrumb({
//     super.key,
//     required this.items,
//     this.separator,
//     this.alignment = MainAxisAlignment.start,
//     this.textStyle,
//     this.activeTextStyle,
//   });

//   @override
//   Widget build(BuildContext context) {
//     if (items.isEmpty) return const SizedBox.shrink();

//     final defaultSeparator = separator ??
//         Icon(
//           Icons.chevron_right_rounded,
//           color: AppTheme.textTertiaryColor,
//           size: 16,
//         );

//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: Row(
//         mainAxisAlignment: alignment,
//         children: List.generate(
//           items.length * 2 - 1,
//           (index) {
//             if (index.isEven) {
//               final itemIndex = index ~/ 2;
//               final item = items[itemIndex];
//               final isLast = itemIndex == items.length - 1;

//               return _buildBreadcrumbItem(
//                 context,
//                 item,
//                 isLast,
//               );
//             } else {
//               return Padding(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: AppTheme.spacing2),
//                 child: defaultSeparator,
//               );
//             }
//           },
//         ),
//       ),
//     );
//   }

//   Widget _buildBreadcrumbItem(
//       BuildContext context, BreadcrumbItem item, bool isLast) {
//     final effectiveTextStyle = isLast
//         ? (activeTextStyle ??
//             Theme.of(context).textTheme.titleSmall?.copyWith(
//                   fontWeight: FontWeight.w600,
//                   color: AppTheme.primaryColor,
//                 ))
//         : (textStyle ??
//             Theme.of(context).textTheme.bodyMedium?.copyWith(
//                   color: AppTheme.textSecondaryColor,
//                 ));

//     Widget child = Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         if (item.icon != null) ...[
//           Icon(
//             item.icon!,
//             color: isLast ? AppTheme.primaryColor : AppTheme.textTertiaryColor,
//             size: 16,
//           ),
//           const SizedBox(width: AppTheme.spacing1),
//         ],
//         Text(
//           item.label,
//           style: effectiveTextStyle,
//         ),
//       ],
//     );

//     if (!isLast && item.onTap != null) {
//       child = Material(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(AppTheme.radiusMd),
//         child: InkWell(
//           onTap: item.onTap,
//           borderRadius: BorderRadius.circular(AppTheme.radiusMd),
//           child: Padding(
//             padding: const EdgeInsets.symmetric(
//               horizontal: AppTheme.spacing2,
//               vertical: AppTheme.spacing1,
//             ),
//             child: child,
//           ),
//         ),
//       );
//     }

//     return child;
//   }
// }

// class BreadcrumbItem {
//   final String label;
//   final IconData? icon;
//   final VoidCallback? onTap;

//   const BreadcrumbItem({
//     required this.label,
//     this.icon,
//     this.onTap,
//   });
// }

// // Enhanced Divider (already included in previous parts, but adding for completeness)
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

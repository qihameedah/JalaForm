import 'package:flutter/material.dart';

/// Metadata pill widget for displaying small info badges
class MetadataPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final double fontSize;
  final double iconSize;

  const MetadataPill({
    super.key,
    required this.label,
    required this.icon,
    this.color,
    this.fontSize = 11,
    this.iconSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 400 ? 4.0 : 6.0;
    final verticalPadding = screenWidth < 400 ? 2.0 : 2.0;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: color ?? Colors.grey.shade700,
          ),
          SizedBox(width: screenWidth < 400 ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color ?? Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

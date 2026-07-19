import 'package:flutter/material.dart';

class SportCategory {
  final String name;
  final String displayName;
  final IconData icon;

  SportCategory({
    required this.name,
    required this.displayName,
    required this.icon,
  });

  /// Map category slug to a display name and icon
  factory SportCategory.fromName(String name) {
    return SportCategory(
      name: name,
      displayName: _getDisplayName(name),
      icon: _getIcon(name),
    );
  }

  static String _getDisplayName(String name) {
    switch (name) {
      case 'soccer':
        return 'Football';
      case 'basketball':
        return 'Basketball';
      case 'hockey':
        return 'Hockey';
      case 'combat':
        return 'Combat';
      case 'baseball':
        return 'Baseball';
      case 'football':
        return 'Rugby';
      case 'racing':
        return 'Racing';
      case 'tennis':
        return 'Tennis';
      case 'cricket':
        return 'Cricket';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }

  static IconData _getIcon(String name) {
    switch (name) {
      case 'soccer':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      case 'hockey':
        return Icons.sports_hockey;
      case 'combat':
        return Icons.sports_mma;
      case 'baseball':
        return Icons.sports_baseball;
      case 'football':
        return Icons.sports_football;
      case 'racing':
        return Icons.directions_car;
      case 'tennis':
        return Icons.sports_tennis;
      case 'cricket':
        return Icons.sports_cricket;
      default:
        return Icons.sports;
    }
  }
}

# Theming System

## Overview

The app uses Flutter's Material 3 theming with custom theme extensions for app-specific colors. This provides:
- Light and dark mode support
- Centralized color management
- System theme detection
- Consistent UI across the app

## Architecture

### Theme Files

- **`lib/theme/app_theme.dart`**: Defines light/dark themes and custom color extensions
- **`lib/services/theme_service.dart`**: Manages theme preference persistence

### Color System

Colors are organized into semantic categories:

#### Chart Colors
- `chartLine`: Main data line color
- `chartThreshold`: Target/threshold line color
- `chartBackground`: Chart background
- `chartAxisText`: Axis labels and text

#### Stat Display Colors
- `statLastRepDuration/Max/Average/Median`: Last rep stat colors
- `statSessionMax/SessionTime`: Session-level stats
- `statRepCount/TimeSinceLast`: Counter stats
- `statPersonalBest`: Personal best highlight color
- `statLabel`: Stat label text

#### Input/Control Colors
- `targetInputBackground/Border/BorderFocused/Text`: Input field styling
- `targetButtonFill/Border/BorderSelected/Text/TextSelected`: Button styling

#### Battery Indicator
- `batteryFull/Medium/Low/Unknown`: Battery level colors

#### Danger Zone
- `dangerZoneBackground/Text/Button`: Destructive action styling

## Usage

### In Widgets

```dart
@override
Widget build(BuildContext context) {
  // Get custom colors
  final appColors = Theme.of(context).extension<AppColors>()!;
  
  // Use semantic colors from ColorScheme
  final colorScheme = Theme.of(context).colorScheme;
  
  return Container(
    color: appColors.chartBackground,
    child: Text(
      'Hello',
      style: TextStyle(color: appColors.chartAxisText),
    ),
  );
}
```

### Standard Material Colors

For standard UI elements, use `Theme.of(context).colorScheme`:
- `primary`, `secondary`: Brand colors
- `surface`, `background`: Container backgrounds
- `error`: Error states
- `onPrimary`, `onSurface`, etc.: Text on colored backgrounds

## Theme Modes

Users can select from three theme modes in Settings:
- **Light**: Always use light theme
- **Dark**: Always use dark theme  
- **System**: Follow system preference (default)

## Customizing Colors

To modify colors, edit `lib/theme/app_theme.dart`:

```dart
// Light theme
static const light = AppColors(
  chartLine: Color(0xFF673AB7),  // Deep purple
  // ... other colors
);

// Dark theme
static const dark = AppColors(
  chartLine: Color(0xFFB39DDB),  // Deep purple 200
  // ... other colors
);
```

Color choices follow Material Design guidelines:
- Light mode: Higher contrast, darker text
- Dark mode: Lower contrast, lighter text
- Consistent semantic meaning across modes

## Benefits

1. **Single Source of Truth**: All colors defined in one place
2. **Easy Theme Switching**: Change entire app appearance instantly
3. **Consistent Dark Mode**: Proper contrast and readability
4. **Maintainable**: Add new colors without searching codebase
5. **Type Safe**: Compile-time checks for color usage

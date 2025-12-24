import 'package:flutter/material.dart';

/// Custom theme extension for app-specific colors
@immutable
class AppColors extends ThemeExtension<AppColors> {
  // Chart colors
  final Color chartLine;
  final Color chartThreshold;
  final Color chartBackground;
  final Color chartAxisText;
  
  // Stat display colors
  final Color statLastRepDuration;
  final Color statLastRepMax;
  final Color statLastRepAverage;
  final Color statLastRepMedian;
  final Color statSessionMax;
  final Color statSessionTime;
  final Color statRepCount;
  final Color statTimeSinceLast;
  final Color statPersonalBest;
  final Color statLabel;
  
  // Input/control colors
  final Color targetInputBackground;
  final Color targetInputBorder;
  final Color targetInputBorderFocused;
  final Color targetInputText;
  final Color targetButtonFill;
  final Color targetButtonBorder;
  final Color targetButtonBorderSelected;
  final Color targetButtonText;
  final Color targetButtonTextSelected;
  
  // Battery indicator colors
  final Color batteryFull;
  final Color batteryMedium;
  final Color batteryLow;
  final Color batteryUnknown;
  
  // Danger zone colors
  final Color dangerZoneBackground;
  final Color dangerZoneText;
  final Color dangerButton;
  
  const AppColors({
    required this.chartLine,
    required this.chartThreshold,
    required this.chartBackground,
    required this.chartAxisText,
    required this.statLastRepDuration,
    required this.statLastRepMax,
    required this.statLastRepAverage,
    required this.statLastRepMedian,
    required this.statSessionMax,
    required this.statSessionTime,
    required this.statRepCount,
    required this.statTimeSinceLast,
    required this.statPersonalBest,
    required this.statLabel,
    required this.targetInputBackground,
    required this.targetInputBorder,
    required this.targetInputBorderFocused,
    required this.targetInputText,
    required this.targetButtonFill,
    required this.targetButtonBorder,
    required this.targetButtonBorderSelected,
    required this.targetButtonText,
    required this.targetButtonTextSelected,
    required this.batteryFull,
    required this.batteryMedium,
    required this.batteryLow,
    required this.batteryUnknown,
    required this.dangerZoneBackground,
    required this.dangerZoneText,
    required this.dangerButton,
  });

  @override
  AppColors copyWith({
    Color? chartLine,
    Color? chartThreshold,
    Color? chartBackground,
    Color? chartAxisText,
    Color? statLastRepDuration,
    Color? statLastRepMax,
    Color? statLastRepAverage,
    Color? statLastRepMedian,
    Color? statSessionMax,
    Color? statSessionTime,
    Color? statRepCount,
    Color? statTimeSinceLast,
    Color? statPersonalBest,
    Color? statLabel,
    Color? targetInputBackground,
    Color? targetInputBorder,
    Color? targetInputBorderFocused,
    Color? targetInputText,
    Color? targetButtonFill,
    Color? targetButtonBorder,
    Color? targetButtonBorderSelected,
    Color? targetButtonText,
    Color? targetButtonTextSelected,
    Color? batteryFull,
    Color? batteryMedium,
    Color? batteryLow,
    Color? batteryUnknown,
    Color? dangerZoneBackground,
    Color? dangerZoneText,
    Color? dangerButton,
  }) {
    return AppColors(
      chartLine: chartLine ?? this.chartLine,
      chartThreshold: chartThreshold ?? this.chartThreshold,
      chartBackground: chartBackground ?? this.chartBackground,
      chartAxisText: chartAxisText ?? this.chartAxisText,
      statLastRepDuration: statLastRepDuration ?? this.statLastRepDuration,
      statLastRepMax: statLastRepMax ?? this.statLastRepMax,
      statLastRepAverage: statLastRepAverage ?? this.statLastRepAverage,
      statLastRepMedian: statLastRepMedian ?? this.statLastRepMedian,
      statSessionMax: statSessionMax ?? this.statSessionMax,
      statSessionTime: statSessionTime ?? this.statSessionTime,
      statRepCount: statRepCount ?? this.statRepCount,
      statTimeSinceLast: statTimeSinceLast ?? this.statTimeSinceLast,
      statPersonalBest: statPersonalBest ?? this.statPersonalBest,
      statLabel: statLabel ?? this.statLabel,
      targetInputBackground: targetInputBackground ?? this.targetInputBackground,
      targetInputBorder: targetInputBorder ?? this.targetInputBorder,
      targetInputBorderFocused: targetInputBorderFocused ?? this.targetInputBorderFocused,
      targetInputText: targetInputText ?? this.targetInputText,
      targetButtonFill: targetButtonFill ?? this.targetButtonFill,
      targetButtonBorder: targetButtonBorder ?? this.targetButtonBorder,
      targetButtonBorderSelected: targetButtonBorderSelected ?? this.targetButtonBorderSelected,
      targetButtonText: targetButtonText ?? this.targetButtonText,
      targetButtonTextSelected: targetButtonTextSelected ?? this.targetButtonTextSelected,
      batteryFull: batteryFull ?? this.batteryFull,
      batteryMedium: batteryMedium ?? this.batteryMedium,
      batteryLow: batteryLow ?? this.batteryLow,
      batteryUnknown: batteryUnknown ?? this.batteryUnknown,
      dangerZoneBackground: dangerZoneBackground ?? this.dangerZoneBackground,
      dangerZoneText: dangerZoneText ?? this.dangerZoneText,
      dangerButton: dangerButton ?? this.dangerButton,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      chartLine: Color.lerp(chartLine, other.chartLine, t)!,
      chartThreshold: Color.lerp(chartThreshold, other.chartThreshold, t)!,
      chartBackground: Color.lerp(chartBackground, other.chartBackground, t)!,
      chartAxisText: Color.lerp(chartAxisText, other.chartAxisText, t)!,
      statLastRepDuration: Color.lerp(statLastRepDuration, other.statLastRepDuration, t)!,
      statLastRepMax: Color.lerp(statLastRepMax, other.statLastRepMax, t)!,
      statLastRepAverage: Color.lerp(statLastRepAverage, other.statLastRepAverage, t)!,
      statLastRepMedian: Color.lerp(statLastRepMedian, other.statLastRepMedian, t)!,
      statSessionMax: Color.lerp(statSessionMax, other.statSessionMax, t)!,
      statSessionTime: Color.lerp(statSessionTime, other.statSessionTime, t)!,
      statRepCount: Color.lerp(statRepCount, other.statRepCount, t)!,
      statTimeSinceLast: Color.lerp(statTimeSinceLast, other.statTimeSinceLast, t)!,
      statPersonalBest: Color.lerp(statPersonalBest, other.statPersonalBest, t)!,
      statLabel: Color.lerp(statLabel, other.statLabel, t)!,
      targetInputBackground: Color.lerp(targetInputBackground, other.targetInputBackground, t)!,
      targetInputBorder: Color.lerp(targetInputBorder, other.targetInputBorder, t)!,
      targetInputBorderFocused: Color.lerp(targetInputBorderFocused, other.targetInputBorderFocused, t)!,
      targetInputText: Color.lerp(targetInputText, other.targetInputText, t)!,
      targetButtonFill: Color.lerp(targetButtonFill, other.targetButtonFill, t)!,
      targetButtonBorder: Color.lerp(targetButtonBorder, other.targetButtonBorder, t)!,
      targetButtonBorderSelected: Color.lerp(targetButtonBorderSelected, other.targetButtonBorderSelected, t)!,
      targetButtonText: Color.lerp(targetButtonText, other.targetButtonText, t)!,
      targetButtonTextSelected: Color.lerp(targetButtonTextSelected, other.targetButtonTextSelected, t)!,
      batteryFull: Color.lerp(batteryFull, other.batteryFull, t)!,
      batteryMedium: Color.lerp(batteryMedium, other.batteryMedium, t)!,
      batteryLow: Color.lerp(batteryLow, other.batteryLow, t)!,
      batteryUnknown: Color.lerp(batteryUnknown, other.batteryUnknown, t)!,
      dangerZoneBackground: Color.lerp(dangerZoneBackground, other.dangerZoneBackground, t)!,
      dangerZoneText: Color.lerp(dangerZoneText, other.dangerZoneText, t)!,
      dangerButton: Color.lerp(dangerButton, other.dangerButton, t)!,
    );
  }

  // Light theme colors
  static const light = AppColors(
    chartLine: Color(0xFF673AB7), // Deep purple
    chartThreshold: Color(0xFFFF9800), // Orange
    chartBackground: Colors.white,
    chartAxisText: Color(0xFF000000), // Black87
    statLastRepDuration: Color(0xFF616161), // Grey 700
    statLastRepMax: Color(0xFF616161),
    statLastRepAverage: Color(0xFF616161),
    statLastRepMedian: Color(0xFF616161),
    statSessionMax: Color(0xFF000000), // Black87
    statSessionTime: Color(0xFF757575), // Grey 600
    statRepCount: Color(0xFF757575),
    statTimeSinceLast: Color(0xFF757575),
    statPersonalBest: Color(0xFF4CAF50), // Green
    statLabel: Color(0xFF616161), // Black54 for labels
    targetInputBackground: Color(0xFFF5F5F5), // Grey 100
    targetInputBorder: Color(0xFFE0E0E0), // Grey 300
    targetInputBorderFocused: Color(0xFF1976D2), // Blue 700
    targetInputText: Color(0xFF757575), // Grey 600
    targetButtonFill: Color(0xFF1976D2), // Blue 700
    targetButtonBorder: Color(0xFFBDBDBD), // Grey 400
    targetButtonBorderSelected: Color(0xFF1976D2),
    targetButtonText: Color(0xFF616161), // Grey 700
    targetButtonTextSelected: Colors.white,
    batteryFull: Colors.white,
    batteryMedium: Color(0xFFFF9800), // Orange
    batteryLow: Color(0xFFF44336), // Red
    batteryUnknown: Color(0xFFFFFFFF), // White70
    dangerZoneBackground: Color(0xFFFFEBEE), // Red 50
    dangerZoneText: Color(0xFFF44336), // Red
    dangerButton: Color(0xFFF44336),
  );

  // Dark theme colors
  static const dark = AppColors(
    chartLine: Color(0xFFB39DDB), // Deep purple 200
    chartThreshold: Color(0xFFFFB74D), // Orange 300
    chartBackground: Color(0xFF121212),
    chartAxisText: Color(0xFFE0E0E0), // Grey 300
    statLastRepDuration: Color(0xFFE0E0E0),
    statLastRepMax: Color(0xFFE0E0E0),
    statLastRepAverage: Color(0xFFE0E0E0),
    statLastRepMedian: Color(0xFFE0E0E0),
    statSessionMax: Color(0xFFFFFFFF),
    statSessionTime: Color(0xFFBDBDBD), // Grey 400
    statRepCount: Color(0xFFBDBDBD),
    statTimeSinceLast: Color(0xFFBDBDBD),
    statPersonalBest: Color(0xFF81C784), // Green 300
    statLabel: Color(0xFFBDBDBD),
    targetInputBackground: Color(0xFF2C2C2C),
    targetInputBorder: Color(0xFF424242), // Grey 800
    targetInputBorderFocused: Color(0xFF64B5F6), // Blue 300
    targetInputText: Color(0xFFBDBDBD),
    targetButtonFill: Color(0xFF1976D2), // Blue 700
    targetButtonBorder: Color(0xFF616161), // Grey 700
    targetButtonBorderSelected: Color(0xFF64B5F6),
    targetButtonText: Color(0xFFE0E0E0),
    targetButtonTextSelected: Colors.white,
    batteryFull: Colors.white,
    batteryMedium: Color(0xFFFFB74D), // Orange 300
    batteryLow: Color(0xFFE57373), // Red 300
    batteryUnknown: Color(0xFFBDBDBD),
    dangerZoneBackground: Color(0xFF3E2723), // Brown 900 (darker)
    dangerZoneText: Color(0xFFEF5350), // Red 400
    dangerButton: Color(0xFFE57373), // Red 300
  );
}

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF673AB7), // Deep purple
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppColors.light,
      ],
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFB39DDB), // Deep purple 200
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppColors.dark,
      ],
    );
  }
}

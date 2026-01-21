import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Show a confirmation dialog with customizable text and actions
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool isDangerous = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final appColors = Theme.of(context).extension<AppColors>();
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmText,
              style: isDangerous && appColors != null
                  ? TextStyle(color: appColors.dangerZoneText)
                  : null,
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Show a number input dialog with validation
Future<double?> showNumberInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  double? initialValue,
  double? min,
  double? max,
  bool allowDecimals = true,
  String? hint,
}) async {
  final controller = TextEditingController(
    text: initialValue?.toString() ?? '',
  );

  final result = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        keyboardType: allowDecimals
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final value = double.tryParse(controller.text);
            if (value == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Invalid number')));
              return;
            }
            if (min != null && value < min) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Value must be at least $min')),
              );
              return;
            }
            if (max != null && value > max) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Value must be at most $max')),
              );
              return;
            }
            Navigator.of(ctx).pop(value);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );

  controller.dispose();
  return result;
}

/// Show an integer input dialog with validation
Future<int?> showIntInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  int? initialValue,
  int? min,
  int? max,
  String? hint,
}) async {
  final result = await showNumberInputDialog(
    context,
    title: title,
    label: label,
    initialValue: initialValue?.toDouble(),
    min: min?.toDouble(),
    max: max?.toDouble(),
    allowDecimals: false,
    hint: hint,
  );

  return result?.round();
}

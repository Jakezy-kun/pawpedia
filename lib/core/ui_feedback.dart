import 'package:flutter/material.dart';

import 'theme/app_colors.dart';

/// One place for snackbars, so every confirmation and error in the app looks
/// and behaves the same.
extension UiFeedback on BuildContext {
  void showSnack(String message, {SnackBarAction? action}) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(this);
    // Replace whatever is on screen rather than queueing: a stack of stale
    // snackbars is worse than the newest message alone.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void showErrorSnack(String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(this);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.destructive,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

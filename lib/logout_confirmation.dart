import 'package:flutter/material.dart';

import 'splash_screen.dart';

Future<void> confirmLogout(
  BuildContext context, {
  required Future<void> Function() onConfirmed,
  String message = 'You will return to the welcome screen.',
}) async {
  var signingOut = false;
  String? error;
  final signedOut = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, updateDialog) => PopScope(
        canPop: !signingOut,
        child: AlertDialog(
          title: const Text('Log out?'),
          content: Text(error ?? message),
          actions: [
            TextButton(
              onPressed: signingOut ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: signingOut
                  ? null
                  : () async {
                      if (signingOut) return;
                      updateDialog(() => signingOut = true);
                      try {
                        await onConfirmed();
                      } on Exception {
                        if (!context.mounted) return;
                        updateDialog(() {
                          signingOut = false;
                          error = 'Could not log out. Try again.';
                        });
                        return;
                      }
                      if (context.mounted) Navigator.pop(context, true);
                    },
              child: Text(signingOut ? 'Logging out…' : 'Log out'),
            ),
          ],
        ),
      ),
    ),
  );
  if (signedOut != true || !context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SplashScreen()),
    (_) => false,
  );
}

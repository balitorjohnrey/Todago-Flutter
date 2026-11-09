import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'booking_destination.dart';
import 'destination_picker_screen.dart';
import 'login_screen.dart';

/// Keeps a selected place attached to booking, including the login detour.
class BookDestinationButton extends StatefulWidget {
  final BookingDestination destination;

  const BookDestinationButton({super.key, required this.destination});

  @override
  State<BookDestinationButton> createState() => _BookDestinationButtonState();
}

class _BookDestinationButtonState extends State<BookDestinationButton> {
  bool _opening = false;

  Future<void> _book() async {
    if (_opening) return;
    final destination = widget.destination;
    setState(() => _opening = true);
    try {
      final loggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => loggedIn
            ? DestinationPickerScreen(initialDestination: destination)
            : LoginScreen(bookingDestination: destination),
      ));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: _opening ? null : _book,
        icon: _opening
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.electric_rickshaw_rounded),
        label: Text(_opening ? 'Opening booking…' : 'Book Now?'),
      );
}

import 'package:flutter/material.dart';
import '../utils/input_formatters.dart';

/// Widget for entering rest period as minutes and seconds.
///
/// Internally stores and returns value in total seconds.
/// Use a `GlobalKey<RestInputState>` to access `totalSeconds` or `setTotalSeconds()`.
///
/// Features:
/// - If minutes is filled and confirmed but seconds is empty, seconds autofills to 0
/// - If seconds is filled and confirmed but minutes is empty, minutes autofills to 0
/// - Tap-to-clear only clears the specific field that was autofilled, not both
class RestInput extends StatefulWidget {
  final int initialSeconds;
  final String label;
  final ValueChanged<int>? onChanged;

  const RestInput({
    super.key,
    this.initialSeconds = 0,
    required this.label,
    this.onChanged,
  });

  @override
  State<RestInput> createState() => RestInputState();
}

class RestInputState extends State<RestInput> {
  late TextEditingController _minutesController;
  late TextEditingController _secondsController;
  late FocusNode _minutesFocusNode;
  late FocusNode _secondsFocusNode;

  // Track which field was autofilled (for tap-to-clear)
  bool _minutesAutoFilled = false;
  bool _secondsAutoFilled = false;

  @override
  void initState() {
    super.initState();
    _initFromSeconds(widget.initialSeconds);

    _minutesFocusNode = FocusNode();
    _secondsFocusNode = FocusNode();

    _minutesFocusNode.addListener(_onMinutesFocusChange);
    _secondsFocusNode.addListener(_onSecondsFocusChange);
  }

  void _initFromSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    _minutesController = TextEditingController(
      text: minutes > 0 ? minutes.toString() : '',
    );
    _secondsController = TextEditingController(
      text: seconds > 0 || minutes > 0 ? seconds.toString() : '',
    );
  }

  void _onMinutesFocusChange() {
    if (_minutesFocusNode.hasFocus) {
      // Tap-to-clear: only clear minutes if it was autofilled
      if (_minutesAutoFilled) {
        _minutesController.clear();
        _minutesAutoFilled = false;
        setState(() {});
        _notifyChanged();
      }
    } else {
      // Focus left minutes field - autofill seconds if needed
      _autoFillOnBlur();
    }
  }

  void _onSecondsFocusChange() {
    if (_secondsFocusNode.hasFocus) {
      // Tap-to-clear: only clear seconds if it was autofilled
      if (_secondsAutoFilled) {
        _secondsController.clear();
        _secondsAutoFilled = false;
        setState(() {});
        _notifyChanged();
      }
    } else {
      // Focus left seconds field - autofill minutes if needed
      _autoFillOnBlur();
    }
  }

  void _autoFillOnBlur() {
    final minutesText = _minutesController.text.trim();
    final secondsText = _secondsController.text.trim();
    final hasMinutes = minutesText.isNotEmpty;
    final hasSeconds = secondsText.isNotEmpty;

    // If one field has a value and the other is empty, autofill empty to 0
    if (hasMinutes && !hasSeconds) {
      _secondsController.text = '0';
      _secondsAutoFilled = true;
      setState(() {});
      _notifyChanged();
    } else if (hasSeconds && !hasMinutes) {
      _minutesController.text = '0';
      _minutesAutoFilled = true;
      setState(() {});
      _notifyChanged();
    }
  }

  @override
  void didUpdateWidget(RestInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSeconds != widget.initialSeconds) {
      setTotalSeconds(widget.initialSeconds);
    }
  }

  void _notifyChanged() {
    widget.onChanged?.call(totalSeconds);
  }

  void _onMinutesChanged(String value) {
    // User is typing - clear autofill flag
    _minutesAutoFilled = false;
    _notifyChanged();
  }

  void _onSecondsChanged(String value) {
    // User is typing - clear autofill flag
    _secondsAutoFilled = false;
    _notifyChanged();
  }

  /// Get current value in total seconds
  int get totalSeconds {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    return (minutes * 60) + seconds;
  }

  /// Set value from total seconds
  void setTotalSeconds(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    _minutesController.text = mins > 0 ? mins.toString() : '';
    _secondsController.text = secs > 0 || mins > 0 ? secs.toString() : '';
    _minutesAutoFilled = false;
    _secondsAutoFilled = false;
    setState(() {});
    _notifyChanged();
  }

  /// Clear the input
  void clear() {
    _minutesController.clear();
    _secondsController.clear();
    _minutesAutoFilled = false;
    _secondsAutoFilled = false;
    setState(() {});
    _notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 60,
              child: TextField(
                controller: _minutesController,
                focusNode: _minutesFocusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [NonNegativeIntFormatter()],
                decoration: InputDecoration(
                  hintText: 'Min',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  fillColor: _minutesAutoFilled ? Colors.grey[100] : null,
                  filled: _minutesAutoFilled,
                ),
                onChanged: _onMinutesChanged,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(':'),
            ),
            SizedBox(
              width: 60,
              child: TextField(
                controller: _secondsController,
                focusNode: _secondsFocusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [NonNegativeIntFormatter()],
                decoration: InputDecoration(
                  hintText: 'Sec',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  fillColor: _secondsAutoFilled ? Colors.grey[100] : null,
                  filled: _secondsAutoFilled,
                ),
                onChanged: _onSecondsChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    _minutesFocusNode.dispose();
    _secondsFocusNode.dispose();
    super.dispose();
  }
}

/// Format seconds as "Xm Ys" or "Ys" string for display
String formatRestTime(int totalSeconds) {
  if (totalSeconds <= 0) return '';
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes > 0 && seconds > 0) {
    return '${minutes}m ${seconds}s';
  } else if (minutes > 0) {
    return '${minutes}m';
  } else {
    return '${seconds}s';
  }
}

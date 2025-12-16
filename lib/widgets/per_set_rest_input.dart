import 'package:flutter/material.dart';
import '../utils/input_formatters.dart';
import 'rest_input.dart';

/// Widget for entering rest periods per set with cascading behavior.
///
/// Each set has minutes and seconds inputs.
/// Auto-fills subsequent empty sets when focus leaves a filled field.
/// Use a `GlobalKey<PerSetRestInputState>` to access `values` or `setValues()`.
///
/// Features:
/// - If minutes is filled but seconds is empty, seconds autofills to 0 on blur
/// - If seconds is filled but minutes is empty, minutes autofills to 0 on blur
/// - Tap-to-clear only clears the specific field (minutes or seconds), not both
/// - Cascading fills subsequent empty sets with the same value
class PerSetRestInput extends StatefulWidget {
  final int setCount;
  final List<int> initialValues; // Values in seconds
  final ValueChanged<List<int?>>? onChanged;

  const PerSetRestInput({
    super.key,
    required this.setCount,
    required this.initialValues,
    this.onChanged,
  });

  @override
  State<PerSetRestInput> createState() => PerSetRestInputState();
}

class PerSetRestInputState extends State<PerSetRestInput> {
  late List<TextEditingController> _minutesControllers;
  late List<TextEditingController> _secondsControllers;
  late List<FocusNode> _minutesFocusNodes;
  late List<FocusNode> _secondsFocusNodes;
  late Set<int> _userEditedIndices;
  // Track per-field autofill status
  late Set<int> _minutesAutoFilledIndices;
  late Set<int> _secondsAutoFilledIndices;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _userEditedIndices = {};
    _minutesAutoFilledIndices = {};
    _secondsAutoFilledIndices = {};

    _minutesControllers = List.generate(widget.setCount, (i) {
      final totalSeconds = i < widget.initialValues.length ? widget.initialValues[i] : 0;
      final minutes = totalSeconds ~/ 60;
      if (totalSeconds > 0) {
        _userEditedIndices.add(i);
      }
      return TextEditingController(text: minutes > 0 ? minutes.toString() : '');
    });

    _secondsControllers = List.generate(widget.setCount, (i) {
      final totalSeconds = i < widget.initialValues.length ? widget.initialValues[i] : 0;
      final seconds = totalSeconds % 60;
      return TextEditingController(
        text: totalSeconds > 0 ? seconds.toString() : '',
      );
    });

    _minutesFocusNodes = List.generate(widget.setCount, (i) {
      final node = FocusNode();
      node.addListener(() => _onMinutesFocusChange(i, node.hasFocus));
      return node;
    });

    _secondsFocusNodes = List.generate(widget.setCount, (i) {
      final node = FocusNode();
      node.addListener(() => _onSecondsFocusChange(i, node.hasFocus));
      return node;
    });
  }

  @override
  void didUpdateWidget(PerSetRestInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setCount != widget.setCount) {
      _adjustControllersForSetCount();
    }
  }

  void _adjustControllersForSetCount() {
    if (widget.setCount > _minutesControllers.length) {
      // Add more controllers, inherit last value
      final lastMinutes = _minutesControllers.isNotEmpty ? _minutesControllers.last.text : '';
      final lastSeconds = _secondsControllers.isNotEmpty ? _secondsControllers.last.text : '';

      for (int i = _minutesControllers.length; i < widget.setCount; i++) {
        _minutesControllers.add(TextEditingController(text: lastMinutes));
        _secondsControllers.add(TextEditingController(text: lastSeconds));

        final minutesNode = FocusNode();
        final secondsNode = FocusNode();
        final index = i;
        minutesNode.addListener(() => _onMinutesFocusChange(index, minutesNode.hasFocus));
        secondsNode.addListener(() => _onSecondsFocusChange(index, secondsNode.hasFocus));
        _minutesFocusNodes.add(minutesNode);
        _secondsFocusNodes.add(secondsNode);

        if (lastMinutes.isNotEmpty || lastSeconds.isNotEmpty) {
          // Mark both as autofilled for cascade
          if (lastMinutes.isNotEmpty) _minutesAutoFilledIndices.add(i);
          if (lastSeconds.isNotEmpty) _secondsAutoFilledIndices.add(i);
        }
      }
    } else if (widget.setCount < _minutesControllers.length) {
      // Remove excess controllers
      for (int i = _minutesControllers.length - 1; i >= widget.setCount; i--) {
        _minutesControllers[i].dispose();
        _minutesControllers.removeAt(i);
        _secondsControllers[i].dispose();
        _secondsControllers.removeAt(i);
        _minutesFocusNodes[i].dispose();
        _minutesFocusNodes.removeAt(i);
        _secondsFocusNodes[i].dispose();
        _secondsFocusNodes.removeAt(i);
        _userEditedIndices.remove(i);
        _minutesAutoFilledIndices.remove(i);
        _secondsAutoFilledIndices.remove(i);
      }
    }
    setState(() {});
    _notifyChanged();
  }

  void _onMinutesFocusChange(int index, bool hasFocus) {
    if (hasFocus) {
      // Tap-to-clear: only clear minutes if it was autofilled
      if (_minutesAutoFilledIndices.contains(index) && !_userEditedIndices.contains(index)) {
        _minutesControllers[index].clear();
        _minutesAutoFilledIndices.remove(index);
        setState(() {});
        _notifyChanged();
      }
    } else {
      // Focus left - check for autofill and cascade
      _autoFillOnBlur(index);
      _maybeCascadeValue(index);
    }
  }

  void _onSecondsFocusChange(int index, bool hasFocus) {
    if (hasFocus) {
      // Tap-to-clear: only clear seconds if it was autofilled
      if (_secondsAutoFilledIndices.contains(index) && !_userEditedIndices.contains(index)) {
        _secondsControllers[index].clear();
        _secondsAutoFilledIndices.remove(index);
        setState(() {});
        _notifyChanged();
      }
    } else {
      // Focus left - check for autofill and cascade
      _autoFillOnBlur(index);
      _maybeCascadeValue(index);
    }
  }

  void _autoFillOnBlur(int index) {
    final minutesText = _minutesControllers[index].text.trim();
    final secondsText = _secondsControllers[index].text.trim();
    final hasMinutes = minutesText.isNotEmpty;
    final hasSeconds = secondsText.isNotEmpty;

    // If one field has a value and the other is empty, autofill empty to 0
    if (hasMinutes && !hasSeconds) {
      _secondsControllers[index].text = '0';
      _secondsAutoFilledIndices.add(index);
      setState(() {});
      _notifyChanged();
    } else if (hasSeconds && !hasMinutes) {
      _minutesControllers[index].text = '0';
      _minutesAutoFilledIndices.add(index);
      setState(() {});
      _notifyChanged();
    }
  }

  void _maybeCascadeValue(int index) {
    final totalSeconds = _getTotalSecondsAt(index);
    if (totalSeconds > 0 && _userEditedIndices.contains(index)) {
      _cascadeValue(index, totalSeconds);
    }
  }

  int _getTotalSecondsAt(int index) {
    final minutes = int.tryParse(_minutesControllers[index].text) ?? 0;
    final seconds = int.tryParse(_secondsControllers[index].text) ?? 0;
    return (minutes * 60) + seconds;
  }

  void _cascadeValue(int fromIndex, int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    for (int i = fromIndex + 1; i < _minutesControllers.length; i++) {
      // Only cascade to fields that are completely empty (not user-edited)
      final hasMinutes = _minutesControllers[i].text.trim().isNotEmpty;
      final hasSeconds = _secondsControllers[i].text.trim().isNotEmpty;
      final isEmpty = !hasMinutes && !hasSeconds;

      if (!_userEditedIndices.contains(i) && isEmpty) {
        _minutesControllers[i].text = minutes > 0 ? minutes.toString() : '0';
        _secondsControllers[i].text = seconds.toString();
        _minutesAutoFilledIndices.add(i);
        _secondsAutoFilledIndices.add(i);
      } else {
        break; // Stop at first filled field
      }
    }
    _notifyChanged();
  }

  void _onMinutesFieldChanged(int index) {
    // User is typing - clear autofill flag for this field only
    _minutesAutoFilledIndices.remove(index);
    _checkUserEdited(index);
    _notifyChanged();
  }

  void _onSecondsFieldChanged(int index) {
    // User is typing - clear autofill flag for this field only
    _secondsAutoFilledIndices.remove(index);
    _checkUserEdited(index);
    _notifyChanged();
  }

  void _checkUserEdited(int index) {
    // Mark as user-edited if either field has content
    final totalSeconds = _getTotalSecondsAt(index);
    if (totalSeconds > 0) {
      _userEditedIndices.add(index);
    } else if (_minutesControllers[index].text.isEmpty &&
               _secondsControllers[index].text.isEmpty) {
      _userEditedIndices.remove(index);
    }
  }

  void _notifyChanged() {
    final values = List.generate(_minutesControllers.length, (i) {
      final total = _getTotalSecondsAt(i);
      return total > 0 ? total : null;
    });
    widget.onChanged?.call(values);
  }

  /// Get the current values as a list of seconds (null for empty)
  List<int?> get values => List.generate(
    _minutesControllers.length,
    (i) {
      final total = _getTotalSecondsAt(i);
      return total > 0 ? total : null;
    },
  );

  /// Fill all empty controllers with the given value (in seconds)
  void fillEmptyWith(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    for (int i = 0; i < _minutesControllers.length; i++) {
      if (_getTotalSecondsAt(i) == 0) {
        _minutesControllers[i].text = minutes > 0 ? minutes.toString() : '0';
        _secondsControllers[i].text = seconds.toString();
        _minutesAutoFilledIndices.add(i);
        _secondsAutoFilledIndices.add(i);
      }
    }
    _notifyChanged();
  }

  /// Fill all controllers with the given value (in seconds)
  void fillAllWith(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    for (int i = 0; i < _minutesControllers.length; i++) {
      _minutesControllers[i].text = minutes > 0 ? minutes.toString() : '0';
      _secondsControllers[i].text = seconds.toString();
      _minutesAutoFilledIndices.add(i);
      _secondsAutoFilledIndices.add(i);
    }
    _userEditedIndices.clear();
    _notifyChanged();
  }

  /// Set all values from a list (used when loading saved per-set values)
  void setValues(List<int> values) {
    _userEditedIndices.clear();
    _minutesAutoFilledIndices.clear();
    _secondsAutoFilledIndices.clear();

    for (int i = 0; i < _minutesControllers.length && i < values.length; i++) {
      final totalSeconds = values[i];
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      _minutesControllers[i].text = minutes > 0 ? minutes.toString() : '';
      _secondsControllers[i].text = totalSeconds > 0 ? seconds.toString() : '';
      if (totalSeconds > 0) {
        _userEditedIndices.add(i);
      }
    }
    // Clear any remaining controllers if values list is shorter
    for (int i = values.length; i < _minutesControllers.length; i++) {
      _minutesControllers[i].clear();
      _secondsControllers[i].clear();
    }
    setState(() {});
    _notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_minutesControllers.isEmpty) {
      return Text(
        'Enter sets first',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[400],
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rest per set:',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        ...List.generate(_minutesControllers.length, (index) {
          final minutesAutoFilled = _minutesAutoFilledIndices.contains(index) &&
                                    !_userEditedIndices.contains(index);
          final secondsAutoFilled = _secondsAutoFilledIndices.contains(index) &&
                                    !_userEditedIndices.contains(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    'Set ${index + 1}:',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _minutesControllers[index],
                    focusNode: _minutesFocusNodes[index],
                    keyboardType: TextInputType.number,
                    inputFormatters: [NonNegativeIntFormatter()],
                    decoration: InputDecoration(
                      hintText: 'Min',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      fillColor: minutesAutoFilled ? Colors.grey[100] : null,
                      filled: minutesAutoFilled,
                    ),
                    onChanged: (_) => _onMinutesFieldChanged(index),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Text(':'),
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _secondsControllers[index],
                    focusNode: _secondsFocusNodes[index],
                    keyboardType: TextInputType.number,
                    inputFormatters: [NonNegativeIntFormatter()],
                    decoration: InputDecoration(
                      hintText: 'Sec',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      fillColor: secondsAutoFilled ? Colors.grey[100] : null,
                      filled: secondsAutoFilled,
                    ),
                    onChanged: (_) => _onSecondsFieldChanged(index),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatRestTime(_getTotalSecondsAt(index)),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  void dispose() {
    for (final c in _minutesControllers) {
      c.dispose();
    }
    for (final c in _secondsControllers) {
      c.dispose();
    }
    for (final f in _minutesFocusNodes) {
      f.dispose();
    }
    for (final f in _secondsFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }
}

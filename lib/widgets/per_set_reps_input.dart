import 'package:flutter/material.dart';
import '../utils/input_formatters.dart';

/// Widget for entering reps/duration per set with cascading behavior.
///
/// When a value is entered in set N and focus leaves, it auto-fills subsequent empty sets.
/// Auto-filled fields are cleared when the user taps on them for fresh input.
/// Use a `GlobalKey<PerSetRepsInputState>` to access `values` or `fillEmptyWith()`.
class PerSetRepsInput extends StatefulWidget {
  final int setCount;
  final List<int> initialValues;
  final String label; // "Reps" or "Seconds"
  final ValueChanged<List<int?>>? onChanged;

  const PerSetRepsInput({
    super.key,
    required this.setCount,
    required this.initialValues,
    required this.label,
    this.onChanged,
  });

  @override
  State<PerSetRepsInput> createState() => PerSetRepsInputState();
}

class PerSetRepsInputState extends State<PerSetRepsInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late Set<int> _userEditedIndices; // Track which fields user has directly edited
  late Set<int> _autoFilledIndices; // Track which fields were auto-filled

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _userEditedIndices = {};
    _autoFilledIndices = {};

    _controllers = List.generate(widget.setCount, (i) {
      final value = i < widget.initialValues.length && widget.initialValues[i] > 0
          ? widget.initialValues[i].toString()
          : '';
      if (value.isNotEmpty) {
        // Initial values from props are considered user-edited (not clearable)
        _userEditedIndices.add(i);
      }
      return TextEditingController(text: value);
    });

    _focusNodes = List.generate(widget.setCount, (i) {
      final node = FocusNode();
      node.addListener(() => _onFocusChange(i, node.hasFocus));
      return node;
    });
  }

  @override
  void didUpdateWidget(PerSetRepsInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setCount != widget.setCount) {
      _adjustControllersForSetCount();
    }
  }

  void _adjustControllersForSetCount() {
    if (widget.setCount > _controllers.length) {
      // Add more controllers, inherit last value
      final lastValue = _controllers.isNotEmpty ? _controllers.last.text : '';
      for (int i = _controllers.length; i < widget.setCount; i++) {
        _controllers.add(TextEditingController(text: lastValue));
        final node = FocusNode();
        final index = i;
        node.addListener(() => _onFocusChange(index, node.hasFocus));
        _focusNodes.add(node);
        if (lastValue.isNotEmpty) {
          _autoFilledIndices.add(i);
        }
      }
    } else if (widget.setCount < _controllers.length) {
      // Remove excess controllers
      for (int i = _controllers.length - 1; i >= widget.setCount; i--) {
        _controllers[i].dispose();
        _controllers.removeAt(i);
        _focusNodes[i].dispose();
        _focusNodes.removeAt(i);
        _userEditedIndices.remove(i);
        _autoFilledIndices.remove(i);
      }
    }
    setState(() {});
    _notifyChanged();
  }

  void _onFocusChange(int index, bool hasFocus) {
    if (hasFocus) {
      // When focusing on an auto-filled field, clear it for fresh input
      if (_autoFilledIndices.contains(index) && !_userEditedIndices.contains(index)) {
        _controllers[index].clear();
        _autoFilledIndices.remove(index);
        _notifyChanged();
      }
    } else {
      // When focus leaves, cascade the value to subsequent fields
      final value = _controllers[index].text;
      if (value.isNotEmpty && _userEditedIndices.contains(index)) {
        _cascadeValue(index, value);
      }
    }
  }

  void _cascadeValue(int fromIndex, String value) {
    for (int i = fromIndex + 1; i < _controllers.length; i++) {
      // Only cascade to fields that are completely empty (not user-edited, not auto-filled)
      if (!_userEditedIndices.contains(i) && !_autoFilledIndices.contains(i)) {
        _controllers[i].text = value;
        _autoFilledIndices.add(i);
      } else {
        break; // Stop at first filled field (either user or auto)
      }
    }
    _notifyChanged();
  }

  void _onFieldChanged(int index, String value) {
    // Mark this field as user-edited
    if (value.isNotEmpty) {
      _userEditedIndices.add(index);
      _autoFilledIndices.remove(index);
    } else {
      _userEditedIndices.remove(index);
    }
    _notifyChanged();
  }

  void _notifyChanged() {
    final values = _controllers.map((c) {
      return int.tryParse(c.text);
    }).toList();
    widget.onChanged?.call(values);
  }

  /// Get the current values as a list of integers
  List<int?> get values => _controllers.map((c) => int.tryParse(c.text)).toList();

  /// Fill all empty controllers with the given value
  void fillEmptyWith(int value) {
    for (int i = 0; i < _controllers.length; i++) {
      if (_controllers[i].text.isEmpty) {
        _controllers[i].text = value.toString();
        _autoFilledIndices.add(i);
      }
    }
    _notifyChanged();
  }

  /// Fill all controllers with the given value
  void fillAllWith(int value) {
    for (int i = 0; i < _controllers.length; i++) {
      _controllers[i].text = value.toString();
      _autoFilledIndices.add(i);
    }
    _userEditedIndices.clear();
    _notifyChanged();
  }

  /// Set all values from a list (used when loading saved per-set values)
  void setValues(List<int> values) {
    _userEditedIndices.clear();
    _autoFilledIndices.clear();
    for (int i = 0; i < _controllers.length && i < values.length; i++) {
      _controllers[i].text = values[i].toString();
      _userEditedIndices.add(i); // Treat loaded values as user-edited
    }
    // Clear any remaining controllers if values list is shorter
    for (int i = values.length; i < _controllers.length; i++) {
      _controllers[i].clear();
    }
    setState(() {});
    _notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_controllers.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 4),
        ..._buildSetFields(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Text(
      'Enter sets first',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[400],
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildLabel() {
    return Text(
      '${widget.label} per set:',
      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
    );
  }

  List<Widget> _buildSetFields() {
    return List.generate(_controllers.length, (index) {
      return _buildSetField(index);
    });
  }

  Widget _buildSetField(int index) {
    final isAutoFilled = _isAutoFilled(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _buildSetLabel(index),
          Expanded(child: _buildTextField(index, isAutoFilled)),
        ],
      ),
    );
  }

  bool _isAutoFilled(int index) {
    return _autoFilledIndices.contains(index) &&
        !_userEditedIndices.contains(index);
  }

  Widget _buildSetLabel(int index) {
    return SizedBox(
      width: 50,
      child: Text(
        'Set ${index + 1}:',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildTextField(int index, bool isAutoFilled) {
    return TextField(
      controller: _controllers[index],
      focusNode: _focusNodes[index],
      keyboardType: TextInputType.number,
      inputFormatters: [NonNegativeIntFormatter()],
      decoration: _buildFieldDecoration(isAutoFilled),
      onChanged: (v) => _onFieldChanged(index, v),
    );
  }

  InputDecoration _buildFieldDecoration(bool isAutoFilled) {
    return InputDecoration(
      hintText: widget.label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      fillColor: isAutoFilled ? Colors.grey[100] : null,
      filled: isAutoFilled,
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
}

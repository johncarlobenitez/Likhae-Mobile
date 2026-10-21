import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Price range control shared by the product catalog and seller store.
///
/// The slider and editable bounds update the same range.
class PriceRangeFilter extends StatefulWidget {
  final double minimum;
  final double maximum;
  final double selectedMinimum;
  final double selectedMaximum;
  final ValueChanged<RangeValues> onChanged;

  const PriceRangeFilter({
    super.key,
    required this.minimum,
    required this.maximum,
    required this.selectedMinimum,
    required this.selectedMaximum,
    required this.onChanged,
  });

  @override
  State<PriceRangeFilter> createState() => _PriceRangeFilterState();
}

class _PriceRangeFilterState extends State<PriceRangeFilter> {
  double get _minimum => widget.minimum.isFinite ? widget.minimum : 0;

  double get _maximum {
    final double candidate = widget.maximum.isFinite ? widget.maximum : 100000;
    return candidate > _minimum ? candidate : _minimum + 1;
  }

  RangeValues get _selected {
    final double rawLower = widget.selectedMinimum.isFinite
        ? widget.selectedMinimum
        : _minimum;
    final double rawUpper = widget.selectedMaximum.isFinite
        ? widget.selectedMaximum
        : _maximum;
    final double lower = rawLower.clamp(_minimum, _maximum).toDouble();
    final double upper = rawUpper.clamp(lower, _maximum).toDouble();
    return RangeValues(lower, upper);
  }

  String _format(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  Future<void> _editBound({required bool isMinimum}) async {
    final RangeValues current = _selected;
    final TextEditingController controller = TextEditingController(
      text: _format(isMinimum ? current.start : current.end),
    );
    final double? enteredValue = await showDialog<double>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(isMinimum ? 'Set minimum price' : 'Set maximum price'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '\u20B1 ',
          ),
          onSubmitted: (String value) {
            final double? parsed = double.tryParse(value.trim());
            if (parsed != null) Navigator.of(dialogContext).pop(parsed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final double? parsed = double.tryParse(controller.text.trim());
              if (parsed != null) Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || enteredValue == null) return;

    double lower = isMinimum
        ? enteredValue.clamp(_minimum, _maximum).toDouble()
        : current.start;
    double upper = isMinimum
        ? current.end
        : enteredValue.clamp(_minimum, _maximum).toDouble();
    if (lower > upper) {
      if (isMinimum) {
        upper = lower;
      } else {
        lower = upper;
      }
    }
    widget.onChanged(RangeValues(lower, upper));
  }

  @override
  Widget build(BuildContext context) {
    final RangeValues value = _selected;
    final Color accent = Theme.of(context).colorScheme.primary;
    final Color outline = Theme.of(context).colorScheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price range',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        RangeSlider(
          min: _minimum,
          max: _maximum,
          values: value,
          divisions: 100,
          labels: RangeLabels(_format(value.start), _format(value.end)),
          onChanged: widget.onChanged,
        ),
        Row(
          children: [
            Expanded(
              child: _priceBound(
                label: 'Minimum',
                value: value.start,
                accent: accent,
                outline: outline,
                onTap: () => _editBound(isMinimum: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _priceBound(
                label: 'Maximum',
                value: value.end,
                accent: accent,
                outline: outline,
                onTap: () => _editBound(isMinimum: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _priceBound({
    required String label,
    required double value,
    required Color accent,
    required Color outline,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(color: accent, fontSize: 10)),
                    const SizedBox(height: 3),
                    Text(
                      '\u20B1 ${_format(value)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 15, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

String? closestProductSuggestion(String query, Iterable<String> candidates) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.length < 3) return null;
  String? best;
  int bestDistance = 4;
  for (final String candidate in candidates) {
    final String value = candidate.trim();
    if (value.isEmpty) continue;
    final String lower = value.toLowerCase();
    if (lower.contains(normalized) || normalized.contains(lower)) continue;
    final List<String> words = value
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) continue;

    for (final String word in words) {
      final int distance = _editDistance(normalized, word.toLowerCase());
      final int threshold =
          ((normalized.length * 0.25).ceil()).clamp(1, 3).toInt();
      if (distance <= threshold && distance < bestDistance) {
        best = word;
        bestDistance = distance;
      }
    }
  }
  return best;
}

int _editDistance(String left, String right) {
  final List<List<int>> distances = List<List<int>>.generate(
    left.length + 1,
    (int row) => List<int>.filled(right.length + 1, 0),
  );
  for (int row = 0; row <= left.length; row++) {
    distances[row][0] = row;
  }
  for (int column = 0; column <= right.length; column++) {
    distances[0][column] = column;
  }

  for (int row = 1; row <= left.length; row++) {
    for (int column = 1; column <= right.length; column++) {
      final int substitution =
          distances[row - 1][column - 1] +
          (left.codeUnitAt(row - 1) == right.codeUnitAt(column - 1) ? 0 : 1);
      distances[row][column] = <int>[
        distances[row][column - 1] + 1,
        distances[row - 1][column] + 1,
        substitution,
      ].reduce((int a, int b) => a < b ? a : b);

      if (row > 1 &&
          column > 1 &&
          left.codeUnitAt(row - 1) == right.codeUnitAt(column - 2) &&
          left.codeUnitAt(row - 2) == right.codeUnitAt(column - 1)) {
        final int transposition = distances[row - 2][column - 2] + 1;
        if (transposition < distances[row][column]) {
          distances[row][column] = transposition;
        }
      }
    }
  }
  return distances[left.length][right.length];
}

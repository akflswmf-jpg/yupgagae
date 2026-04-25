import 'package:flutter/services.dart';

class PostComposeTextFormatter extends TextInputFormatter {
  const PostComposeTextFormatter();

  static const int _maxConsecutiveNewLines = 3;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    text = text.replaceFirst(RegExp(r'^\n+'), '');

    text = text.replaceAllMapped(
      RegExp(r'\n{4,}'),
      (_) => '\n' * _maxConsecutiveNewLines,
    );

    if (text == newValue.text) {
      return newValue;
    }

    final baseOffset = newValue.selection.baseOffset;
    final extentOffset = newValue.selection.extentOffset;
    final diff = newValue.text.length - text.length;

    final nextBase = (baseOffset - diff).clamp(0, text.length);
    final nextExtent = (extentOffset - diff).clamp(0, text.length);

    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: nextBase,
        extentOffset: nextExtent,
      ),
      composing: TextRange.empty,
    );
  }
}
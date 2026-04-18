import 'package:flutter/material.dart';

String formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y.$m.$d';
}

String formatMonth(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}';
}

String formatWeekRangeLabel(String rawLabel) {
  final parts = rawLabel.split('|');
  if (parts.length == 2) {
    return '${parts[0]} ~ ${parts[1]}';
  }
  return rawLabel;
}

String formatMoney(int value) {
  final text = value.toString();
  final buffer = StringBuffer();

  for (int i = 0; i < text.length; i++) {
    buffer.write(text[i]);
    final remaining = text.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
  }

  return '${buffer.toString()}원';
}

String formatCompactMoney(int value) {
  if (value >= 100000000) {
    final eok = value / 100000000;
    return '${eok.toStringAsFixed(eok % 1 == 0 ? 0 : 1)}억';
  }
  if (value >= 10000) {
    final man = value / 10000;
    return '${man.toStringAsFixed(man % 1 == 0 ? 0 : 1)}만';
  }
  return value.toString();
}

String formatDeltaRate(double? value) {
  if (value == null) return '비교 불가';
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}%';
}

String formatCompareDeltaText(double? value) {
  if (value == null) return '비교 데이터 없음';
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}%';
}

String formatWeekDeltaRate(int myTotal, int average) {
  if (average <= 0) return '업종 평균 없음';
  final delta = ((myTotal - average) / average) * 100;
  final sign = delta >= 0 ? '+' : '';
  return '$sign${delta.toStringAsFixed(1)}%';
}

Color deltaColor(double? value) {
  if (value == null) return const Color(0xFF6B7280);
  if (value > 0) return const Color(0xFFCC5A4E);
  if (value < 0) return const Color(0xFFD92D20);
  return const Color(0xFF6B7280);
}

Color weekDeltaColor(int myTotal, int average) {
  if (average <= 0) return const Color(0xFF6B7280);
  final delta = ((myTotal - average) / average) * 100;
  if (delta > 0) return const Color(0xFFCC5A4E);
  if (delta < 0) return const Color(0xFFD92D20);
  return const Color(0xFF6B7280);
}
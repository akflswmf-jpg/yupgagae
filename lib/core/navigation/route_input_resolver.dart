import 'package:get/get.dart';

class RouteInputResolver {
  const RouteInputResolver._();

  static Map<String, dynamic>? _argumentsMap() {
    final args = Get.arguments;

    if (args is Map) {
      final map = <String, dynamic>{};

      args.forEach((key, value) {
        if (key == null) return;
        map[key.toString()] = value;
      });

      return map;
    }

    return null;
  }

  /// String 값 추출 (arguments → parameters 순서)
  static String? string(String key) {
    final args = _argumentsMap();

    final argValue = args?[key];
    if (argValue != null) {
      final value = argValue.toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    final paramValue = Get.parameters[key];
    if (paramValue != null && paramValue.trim().isNotEmpty) {
      return paramValue.trim();
    }

    return null;
  }

  /// int 값 추출
  static int? intValue(String key) {
    final args = _argumentsMap();

    final argValue = args?[key];
    if (argValue is int) return argValue;
    if (argValue != null) {
      return int.tryParse(argValue.toString());
    }

    final paramValue = Get.parameters[key];
    if (paramValue != null) {
      return int.tryParse(paramValue);
    }

    return null;
  }

  /// bool 값 추출
  static bool? boolValue(String key) {
    final args = _argumentsMap();

    final argValue = args?[key];
    if (argValue is bool) return argValue;
    if (argValue != null) {
      final value = argValue.toString().trim().toLowerCase();
      if (value == 'true') return true;
      if (value == 'false') return false;
    }

    final paramValue = Get.parameters[key]?.trim().toLowerCase();
    if (paramValue == 'true') return true;
    if (paramValue == 'false') return false;

    return null;
  }
}
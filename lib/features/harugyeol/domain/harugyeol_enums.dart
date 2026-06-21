enum HarugyeolMood {
  slow,
  normal,
  good,
  great,
}

extension HarugyeolMoodX on HarugyeolMood {
  String get key {
    switch (this) {
      case HarugyeolMood.slow:
        return 'slow';
      case HarugyeolMood.normal:
        return 'normal';
      case HarugyeolMood.good:
        return 'good';
      case HarugyeolMood.great:
        return 'great';
    }
  }

  String get label {
    switch (this) {
      case HarugyeolMood.slow:
        return '한산';
      case HarugyeolMood.normal:
        return '무난';
      case HarugyeolMood.good:
        return '만족';
      case HarugyeolMood.great:
        return '대박';
    }
  }

  int get score {
    switch (this) {
      case HarugyeolMood.slow:
        return 10;
      case HarugyeolMood.normal:
        return 45;
      case HarugyeolMood.good:
        return 75;
      case HarugyeolMood.great:
        return 100;
    }
  }

  String get emoji {
    switch (this) {
      case HarugyeolMood.slow:
        return '💤';
      case HarugyeolMood.normal:
        return '🌿';
      case HarugyeolMood.good:
        return '☀️';
      case HarugyeolMood.great:
        return '🔥';
    }
  }

  String get shortDescription {
    switch (this) {
      case HarugyeolMood.slow:
        return '오늘은 조용했어요';
      case HarugyeolMood.normal:
        return '평소랑 비슷했어요';
      case HarugyeolMood.good:
        return '괜찮은 하루였어요';
      case HarugyeolMood.great:
        return '장사 잘 된 날이에요';
    }
  }
}

HarugyeolMood harugyeolMoodFromKey(String? value) {
  switch ((value ?? '').trim()) {
    case 'slow':
      return HarugyeolMood.slow;
    case 'normal':
      return HarugyeolMood.normal;
    case 'good':
      return HarugyeolMood.good;
    case 'great':
      return HarugyeolMood.great;
    default:
      return HarugyeolMood.normal;
  }
}

enum HarugyeolReason {
  economy,
  weekdayHoliday,
  delivery,
  localMood,
  event,
  groupGuest,
  rudeGuest,
  unexpectedGood,
  weather,
  etc,
}

extension HarugyeolReasonX on HarugyeolReason {
  String get key {
    switch (this) {
      case HarugyeolReason.economy:
        return 'economy';
      case HarugyeolReason.weekdayHoliday:
        return 'weekdayHoliday';
      case HarugyeolReason.delivery:
        return 'delivery';
      case HarugyeolReason.localMood:
        return 'localMood';
      case HarugyeolReason.event:
        return 'event';
      case HarugyeolReason.groupGuest:
        return 'groupGuest';
      case HarugyeolReason.rudeGuest:
        return 'rudeGuest';
      case HarugyeolReason.unexpectedGood:
        return 'unexpectedGood';
      case HarugyeolReason.weather:
        return 'weather';
      case HarugyeolReason.etc:
        return 'etc';
    }
  }

  String get label {
    switch (this) {
      case HarugyeolReason.economy:
        return '경기 영향';
      case HarugyeolReason.weekdayHoliday:
        return '연휴';
      case HarugyeolReason.delivery:
        return '배달';
      case HarugyeolReason.localMood:
        return '상권 분위기';
      case HarugyeolReason.event:
        return '행사/이벤트';
      case HarugyeolReason.groupGuest:
        return '단체손님';
      case HarugyeolReason.rudeGuest:
        return '진상';
      case HarugyeolReason.unexpectedGood:
        return '뜻밖의 선전';
      case HarugyeolReason.weather:
        return '날씨';
      case HarugyeolReason.etc:
        return '기타';
    }
  }
}

HarugyeolReason harugyeolReasonFromKey(String? value) {
  switch ((value ?? '').trim()) {
    case 'economy':
      return HarugyeolReason.economy;

    case 'weekday':
    case 'weekdayHoliday':
      return HarugyeolReason.weekdayHoliday;

    case 'deliveryDown':
    case 'delivery':
      return HarugyeolReason.delivery;

    case 'localMood':
      return HarugyeolReason.localMood;

    case 'event':
      return HarugyeolReason.event;

    case 'groupGuest':
      return HarugyeolReason.groupGuest;

    case 'rudeGuest':
      return HarugyeolReason.rudeGuest;

    case 'unexpectedGood':
      return HarugyeolReason.unexpectedGood;

    case 'weather':
      return HarugyeolReason.weather;

    case 'etc':
      return HarugyeolReason.etc;

    default:
      return HarugyeolReason.etc;
  }
}

enum HarugyeolSlot {
  midday,
  evening,
}

extension HarugyeolSlotX on HarugyeolSlot {
  String get key {
    switch (this) {
      case HarugyeolSlot.midday:
        return 'midday';
      case HarugyeolSlot.evening:
        return 'evening';
    }
  }

  String get label {
    switch (this) {
      case HarugyeolSlot.midday:
        return '낮 장사';
      case HarugyeolSlot.evening:
        return '저녁 장사';
    }
  }

  String get shortLabel {
    switch (this) {
      case HarugyeolSlot.midday:
        return '낮';
      case HarugyeolSlot.evening:
        return '저녁';
    }
  }

  String get timeLabel {
    switch (this) {
      case HarugyeolSlot.midday:
        return '오전 11시 ~ 오후 5시';
      case HarugyeolSlot.evening:
        return '오후 5시 1분 ~ 자정';
    }
  }

  String get resultTimeLabel {
    switch (this) {
      case HarugyeolSlot.midday:
        return '오전 11시 ~ 오후 5시';
      case HarugyeolSlot.evening:
        return '오후 5시 1분 ~ 자정';
    }
  }
}

HarugyeolSlot? harugyeolSlotFromKey(String? value) {
  switch ((value ?? '').trim()) {
    case 'midday':
      return HarugyeolSlot.midday;
    case 'evening':
      return HarugyeolSlot.evening;
    default:
      return null;
  }
}

List<HarugyeolSlot> availableHarugyeolInputSlots(DateTime now) {
  final minutes = (now.hour * 60) + now.minute;

  const middayStart = 11 * 60;
  const eveningStart = (17 * 60) + 1;
  const dayEnd = (23 * 60) + 59;

  if (minutes < middayStart || minutes > dayEnd) {
    return const <HarugyeolSlot>[];
  }

  if (minutes >= eveningStart) {
    return const <HarugyeolSlot>[
      HarugyeolSlot.midday,
      HarugyeolSlot.evening,
    ];
  }

  return const <HarugyeolSlot>[
    HarugyeolSlot.midday,
  ];
}

HarugyeolSlot? currentHarugyeolSlot(DateTime now) {
  final minutes = (now.hour * 60) + now.minute;

  const middayStart = 11 * 60;
  const middayEnd = 17 * 60;
  const eveningStart = (17 * 60) + 1;
  const eveningEnd = (23 * 60) + 59;

  if (minutes >= middayStart && minutes <= middayEnd) {
    return HarugyeolSlot.midday;
  }

  if (minutes >= eveningStart && minutes <= eveningEnd) {
    return HarugyeolSlot.evening;
  }

  return null;
}
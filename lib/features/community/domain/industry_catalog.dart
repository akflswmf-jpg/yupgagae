import 'package:flutter/material.dart';

class IndustryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const IndustryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class IndustryCatalog {
  static const List<IndustryItem> items = [
    IndustryItem(
      id: 'food_delivery',
      name: '요식업',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFE86A33),
    ),
    IndustryItem(
      id: 'cafe_bakery',
      name: '카페/제과',
      icon: Icons.local_cafe_rounded,
      color: Color(0xFF6F4E37),
    ),
    IndustryItem(
      id: 'pub_bar',
      name: '주점/바',
      icon: Icons.wine_bar_rounded,
      color: Color(0xFF8D3C3C),
    ),
    IndustryItem(
      id: 'beauty_hair',
      name: '뷰티/헤어',
      icon: Icons.content_cut_rounded,
      color: Color(0xFFA8B0B8),
    ),
    IndustryItem(
      id: 'hospital_clinic',
      name: '병원/의원',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFF2E7D32),
    ),
    IndustryItem(
      id: 'academy_lesson',
      name: '학원/레슨',
      icon: Icons.school_rounded,
      color: Color(0xFF283593),
    ),
    IndustryItem(
      id: 'fitness',
      name: '헬스/피트니스',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFF1565C0),
    ),
    IndustryItem(
      id: 'retail_clothing',
      name: '도소매/의류',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFF9A825),
    ),
    IndustryItem(
      id: 'agriculture_livestock',
      name: '농축산물',
      icon: Icons.grass_rounded,
      color: Color(0xFF558B2F),
    ),
    IndustryItem(
      id: 'distribution_logistics',
      name: '유통업',
      icon: Icons.local_shipping_rounded,
      color: Color(0xFF5D6D7E),
    ),
    IndustryItem(
      id: 'it_digital',
      name: 'IT/디지털',
      icon: Icons.devices_rounded,
      color: Color(0xFF3949AB),
    ),
    IndustryItem(
      id: 'lodging',
      name: '숙박업',
      icon: Icons.hotel_rounded,
      color: Color(0xFF00838F),
    ),
    IndustryItem(
      id: 'unmanned',
      name: '편의점/무인점',
      icon: Icons.smart_toy_rounded,
      color: Color(0xFF546E7A),
    ),
    IndustryItem(
      id: 'pet_shop',
      name: '반려동물/애견샵',
      icon: Icons.pets_rounded,
      color: Color(0xFF6A1B9A),
    ),
    IndustryItem(
      id: 'etc',
      name: '기타',
      icon: Icons.category_rounded,
      color: Color(0xFF78909C),
    ),
  ];

  static List<IndustryItem> ordered() => List<IndustryItem>.from(items);

  static List<String> get orderedIds => items.map((e) => e.id).toList();

  static IndustryItem? byId(String? id) {
    if (id == null || id.isEmpty) return null;

    for (final x in items) {
      if (x.id == id) return x;
    }

    return null;
  }

  static IndustryItem? byName(String? name) {
    final normalized = name?.trim();

    if (normalized == null || normalized.isEmpty) return null;

    for (final x in items) {
      if (x.name == normalized) return x;
    }

    return null;
  }

  static bool isValidName(String? name) {
    return byName(name) != null;
  }

  static String nameOf(String? id, {String fallback = '전체'}) {
    return byId(id)?.name ?? fallback;
  }

  static IconData iconOf(String? id, {IconData fallback = Icons.work_rounded}) {
    return byId(id)?.icon ?? fallback;
  }

  static Color colorOf(String? id, {Color fallback = const Color(0xFF757575)}) {
    return byId(id)?.color ?? fallback;
  }
}
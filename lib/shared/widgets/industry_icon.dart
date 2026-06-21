import 'package:flutter/material.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';

class IndustryIcon extends StatelessWidget {
  final String? industryId;
  final double size;

  const IndustryIcon({
    super.key,
    required this.industryId,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      IndustryCatalog.iconOf(industryId),
      size: size,
      color: IndustryCatalog.colorOf(industryId),
    );
  }
}
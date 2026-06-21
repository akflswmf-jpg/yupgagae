import 'package:flutter/material.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';

const Color kMetaTextColor = Color(0xFF6B7280);
const Color kMetaTimeColor = Color(0xFF9CA3AF);
const Color kMetaDividerColor = Color(0xFFB0B8C1);
const Color kMetaOwnerBadgeRing = Color(0xFFD9B8A4);

const String kWithdrawnAuthorLabel = '탈퇴한 사용자';

class AuthorMetaLine extends StatelessWidget {
  final String? industryId;
  final String? locationLabel;
  final String nicknameLabel;
  final String timeLabel;
  final bool isOwnerVerified;
  final bool dense;

  const AuthorMetaLine({
    super.key,
    required this.industryId,
    required this.locationLabel,
    required this.nicknameLabel,
    required this.timeLabel,
    this.isOwnerVerified = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final rawNickname = nicknameLabel.trim();
    final isWithdrawnAuthor = rawNickname == kWithdrawnAuthorLabel;

    final item = (industryId == null || industryId!.trim().isEmpty)
        ? null
        : IndustryCatalog.byId(industryId!.trim());

    final nickname = rawNickname.isEmpty ? '익명' : rawNickname;
    final industryName = item?.name.trim() ?? '';
    final location = locationLabel?.trim() ?? '';
    final time = timeLabel.trim();

    final hasIndustry = !isWithdrawnAuthor && item != null && industryName.isNotEmpty;
    final hasLocation = !isWithdrawnAuthor && location.isNotEmpty;
    final hasTime = time.isNotEmpty;
    final showOwnerVerified = !isWithdrawnAuthor && isOwnerVerified;

    final nicknameFontSize = dense ? 12.8 : 13.4;
    final metaFontSize = dense ? 12.0 : 12.5;
    final timeFontSize = dense ? 11.6 : 12.1;
    final industryIconSize = dense ? 12.5 : 13.5;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: isWithdrawnAuthor
                    ? _WithdrawnAuthorPill(dense: dense)
                    : Text(
                        nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: nicknameFontSize,
                          color: const Color(0xFF4B5563),
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
              ),
              if (showOwnerVerified) ...[
                const SizedBox(width: 4),
                _OwnerVerifiedBadge(dense: dense),
              ],
              if (hasIndustry || hasLocation) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: _MetaFlow(
                    hasIndustry: hasIndustry,
                    hasLocation: hasLocation,
                    industryIcon: item?.icon,
                    industryColor: item?.color,
                    industryName: industryName,
                    location: location,
                    iconSize: industryIconSize,
                    fontSize: metaFontSize,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasTime) ...[
          const SizedBox(width: 4),
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: timeFontSize,
              color: kMetaTimeColor,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ],
    );
  }
}

class _WithdrawnAuthorPill extends StatelessWidget {
  final bool dense;

  const _WithdrawnAuthorPill({
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = dense ? 10.8 : 11.2;
    final horizontalPadding = dense ? 6.0 : 7.0;
    final verticalPadding = dense ? 2.0 : 2.5;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: const Text(
        kWithdrawnAuthorLabel,
        maxLines: 1,
        overflow: TextOverflow.visible,
        softWrap: false,
        style: TextStyle(
          fontSize: 11,
          color: Color(0xFF9CA3AF),
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _MetaFlow extends StatelessWidget {
  final bool hasIndustry;
  final bool hasLocation;
  final IconData? industryIcon;
  final Color? industryColor;
  final String industryName;
  final String location;
  final double iconSize;
  final double fontSize;

  const _MetaFlow({
    required this.hasIndustry,
    required this.hasLocation,
    required this.industryIcon,
    required this.industryColor,
    required this.industryName,
    required this.location,
    required this.iconSize,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasIndustry)
          Flexible(
            flex: 3,
            fit: FlexFit.loose,
            child: Text(
              industryName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: fontSize,
                color: kMetaTextColor,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        if (hasIndustry) ...[
          const SizedBox(width: 3),
          Icon(
            industryIcon,
            size: iconSize,
            color: industryColor,
          ),
        ],
        if (hasIndustry && hasLocation)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '·',
              style: TextStyle(
                fontSize: fontSize,
                color: kMetaDividerColor,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
        if (hasLocation)
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: fontSize,
                color: kMetaTextColor,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
      ],
    );
  }
}

class _OwnerVerifiedBadge extends StatelessWidget {
  final bool dense;

  const _OwnerVerifiedBadge({
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final size = dense ? 18.0 : 20.0;
    final iconSize = dense ? 11.0 : 12.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFA56B54),
            Color(0xFF7E4E3D),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1E875646),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: kMetaOwnerBadgeRing,
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: iconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../services/badges_service.dart';
import '../../services/language_service.dart';

class BadgesScreen extends StatelessWidget {
  final int userDays;

  const BadgesScreen({super.key, required this.userDays});

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    final isDark = lang.isDarkMode;
    final all = BadgesService.allBadges;
    final earned = BadgesService.getEarnedBadges(userDays);
    final next = BadgesService.getNextBadge(userDays);
    final highest = BadgesService.getHighestBadge(userDays);
    final background =
        isDark ? const Color(0xFF101C2B) : const Color(0xFFF6FAF9);
    final surface = isDark ? const Color(0xFF17283A) : Colors.white;
    final primary = const Color(0xFF0D9488);

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          title: Text(_title(lang),
              style:
                  lang.getTextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context)),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(
                  child: Text('${earned.length}/${all.length}',
                      style: lang.getTextStyle(
                          color: primary, fontWeight: FontWeight.w800))),
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: primary.withOpacity(.18)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: primary.withOpacity(.12),
                                  shape: BoxShape.circle),
                              child: Icon(Icons.workspace_premium_rounded,
                                  color: primary, size: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('${earned.length} ${_earnedLabel(lang)}',
                                    style: lang.getTextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                Text('${userDays} ${_daysLabel(lang)}',
                                    style: lang.getTextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF64748B))),
                              ])),
                          if (highest != null) _badgeArtwork(highest, 48),
                        ]),
                        if (next != null) ...[
                          const SizedBox(height: 18),
                          Text('${_nextLabel(lang)}: ${_name(next, lang)}',
                              style: lang.getTextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: primary)),
                          const SizedBox(height: 8),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                  value: (userDays / next.daysRequired)
                                      .clamp(0.0, 1.0),
                                  minHeight: 8,
                                  backgroundColor: primary.withOpacity(.12),
                                  valueColor:
                                      AlwaysStoppedAnimation(primary))),
                          const SizedBox(height: 6),
                          Text(
                              '${next.daysRequired - userDays} ${_remainingLabel(lang)}',
                              style: lang.getTextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white54
                                      : const Color(0xFF64748B))),
                        ],
                      ]),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _badgeCard(all[index], lang, isDark, surface),
                    childCount: all.length),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.sizeOf(context).width < 700 ? 1 : 2,
                    mainAxisExtent:
                        MediaQuery.sizeOf(context).width < 700 ? 390 : 350,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeCard(AchievementBadge badge, LanguageService lang, bool isDark,
      Color surface) {
    final unlocked = userDays >= badge.daysRequired;
    final progress = (userDays / badge.daysRequired).clamp(0.0, 1.0);
    final color = unlocked
        ? badge.color
        : (isDark ? Colors.white38 : const Color(0xFF94A3B8));
    return Opacity(
      opacity: unlocked ? 1 : .58,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(.28))),
        child: Column(children: [
          Align(
              alignment: AlignmentDirectional.topEnd,
              child: Icon(
                  unlocked
                      ? Icons.check_circle_rounded
                      : Icons.lock_outline_rounded,
                  color: color,
                  size: 18)),
          const SizedBox(height: 2),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => _badgeArtwork(
                badge,
                constraints.maxWidth,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(_name(badge, lang),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  lang.getTextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${badge.daysRequired} ${_daysLabel(lang)}',
              style: lang.getTextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          const Spacer(),
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: color.withOpacity(.12),
                  valueColor: AlwaysStoppedAnimation(color))),
          const SizedBox(height: 5),
          Text(
              unlocked
                  ? _unlockedLabel(lang)
                  : '${badge.daysRequired - userDays} ${_remainingLabel(lang)}',
              style: lang.getTextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B))),
        ]),
      ),
    );
  }

  String _name(AchievementBadge badge, LanguageService lang) =>
      lang.currentLanguage == AppLanguage.kurdish
          ? badge.nameKu
          : lang.currentLanguage == AppLanguage.arabic
              ? badge.nameAr
              : badge.nameEn;

  // Each milestone gets its own emblem, icon, palette and ornamental pattern.
  Widget _badgeArtwork(AchievementBadge badge, double size) {
    if (badge.artwork != null) {
      return Image.asset(
        'assets/images/${badge.artwork!}',
        fit: BoxFit.contain,
        width: size,
        height: size,
      );
    }
    final color = badge.color;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: size * .82,
              height: size * .82,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                border: Border.all(color: color.withOpacity(.72), width: 1.5),
                borderRadius: BorderRadius.circular(size * .18),
              ),
            ),
          ),
          Container(
            width: size * .78,
            height: size * .78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                  colors: [color.withOpacity(.32), color.withOpacity(.08)]),
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(color: color.withOpacity(.28), blurRadius: size * .22)
              ],
            ),
          ),
          Icon(badge.icon, color: color, size: size * .43),
          Positioned(
              top: 1,
              child: Icon(Icons.star_rounded, color: color, size: size * .18)),
          Positioned(
              bottom: 1,
              left: size * .06,
              child: Icon(Icons.auto_awesome,
                  color: color.withOpacity(.8), size: size * .15)),
          Positioned(
              bottom: 1,
              right: size * .06,
              child: Icon(Icons.auto_awesome,
                  color: color.withOpacity(.8), size: size * .15)),
        ],
      ),
    );
  }

  String _title(LanguageService l) => l.currentLanguage == AppLanguage.kurdish
      ? 'ئۆسمەکان'
      : l.currentLanguage == AppLanguage.arabic
          ? 'الأوسمة'
          : 'Badges';
  String _earnedLabel(LanguageService l) =>
      l.currentLanguage == AppLanguage.kurdish
          ? 'ئۆسمەی بەدەستهێنراو'
          : l.currentLanguage == AppLanguage.arabic
              ? 'وسام مكتسب'
              : 'badges earned';
  String _nextLabel(LanguageService l) =>
      l.currentLanguage == AppLanguage.kurdish
          ? 'ئامانجی داهاتوو'
          : l.currentLanguage == AppLanguage.arabic
              ? 'الهدف القادم'
              : 'Next milestone';
  String _daysLabel(LanguageService l) =>
      l.currentLanguage == AppLanguage.kurdish
          ? 'ڕۆژ'
          : l.currentLanguage == AppLanguage.arabic
              ? 'يوم'
              : 'days';
  String _remainingLabel(LanguageService l) =>
      l.currentLanguage == AppLanguage.kurdish
          ? 'ڕۆژ ماوە'
          : l.currentLanguage == AppLanguage.arabic
              ? 'يوم متبقي'
              : 'days left';
  String _unlockedLabel(LanguageService l) =>
      l.currentLanguage == AppLanguage.kurdish
          ? 'کراوەتەوە'
          : l.currentLanguage == AppLanguage.arabic
              ? 'مفتوح'
              : 'Unlocked';
}

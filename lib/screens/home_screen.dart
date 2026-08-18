import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/timer_service.dart';
import '../services/quotes_service.dart';
import '../services/badges_service.dart';
import '../services/tips_service.dart';
import 'settings_screen.dart';
import 'leaderboard_screen.dart';
import 'tips_screen.dart';
import 'webview_screen.dart';
import 'breathing_exercise_screen.dart';
import 'stories_screen.dart';
import 'commitment_screen.dart';
import 'journal_screen.dart';
import 'habits_screen.dart';
import 'tracking_screen.dart';
import 'library_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/timer_widget.dart';
import '../widgets/welcome_message_widget.dart';
import 'accountability_screen.dart';
import 'challenge_screen.dart';
import 'assessment_screen.dart';
import 'roadmap_screen.dart';
import 'components/certificates_screen.dart';
import '../services/analytics_service.dart';
import '../services/announcements_service.dart';
import '../services/notification_service.dart';
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Future<void> _launchExternalUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not launch')));
      }
    }
  }

  final _authService = AuthService();
  final _timerService = RecoveryTimerService();
  final _quotesService = QuotesService();
  final _tipsService = TipsService();
  final _analyticsService = AnalyticsService();
  final _announcementsService = AnnouncementsService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Timer? _timer;
  Timer? _quoteTimer; // NEW: Timer for quotes slideshow
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isTipsExpanded = false; // Tips collapsed by default
  List<Map<String, double>>? _starPositions; // Cached star positions

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Request notification permissions safely after UI has rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().requestPermissions().catchError(
            (e) => debugPrint('Error requesting notification perms: $e'),
          );
    });

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _timerService.loadStartDate();
      await _quotesService.loadQuotes();
      await _tipsService.loadTips();
      await _announcementsService.init(); // Load announcements
      _analyticsService.trackUserActivity(); // Track user visit

      bool hasInternet = false;
      try {
        final result = await InternetAddress.lookup(
          'google.com',
        ).timeout(const Duration(seconds: 2));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          hasInternet = true;
        }
      } catch (_) {}

      if (hasInternet) {
        // Updated: Removed Google Play update check
      }

      _startTimer();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('HomeScreen _loadData error: $e');
    }
  }

  void _startTimer() {
    // Main timer moved to RecoveryTimerWidget for performance
    // Only quote slideshow timer remains here

    // Quote Slideshow (every 15 seconds for better performance)
    _quoteTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _quotesService.nextQuote();
        // Don't call setState here - timer already updates every second
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();

    _timer?.cancel();
    _quoteTimer?.cancel(); // NEW: Cancel quote timer
    super.dispose();
  }

  String _getUserName(LanguageService lang) {
    final user = _authService.currentUser;
    if (user == null) return lang.guest;
    if (user.isAnonymous) return lang.guest;
    return user.displayName ?? user.email?.split('@').first ?? lang.guest;
  }

  String _getLeaderboardTitle(LanguageService lang) {
    switch (lang.currentLanguage) {
      case AppLanguage.arabic:
        return 'لوحة الصدارة';
      case AppLanguage.kurdish:
        return 'پلەی پێشەوان';
      case AppLanguage.english:
        return 'Leaderboard';
    }
  }

  void _showBadgesDialog(LanguageService lang) {
    final isDark = lang.isDarkMode;
    final allBadges = BadgesService.allBadges;
    final userDays = _timerService.totalDays;
    final earnedBadges = BadgesService.getEarnedBadges(userDays);

    // Find highest earned and next badges
    final currentBadge = BadgesService.getHighestBadge(userDays);
    final nextBadge = BadgesService.getNextBadge(userDays);
    final daysUntilNext = BadgesService.daysUntilNextBadge(userDays);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: lang.textDirection,
          child: Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFA),
            appBar: AppBar(
              backgroundColor:
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
              elevation: 0,
              centerTitle: false,
              leading: IconButton(
                icon: Icon(
                  lang.isRTL
                      ? Icons.arrow_forward_ios
                      : Icons.arrow_back_ios_new,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                lang.currentLanguage == AppLanguage.kurdish
                    ? 'ئۆسمەکان'
                    : lang.currentLanguage == AppLanguage.arabic
                        ? 'الأوسمة'
                        : 'Badges',
                style: lang.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${earnedBadges.length}/${allBadges.length}',
                      style: lang.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                      : [const Color(0xFFF8FAFA), const Color(0xFFF0FBF9)],
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  // 1. Top progress summary card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF1E293B),
                                    const Color(0xFF0F172A),
                                  ]
                                : [Colors.white, const Color(0xFFFFFFFF)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.teal.withOpacity(0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(
                                isDark ? 0.05 : 0.08,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.currentLanguage ==
                                              AppLanguage.kurdish
                                          ? 'ئاستی ئێستات'
                                          : lang.currentLanguage ==
                                                  AppLanguage.arabic
                                              ? 'مستواك الحالي'
                                              : 'Your Current Milestone',
                                      style: lang.getTextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentBadge != null
                                          ? (lang.currentLanguage ==
                                                  AppLanguage.kurdish
                                              ? currentBadge.nameKu
                                              : lang.currentLanguage ==
                                                      AppLanguage.arabic
                                                  ? currentBadge.nameAr
                                                  : currentBadge.nameEn)
                                          : (lang.currentLanguage ==
                                                  AppLanguage.kurdish
                                              ? 'سەرەتا'
                                              : lang.currentLanguage ==
                                                      AppLanguage.arabic
                                                  ? 'البداية'
                                                  : 'Beginner'),
                                      style: lang.getTextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: currentBadge?.color ??
                                            (isDark
                                                ? Colors.white
                                                : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (currentBadge?.color ?? Colors.teal)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          (currentBadge?.color ?? Colors.teal)
                                              .withOpacity(0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.local_fire_department,
                                        color: currentBadge?.color ??
                                            const Color(0xFFFF9800),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$userDays ${lang.currentLanguage == AppLanguage.kurdish ? "ڕۆژ" : lang.currentLanguage == AppLanguage.arabic ? "يوم" : "Days"}',
                                        style: lang.getTextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (nextBadge != null) ...[
                              const SizedBox(height: 20),
                              // Progress bar
                              Builder(
                                builder: (context) {
                                  final currentBase =
                                      currentBadge?.daysRequired ?? 0;
                                  final nextTarget = nextBadge.daysRequired;
                                  final range = nextTarget - currentBase;
                                  final progressInRange =
                                      userDays - currentBase;
                                  final progressPercent =
                                      (progressInRange / range).clamp(0.0, 1.0);

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            lang.currentLanguage ==
                                                    AppLanguage.kurdish
                                                ? 'ئۆسمەی داهاتوو: ${nextBadge.nameKu}'
                                                : lang.currentLanguage ==
                                                        AppLanguage.arabic
                                                    ? 'الوسام القادم: ${nextBadge.nameAr}'
                                                    : 'Next Badge: ${nextBadge.nameEn}',
                                            style: lang.getTextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                            ),
                                          ),
                                          Text(
                                            '${(progressPercent * 100).toInt()}%',
                                            style: lang.getTextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: nextBadge.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: progressPercent,
                                          minHeight: 10,
                                          backgroundColor: isDark
                                              ? Colors.white.withOpacity(0.08)
                                              : Colors.teal.withOpacity(0.05),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            nextBadge.color,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.event,
                                            size: 14,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black38,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            lang.currentLanguage ==
                                                    AppLanguage.kurdish
                                                ? '$daysUntilNext ڕۆژ ماوە بۆ بەدەستهێنانی'
                                                : lang.currentLanguage ==
                                                        AppLanguage.arabic
                                                    ? 'متبقي $daysUntilNext يوم للحصول عليه'
                                                    : '$daysUntilNext days remaining to achieve',
                                            style: lang.getTextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? Colors.white60
                                                  : Colors.black54,
                                            ),
                                          ),
                                          if (_timerService.startDate !=
                                              null) ...[
                                            const Spacer(),
                                            Builder(
                                              builder: (_) {
                                                final startDate =
                                                    _timerService.startDate!;
                                                final bonusDays =
                                                    _timerService.bonusDays;
                                                final effectiveStartDate =
                                                    startDate.subtract(
                                                  Duration(days: bonusDays),
                                                );
                                                final unlockDate =
                                                    effectiveStartDate.add(
                                                  Duration(
                                                    days:
                                                        nextBadge.daysRequired,
                                                  ),
                                                );
                                                String dateStr;
                                                if (unlockDate.year >= 2024) {
                                                  dateStr =
                                                      '${unlockDate.day.toString().padLeft(2, '0')}/${unlockDate.month.toString().padLeft(2, '0')}/${unlockDate.year}';
                                                } else {
                                                  dateStr = '---';
                                                }
                                                return Text(
                                                  '📅 $dateStr',
                                                  style: lang.getTextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: nextBadge.color
                                                        .withOpacity(0.8),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ] else ...[
                              const SizedBox(height: 16),
                              Text(
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? '🎉 تۆ هەموو ئۆسمەکانت بەدەستهێناوە! پیرۆزە!'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? '🎉 لقد حصلت على جميع الأوسمة! تهانينا!'
                                        : '🎉 You have achieved all badges! Congratulations!',
                                style: lang.getTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Badges Grid
                  SliverPadding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom: 120,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final badge = allBadges[index];
                        final isUnlocked = userDays >= badge.daysRequired;
                        final name = lang.currentLanguage == AppLanguage.kurdish
                            ? badge.nameKu
                            : lang.currentLanguage == AppLanguage.arabic
                                ? badge.nameAr
                                : badge.nameEn;
                        final displayColor =
                            isUnlocked ? badge.color : Colors.grey;

                        // Level Translation
                        String levelName = '';
                        if (badge.level == 'beginner') {
                          levelName =
                              lang.currentLanguage == AppLanguage.kurdish
                                  ? 'سەرەتایی'
                                  : lang.currentLanguage == AppLanguage.arabic
                                      ? 'مبتدئ'
                                      : 'Beginner';
                        } else if (badge.level == 'intermediate') {
                          levelName =
                              lang.currentLanguage == AppLanguage.kurdish
                                  ? 'ناوەند'
                                  : lang.currentLanguage == AppLanguage.arabic
                                      ? 'متوسط'
                                      : 'Intermediate';
                        } else if (badge.level == 'advanced') {
                          levelName =
                              lang.currentLanguage == AppLanguage.kurdish
                                  ? 'پێشکەوتوو'
                                  : lang.currentLanguage == AppLanguage.arabic
                                      ? 'متقدم'
                                      : 'Advanced';
                        } else if (badge.level == 'master') {
                          levelName =
                              lang.currentLanguage == AppLanguage.kurdish
                                  ? 'ماستەر'
                                  : lang.currentLanguage == AppLanguage.arabic
                                      ? 'ماستر'
                                      : 'Master';
                        } else {
                          levelName =
                              lang.currentLanguage == AppLanguage.kurdish
                                  ? 'ئەفسانەیی'
                                  : lang.currentLanguage == AppLanguage.arabic
                                      ? 'أسطوري'
                                      : 'Legend';
                        }

                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      isUnlocked
                                          ? displayColor.withOpacity(0.18)
                                          : Colors.white.withOpacity(0.02),
                                      isUnlocked
                                          ? displayColor.withOpacity(0.04)
                                          : Colors.white.withOpacity(0.01),
                                    ]
                                  : [
                                      isUnlocked
                                          ? displayColor.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.05),
                                      isUnlocked
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.8),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isUnlocked
                                  ? displayColor.withOpacity(0.4)
                                  : (isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.grey.withOpacity(0.2)),
                              width: isUnlocked ? 2 : 1,
                            ),
                            boxShadow: isUnlocked
                                ? [
                                    BoxShadow(
                                      color: displayColor.withOpacity(
                                        isDark ? 0.15 : 0.08,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Stack(
                            children: [
                              // Level tag
                              Positioned(
                                top: 10,
                                left: lang.isRTL ? null : 10,
                                right: lang.isRTL ? 10 : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUnlocked
                                        ? displayColor.withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    levelName,
                                    style: lang.getTextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isUnlocked
                                          ? displayColor
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              // Main Content
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  34,
                                  12,
                                  12,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Animated/glowing badge icon
                                    Center(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          if (isUnlocked)
                                            Container(
                                              width: 72,
                                              height: 72,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: displayColor
                                                        .withOpacity(0.4),
                                                    blurRadius: 16,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: isUnlocked
                                                    ? [
                                                        displayColor,
                                                        displayColor
                                                            .withOpacity(0.7),
                                                      ]
                                                    : [
                                                        Colors.grey.shade400,
                                                        Colors.grey.shade500,
                                                      ],
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: ColorFiltered(
                                              colorFilter: isUnlocked
                                                  ? const ColorFilter.mode(
                                                      Colors.transparent,
                                                      BlendMode.multiply,
                                                    )
                                                  : const ColorFilter.matrix(
                                                      <double>[
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        0.6,
                                                        0,
                                                      ],
                                                    ),
                                              child: Image.asset(
                                                badge.artwork == null
                                                    ? 'assets/images/badge_level_${badge.level}.png'
                                                    : 'assets/images/${badge.artwork}',
                                                width: 42,
                                                height: 42,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                          if (!isUnlocked)
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade700,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF0F172A,
                                                          )
                                                        : const Color(
                                                            0xFFF8FAFA,
                                                          ),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.lock,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      name,
                                      style: lang.getTextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isUnlocked
                                            ? (isDark
                                                ? Colors.white
                                                : Colors.black87)
                                            : Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    // Days required pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isUnlocked
                                            ? displayColor.withOpacity(0.12)
                                            : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${badge.daysRequired} ${lang.currentLanguage == AppLanguage.kurdish ? "ڕۆژ" : lang.currentLanguage == AppLanguage.arabic ? "يوم" : "days"}',
                                        style: lang.getTextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isUnlocked
                                              ? displayColor
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    // Mini progress bar for locked badges
                                    if (!isUnlocked) ...[
                                      const SizedBox(height: 8),
                                      Builder(
                                        builder: (context) {
                                          final pct =
                                              (userDays / badge.daysRequired)
                                                  .clamp(0.0, 1.0);
                                          return Column(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: pct,
                                                  minHeight: 4,
                                                  backgroundColor: isDark
                                                      ? Colors.white
                                                          .withOpacity(0.05)
                                                      : Colors.grey.withOpacity(
                                                          0.1,
                                                        ),
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Colors.grey.shade400),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${(pct * 100).toInt()}%',
                                                style: lang.getTextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade500,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                    if (isUnlocked &&
                                        _timerService.startDate != null) ...[
                                      Builder(
                                        builder: (_) {
                                          final startDate =
                                              _timerService.startDate!;
                                          final bonusDays =
                                              _timerService.bonusDays;
                                          final effectiveStartDate =
                                              startDate.subtract(
                                            Duration(days: bonusDays),
                                          );
                                          final unlockDate =
                                              effectiveStartDate.add(
                                            Duration(
                                              days: badge.daysRequired,
                                            ),
                                          );
                                          if (unlockDate.year < 2024)
                                            return const SizedBox.shrink();
                                          final dateStr =
                                              '${unlockDate.day.toString().padLeft(2, '0')}/${unlockDate.month.toString().padLeft(2, '0')}/${unlockDate.year}';
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              '📅 $dateStr',
                                              style: lang.getTextStyle(
                                                fontSize: 9,
                                                color: isDark
                                                    ? Colors.white38
                                                    : Colors.black38,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }, childCount: allBadges.length),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAnnouncementsDialog(LanguageService lang) {
    final isDark = lang.isDarkMode;
    _announcementsService.markAllAsRead(); // Mark as read when opened
    if (mounted) setState(() {}); // Clear badge

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: isDark ? const Color(0xFF0a1628) : Colors.grey[100],
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1a2a4a) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  lang.currentLanguage == AppLanguage.kurdish
                      ? 'ئاگاداریەکان'
                      : lang.currentLanguage == AppLanguage.arabic
                          ? 'الإشعارات'
                          : 'Announcements',
                  style: lang.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            actions: [
              // Admin add button
              if (_announcementsService.isAdmin)
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  onPressed: () => _showAddAnnouncementDialog(lang),
                ),
            ],
          ),
          body: StreamBuilder<List<Announcement>>(
            stream: _announcementsService.getAnnouncementsStream(),
            builder: (context, snapshot) {
              // Handle error state - show empty instead of error
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🔔', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text(
                        lang.currentLanguage == AppLanguage.kurdish
                            ? 'هیچ ئاگادارییەک نییە'
                            : lang.currentLanguage == AppLanguage.arabic
                                ? 'لا توجد إشعارات'
                                : 'No announcements yet',
                        style: lang.getTextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Show loading only on first load with no data
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: isDark ? Colors.white : const Color(0xFF0D9488),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        lang.currentLanguage == AppLanguage.kurdish
                            ? 'چاوەڕوان بە...'
                            : lang.currentLanguage == AppLanguage.arabic
                                ? 'جاري التحميل...'
                                : 'Loading...',
                        style: lang.getTextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                );
              }
              final announcements = snapshot.data ?? [];
              if (announcements.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🔔', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text(
                        lang.currentLanguage == AppLanguage.kurdish
                            ? 'هیچ ئاگادارییەک نییە'
                            : lang.currentLanguage == AppLanguage.arabic
                                ? 'لا توجد إشعارات'
                                : 'No announcements yet',
                        style: lang.getTextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 120,
                ),
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final item = announcements[index];
                  final title = lang.currentLanguage == AppLanguage.kurdish
                      ? item.titleKu
                      : lang.currentLanguage == AppLanguage.arabic
                          ? item.titleAr
                          : item.titleEn;
                  final rawBody = lang.currentLanguage == AppLanguage.kurdish
                      ? item.bodyKu
                      : lang.currentLanguage == AppLanguage.arabic
                          ? item.bodyAr
                          : item.bodyEn;
                  final body = rawBody.replaceAll(
                    RegExp(r'<[^>]*>|&[^;]+;'),
                    '',
                  );

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 400 + (index * 100)),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) => Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: item.isImportant
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.red.withOpacity(0.25),
                                  Colors.orange.withOpacity(0.15),
                                  Colors.red.withOpacity(0.1),
                                ],
                              )
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? [
                                        const Color(0xFF2a3a5a),
                                        const Color(0xFF1a2a4a),
                                      ]
                                    : [Colors.white, Colors.grey[50]!],
                              ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: item.isImportant
                              ? Colors.red.withOpacity(0.5)
                              : (isDark ? Colors.white12 : Colors.grey[200]!),
                          width: item.isImportant ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: item.isImportant
                                ? Colors.red.withOpacity(0.2)
                                : (isDark
                                    ? Colors.black26
                                    : Colors.grey.withOpacity(0.15)),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with icon
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: item.isImportant
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFFF5252),
                                          Color(0xFFFF7043),
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          const Color(
                                            0xFF0D9488,
                                          ).withOpacity(0.8),
                                          const Color(
                                            0xFF0F766E,
                                          ).withOpacity(0.8),
                                        ],
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      item.isImportant
                                          ? Icons.warning_rounded
                                          : Icons.campaign_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      title.isNotEmpty ? title : 'Announcement',
                                      style: lang.getTextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Admin delete button
                                  if (_announcementsService.isAdmin)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white70,
                                        size: 22,
                                      ),
                                      onPressed: () => _announcementsService
                                          .deleteAnnouncement(item.id),
                                    ),
                                ],
                              ),
                            ),
                            // Body
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (body.isNotEmpty)
                                    Text(
                                      body,
                                      style: lang.getTextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                        height: 1.5,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatAnnouncementDate(
                                          item.createdAt,
                                          lang,
                                        ),
                                        style: lang.getTextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatAnnouncementDate(DateTime date, LanguageService lang) {
    final now = DateTime.now();
    var diff = now.difference(date);
    if (diff.isNegative) {
      diff = Duration.zero;
    }
    if (diff.inMinutes < 1)
      return lang.currentLanguage == AppLanguage.kurdish
          ? 'ئێستا'
          : lang.currentLanguage == AppLanguage.arabic
              ? 'الآن'
              : 'Just now';
    if (diff.inHours < 1)
      return '${diff.inMinutes} ${lang.currentLanguage == AppLanguage.kurdish ? "خولەک" : lang.currentLanguage == AppLanguage.arabic ? "دقيقة" : "min"}';
    if (diff.inDays < 1)
      return '${diff.inHours} ${lang.currentLanguage == AppLanguage.kurdish ? "کاتژمێر" : lang.currentLanguage == AppLanguage.arabic ? "ساعة" : "hr"}';
    return '${diff.inDays} ${lang.currentLanguage == AppLanguage.kurdish ? "ڕۆژ" : lang.currentLanguage == AppLanguage.arabic ? "يوم" : "days"}';
  }

  void _showAddAnnouncementDialog(LanguageService lang) {
    final titleEnController = TextEditingController();
    final titleArController = TextEditingController();
    final titleKuController = TextEditingController();
    final bodyEnController = TextEditingController();
    final bodyArController = TextEditingController();
    final bodyKuController = TextEditingController();
    bool isImportant = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'New Announcement',
                  style: lang.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: lang.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                // English
                _buildAnnouncementField('Title (EN)', titleEnController, lang),
                _buildAnnouncementField(
                  'Body (EN)',
                  bodyEnController,
                  lang,
                  maxLines: 3,
                ),
                // Arabic
                _buildAnnouncementField(
                  'العنوان (AR)',
                  titleArController,
                  lang,
                ),
                _buildAnnouncementField(
                  'المحتوى (AR)',
                  bodyArController,
                  lang,
                  maxLines: 3,
                ),
                // Kurdish
                _buildAnnouncementField(
                  'ناونیشان (KU)',
                  titleKuController,
                  lang,
                ),
                _buildAnnouncementField(
                  'ناوەڕۆک (KU)',
                  bodyKuController,
                  lang,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: isImportant,
                  onChanged: (v) =>
                      setModalState(() => isImportant = v ?? false),
                  title: Text(
                    'Important (Red highlight)',
                    style: lang.getTextStyle(
                      color: lang.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  activeColor: Colors.red,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleEnController.text.isEmpty &&
                          titleArController.text.isEmpty &&
                          titleKuController.text.isEmpty) return;
                      await _announcementsService.postAnnouncement(
                        titleEn: titleEnController.text,
                        titleAr: titleArController.text,
                        titleKu: titleKuController.text,
                        bodyEn: bodyEnController.text,
                        bodyAr: bodyArController.text,
                        bodyKu: bodyKuController.text,
                        isImportant: isImportant,
                      );
                      if (mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Post Announcement',
                      style: lang.getTextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementField(
    String label,
    TextEditingController controller,
    LanguageService lang, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: lang.getTextStyle(
          color: lang.isDarkMode ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: lang.getTextStyle(
            color: lang.isDarkMode ? Colors.white54 : Colors.black45,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: lang.isDarkMode ? Colors.white24 : Colors.grey[300]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0D9488)),
          ),
        ),
      ),
    );
  }

  void _showCertificatesDialog(LanguageService lang) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CertificatesScreen(
          userDays: _timerService.totalDays,
          userName: _getUserName(lang),
          startDate: _timerService.startDate,
        ),
      ),
    );
    return;
  }

  void _showTimerSettingsModal(LanguageService lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Directionality(
        textDirection: lang.textDirection,
        child: Container(
          decoration: BoxDecoration(
            color: lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: lang.isDarkMode ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4facfe).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.timer, color: Color(0xFF4facfe)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    lang.timerSettings,
                    style: lang.getTextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: lang.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildSettingsOption(
                icon: Icons.calendar_today_rounded,
                title: lang.setCustomDateTime,
                color: const Color(0xFF4facfe),
                lang: lang,
                onTap: () async {
                  // Don't pop yet - we need the context for pickers

                  // First pick date
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _timerService.startDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF4facfe),
                          surface: Color(0xFF1a2a4a),
                        ),
                      ),
                      child: child!,
                    ),
                  );

                  if (date == null) {
                    if (mounted) Navigator.pop(context); // User cancelled
                    return;
                  }

                  if (!mounted) return;

                  // Then pick time
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(
                      _timerService.startDate ?? DateTime.now(),
                    ),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF4facfe),
                          surface: Color(0xFF1a2a4a),
                        ),
                      ),
                      child: child!,
                    ),
                  );

                  if (time == null) {
                    if (mounted) Navigator.pop(context); // User cancelled
                    return;
                  }

                  // Save the new date/time
                  final dateTime = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                  await _timerService.setStartDate(dateTime);

                  // Now close modal and refresh
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildSettingsOption(
                icon: Icons.timer_rounded,
                title: lang.currentLanguage == AppLanguage.kurdish
                    ? 'نوسینی ژمارەی ڕۆژ و کاتژمێر'
                    : lang.currentLanguage == AppLanguage.arabic
                        ? 'إدخال عدد الأيام والساعات'
                        : 'Enter Days & Hours',
                color: const Color(0xFFD500F9),
                lang: lang,
                onTap: () {
                  Navigator.pop(context);
                  _showManualDaysInputDialog(lang);
                },
              ),
              const SizedBox(height: 12),
              _buildSettingsOption(
                icon: Icons.refresh_rounded,
                title: lang.resetToNow,
                color: Colors.orange,
                lang: lang,
                onTap: () {
                  Navigator.pop(context);
                  _showResetConfirmDialog(lang);
                },
              ),
              const SizedBox(height: 12),
              _buildSettingsOption(
                icon: Icons.wallpaper_rounded,
                title: lang.currentLanguage == AppLanguage.kurdish
                    ? 'گۆڕینی پاشبنەما'
                    : lang.currentLanguage == AppLanguage.arabic
                        ? 'تغيير الخلفية'
                        : 'Change Background',
                color: const Color(0xFF14B8A6),
                lang: lang,
                onTap: () {
                  Navigator.pop(context);
                  _showBackgroundPickerDialog(lang);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showBackgroundPickerDialog(LanguageService lang) {
    final isDark = lang.isDarkMode;
    final presets = [
      'assets/images/bright_nature_bg.png',
      'assets/images/timer_bg_nature1.png',
      'assets/images/timer_bg_nature2.png',
      'assets/images/timer_bg_nature3.png',
      'assets/images/timer_bg_nature4.png',
      'assets/images/timer_bg_nature5.png',
      'assets/images/timer_bg_solid1.png',
      'assets/images/timer_bg_solid2.png',
      'assets/images/timer_bg_solid3.png',
      'assets/images/timer_bg_nature6.png',
      'assets/images/timer_bg_nature7.png',
      'assets/images/timer_bg_nature8.png',
    ];

    String dialogTitle;
    String uploadText;
    switch (lang.currentLanguage) {
      case AppLanguage.kurdish:
        dialogTitle = 'پاشبنەمای عداد';
        uploadText = 'وێنەیەک هەڵبژێرە';
        break;
      case AppLanguage.arabic:
        dialogTitle = 'خلفية العداد';
        uploadText = 'اختر صورة';
        break;
      case AppLanguage.english:
        dialogTitle = 'Timer Background';
        uploadText = 'Pick an Image';
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentBg = _timerService.backgroundImagePath;
          return Directionality(
            textDirection: lang.textDirection,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1a2a4a) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF66BB6A).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.image_rounded,
                          color: Color(0xFF66BB6A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        dialogTitle,
                        style: lang.getTextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: presets.length,
                      itemBuilder: (context, index) {
                        final preset = presets[index];
                        final isSelected = currentBg == preset;
                        return GestureDetector(
                          onTap: () async {
                            await _timerService.setBackgroundImage(preset);
                            setModalState(() {});
                            setState(() {});
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4facfe)
                                    : (isDark
                                        ? Colors.white12
                                        : Colors.grey[300]!),
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF4facfe,
                                        ).withOpacity(0.3),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    preset,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.low,
                                  ),
                                  if (isSelected)
                                    Container(
                                      color: Colors.black.withOpacity(0.3),
                                      child: const Center(
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Upload from gallery button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 70,
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            final base64Str = base64Encode(bytes);
                            final dataUri = 'data:image/jpeg;base64,$base64Str';
                            await _timerService.setBackgroundImage(dataUri);
                            setModalState(() {});
                            if (mounted) setState(() {});
                          }
                        } catch (e) {
                          debugPrint('Image pick error: $e');
                        }
                      },
                      icon: const Icon(Icons.photo_library_rounded),
                      label: Text(
                        uploadText,
                        style: lang.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF66BB6A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showManualDaysInputDialog(LanguageService lang) {
    final daysController = TextEditingController();
    final hoursController = TextEditingController();
    final isDark = lang.isDarkMode;

    String title;
    String desc;
    String daysLabel;
    String hoursLabel;
    String saveBtn;
    String cancelBtn;

    switch (lang.currentLanguage) {
      case AppLanguage.kurdish:
        title = 'نوسینی ژمارەی ڕۆژەکان';
        desc = 'ژمارەی ئەو ڕۆژ و کاتژمێرانە بنوسە کە پێی گەیشتوویت:';
        daysLabel = 'ڕۆژ';
        hoursLabel = 'کاتژمێر';
        saveBtn = 'پاشەکەوتکردن';
        cancelBtn = 'پاشگەزبوونەوە';
        break;
      case AppLanguage.arabic:
        title = 'إدخال عدد الأيام';
        desc = 'أدخل عدد الأيام والساعات التي حققتها:';
        daysLabel = 'يوم';
        hoursLabel = 'ساعة';
        saveBtn = 'حفظ';
        cancelBtn = 'إلغاء';
        break;
      case AppLanguage.english:
        title = 'Enter Days & Hours';
        desc = 'Enter the number of days and hours you have achieved:';
        daysLabel = 'Days';
        hoursLabel = 'Hours';
        saveBtn = 'Save';
        cancelBtn = 'Cancel';
        break;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: lang.textDirection,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1a2a4a) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD500F9).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.timer_rounded,
                    color: Color(0xFFD500F9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: lang.getTextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  desc,
                  style: lang.getTextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: daysController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: lang.getTextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: daysLabel,
                          labelStyle: lang.getTextStyle(
                            color: const Color(0xFFAB47BC),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFAB47BC),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: hoursController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: lang.getTextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: hoursLabel,
                          labelStyle: lang.getTextStyle(
                            color: const Color(0xFFAB47BC),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFAB47BC),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  cancelBtn,
                  style: lang.getTextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  int days = int.tryParse(daysController.text.trim()) ?? 0;
                  int hours = int.tryParse(hoursController.text.trim()) ?? 0;

                  if (days > 0 || hours > 0) {
                    final now = DateTime.now();
                    final newStartDate = now.subtract(
                      Duration(days: days, hours: hours),
                    );
                    await _timerService.setStartDate(
                      newStartDate,
                      resetProgressBonuses: true,
                    );
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFAB47BC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  saveBtn,
                  style: lang.getTextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required Color color,
    required LanguageService lang,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: lang.isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: lang.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: lang.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              lang.isRTL ? Icons.chevron_left : Icons.chevron_right,
              color: lang.isDarkMode ? Colors.white38 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmDialog(LanguageService lang) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: lang.textDirection,
        child: AlertDialog(
          backgroundColor:
              lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Text(
                lang.resetTimer,
                style: lang.getTextStyle(
                  fontWeight: FontWeight.bold,
                  color: lang.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            lang.resetConfirm,
            style: lang.getTextStyle(
              fontSize: 16,
              color: lang.isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                lang.cancel,
                style: lang.getTextStyle(
                  color: lang.isDarkMode ? Colors.white54 : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _timerService.resetTimer().then((_) => setState(() {}));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                lang.yes,
                style: lang.getTextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentQuote(LanguageService lang) {
    final quote = _quotesService.currentQuote;
    if (quote == null) return lang.motivationalQuote;

    switch (lang.currentLanguage) {
      case AppLanguage.arabic:
        return quote.textAr.isNotEmpty
            ? '"${quote.textAr}"'
            : '"${quote.text}"';
      case AppLanguage.kurdish:
        return quote.textKu.isNotEmpty
            ? '"${quote.textKu}"'
            : '"${quote.text}"';
      case AppLanguage.english:
        return '"${quote.text}"';
    }
  }

  // Cached star widgets for performance - reduced to 15 for mobile performance
  List<Widget> _buildCachedStars(Size size) {
    _starPositions ??= List.generate(
      15,
      (index) => {
        'top': (index * 31) % size.height,
        'left': (index * 47) % size.width,
        'opacity': 0.2 + (index % 4) * 0.15,
      },
    );

    return _starPositions!
        .map(
          (pos) => Positioned(
            top: pos['top']!,
            left: pos['left']!,
            child: Container(
              width: 2,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(pos['opacity']!),
                shape: BoxShape.circle,
              ),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final size = MediaQuery.of(context).size;
    final isDark = lang.isDarkMode;

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(lang),
        drawerEnableOpenDragGesture: false,
        body: Stack(
          children: [
            // Background — premium multi-layer gradient with soft mesh
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: isDark
                      ? [0.0, 0.35, 0.7, 1.0]
                      : [0.0, 0.3, 0.65, 1.0],
                  colors: isDark
                      ? [
                          const Color(0xFF0B1426),
                          const Color(0xFF0F1E3D),
                          const Color(0xFF13283F),
                          const Color(0xFF0A1628),
                        ]
                      : [
                          const Color(0xFFFAFCFD),
                          const Color(0xFFF0F7F6),
                          const Color(0xFFE8F4F2),
                          const Color(0xFFF5FAF9),
                        ],
                ),
              ),
            ),
            // Soft radial glow accents for depth — premium ambient orbs
            Positioned(
              top: -100,
              right: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark
                          ? const Color(0xFF14B8A6)
                          : const Color(0xFF0D9488))
                          .withOpacity(isDark ? 0.1 : 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 200,
              left: -120,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark
                          ? const Color(0xFF818CF8)
                          : const Color(0xFFA78BFA))
                          .withOpacity(isDark ? 0.07 : 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -80,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF14B8A6))
                          .withOpacity(isDark ? 0.08 : 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              right: -100,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark
                          ? const Color(0xFFC084FC)
                          : const Color(0xFFF59E0B))
                          .withOpacity(isDark ? 0.05 : 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (isDark) ..._buildCachedStars(size),

            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: 120,
                  ),
                  child: Column(
                    children: [
                      // Header - Optimized for small screens
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final screenWidth = constraints.maxWidth;
                          final isVerySmall = screenWidth < 340;
                          final isSmallScreen = screenWidth < 380;
                          final iconPadding =
                              isVerySmall ? 5.0 : (isSmallScreen ? 7.0 : 8.0);
                          final iconSize = isVerySmall
                              ? 18.0
                              : (isSmallScreen ? 21.0 : 24.0);
                          final topImageIconSize = isVerySmall
                              ? 34.0
                              : (isSmallScreen ? 38.0 : 42.0);
                          final spacing =
                              isVerySmall ? 4.0 : (isSmallScreen ? 6.0 : 8.0);

                          final btnBg = isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.white.withOpacity(0.75);
                          final btnBorder = isDark
                              ? Colors.white.withOpacity(0.12)
                              : Colors.white.withOpacity(0.9);
                          final btnShadow = isDark
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF14B8A6)
                                        .withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF0D9488)
                                        .withOpacity(0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 2),
                                  ),
                                ];
                          final btnRadius = BorderRadius.circular(18);

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left side - Menu + Leaderboard + Awards (combined)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Menu Button - Balanced premium touch target with container matching settings
                                  GestureDetector(
                                    onTap: () =>
                                        _scaffoldKey.currentState?.openDrawer(),
                                    child: Container(
                                      margin: EdgeInsets.symmetric(
                                        horizontal: spacing / 2,
                                      ),
                                      padding: EdgeInsets.all(iconPadding),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: isDark
                                              ? [
                                                  Colors.white
                                                      .withOpacity(0.12),
                                                  Colors.white
                                                      .withOpacity(0.06),
                                                ]
                                              : [
                                                  Colors.white
                                                      .withOpacity(0.9),
                                                  Colors.white
                                                      .withOpacity(0.6),
                                                ],
                                        ),
                                        borderRadius: btnRadius,
                                        border: Border.all(
                                          color: btnBorder,
                                          width: 1,
                                        ),
                                        boxShadow: btnShadow,
                                      ),
                                      child: Icon(
                                        Icons.menu_rounded,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                        size: iconSize,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: spacing / 2),
                                  // Leaderboard
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const LeaderboardScreen(),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(iconPadding / 2),
                                      child: Image.asset(
                                        'assets/images/icon_top_leaderboard.png',
                                        width: topImageIconSize,
                                        height: topImageIconSize,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: spacing / 2),
                                  // Awards (Badges + Certificates) - Combined popup
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'badges')
                                        _showBadgesDialog(lang);
                                      if (value == 'certificates')
                                        _showCertificatesDialog(lang);
                                    },
                                    offset: const Offset(0, 45),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    color: isDark
                                        ? const Color(0xFF1a2a4a)
                                        : Colors.white,
                                    child: Padding(
                                      padding: EdgeInsets.all(iconPadding / 2),
                                      child: Image.asset(
                                        'assets/images/icon_top_badges.png',
                                        width: topImageIconSize,
                                        height: topImageIconSize,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'badges',
                                        child: Row(
                                          children: [
                                            Image.asset(
                                              'assets/images/icon_popup_badges.png',
                                              width: 32.0,
                                              height: 32.0,
                                              fit: BoxFit.contain,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              lang.currentLanguage ==
                                                      AppLanguage.kurdish
                                                  ? 'ئۆسمەکان'
                                                  : lang.currentLanguage ==
                                                          AppLanguage.arabic
                                                      ? 'الأوسمة'
                                                      : 'Badges',
                                              style: lang.getTextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'certificates',
                                        child: Row(
                                          children: [
                                            Image.asset(
                                              'assets/images/icon_popup_certificates.png',
                                              width: 32.0,
                                              height: 32.0,
                                              fit: BoxFit.contain,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              lang.currentLanguage ==
                                                      AppLanguage.kurdish
                                                  ? 'بڕوانامەکان'
                                                  : lang.currentLanguage ==
                                                          AppLanguage.arabic
                                                      ? 'الشهادات'
                                                      : 'Certificates',
                                              style: lang.getTextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: spacing / 2),
                                  // Notifications
                                  GestureDetector(
                                    onTap: () => _showAnnouncementsDialog(lang),
                                    child: ListenableBuilder(
                                      listenable: _announcementsService,
                                      builder: (context, _) {
                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.all(
                                                iconPadding / 2,
                                              ),
                                              child: Image.asset(
                                                'assets/images/icon_top_notifications.png',
                                                width: topImageIconSize,
                                                height: topImageIconSize,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            if (_announcementsService
                                                    .unreadCount >
                                                0)
                                              Positioned(
                                                right: -4,
                                                top: -4,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                      begin:
                                                          Alignment.topLeft,
                                                      end: Alignment
                                                          .bottomRight,
                                                      colors: [
                                                        Color(0xFFFF6B6B),
                                                        Color(0xFFF43F5E),
                                                      ],
                                                    ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 1.5,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(
                                                          0xFFF43F5E,
                                                        ).withOpacity(0.4),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(
                                                    minWidth: 18,
                                                    minHeight: 18,
                                                  ),
                                                  child: Text(
                                                    '${_announcementsService.unreadCount}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              // Middle - User info (Expanded to prevent overflow)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        lang
                                            .welcome(_getUserName(lang))
                                            .replaceAll('!', ''),
                                        style: lang.getTextStyle(
                                          fontSize: isSmallScreen ? 12 : 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      Text(
                                        _formatDate(lang),
                                        style: lang.getTextStyle(
                                          fontSize: isSmallScreen ? 9 : 10,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Right - Settings
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                ),
                                child: Container(
                                  margin: EdgeInsets.symmetric(
                                    horizontal: spacing / 2,
                                  ),
                                  padding: EdgeInsets.all(iconPadding),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isDark
                                          ? [
                                              Colors.white
                                                  .withOpacity(0.12),
                                              Colors.white
                                                  .withOpacity(0.06),
                                            ]
                                          : [
                                              Colors.white
                                                  .withOpacity(0.9),
                                              Colors.white
                                                  .withOpacity(0.6),
                                            ],
                                    ),
                                    borderRadius: btnRadius,
                                    border: Border.all(
                                      color: btnBorder,
                                      width: 1,
                                    ),
                                    boxShadow: btnShadow,
                                  ),
                                  child: Icon(
                                    Icons.settings_rounded,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    size: iconSize,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Support button — elegant, near the day counter
                      _SupportButton(lang: lang),
                      const SizedBox(height: 16),

                      // Timer Card - Using isolated widget for performance
                      RecoveryTimerWidget(
                        timerService: _timerService,
                        lang: lang,
                        onSettingsTap: () => _showTimerSettingsModal(lang),
                      ),
                      const SizedBox(height: 24),
                      // Quotes Carousel
                      _buildQuotesWidget(lang, isDark),
                      const SizedBox(height: 16),

                      // Category Group: Support & Help
                      _buildCategoryHeader(
                        lang.currentLanguage == AppLanguage.kurdish
                            ? 'پاڵپشتی و فریاگوزاری خێرا'
                            : lang.currentLanguage == AppLanguage.arabic
                                ? 'الدعم والإنقاذ السريع'
                                : 'Immediate Support & Help',
                        lang,
                        isDark,
                        const Color(0xFFF43F5E),
                      ),

                      _buildPremiumSequentialCard(
                        title: lang.currentLanguage == AppLanguage.kurdish
                            ? 'ڕاهێنانی هەناسەدان'
                            : lang.currentLanguage == AppLanguage.arabic
                                ? 'تمرين التنفس'
                                : 'Breathing Exercise',
                        subtitle: lang.currentLanguage == AppLanguage.kurdish
                            ? 'ئارام به‌ و به‌ قوڵی هه‌ناسه‌ بده‌ بۆ ڕووبه‌ڕووبوونه‌وه‌ی خه‌مۆكی'
                            : lang.currentLanguage == AppLanguage.arabic
                                ? 'استرخِ وتنفس بعمق لمقاومة الرغبات الطارئة'
                                : 'Relax and breathe deeply to resist sudden urges',
                        iconAsset: 'assets/images/icon_breathing.png',
                        glowColors: [
                          const Color(0xFF06B6D4),
                          const Color(0xFF0891B2),
                        ],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BreathingExerciseScreen(),
                          ),
                        ),
                        lang: lang,
                        isDark: isDark,
                      ),

                      _buildPremiumSequentialCard(
                        title: lang.currentLanguage == AppLanguage.kurdish
                            ? 'ئارەزوویەکی بەهێزت هەیە؟'
                            : lang.currentLanguage == AppLanguage.arabic
                                ? 'هل تشعر برغبة شديدة؟'
                                : 'Feeling a strong urge?',
                        subtitle: lang.currentLanguage == AppLanguage.kurdish
                            ? 'بۆ یارمەتی خێرا و ئامۆژگاری فریاگوزاری'
                            : lang.currentLanguage == AppLanguage.arabic
                                ? 'للحصول على مساعدة فورية ونصائح إسعافية'
                                : 'For instant help and emergency tips',
                        iconAsset: 'assets/images/icon_tips.png',
                        glowColors: [
                          const Color(0xFFFF4757),
                          const Color(0xFFFF6B6B),
                        ],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TipsScreen()),
                        ),
                        lang: lang,
                        isDark: isDark,
                      ),

                      _buildActionGrid(
                        lang: lang,
                        isDark: isDark,
                        children: [
                          _buildCompactSectionTile(
                            title: lang.currentLanguage == AppLanguage.kurdish
                                ? 'دکتۆر و ڕەفیقی تعافی'
                                : lang.currentLanguage == AppLanguage.arabic
                                    ? 'دكتور ورفيق التعافي'
                                    : 'Doctor & Companion',
                            subtitle:
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? 'ڕاوێژکاری بەردەوام'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? 'استشارات مستمرة'
                                        : 'Continuous support',
                            iconAsset: 'assets/images/icon_dr_taafi.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WebViewScreen(
                                  title: 'دكتور ورفيق التعافي',
                                  url: 'https://ta3afi.pages.dev',
                                ),
                              ),
                            ),
                            lang: lang,
                            isDark: isDark,
                          ),
                          _buildCompactSectionTile(
                            title: lang.currentLanguage == AppLanguage.kurdish
                                ? 'کۆمەڵگەی لا ئەبرەح'
                                : lang.currentLanguage == AppLanguage.arabic
                                    ? 'مجتمع لا أبرح'
                                    : 'La Abrah Community',
                            subtitle:
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? 'پاڵپشتیی کۆمەڵە'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? 'دعم جماعي'
                                        : 'Group support',
                            iconAsset: 'assets/images/icon_community.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WebViewScreen(
                                  title: 'مجتمع لا أبرح',
                                    url:
                                        'https://8erfuc-dkveergqr-arcadawebapps7.vercel.app/',
                                ),
                              ),
                            ),
                            lang: lang,
                            isDark: isDark,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Category Group: Daily Tools
                      _buildCategoryHeader(
                        lang.currentLanguage == AppLanguage.kurdish
                            ? 'ئامرازەکانی چاکبوونەوەی ڕۆژانە'
                            : lang.currentLanguage == AppLanguage.arabic
                                ? 'أدوات التعافي اليومية'
                                : 'Daily Recovery Tools',
                        lang,
                        isDark,
                        const Color(0xFF0D9488),
                      ),

                      _buildActionGrid(
                        lang: lang,
                        isDark: isDark,
                        children: [
                          _buildCompactSectionTile(
                            title: lang.currentLanguage == AppLanguage.kurdish
                                ? 'خوەکان'
                                : lang.currentLanguage == AppLanguage.arabic
                                    ? 'العادات'
                                    : 'Habits',
                            subtitle:
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? 'چاودێری ڕۆژانە'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? 'متابعة يومية'
                                        : 'Daily tracking',
                            iconAsset: 'assets/images/icon_habits.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HabitsScreen(),
                              ),
                            ),
                            lang: lang,
                            isDark: isDark,
                          ),
                          _buildCompactSectionTile(
                            title: lang.currentLanguage == AppLanguage.kurdish
                                ? 'بەدواداچوون'
                                : lang.currentLanguage == AppLanguage.arabic
                                    ? 'تتبع التقدم'
                                    : 'Progress Tracking',
                            subtitle:
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? 'ئامار و گراف'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? 'إحصائيات ورسوم'
                                        : 'Stats and charts',
                            iconAsset: 'assets/images/icon_tracking.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TrackingScreen(),
                              ),
                            ),
                            lang: lang,
                            isDark: isDark,
                          ),
                          _buildCompactSectionTile(
                            title: lang.currentLanguage == AppLanguage.kurdish
                                ? 'ڕۆژنامەکەم'
                                : lang.currentLanguage == AppLanguage.arabic
                                    ? 'يومياتي'
                                    : 'My Journal',
                            subtitle:
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? 'نووسینی هەستەکان'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? 'كتابة المشاعر'
                                        : 'Write feelings',
                            iconAsset: 'assets/images/icon_journal.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const JournalScreen(),
                              ),
                            ),
                            lang: lang,
                            isDark: isDark,
                          ),
                          _buildCompactSectionTile(
                            title: lang.currentLanguage == AppLanguage.kurdish
                                ? 'بەڵێننامەی پابەندبوون'
                                : lang.currentLanguage == AppLanguage.arabic
                                    ? 'وثيقة الالتزام'
                                    : 'Commitment Document',
                            subtitle:
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? 'بەڵێنی پاکی'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? 'عهد الطهارة'
                                        : 'Promise of purity',
                            iconAsset: 'assets/images/icon_commitment.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CommitmentScreen(),
                              ),
                            ),
                            lang: lang,
                            isDark: isDark,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Category Group: Spiritual & Cognitive
                      _buildCategoryHeader(
                        lang.currentLanguage == AppLanguage.kurdish
                            ? 'لایه نی ڕۆحی و مەعریفی'
                            : lang.currentLanguage == AppLanguage.arabic
                                ? 'الجانب الروحي والمعرفي'
                                : 'Spiritual & Cognitive',
                        lang,
                        isDark,
                        const Color(0xFFD97706),
                      ),

                      _buildActionGrid(
                        lang: lang,
                        isDark: isDark,
                        children: [
                          _buildCompactSectionTile(
                            title: lang.currentLanguage == AppLanguage.kurdish
                                ? 'گوێ لە قورئانی پیرۆز بگرە'
                                : lang.currentLanguage == AppLanguage.arabic
                                    ? 'استمع للقرآن الكريم'
                                    : 'Listen to Quran',
                            subtitle:
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? 'قورئان و ئارامی'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? 'قرآن وطمأنينة'
                                        : 'Quran and calm',
                            iconAsset: 'assets/images/icon_quran.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WebViewScreen(
                                  title: 'القرآن الكريم',
                                  url: 'https://www.mp3quran.net/ar',
                                ),
                              ),
                            ),
                            lang: lang,
                            isDark: isDark,
                          ),
                          _buildCompactSectionTile(
                            title: lang.currentLanguage == AppLanguage.kurdish
                                ? 'دۆزی ئیمانی'
                                : lang.currentLanguage == AppLanguage.arabic
                                    ? 'جرعة إيمانية'
                                    : 'Faith Dose',
                            subtitle:
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? 'چیرۆک و پەند'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? 'قصص وعبر'
                                        : 'Stories and lessons',
                            iconAsset: 'assets/images/icon_stories.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StoriesScreen(),
                              ),
                            ),
                            lang: lang,
                            isDark: isDark,
                          ),
                          _buildCompactSectionTile(
                            title: lang.currentLanguage == AppLanguage.kurdish
                                ? 'ڕێگەی ئاسان'
                                : lang.currentLanguage == AppLanguage.arabic
                                    ? 'الطريقة السهلة'
                                    : 'Easy Way',
                            subtitle:
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? 'فێرکاری دەنگی'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? 'شروحات صوتية'
                                        : 'Audio lessons',
                            iconAsset: 'assets/images/icon_easy_way.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WebViewScreen(
                                  title: 'الطريقة السهلة',
                                  url: 'https://muhamadabdulah.lovable.app/',
                                ),
                              ),
                            ),
                            lang: lang,
                            isDark: isDark,
                          ),
                          _buildCompactSectionTile(
                            title: lang.currentLanguage == AppLanguage.kurdish
                                ? 'مۆدێلی ئازادی'
                                : lang.currentLanguage == AppLanguage.arabic
                                    ? 'نموذج الحرية'
                                    : 'Freedom Model',
                            subtitle:
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? 'تێگەیشتنی قووڵ'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? 'فهم أعمق'
                                        : 'Deeper understanding',
                            iconAsset: 'assets/images/icon_freedom_model.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WebViewScreen(
                                  title: 'نموذج الحرية',
                                  url:
                                      'https://namoothaj-5nds9uxr.manus.space/',
                                ),
                              ),
                            ),
                            lang: lang,
                            isDark: isDark,
                          ),
                          _buildCompactSectionTile(
                            title: lang.currentLanguage == AppLanguage.kurdish
                                ? 'ڤیدیۆ و دەنگەکان'
                                : lang.currentLanguage == AppLanguage.arabic
                                    ? 'فيديوهات وصوتيات'
                                    : 'Videos & Audio',
                            subtitle:
                                lang.currentLanguage == AppLanguage.kurdish
                                    ? 'وانەی بەسوود'
                                    : lang.currentLanguage == AppLanguage.arabic
                                        ? 'محاضرات مفيدة'
                                        : 'Useful lectures',
                            iconAsset: 'assets/images/icon_media.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WebViewScreen(
                                  title: 'فيديوهات وصوتيات التعافي',
                                  url: 'https://yusf4.lovable.app/',
                                ),
                              ),
                            ),
                            lang: lang,
                            isDark: isDark,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      // Developer Analytics Dashboard (only visible to developers)
                      if (_analyticsService.isDeveloper)
                        _buildAnalyticsDashboard(lang, isDark),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeUnit(
    int value,
    String label,
    LanguageService lang,
    Color color,
    int maxValue,
  ) {
    final fillPercent = (value / maxValue).clamp(0.0, 1.0);

    // Deeper, richer colors using the passed color
    final Color bottomColor = HSVColor.fromColor(
      color,
    ).withValue(0.6).toColor(); // Darker
    final Color midColor = color;
    final Color topColor = HSVColor.fromColor(
      color,
    ).withSaturation(0.7).withValue(0.9).toColor(); // Lighter

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 110,
          decoration: BoxDecoration(
            // Premium Glass Effect
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              18,
            ), // Slightly less than container to avoid artifact
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Liquid Background (Empty part)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),

                // Water fill with rich gradient
                if (fillPercent > 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 300,
                      ), // Faster animation for seconds
                      curve: Curves.easeInOut, // Smoother linear-like movement
                      // Calculate height ensuring movement from start: minHeight + (variable * range)
                      height: 15.0 + (fillPercent * (110.0 - 15.0)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            topColor.withOpacity(0.9),
                            midColor,
                            bottomColor,
                          ],
                        ),
                        // No rounded corners on top to ensure clean fill
                      ),
                    ),
                  ),

                // Glass Shine
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 45,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value.toString().padLeft(2, '0'),
                        style: lang.getTextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: lang.getTextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    // Use externalApplication mode to properly handle deep links like tg:// and whatsapp://
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  // Developer Analytics Dashboard
  Widget _buildAnalyticsDashboard(LanguageService lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1a2a4a), const Color(0xFF0d1a2d)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF0D9488).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.currentLanguage == AppLanguage.arabic
                        ? 'إحصائيات المستخدمين'
                        : lang.currentLanguage == AppLanguage.kurdish
                            ? 'ئاماری بەکارهێنەران'
                            : 'User Analytics',
                    style: lang.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    lang.currentLanguage == AppLanguage.arabic
                        ? 'للمطور فقط • تحديث مباشر'
                        : lang.currentLanguage == AppLanguage.kurdish
                            ? 'تەنها بۆ دروستکەر • لایڤ'
                            : 'Developer only • Live',
                    style: lang.getTextStyle(
                      fontSize: 11,
                      color: const Color(0xFF0D9488),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats Cards Row
          Row(
            children: [
              // Daily Users
              Expanded(
                child: StreamBuilder<int>(
                  stream: _analyticsService.getDailyActiveUsersStream(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return _buildStatCard(
                      title: lang.currentLanguage == AppLanguage.arabic
                          ? 'اليوم'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'ئەمڕۆ'
                              : 'Today',
                      value: count.toString(),
                      icon: Icons.today,
                      color: const Color(0xFF4CAF50),
                      isDark: isDark,
                      lang: lang,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Weekly Users
              Expanded(
                child: StreamBuilder<int>(
                  stream: _analyticsService.getWeeklyActiveUsersStream(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return _buildStatCard(
                      title: lang.currentLanguage == AppLanguage.arabic
                          ? 'الأسبوع'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'هەفتە'
                              : 'Week',
                      value: count.toString(),
                      icon: Icons.date_range,
                      color: const Color(0xFF2196F3),
                      isDark: isDark,
                      lang: lang,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Monthly Users
              Expanded(
                child: StreamBuilder<int>(
                  stream: _analyticsService.getMonthlyActiveUsersStream(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return _buildStatCard(
                      title: lang.currentLanguage == AppLanguage.arabic
                          ? 'الشهر'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'مانگ'
                              : 'Month',
                      value: count.toString(),
                      icon: Icons.calendar_month,
                      color: const Color(0xFF9C27B0),
                      isDark: isDark,
                      lang: lang,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Line Chart for past 7 days
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _analyticsService.getDailyUserCounts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!;
              final maxCount = data
                  .map((d) => d['count'] as int)
                  .fold(0, (a, b) => a > b ? a : b);
              final chartMax = maxCount == 0 ? 10 : maxCount + 2;

              return Container(
                height: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.currentLanguage == AppLanguage.arabic
                          ? 'النشاط اليومي - آخر 7 أيام'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'چالاکی ڕۆژانە - ٧ ڕۆژی ڕابردوو'
                              : 'Daily Activity - Last 7 Days',
                      style: lang.getTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: data.map((item) {
                          final count = item['count'] as int;
                          final dayName = item['dayName'] as String;
                          final heightPercent =
                              chartMax > 0 ? (count / chartMax) : 0.0;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                count.toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D9488),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 28,
                                height: 60 * heightPercent.clamp(0.05, 1.0),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Color(0xFF0D9488),
                                      Color(0xFF14B8A6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dayName,
                                style: TextStyle(
                                  fontSize: 9,
                                  color:
                                      isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Recent Logins (Live - minute by minute)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _analyticsService.getRecentLoginsStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox();
              }

              final logins = snapshot.data!;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lang.currentLanguage == AppLanguage.arabic
                              ? 'تسجيلات الدخول الأخيرة'
                              : lang.currentLanguage == AppLanguage.kurdish
                                  ? 'داغڵبوونەکانی ئەمڕۆ'
                                  : 'Recent Logins Today',
                          style: lang.getTextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${logins.length}',
                          style: lang.getTextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...logins.take(10).map((login) {
                      final name = login['name'] as String;
                      final time = login['time'] as DateTime?;
                      final timeStr = time != null
                          ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                          : '--:--';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D9488),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: lang.getTextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required LanguageService lang,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: lang.getTextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: lang.getTextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSeparator() => Text(
        ':',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white.withOpacity(0.5),
        ),
      );

  Widget _buildDrawer(LanguageService lang) {
    final isDark = lang.isDarkMode;
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.3, 1.0],
            colors: isDark
                ? [
                    const Color(0xFF0B1426),
                    const Color(0xFF0F172A),
                    const Color(0xFF080F1E),
                  ]
                : [
                    const Color(0xFFFAFCFD),
                    const Color(0xFFF8FAFC),
                    const Color(0xFFF1F5F9),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with profile — premium gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF14B8A6).withOpacity(0.08),
                            Colors.transparent,
                          ]
                        : [
                            const Color(0xFF0D9488).withOpacity(0.06),
                            Colors.transparent,
                          ],
                  ),
                ),
                child: Column(
                  children: [
                    // Profile image with glowing border ring
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF14B8A6),
                            Color(0xFF0D9488),
                            Color(0xFF00BFA5),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BFA5).withOpacity(0.35),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                        backgroundImage: (_authService.currentUser?.photoURL !=
                                    null &&
                                _authService.currentUser!.photoURL!.isNotEmpty)
                            ? NetworkImage(_authService.currentUser!.photoURL!)
                            : null,
                        onBackgroundImageError:
                            (_authService.currentUser?.photoURL != null &&
                                    _authService
                                        .currentUser!.photoURL!.isNotEmpty)
                                ? (_, __) {}
                                : null,
                        child: (_authService.currentUser?.photoURL == null ||
                                _authService.currentUser!.photoURL!.isEmpty)
                            ? Icon(
                                _authService.isGuest
                                    ? Icons.person_outline
                                    : Icons.person,
                                size: 40,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getUserName(lang),
                      style: lang.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang.appSlogan,
                      style: lang.getTextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Share App Button
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        final uri = Uri.parse('https://laabrah.lovable.app');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00C9FF).withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: const Color(0xFF92FE9D).withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.share_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              lang.currentLanguage == AppLanguage.arabic
                                  ? 'شارك التطبيق'
                                  : lang.currentLanguage == AppLanguage.kurdish
                                      ? 'هاوبەشی بکە'
                                      : 'Share App',
                              style: lang.getTextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 0,
                    bottom: 120,
                  ),
                  children: [
                    _buildDrawerItem(
                      'assets/images/icon_home.png',
                      lang.home,
                      true,
                      lang,
                      () => Navigator.pop(context),
                    ),
                    _buildDrawerItem(
                      'assets/images/icon_roadmap.png',
                      lang.currentLanguage == AppLanguage.arabic
                          ? 'خارطة التعافي'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'نەخشەی چاکبوونەوە'
                              : 'Recovery Roadmap',
                      false,
                      lang,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoadmapScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      'assets/images/icon_journal.png',
                      lang.currentLanguage == AppLanguage.arabic
                          ? 'يومياتي'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'ڕۆژنامەکەم'
                              : 'My Journal',
                      false,
                      lang,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JournalScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      'assets/images/icon_habits.png',
                      lang.currentLanguage == AppLanguage.arabic
                          ? 'العادات'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'ڕەوشتەکان'
                              : 'Habits',
                      false,
                      lang,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HabitsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      'assets/images/icon_tracking.png',
                      lang.currentLanguage == AppLanguage.arabic
                          ? 'المتابعة'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'بەدواداچوون'
                              : 'Tracking',
                      false,
                      lang,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrackingScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      'assets/images/icon_library.png',
                      lang.currentLanguage == AppLanguage.arabic
                          ? 'المكتبة'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'کتێبخانە'
                              : 'Library',
                      false,
                      lang,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LibraryScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      'assets/images/icon_community.png',
                      lang.currentLanguage == AppLanguage.arabic
                          ? 'مجموعة لا أبرح للدردشة'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'مجموعة لا أبرح دردشة'
                              : 'La Abraha Chat Group',
                      false,
                      lang,
                      () async {
                        Navigator.pop(context);
                        final url = 'https://web.telegram.org/k/#@Ta3fi_group';
                        if (kIsWeb) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  WebViewScreen(url: url, title: 'Telegram'),
                            ),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      'assets/images/icon_challenge.png',
                      lang.currentLanguage == AppLanguage.arabic
                          ? 'تحدي ٩٠ يوم'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'چاڵینجی ٩٠ ڕۆژ'
                              : '90-Day Challenge',
                      false,
                      lang,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChallengeScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      'assets/images/icon_freedom_model.png',
                      lang.currentLanguage == AppLanguage.arabic
                          ? 'اعرف مستواك الإدماني'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'مستوای ئیدمانت بزانە'
                              : 'Know Your Addiction Level',
                      false,
                      lang,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AssessmentScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      'assets/images/icon_popup_badges.png',
                      lang.currentLanguage == AppLanguage.arabic
                          ? 'الأوسمة'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'ئۆسمەکان'
                              : 'Badges',
                      false,
                      lang,
                      () {
                        Navigator.pop(context);
                        _showBadgesDialog(lang);
                      },
                    ),
                    _buildDrawerItem(
                      'assets/images/icon_popup_certificates.png',
                      lang.currentLanguage == AppLanguage.arabic
                          ? 'الشهادات'
                          : lang.currentLanguage == AppLanguage.kurdish
                              ? 'بڕوانامەکان'
                              : 'Certificates',
                      false,
                      lang,
                      () {
                        Navigator.pop(context);
                        _showCertificatesDialog(lang);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  lang.currentLanguage == AppLanguage.arabic
                      ? 'التعافي من الإدمان'
                      : lang.currentLanguage == AppLanguage.kurdish
                          ? 'چاکبوونەوە لە ئاڵوودەبوون'
                          : 'Recovery from Addiction',
                  style: lang.getTextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    dynamic iconOrAsset,
    String title,
    bool isActive,
    LanguageService lang,
    VoidCallback onTap, {
    bool isDisabled = false,
  }) {
    final isDark = lang.isDarkMode;
    final primaryColor = const Color(0xFF0D9488);
    final isRTL = lang.currentLanguage == AppLanguage.arabic ||
        lang.currentLanguage == AppLanguage.kurdish;

    Widget iconWidget;
    if (iconOrAsset is IconData) {
      iconWidget = Icon(
        iconOrAsset,
        color: isActive
            ? primaryColor
            : (isDisabled
                ? (isDark ? Colors.white24 : Colors.black26)
                : (isDark ? Colors.white54 : Colors.black54)),
        size: 24,
      );
    } else if (iconOrAsset is String) {
      iconWidget = Image.asset(
        iconOrAsset,
        width: 30,
        height: 30,
        fit: BoxFit.contain,
      );
    } else {
      iconWidget = const SizedBox(width: 28, height: 28);
    }

    final itemContent = [
      Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? [
                    primaryColor.withOpacity(isDark ? 0.22 : 0.15),
                    primaryColor.withOpacity(isDark ? 0.1 : 0.06),
                  ]
                : isDark
                    ? [
                        Colors.white.withOpacity(0.07),
                        Colors.white.withOpacity(0.03),
                      ]
                    : [
                        const Color(0xFFF1F5F9),
                        Colors.white.withOpacity(0.8),
                      ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isActive
                ? primaryColor.withOpacity(isDark ? 0.3 : 0.2)
                : isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.white.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: iconWidget,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          title,
          style: lang.getTextStyle(
            fontSize: 14.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? primaryColor
                : (isDisabled
                    ? (isDark ? Colors.white24 : Colors.black26)
                    : (isDark ? Colors.white70 : Colors.black87)),
          ),
          textAlign: isRTL ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (isActive)
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 8),
            ],
          ),
        ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: primaryColor.withOpacity(isDark ? 0.12 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: isActive
              ? (isDark
                  ? const Color(0xFF12362F).withOpacity(0.74)
                  : const Color(0xFFEFFCF8))
              : (isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.white.withOpacity(0.7)),
          child: InkWell(
            onTap: isDisabled ? null : onTap,
            splashColor: primaryColor.withOpacity(0.15),
            highlightColor: primaryColor.withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive
                      ? primaryColor.withOpacity(0.35)
                      : (isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white.withOpacity(0.4)),
                  width: 1,
                ),
              ),
              child: Row(
                children: isRTL ? itemContent.reversed.toList() : itemContent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(
    String title,
    LanguageService lang,
    bool isDark,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12, left: 2, right: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: isDark
                ? [
                    color.withOpacity(0.2),
                    color.withOpacity(0.08),
                    Colors.transparent,
                  ]
                : [
                    color.withOpacity(0.12),
                    color.withOpacity(0.04),
                    Colors.transparent,
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.25 : 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDark ? 0.08 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left accent bar with glow
            Container(
              width: 6,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color,
                    color.withOpacity(0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: lang.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Colors.white.withOpacity(0.95)
                      : const Color(0xFF1E293B),
                  height: 1.2,
                ),
              ),
            ),
            // Arrow pill with gradient
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(isDark ? 0.25 : 0.15),
                    color.withOpacity(isDark ? 0.1 : 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withOpacity(isDark ? 0.2 : 0.15),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(isDark ? 0.08 : 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: color.withOpacity(isDark ? 0.85 : 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid({
    required List<Widget> children,
    required LanguageService lang,
    required bool isDark,
  }) {
    final isRTL = lang.currentLanguage == AppLanguage.arabic ||
        lang.currentLanguage == AppLanguage.kurdish;

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 360 ? 8.0 : 10.0;
        return Directionality(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: children.map((child) {
              final itemWidth = (constraints.maxWidth - spacing) / 2;
              return SizedBox(width: itemWidth, child: child);
            }).toList(),
          ),
        );
      },
    );
  }

  // Unified icon + accent color map: one accent per category for a cohesive design
  static const Map<String, IconData> _cardIcons = {
    'assets/images/icon_breathing.png': Icons.self_improvement_rounded,
    'assets/images/icon_tips.png': Icons.health_and_safety_rounded,
    'assets/images/icon_dr_taafi.png': Icons.medical_services_rounded,
    'assets/images/icon_community.png': Icons.groups_rounded,
    'assets/images/icon_habits.png': Icons.task_alt_rounded,
    'assets/images/icon_tracking.png': Icons.insights_rounded,
    'assets/images/icon_journal.png': Icons.edit_note_rounded,
    'assets/images/icon_commitment.png': Icons.handshake_rounded,
    'assets/images/icon_quran.png': Icons.menu_book_rounded,
    'assets/images/icon_stories.png': Icons.auto_stories_rounded,
    'assets/images/icon_easy_way.png': Icons.headphones_rounded,
    'assets/images/icon_freedom_model.png': Icons.psychology_rounded,
    'assets/images/icon_sharia.png': Icons.question_answer_rounded,
    'assets/images/icon_media.png': Icons.play_circle_rounded,
    'assets/images/icon_challenge.png': Icons.emoji_events_rounded,
  };

  // Category accents: coral = support, teal = daily tools, amber = spiritual
  static const Map<String, Color> _cardAccents = {
    'assets/images/icon_breathing.png': Color(0xFFF43F5E),
    'assets/images/icon_tips.png': Color(0xFFF43F5E),
    'assets/images/icon_dr_taafi.png': Color(0xFFF43F5E),
    'assets/images/icon_community.png': Color(0xFFF43F5E),
    'assets/images/icon_habits.png': Color(0xFF0D9488),
    'assets/images/icon_tracking.png': Color(0xFF0D9488),
    'assets/images/icon_journal.png': Color(0xFF0D9488),
    'assets/images/icon_commitment.png': Color(0xFF0D9488),
    'assets/images/icon_quran.png': Color(0xFFD97706),
    'assets/images/icon_stories.png': Color(0xFFD97706),
    'assets/images/icon_easy_way.png': Color(0xFFD97706),
    'assets/images/icon_freedom_model.png': Color(0xFFD97706),
    'assets/images/icon_sharia.png': Color(0xFFD97706),
    'assets/images/icon_media.png': Color(0xFFD97706),
    'assets/images/icon_challenge.png': Color(0xFF0D9488),
  };

  Widget _buildPremiumSequentialCard({
    required String title,
    required String subtitle,
    required String iconAsset,
    required List<Color> glowColors,
    required VoidCallback onTap,
    required LanguageService lang,
    required bool isDark,
  }) {
    final accentColor = _cardAccents[iconAsset] ?? const Color(0xFF0D9488);
    final isRTL = lang.currentLanguage == AppLanguage.arabic ||
        lang.currentLanguage == AppLanguage.kurdish;

    final cardContent = [
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    accentColor.withOpacity(0.25),
                    accentColor.withOpacity(0.1),
                  ]
                : [
                    accentColor.withOpacity(0.16),
                    accentColor.withOpacity(0.06),
                  ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: accentColor.withOpacity(isDark ? 0.28 : 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(isDark ? 0.14 : 0.1),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(iconAsset, fit: BoxFit.contain),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment:
              isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: lang.getTextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? Colors.white.withOpacity(0.95)
                    : const Color(0xFF1E293B),
              ),
              textAlign: isRTL ? TextAlign.right : TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: lang.getTextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: isRTL ? TextAlign.right : TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isRTL ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          color: accentColor.withOpacity(isDark ? 0.6 : 0.5),
          size: 20,
        ),
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: isDark ? const Color(0xFF15231F) : Colors.white,
          child: InkWell(
            onTap: onTap,
            splashColor: accentColor.withOpacity(0.12),
            highlightColor: accentColor.withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withOpacity(0.04),
                          Colors.transparent,
                        ]
                      : [
                          Colors.white,
                          const Color(0xFFFAFCFD),
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(isDark ? 0.12 : 0.09),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: accentColor.withOpacity(isDark ? 0.04 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Accent glow orb in background
                  Positioned(
                    top: -20,
                    right: isRTL ? null : -20,
                    left: isRTL ? -20 : null,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentColor.withOpacity(isDark ? 0.08 : 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children:
                        isRTL ? cardContent.reversed.toList() : cardContent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSectionTile({
    required String title,
    required String subtitle,
    required String iconAsset,
    required VoidCallback onTap,
    required LanguageService lang,
    required bool isDark,
  }) {
    final accentColor = _cardAccents[iconAsset] ?? const Color(0xFF0D9488);
    final isRTL = lang.currentLanguage == AppLanguage.arabic ||
        lang.currentLanguage == AppLanguage.kurdish;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: accentColor.withOpacity(0.12),
        highlightColor: accentColor.withOpacity(0.05),
        child: Container(
          height: 148,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF15231F),
                      const Color(0xFF101C19),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFFAFCFD),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(isDark ? 0.1 : 0.07),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.12 : 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Background accent glow — radial for depth
                Positioned(
                  top: -30,
                  right: isRTL ? null : -30,
                  left: isRTL ? -30 : null,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accentColor.withOpacity(isDark ? 0.1 : 0.06),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Top gradient accent line — wider and glowing
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          accentColor,
                          accentColor.withOpacity(0.7),
                          accentColor.withOpacity(0.15),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: isRTL
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: isRTL
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? [
                                        accentColor.withOpacity(0.25),
                                        accentColor.withOpacity(0.1),
                                      ]
                                    : [
                                        accentColor.withOpacity(0.16),
                                        accentColor.withOpacity(0.06),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: accentColor
                                    .withOpacity(isDark ? 0.25 : 0.2),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor
                                      .withOpacity(isDark ? 0.15 : 0.1),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: Colors.white
                                      .withOpacity(isDark ? 0.04 : 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, -1),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Inner glow
                                Positioned.fill(
                                  child: Container(
                                    margin: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      gradient: RadialGradient(
                                        center: Alignment.topLeft,
                                        radius: 1,
                                        colors: [
                                          Colors.white
                                              .withOpacity(isDark ? 0.06 : 0.04),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(9),
                                  child: Image.asset(
                                    iconAsset,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        title,
                        style: lang.getTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white.withOpacity(0.95)
                              : const Color(0xFF1E293B),
                          height: 1.2,
                        ),
                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: lang.getTextStyle(
                          fontSize: 11.5,
                          color:
                              isDark ? Colors.white54 : const Color(0xFF64748B),
                          height: 1.2,
                        ),
                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    required List<Color> iconGradient,
    required VoidCallback onTap,
    required LanguageService lang,
    required bool isDark,
  }) {
    final Color bgColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);
    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.08);
    final Color textColor =
        isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8);
    final Color shadowColor =
        isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Circular Glowing Icon container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: iconGradient,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.first.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              // Minimalist uniform title
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    style: lang.getTextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotesWidget(LanguageService lang, bool isDark) {
    if (_quotesService.quotes.isEmpty) return const SizedBox.shrink();

    final quote = _quotesService.currentQuote;
    if (quote == null) return const SizedBox.shrink();

    // Islamic gold/green color palette
    const islamicGold = Color(0xFFD4AF37);
    const islamicGoldLight = Color(0xFFF0D878);
    const islamicGreen = Color(0xFF0D6B4E);
    const islamicTeal = Color(0xFF006B5B);

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<String>(
            'quote_${quote.id}_${_quotesService.quotes.indexOf(quote)}',
          ),
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: 100,
            maxHeight: 130,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.5, 1.0],
              colors: isDark
                  ? [
                      const Color(0xFF0a1f1a),
                      const Color(0xFF0d2a23),
                      const Color(0xFF081814),
                    ]
                  : [
                      const Color(0xFFFFFDF5),
                      const Color(0xFFFFF8E7),
                      const Color(0xFFFFFBEF),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: islamicGold.withOpacity(isDark ? 0.45 : 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: islamicGold.withOpacity(isDark ? 0.2 : 0.15),
                blurRadius: 28,
                offset: const Offset(0, 12),
                spreadRadius: -3,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              children: [
                // Subtle inner glow border
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(
                        color: islamicGoldLight
                            .withOpacity(isDark ? 0.08 : 0.15),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
                // Corner decorations — larger and more elegant
                Positioned(
                  top: 8,
                  left: 8,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: islamicGold.withOpacity(0.4),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: islamicGold.withOpacity(0.4),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: islamicGold.withOpacity(0.4),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: islamicGold.withOpacity(0.4),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Quote text - only Arabic, with overflow handling
                      Flexible(
                        child: Text(
                          quote.textAr, // Always show Arabic text
                          style: GoogleFonts.amiri(
                            fontSize: 16,
                            color: isDark
                                ? const Color(0xFFE8DCC8)
                                : const Color(0xFF2C3E2D),
                            fontWeight: FontWeight.w500,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Small quote icon at bottom with glow
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              islamicGold.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.format_quote_rounded,
                          color: islamicGold.withOpacity(0.7),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(LanguageService lang) {
    final now = DateTime.now();
    final months = lang.currentLanguage == AppLanguage.english
        ? [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ]
        : lang.currentLanguage == AppLanguage.arabic
            ? [
                'كانون الثاني',
                'شباط',
                'آذار',
                'نيسان',
                'أيار',
                'حزيران',
                'تموز',
                'آب',
                'أيلول',
                'تشرين الأول',
                'تشرين الثاني',
                'كانون الأول',
              ]
            : [
                'کانوونی دووەم',
                'شوبات',
                'ئازار',
                'نیسان',
                'ئایار',
                'حوزەیران',
                'تەمووز',
                'ئاب',
                'ئەیلوول',
                'تشرینی یەکەم',
                'تشرینی دووەم',
                'کانوونی یەکەم',
              ];
    final days = lang.currentLanguage == AppLanguage.english
        ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        : lang.currentLanguage == AppLanguage.arabic
            ? [
                'الأحد',
                'الاثنين',
                'الثلاثاء',
                'الأربعاء',
                'الخميس',
                'الجمعة',
                'السبت',
              ]
            : [
                'یەکشەممە',
                'دووشەممە',
                'سێشەممە',
                'چوارشەممە',
                'پێنجشەممە',
                'هەینی',
                'شەممە',
              ];
    return '${days[now.weekday % 7]}، ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  void _showKhatmahAppDialog(LanguageService lang) {
    final isDark = lang.isDarkMode;

    String title;
    String description;
    String downloadBtn;
    switch (lang.currentLanguage) {
      case AppLanguage.arabic:
        title = '\u062a\u0637\u0628\u064a\u0642 \u062e\u062a\u0645\u0629';
        description =
            '\u0631\u0641\u064a\u0642\u0643 \u0627\u0644\u0625\u064a\u0645\u0627\u0646\u064a \u2022 \u0642\u0631\u0622\u0646 \u0643\u0631\u064a\u0645 \u2022 \u0645\u0648\u0627\u0642\u064a\u062a \u0627\u0644\u0635\u0644\u0627\u0629 \u2022 \u0623\u0630\u0643\u0627\u0631 \u0648\u0623\u062d\u0627\u062f\u064a\u062b \u2022 \u0662\u0664\u0660 \u0642\u0627\u0631\u0626 \u2022 \u0645\u062c\u0627\u0646\u064a \u0628\u0627\u0644\u0643\u0627\u0645\u0644';
        downloadBtn =
            '\ud83d\udcf1 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u062a\u0637\u0628\u064a\u0642';
        break;
      case AppLanguage.kurdish:
        title = '\u0626\u06d5\u067e\u06cc \u062e\u06d5\u062a\u0645\u06d5';
        description =
            '\u0647\u0627\u0648\u0695\u06ce\u06cc \u0626\u06cc\u0645\u0627\u0646\u06cc\u062a \u2022 \u0642\u0648\u0631\u0626\u0627\u0646\u06cc \u067e\u06cc\u0631\u06c6\u0632 \u2022 \u0643\u0627\u062a\u06d5\u0643\u0627\u0646\u06cc \u0646\u0648\u06ce\u0698 \u2022 \u0626\u06d5\u0632\u0643\u0627\u0631 \u0648 \u062d\u06d5\u062f\u06cc\u0633 \u2022 \u0662\u0664\u0660 \u0642\u0627\u0631\u06cc \u2022 \u0628\u06d5\u062e\u06c6\u0695\u0627\u06cc\u06cc';
        downloadBtn =
            '\ud83d\udcf1 \u062f\u0627\u0628\u06d5\u0632\u0627\u0646\u062f\u0646\u06cc \u0626\u06d5\u067e';
        break;
      case AppLanguage.english:
        title = 'Khatmah App';
        description =
            'Your faith companion \u2022 Quran \u2022 Prayer Times \u2022 Adhkar & Hadith \u2022 240 Reciters \u2022 Completely Free';
        downloadBtn = '\ud83d\udcf1 Download App';
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1B3A2D), const Color(0xFF0D1F17)]
                : [const Color(0xFFE8F5E9), Colors.white],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark
                ? const Color(0xFF4CAF50).withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B5E20).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: lang.getTextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: lang.getTextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFD700),
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final uri = Uri.parse(
                    'https://play.google.com/store/apps/details?id=com.khatmah.quran.yusf.app',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B5E20).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          downloadBtn,
                          style: lang.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Islamic corner decoration painter
class _IslamicCornerPainter extends CustomPainter {
  final Color color;
  final bool isTopLeft;
  final bool isTopRight;
  final bool isBottomLeft;
  final bool isBottomRight;

  _IslamicCornerPainter({
    required this.color,
    this.isTopLeft = false,
    this.isTopRight = false,
    this.isBottomLeft = false,
    this.isBottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (isTopLeft) {
      // Curved L-shape for top-left
      path.moveTo(0, size.height * 0.6);
      path.lineTo(0, size.height * 0.15);
      path.quadraticBezierTo(0, 0, size.width * 0.15, 0);
      path.lineTo(size.width * 0.6, 0);
      // Small decorative arc
      path.moveTo(size.width * 0.2, size.height * 0.2);
      path.arcToPoint(
        Offset(size.width * 0.35, size.height * 0.35),
        radius: const Radius.circular(15),
      );
    } else if (isTopRight) {
      path.moveTo(size.width, size.height * 0.6);
      path.lineTo(size.width, size.height * 0.15);
      path.quadraticBezierTo(size.width, 0, size.width * 0.85, 0);
      path.lineTo(size.width * 0.4, 0);
      path.moveTo(size.width * 0.8, size.height * 0.2);
      path.arcToPoint(
        Offset(size.width * 0.65, size.height * 0.35),
        radius: const Radius.circular(15),
        clockwise: false,
      );
    } else if (isBottomLeft) {
      path.moveTo(0, size.height * 0.4);
      path.lineTo(0, size.height * 0.85);
      path.quadraticBezierTo(0, size.height, size.width * 0.15, size.height);
      path.lineTo(size.width * 0.6, size.height);
      path.moveTo(size.width * 0.2, size.height * 0.8);
      path.arcToPoint(
        Offset(size.width * 0.35, size.height * 0.65),
        radius: const Radius.circular(15),
        clockwise: false,
      );
    } else if (isBottomRight) {
      path.moveTo(size.width, size.height * 0.4);
      path.lineTo(size.width, size.height * 0.85);
      path.quadraticBezierTo(
        size.width,
        size.height,
        size.width * 0.85,
        size.height,
      );
      path.lineTo(size.width * 0.4, size.height);
      path.moveTo(size.width * 0.8, size.height * 0.8);
      path.arcToPoint(
        Offset(size.width * 0.65, size.height * 0.65),
        radius: const Radius.circular(15),
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Elegant support button shown near the day counter.
/// Opens the official support page in the device's external browser.
class _SupportButton extends StatelessWidget {
  final LanguageService lang;

  const _SupportButton({required this.lang});

  @override
  Widget build(BuildContext context) {
    final isDark = lang.isDarkMode;

    final label = switch (lang.currentLanguage) {
      AppLanguage.kurdish => 'ساهم في استمرار التطبيق',
      AppLanguage.arabic => 'ساهم في استمرار التطبيق',
      AppLanguage.english => 'Keep the app going',
    };

    // Static (no continuous animation) — light and cheap.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: GestureDetector(
        onTap: openSupportExternal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: isDark
                  ? const [Color(0xFF14B8A6), Color(0xFF0D9488)]
                  : const [Color(0xFF0D9488), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.28),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3314B8A6),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: lang.getTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.open_in_new_rounded,
                color: Colors.white,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

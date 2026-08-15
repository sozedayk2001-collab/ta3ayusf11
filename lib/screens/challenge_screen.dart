import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/challenge_service.dart';
import '../services/language_service.dart';

/// 90-Day Challenge Screen with RPG Game Design
class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;
  final ChallengeService _challengeService = ChallengeService();
  bool _isLoading = true;
  int _currentTab = 0; // 0: Challenge, 1: Hall of Fame
  Timer? _dayTimer;
  int _lastCheckedDay = -1;

  @override
  void initState() {
    super.initState();
    _startDayWatcher();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  void _startDayWatcher() {
    _lastCheckedDay = _challengeService.realDay;
    // Check every 10 seconds if the day has changed
    _dayTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkDayChange();
    });
  }

  Future<void> _checkDayChange() async {
    if (!mounted || !_challengeService.isActive) return;
    final newDay = _challengeService.realDay;
    if (newDay != _lastCheckedDay) {
      _lastCheckedDay = newDay;
      // Generate/align today's task set exactly once (idempotent + race-safe).
      await _challengeService.ensureTasksForToday();
      if (!mounted) return;
      setState(() {});
      final newStage = _challengeService.checkNewStageCelebration();
      if (newStage != null) {
        _showStageCelebration(newStage);
      }
    }
  }

  Future<void> _loadData() async {
    await _challengeService.loadData();
    _lastCheckedDay = _challengeService.realDay;

    // Check for 5-day inactivity reset
    if (_challengeService.isActive && _challengeService.shouldResetDueToInactivity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInactivityResetDialog();
      });
    }
    
    // Check for new stage celebration
    if (_challengeService.isActive) {
        final newStage = _challengeService.checkNewStageCelebration();
        if (newStage != null) {
          _showStageCelebration(newStage);
        }
        
        // Check for self message (Day 1 only)
        if (_challengeService.realDay == 1 && _challengeService.selfMessage == null) {
          _showSelfMessageDialog();
        }

    }
    
    setState(() => _isLoading = false);
  }

  void _showStageCelebration(int stageNum) {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final stage = ChallengeService.journeyStages.firstWhere((s) => s.stage == stageNum, orElse: () => ChallengeService.journeyStages[0]);
    final langCode = lang.currentLanguage == AppLanguage.kurdish ? 'ku' : lang.currentLanguage == AppLanguage.arabic ? 'ar' : 'en';
    final story = _challengeService.getStageStory(stageNum, langCode);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: stage.color.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Confetti-like header
              Stack(
                alignment: Alignment.center,
                children: [
                  Text('🎊', style: TextStyle(fontSize: 80)),
                  Text(stage.emoji, style: TextStyle(fontSize: 60)),
                ],
              ),
              const SizedBox(height: 16),
              Text('🎉 ${_getCongratulationsText(lang)} 🎉', style: lang.getTextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
              )),
              const SizedBox(height: 12),
              Text(_getStageName(stage, lang), style: lang.getTextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70,
              )),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(story, style: lang.getTextStyle(
                  fontSize: 14, color: Colors.white, height: 1.5,
                ), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 20),
              // Hidden reward check
              if (_challengeService.hasHiddenReward)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎁', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(_getHiddenRewardText(lang), style: lang.getTextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white,
                      )),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: stage.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(_getContinueText(lang), style: lang.getTextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInactivityResetDialog() {
    final lang = Provider.of<LanguageService>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getInactivityTitle(lang),
                style: lang.getTextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😔', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              _getInactivityMessage(lang),
              style: lang.getTextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          // Continue button - allows user to keep going
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _getContinueText(lang), 
              style: lang.getTextStyle(color: Colors.green),
            ),
          ),
          // Reset button
          ElevatedButton(
            onPressed: () async {
              await _challengeService.resetChallenge();
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_getRestartText(lang), style: lang.getTextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  String _getInactivityTitle(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish 
      ? 'سفر بوویتەوە!' 
      : lang.currentLanguage == AppLanguage.arabic 
          ? 'تم إعادة الضبط!' 
          : 'Reset!';
  
  String _getInactivityMessage(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish 
      ? 'ماوەیەکی زۆر بێ کردەوەی بوویت!\n\n• لە سەرەتا: ٣ ڕۆژ هیچ نەکەیت = سفر\n• لە ڕێگادا: ٥ ڕۆژ هیچ نەکەیت = سفر\n\nجارێکی تر هەوڵ بدەرەوە!' 
      : lang.currentLanguage == AppLanguage.arabic 
          ? 'مدة طويلة دون نشاط!\n\n• في البداية: ٣ أيام دون نشاط = إعادة\n• في الرحلة: ٥ أيام دون نشاط = إعادة\n\nحاول مرة أخرى!' 
          : 'Too long without activity!\n\n• At start: 3 days no activity = reset\n• During journey: 5 days no activity = reset\n\nTry again!';
  
  String _getRestartText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish 
      ? 'دەستپێبکەوە' 
      : lang.currentLanguage == AppLanguage.arabic 
          ? 'ابدأ من جديد' 
          : 'Start Over';

  @override
  void dispose() {
    _dayTimer?.cancel();
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check for day change on every build
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDayChange());
    final lang = Provider.of<LanguageService>(context);
    final isDark = lang.isDarkMode;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0a1628) : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _getStageColors(),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -90,
                right: -70,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [const Color(0xFFFFD700).withOpacity(0.16), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: -90,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [const Color(0xFF14B8A6).withOpacity(0.13), Colors.transparent],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(lang),
                    Expanded(
                      child: _currentTab == 0
                          ? (_challengeService.isActive
                              ? _buildActiveChallenge(lang, isDark)
                              : _buildStartScreen(lang, isDark))
                          : _currentTab == 1
                              ? _buildStatsAndBadges(lang, isDark)
                              : _buildHallOfFame(lang, isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _challengeSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double radius = 24,
    Color? accent,
  }) {
    final glow = accent ?? const Color(0xFF14B8A6);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.16),
            Colors.white.withOpacity(0.07),
            glow.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.15),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: glow.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildChallengeHeroBanner(LanguageService lang, {required bool isActive}) {
    final stage = _challengeService.isActive ? _challengeService.getCurrentStage() : null;
    final accent = stage?.color ?? const Color(0xFFFFD700);
    final day = _challengeService.currentDay.clamp(1, 90);
    return _challengeSurface(
      radius: 32,
      accent: accent,
      padding: const EdgeInsets.all(22),
      child: Stack(
        children: [
          // Inner glow orb
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent.withOpacity(0.95), const Color(0xFFFFD700).withOpacity(0.85)],
                      ),
                      boxShadow: [
                        BoxShadow(color: accent.withOpacity(0.5), blurRadius: 32, offset: const Offset(0, 14)),
                        BoxShadow(color: accent.withOpacity(0.2), blurRadius: 40, spreadRadius: 2),
                      ],
                      border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
                    ),
                    child: Center(
                      child: Text(isActive ? (stage?.emoji ?? '🛡️') : '🛡️', style: const TextStyle(fontSize: 44)),
                    ),
                  ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? '${_getDayText(lang)} $day / 90' : _getTitle(lang),
                      style: lang.getTextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isActive ? _getStageName(stage!, lang) : _getSubtitle(lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: lang.getTextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.74), height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LinearProgressIndicator(
              value: isActive ? (day / 90).clamp(0.0, 1.0) : 0.0,
              minHeight: 12,
              backgroundColor: Colors.black.withOpacity(0.24),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildHeroMetric(Icons.local_fire_department_rounded, '${_challengeService.currentStreak}', 'Streak', Colors.orange),
              const SizedBox(width: 10),
              _buildHeroMetric(Icons.star_rounded, '${_challengeService.totalXP}', 'XP', const Color(0xFFFFD700)),
              const SizedBox(width: 10),
              _buildHeroMetric(Icons.flag_rounded, '${_challengeService.getCurrentStageNumber()}/18', _getStagesText(lang), const Color(0xFF14B8A6)),
            ],
          ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withOpacity(0.22),
              Colors.black.withOpacity(0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 5),
            Text(value, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(LanguageService lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 360;
          final iconSize = isSmall ? 18.0 : 22.0;
          
          return Row(
            children: [
              // Back to home button
              _challengeSurface(
                radius: 18,
                padding: EdgeInsets.zero,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: iconSize),
                  padding: EdgeInsets.all(isSmall ? 10 : 12),
                  constraints: const BoxConstraints(),
                  tooltip: 'Back',
                ),
              ),
              if (_challengeService.isCompleted)
                 IconButton(
                   onPressed: _showCertificateDialog,
                   icon: Icon(Icons.workspace_premium, color: Colors.amber, size: iconSize),
                   padding: const EdgeInsets.all(4),
                   constraints: const BoxConstraints(),
                 ),
              const SizedBox(width: 8),
              // Tab buttons - flexible
              Expanded(
                child: _challengeSurface(
                  radius: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTabButton(0, Icons.shield, _getChallenge(lang), lang, isSmall),
                      _buildTabButton(1, Icons.bar_chart, _getStatsText(lang), lang, isSmall),
                      _buildTabButton(2, Icons.emoji_events, _getHallOfFame(lang), lang, isSmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // XP Counter - compact
              if (_challengeService.isActive)
                _challengeSurface(
                  accent: const Color(0xFFFFD700),
                  radius: 18,
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: const Color(0xFFFFD700), size: isSmall ? 16 : 18),
                      const SizedBox(width: 2),
                      Text(
                        '${_challengeService.totalXP}',
                        style: lang.getTextStyle(
                          fontSize: isSmall ? 13 : 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFD700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildTabButton(int index, IconData icon, String label, LanguageService lang, bool isSmall) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: isSmall ? 10 : 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFF0D9488)])
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? Colors.white.withOpacity(0.16) : Colors.transparent,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF14B8A6).withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? Colors.white : Colors.white54, size: isSmall ? 20 : 24),
            // Hide text on small screens
            if (!isSmall) ...[
              const SizedBox(width: 4),
              Text(label, style: lang.getTextStyle(
                fontSize: 10,
                           color: isActive ? Colors.white : Colors.white70,
                           fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              )),
            ],
          ],
        ),
      ),
    );
  }


  List<Color> _getStageColors() {
    if (!_challengeService.isActive) {
      return [const Color(0xFF0F172A), const Color(0xFF1E293B)]; // Slate Dark
    }
    final stage = _challengeService.getCurrentStage();
    // Using muted versions of stage colors mixed with dark slate for eye comfort
    return [
      Color.alphaBlend(stage.color.withOpacity(0.2), const Color(0xFF0F172A)),
      Color.alphaBlend(stage.color.withOpacity(0.1), const Color(0xFF1E293B)),
      const Color(0xFF0F172A),
    ];
  }

  Widget _buildStatsAndBadges(LanguageService lang, bool isDark) {
    final stats = _challengeService.getStats();
    final earnedBadges = _challengeService.getEarnedBadges();
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Header
            Text('📊 ${_getStatsText(lang)}', style: lang.getTextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
            )),
            const SizedBox(height: 16),
            
            // Stats Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard('📅', _getDayText(lang), '${stats['currentDay']}/90', Colors.blue),
                _buildStatCard('⭐', 'XP', '${stats['totalXP']}', Colors.amber),
                _buildStatCard('🔥', 'Streak', '${stats['currentStreak']}', Colors.orange),
                _buildStatCard('🏆', _getBestStreakText(lang), '${stats['highestStreak']}', Colors.teal),
                _buildStatCard('✅', _getTotalTasksText(lang), '${stats['totalTasks']}', Colors.green),
                _buildStatCard('📍', _getStagesText(lang), '${stats['currentStage']}/18', Colors.teal),
              ],
            ),
            
            // Progress Bar
            const SizedBox(height: 24),
            Text('${stats['progressPercent']}% ${_getCompleteText(lang)}', style: lang.getTextStyle(
              fontSize: 14, color: Colors.white70,
            )),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: stats['progressPercent'] / 100,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                minHeight: 10,
              ),
            ),
            
            // Badges Section
            const SizedBox(height: 32),
            Text('🏅 ${_getBadgesText(lang)} (${earnedBadges.length}/${allBadges.length})', style: lang.getTextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
            )),
            const SizedBox(height: 16),
            
            // Badges Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: allBadges.length,
              itemBuilder: (context, index) {
                final badge = allBadges[index];
                final isEarned = earnedBadges.contains(badge);
                return _buildBadgeItem(badge, isEarned, lang);
              },
            ),
            
            // Progress Calendar Section
            const SizedBox(height: 32),
            Text('📅 ${_getCalendarText(lang)}', style: lang.getTextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
            )),
            const SizedBox(height: 8),
            _buildCalendarLegend(lang),
            const SizedBox(height: 16),
            _buildProgressCalendar(lang),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String emoji, String label, String value, Color color) {
    return _challengeSurface(
      accent: color,
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(ChallengeBadge badge, bool isEarned, LanguageService lang) {
    return GestureDetector(
      onTap: () => _showBadgeDialog(badge, isEarned, lang),
      child: _challengeSurface(
        accent: isEarned ? badge.color : Colors.grey,
        radius: 18,
        padding: const EdgeInsets.all(10),
        child: Center(
          child: Text(
            isEarned ? badge.emoji : '🔒',
            style: TextStyle(fontSize: 28, color: isEarned ? null : Colors.grey),
          ),
        ),
      ),
    );
  }

  void _showBadgeDialog(ChallengeBadge badge, bool isEarned, LanguageService lang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getBadgeName(badge, lang),
                style: lang.getTextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getBadgeDesc(badge, lang),
              style: lang.getTextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isEarned ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isEarned ? '✅ ${_getUnlockedText(lang)}' : '🔒 ${_getStagesText(lang)} ${badge.stageRequired}',
                style: lang.getTextStyle(color: isEarned ? Colors.green : Colors.orange, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_getCloseText(lang), style: lang.getTextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarLegend(LanguageService lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.green, _getCompletedText(lang)),
        const SizedBox(width: 16),
        _buildLegendItem(Colors.orange, _getPartialText(lang)),
        const SizedBox(width: 16),
        _buildLegendItem(Colors.red, _getMissedText(lang)),
        const SizedBox(width: 16),
        _buildLegendItem(Colors.grey.shade700, _getFutureText(lang)),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
      ],
    );
  }

  Widget _buildProgressCalendar(LanguageService lang) {
    final currentDay = _challengeService.currentDay;
    final realDay = _challengeService.realDay;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
      ),
      child: Column(
        children: [
          // Stage headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStageHeader('1-30', '🌱', Colors.green),
              _buildStageHeader('31-60', '⚔️', Colors.blue),
              _buildStageHeader('61-90', '👑', Colors.amber),
            ],
          ),
          const SizedBox(height: 16),
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10, mainAxisSpacing: 8, crossAxisSpacing: 8,
            ),
            itemCount: 90,
            itemBuilder: (context, index) {
              final day = index + 1;
              Color bgColor;
              IconData? icon;
              
              if (day > realDay) {
                bgColor = Colors.grey.shade800;
              } else if (_challengeService.isDayCompleted(day)) {
                bgColor = const Color(0xFF4CAF50);
                icon = Icons.check;
              } else if (_challengeService.hasAnyTaskDone(day)) {
                bgColor = const Color(0xFFFF9800);
                icon = Icons.remove;
              } else {
                bgColor = const Color(0xFFE53935);
                icon = Icons.close;
              }
              
              final isToday = day == currentDay;
              final isMilestone = day % 10 == 0;
              
              return GestureDetector(
                onTap: () => _showDayDetails(day, lang),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: day <= realDay 
                        ? LinearGradient(colors: [bgColor, bgColor.withOpacity(0.6)])
                        : null,
                    color: day > realDay ? bgColor.withOpacity(0.2) : null,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday ? Border.all(color: Colors.white, width: 2.5) : null,
                    boxShadow: isToday ? [BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 8)] : null,
                  ),
                  child: Center(
                    child: isMilestone 
                        ? Text('$day', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))
                        : icon != null && day <= realDay
                            ? Icon(icon, size: 14, color: Colors.white.withOpacity(0.9))
                            : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader(String range, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(range, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showDayDetails(int day, LanguageService lang) {
    final realDay = _challengeService.realDay;
    if (day > realDay) return;
    
    final isDone = _challengeService.isDayCompleted(day);
    final hasAny = _challengeService.hasAnyTaskDone(day);
    
    String status = isDone 
        ? '✅ ${_getCompletedText(lang)}' 
        : hasAny 
            ? '◐ ${_getPartialText(lang)}'
            : '❌ ${_getMissedText(lang)}';

    // Calculate the actual calendar date for this challenge day
    final challengeStartDate = DateTime.now().subtract(Duration(days: realDay - 1));
    final dayDate = challengeStartDate.add(Duration(days: day - 1));
    final dateStr = '${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}/${dayDate.year}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${_getDayText(lang)} $day', style: lang.getTextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20,
        )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status, style: lang.getTextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 10),
            Text('📅 $dateStr', style: lang.getTextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_getCloseText(lang), style: lang.getTextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildStartScreen(LanguageService lang, bool isDark) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
        child: Column(
          children: [
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) => Transform.translate(offset: Offset(0, _floatAnimation.value), child: child),
              child: _buildChallengeHeroBanner(lang, isActive: false),
            ),
            const SizedBox(height: 30),
            _buildStagesPreview(lang),
            const SizedBox(height: 30),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(scale: _pulseAnimation.value, child: child);
              },
              child: GestureDetector(
                onTap: () async {
                  await _challengeService.startChallenge();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        _getStartButtonText(lang),
                        style: lang.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStagesPreview(LanguageService lang) {
    return _challengeSurface(
      radius: 28,
      accent: const Color(0xFFFFD700),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('🗺️ 18 ${_getStagesText(lang)}', style: lang.getTextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
          )),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: ChallengeService.journeyStages.length,
              itemBuilder: (context, index) {
                final stage = ChallengeService.journeyStages[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [stage.color.withOpacity(0.3), stage.color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: stage.color.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: stage.color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text(stage.emoji, style: const TextStyle(fontSize: 20))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStageName(stage, lang),
                              style: lang.getTextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _getStageDesc(stage, lang),
                              style: lang.getTextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_getDayText(lang)} ${stage.startDay}-${stage.endDay}',
                          style: lang.getTextStyle(fontSize: 10, color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChallenge(LanguageService lang, bool isDark) {
    final currentDay = _challengeService.currentDay;
    final currentLevel = _challengeService.getCurrentLevel();
    final nextLevel = _challengeService.getNextLevel();
    final currentStage = _challengeService.getCurrentStage();
    final dailyTasks = _challengeService.getDailyTasks(currentDay);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
        child: Column(
          children: [
            _buildChallengeHeroBanner(lang, isActive: true),
            const SizedBox(height: 18),
            // Hero section
            _buildHeroSection(currentLevel, nextLevel, lang),
            const SizedBox(height: 20),
            // Current stage
            _buildStageCard(currentStage, currentDay, lang),
            const SizedBox(height: 20),
            // Daily tasks (2-3)
            Text('⚔️ ${dailyTasks.length} ${_getTodayMissions(lang)}', style: lang.getTextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
            )),
            const SizedBox(height: 12),
            // Check if all tasks completed
            if (dailyTasks.every((t) => t.isCompleted)) ...[
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.withOpacity(0.3), Colors.teal.withOpacity(0.2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(_getWellDoneText(lang), style: lang.getTextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green,
                    )),
                    const SizedBox(height: 8),
                    Text(_getComeBackTomorrowText(lang), style: lang.getTextStyle(
                      fontSize: 14, color: Colors.white70,
                    ), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
            ...dailyTasks.map((task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTaskCard(task, lang),
            )),
            const SizedBox(height: 16),
            // Journey map
            _buildJourneyMap(currentDay, lang),
            const SizedBox(height: 16),
            if (_challengeService.isCompleted) ...[
              _buildHomeStyleButton(
                icon: Icons.replay_circle_filled_rounded,
                title: _getRestartCompleteChallengeText(lang),
                color: Colors.amber,
                onTap: () => _showRestartChallengeDialog(lang),
                lang: lang,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
            ],
            _buildHomeStyleButton(
              icon: Icons.refresh_rounded,
              title: _getResetText(lang),
              color: Colors.redAccent,
              onTap: () => _showResetDialog(lang),
              lang: lang,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeStyleButton({required IconData icon, required String title, required Color color, required VoidCallback onTap, required LanguageService lang, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title, 
                style: lang.getTextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
            ),
            Icon(lang.isRTL ? Icons.chevron_left : Icons.chevron_right, color: isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(HeroLevel currentLevel, HeroLevel? nextLevel, LanguageService lang) {
    final currentDay = _challengeService.currentDay;
    final daysToNext = nextLevel != null ? nextLevel.daysRequired - currentDay : 0;
    final progress = nextLevel != null
        ? (currentDay - currentLevel.daysRequired) / (nextLevel.daysRequired - currentLevel.daysRequired)
        : 1.0;

    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(offset: Offset(0, _floatAnimation.value), child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              currentLevel.color.withOpacity(0.4),
              currentLevel.color.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: currentLevel.color.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(color: currentLevel.color.withOpacity(0.15), blurRadius: 24, spreadRadius: 4, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow effect
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: currentLevel.color.withOpacity(0.6), blurRadius: 30, spreadRadius: 5)],
                      ),
                    ),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [currentLevel.color.withOpacity(0.8), currentLevel.color],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                      ),
                      child: Center(child: Text(currentLevel.emoji, style: const TextStyle(fontSize: 36))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(_getLevelName(currentLevel, lang), style: lang.getTextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white,
                  shadows: [Shadow(color: currentLevel.color.withOpacity(0.8), blurRadius: 10)],
                )),
                if (nextLevel != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🚀 ${_getNextLevelText(lang)}', style: lang.getTextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: nextLevel.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: nextLevel.color.withOpacity(0.5)),
                        ),
                        child: Text('$daysToNext ${_getDaysRemaining(lang)}', style: lang.getTextStyle(fontSize: 11, color: nextLevel.color, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: nextLevel.color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.black.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(nextLevel.color),
                      ),
                    ),
                  ),
                ],
              ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageCard(JourneyStage stage, int currentDay, LanguageService lang) {
    final stageProgress = (currentDay - stage.startDay) / (stage.endDay - stage.startDay);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [stage.color.withOpacity(0.35), stage.color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stage.color.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: stage.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: stage.color.withOpacity(0.5)),
                    ),
                    child: Text(stage.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getStageName(stage, lang), style: lang.getTextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                        )),
                        const SizedBox(height: 4),
                        Text(_getStageDesc(stage, lang), style: lang.getTextStyle(
                          fontSize: 12, color: Colors.white70, height: 1.3,
                        )),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text('${_getDayText(lang)} ${stage.startDay}-${stage.endDay}', style: lang.getTextStyle(
                      fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold,
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: stageProgress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.black.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(stage.color),
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildTaskCard(DailyTask task, LanguageService lang) {
    final isCompleted = task.isCompleted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.withOpacity(0.08) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isCompleted ? Colors.green.withOpacity(0.5) : Colors.white12, width: 1.5),
        boxShadow: isCompleted ? [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 10)] : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getTaskIcon(task.type), color: isCompleted ? Colors.green : Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTaskTitle(task, lang), 
                  style: lang.getTextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white).copyWith(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTaskDesc(task, lang), 
                  style: lang.getTextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 4)],
                ),
                child: Text('+${task.xpReward} XP', style: lang.getTextStyle(
                  fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold,
                )),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Timer Button
                  if (!isCompleted && task.durationMinutes != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _showTimerDialog(task),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withOpacity(0.2),
                            border: Border.all(color: const Color(0xFF9C27B0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.timer_rounded, color: Color(0xFFE040FB), size: 18),
                        ),
                      ),
                    ),

                  // Swap Button
                  if (!isCompleted && _challengeService.canSwapTask)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () async {
                          _challengeService.useTaskSwap();
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: Colors.blueAccent, size: 18),
                        ),
                      ),
                    ),

                  // Toggle Button
                  GestureDetector(
                    onTap: () async {
                      await _challengeService.toggleTask(task);
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: isCompleted 
                            ? LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade400])
                            : LinearGradient(colors: [Colors.green.shade400, Colors.teal.shade500]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: isCompleted ? Colors.orange.withOpacity(0.4) : Colors.green.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Icon(
                        isCompleted ? Icons.undo_rounded : Icons.check_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyMap(int currentDay, LanguageService lang) {
    final currentStageNum = _challengeService.getCurrentStageNumber();
    final realDay = _challengeService.realDay;
    final challengeStartDate = DateTime.now().subtract(Duration(days: realDay - 1));
    return _challengeSurface(
      radius: 24,
      accent: const Color(0xFF14B8A6),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text('🗺️ ${_getJourneyMap(lang)}', style: lang.getTextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
          )),
          const SizedBox(height: 16),
          SizedBox(
            height: 145,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ChallengeService.journeyStages.length,
              itemBuilder: (context, index) {
                final stage = ChallengeService.journeyStages[index];
                final isPassed = currentStageNum > stage.stage;
                final isCurrent = currentStageNum == stage.stage;
                final stageDate = challengeStartDate.add(Duration(days: stage.startDay - 1));
                final dateStr = '${stageDate.day.toString().padLeft(2, '0')}/${stageDate.month.toString().padLeft(2, '0')}';
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isPassed || isCurrent
                          ? [stage.color.withOpacity(0.5), stage.color.withOpacity(0.2)]
                          : [Colors.grey.withOpacity(0.2), Colors.grey.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrent 
                        ? Border.all(color: Colors.white, width: 2) 
                        : Border.all(color: isPassed ? stage.color.withOpacity(0.5) : Colors.grey.withOpacity(0.3)),
                    boxShadow: isCurrent ? [
                      BoxShadow(color: stage.color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2),
                    ] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(stage.emoji, style: TextStyle(
                        fontSize: 24,
                        color: isPassed || isCurrent ? null : Colors.grey,
                      )),
                      const SizedBox(height: 4),
                      Text(
                        _getStageName(stage, lang),
                        style: lang.getTextStyle(
                          fontSize: 9,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? Colors.white : (isPassed ? Colors.white70 : Colors.white38),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '📅 $dateStr',
                        style: lang.getTextStyle(
                          fontSize: 8,
                          color: isCurrent ? Colors.white70 : (isPassed ? Colors.white54 : Colors.white24),
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (isPassed)
                        const Icon(Icons.check_circle, color: Colors.green, size: 14)
                      else if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${stage.startDay}-${stage.endDay}', style: lang.getTextStyle(
                            fontSize: 8, color: Colors.white,
                          )),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHallOfFame(LanguageService lang, bool isDark) {
    return StreamBuilder<List<ChallengeCompleter>>(
      stream: _challengeService.getCompletersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final completers = snapshot.data ?? [];
        if (completers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('👑', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(_getNoCompleters(lang), style: lang.getTextStyle(
                  fontSize: 16, color: Colors.white70,
                ), textAlign: TextAlign.center),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
          itemCount: completers.length,
          itemBuilder: (context, index) {
            final completer = completers[index];
            return _buildCompleterCard(completer, index + 1, lang);
          },
        );
      },
    );
  }

  Widget _buildCompleterCard(ChallengeCompleter completer, int rank, LanguageService lang) {
    bool isTop3 = rank <= 3;
    Color rankColor;
    String rankBadge;
    
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankBadge = '🥇';
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankBadge = '🥈';
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankBadge = '🥉';
    } else {
      rankColor = Colors.white38;
      rankBadge = '🎖️';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTop3 ? rankColor.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop3 ? rankColor.withOpacity(0.5) : Colors.white12,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (isTop3)
            // Medal replaces avatar for top 3
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    rankColor.withOpacity(0.3),
                    rankColor.withOpacity(0.1),
                  ],
                ),
                border: Border.all(color: rankColor, width: 2.5),
                boxShadow: [
                  BoxShadow(color: rankColor.withOpacity(0.4), blurRadius: 12, spreadRadius: 2),
                ],
              ),
              child: Center(
                child: Text(rankBadge, style: const TextStyle(fontSize: 32)),
              ),
            )
          else
            // Regular avatar for rank 4+
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white10,
              backgroundImage: completer.photoURL != null ? NetworkImage(completer.photoURL!) : null,
              child: completer.photoURL == null
                  ? Text(
                      completer.displayName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 18),
                    )
                  : null,
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        completer.displayName,
                        style: lang.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isTop3 ? Colors.white : Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (completer.completionsCount > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withOpacity(0.5)),
                        ),
                        child: Text(
                          'x${completer.completionsCount}',
                          style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(completer.completedAt, lang),
                  style: lang.getTextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#$rank',
                style: lang.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isTop3 ? rankColor : Colors.white38,
                ),
              ),
              if (completer.totalXP > 0)
                Text(
                  '${completer.totalXP} XP',
                  style: lang.getTextStyle(fontSize: 11, color: Colors.amber),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showResetDialog(LanguageService lang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_getResetConfirmTitle(lang), style: lang.getTextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(_getResetConfirmMsg(lang), style: lang.getTextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_getCancel(lang), style: lang.getTextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _challengeService.resetChallenge();
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_getResetText(lang), style: lang.getTextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _getTaskIcon(TaskType type) {
    switch (type) {
      case TaskType.physical: return Icons.fitness_center;
      case TaskType.mental: return Icons.psychology;
      case TaskType.spiritual: return Icons.mosque;
      case TaskType.social: return Icons.people;
      case TaskType.discipline: return Icons.self_improvement;
    }
  }

  String _formatDate(DateTime date, LanguageService lang) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Localization
  String _getTitle(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'چاڵینجی ٩٠ ڕۆژ' : lang.currentLanguage == AppLanguage.arabic ? 'تحدي ٩٠ يوم' : '90-Day Challenge';
  String _getSubtitle(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'گەشتێک بۆ ئازادی - لە دیل بۆ پاشا' : lang.currentLanguage == AppLanguage.arabic ? 'رحلة نحو الحرية' : 'A journey to freedom';
  String _getStartButtonText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'دەستپێبکە' : lang.currentLanguage == AppLanguage.arabic ? 'ابدأ الآن' : 'Start Now';
  String _getChallenge(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'چاڵینج' : lang.currentLanguage == AppLanguage.arabic ? 'التحدي' : 'Challenge';
  String _getHallOfFame(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'سەرکەوتووان' : lang.currentLanguage == AppLanguage.arabic ? 'الفائزون' : 'Winners';
  String _getStagesText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'قۆناغ' : lang.currentLanguage == AppLanguage.arabic ? 'مرحلة' : 'Stages';
  String _getAndMore(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'و زیاتر' : lang.currentLanguage == AppLanguage.arabic ? 'والمزيد' : 'and more';
  String _getDayText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'ڕۆژ' : lang.currentLanguage == AppLanguage.arabic ? 'يوم' : 'Day';
  String _getDaysText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'ڕۆژ' : lang.currentLanguage == AppLanguage.arabic ? 'يوم' : 'days';
  String _getTodayMissions(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'مەرجەکانی ئەمڕۆ' : lang.currentLanguage == AppLanguage.arabic ? 'مهام اليوم' : "Today's Missions";
  String _getNextLevelText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'تاکو ئاستی داهاتوو' : lang.currentLanguage == AppLanguage.arabic ? 'للمستوى القادم' : 'To next level';
  String _getDaysRemaining(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'ڕۆژ ماوە' : lang.currentLanguage == AppLanguage.arabic ? 'يوم متبقي' : 'days left';
  String _getJourneyMap(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'نەخشەی گەشت' : lang.currentLanguage == AppLanguage.arabic ? 'خريطة الرحلة' : 'Journey Map';
  String _getResetText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'دەستپێکردنەوە' : lang.currentLanguage == AppLanguage.arabic ? 'إعادة البدء' : 'Reset';
  String _getResetConfirmTitle(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'دڵنیایت؟' : lang.currentLanguage == AppLanguage.arabic ? 'هل أنت متأكد؟' : 'Are you sure?';
  String _getResetConfirmMsg(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'هەموو پێشکەوتنەکەت دەسڕدرێتەوە' : lang.currentLanguage == AppLanguage.arabic ? 'سيتم حذف كل تقدمك' : 'All progress will be deleted';
  String _getCancel(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'نەخێر' : lang.currentLanguage == AppLanguage.arabic ? 'إلغاء' : 'Cancel';
  String _getNoCompleters(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'هێشتا کەس تەواوی نەکردووە\nیەکەمین بە!' : lang.currentLanguage == AppLanguage.arabic ? 'لم يكمله أحد بعد\nكن الأول!' : 'No completers yet\nBe the first!';
  String _getLevelName(HeroLevel l, LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? l.nameKu : lang.currentLanguage == AppLanguage.arabic ? l.nameAr : l.nameEn;
  String _getStageName(JourneyStage s, LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? s.nameKu : lang.currentLanguage == AppLanguage.arabic ? s.nameAr : s.nameEn;
  String _getStageDesc(JourneyStage s, LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? s.descriptionKu : lang.currentLanguage == AppLanguage.arabic ? s.descriptionAr : s.descriptionEn;
  String _getTaskTitle(DailyTask t, LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? t.titleKu : lang.currentLanguage == AppLanguage.arabic ? t.titleAr : t.titleEn;
  String _getTaskDesc(DailyTask t, LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? t.descriptionKu : lang.currentLanguage == AppLanguage.arabic ? t.descriptionAr : t.descriptionEn;
  String _getWellDoneText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'زۆر باش! ئەمڕۆ تەواوت کرد!' : lang.currentLanguage == AppLanguage.arabic ? 'أحسنت! أكملت اليوم!' : 'Well Done! Today Complete!';
  String _getComeBackTomorrowText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'سبەی بگەڕێوە بۆ مەرجەکانی نوێ' : lang.currentLanguage == AppLanguage.arabic ? 'عد غداً للمهام الجديدة' : 'Come back tomorrow for new tasks';
  
  // New Stats & Badges Localization
  String _getStatsText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'ئامار' : lang.currentLanguage == AppLanguage.arabic ? 'الإحصائيات' : 'Stats';
  String _getBestStreakText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'باشترین' : lang.currentLanguage == AppLanguage.arabic ? 'الأفضل' : 'Best';
  String _getTotalTasksText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'مەرجەکان' : lang.currentLanguage == AppLanguage.arabic ? 'المهام' : 'Tasks';
  String _getCompleteText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'تەواوکراوە' : lang.currentLanguage == AppLanguage.arabic ? 'مكتمل' : 'Complete';
  String _getBadgesText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'هێماکان' : lang.currentLanguage == AppLanguage.arabic ? 'الشارات' : 'Badges';
  String _getUnlockedText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'کرایەوە' : lang.currentLanguage == AppLanguage.arabic ? 'مفتوح' : 'Unlocked';
  String _getCloseText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'داخستن' : lang.currentLanguage == AppLanguage.arabic ? 'إغلاق' : 'Close';
  String _getBadgeName(ChallengeBadge b, LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? b.nameKu : lang.currentLanguage == AppLanguage.arabic ? b.nameAr : b.nameEn;
  String _getBadgeDesc(ChallengeBadge b, LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? b.descriptionKu : lang.currentLanguage == AppLanguage.arabic ? b.descriptionAr : b.descriptionEn;
  
  // Calendar Localization
  String _getCalendarText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'کالێندەری پێشکەوتن' : lang.currentLanguage == AppLanguage.arabic ? 'تقويم التقدم' : 'Progress Calendar';
  String _getCompletedText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'تەواو' : lang.currentLanguage == AppLanguage.arabic ? 'مكتمل' : 'Done';
  String _getPartialText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'نیوەی' : lang.currentLanguage == AppLanguage.arabic ? 'جزئي' : 'Partial';
  String _getMissedText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'نەکراو' : lang.currentLanguage == AppLanguage.arabic ? 'فائت' : 'Missed';
  String _getFutureText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'داهاتوو' : lang.currentLanguage == AppLanguage.arabic ? 'قادم' : 'Future';
  
  // Celebration & Features Localization
  String _getCongratulationsText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'پیرۆزە!' : lang.currentLanguage == AppLanguage.arabic ? 'مبروك!' : 'Congratulations!';
  String _getContinueText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'بەردەوام بە' : lang.currentLanguage == AppLanguage.arabic ? 'استمر' : 'Continue';
  String _getHiddenRewardText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'پاداشتی شاراوە دۆزرایەوە!' : lang.currentLanguage == AppLanguage.arabic ? 'تم العثور على مكافأة مخفية!' : 'Hidden Reward Found!';

  
  // Self Message Localization
  String _getSelfMessageTitle(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'پەیام بۆ داهاتوو' : lang.currentLanguage == AppLanguage.arabic ? 'رسالة للمستقبل' : 'Message to Future';
  String _getSelfMessageBody(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'پەیامێک بۆ خۆت بنووسە. لە ڕۆژی ٩٠ دەیبینیتەوە!' : lang.currentLanguage == AppLanguage.arabic ? 'اكتب رسالة لنفسك. ستراها في اليوم ٩٠!' : 'Write a message to yourself. You will see it on Day 90!';
  String _getSelfMessageHint(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'دەوێت ببم بە...' : lang.currentLanguage == AppLanguage.arabic ? 'أريد أن أصبح...' : 'I want to be...';
  String _getSaveText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'خەزنکردن' : lang.currentLanguage == AppLanguage.arabic ? 'حفظ' : 'Save';

  // Timer Localization
  String _getTimerText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'کاتژمێر' : lang.currentLanguage == AppLanguage.arabic ? 'المؤقت' : 'Timer';
  String _getStartText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'دەستپێکردن' : lang.currentLanguage == AppLanguage.arabic ? 'ابدأ' : 'Start';
  String _getStopText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'وەستان' : lang.currentLanguage == AppLanguage.arabic ? 'توقف' : 'Stop';
  String _getTimeUpText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'کات تەواو!' : lang.currentLanguage == AppLanguage.arabic ? 'انتهى الوقت!' : 'Time\'s Up!';

  Future<void> _showTimerDialog(DailyTask task) async {
    final lang = Provider.of<LanguageService>(context, listen: false);
    int remainingSeconds = (task.durationMinutes ?? 5) * 60;
    bool isRunning = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            
            // Timer logic would ideally be in a Timer object, but for simplicity:
            if (isRunning && remainingSeconds > 0) {
              Future.delayed(const Duration(seconds: 1), () {
                if (context.mounted && isRunning && remainingSeconds > 0) {
                  setState(() {
                    remainingSeconds--;
                  });
                }
              });
            }

            final minutes = remainingSeconds ~/ 60;
            final seconds = remainingSeconds % 60;
            final isDone = remainingSeconds <= 0;

            return AlertDialog(
              backgroundColor: const Color(0xFF1a2a4a),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                   const Icon(Icons.timer, color: Colors.white),
                   const SizedBox(width: 8),
                   Expanded(child: Text(_getTimerText(lang), style: lang.getTextStyle(color: Colors.white))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (isDone)
                    Text(_getTimeUpText(lang), style: lang.getTextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              actions: [
                if (!isDone)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isRunning = !isRunning;
                      });
                    },
                    child: Text(isRunning ? _getStopText(lang) : _getStartText(lang), style: TextStyle(color: isRunning ? Colors.red : Colors.green)),
                  ),
                ElevatedButton(
                  onPressed: () {
                    // Stop timer and close
                    isRunning = false;
                    Navigator.pop(context);
                    if (isDone) {
                       _challengeService.toggleTask(task); // Auto-complete if done? Maybe just let user check manually.
                       // Actually, better to just close. User can check manually.
                    }
                  },
                  child: Text(_getCloseText(lang)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSelfMessageDialog() async {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final controller = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_getSelfMessageTitle(lang), style: lang.getTextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_getSelfMessageBody(lang), style: lang.getTextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: lang.getTextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _getSelfMessageHint(lang),
                hintStyle: TextStyle(color: Colors.white38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white10,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _challengeService.saveSelfMessage(controller.text);
                Navigator.pop(context);
              }
            },
            child: Text(_getSaveText(lang)),
          ),
        ],
      ),
    );
  }
  
  // Certificate Localization
  String _getCertificateText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'بڕوانامە' : lang.currentLanguage == AppLanguage.arabic ? 'شهادة' : 'Certificate';
  String _getCompletedChallengeText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'چاڵینجی ٩٠ ڕۆژە تەواو بوو' : lang.currentLanguage == AppLanguage.arabic ? 'تم إكمال تحدي ٩٠ يوم' : '90 Days Challenge Completed';
  
  void _showCertificateDialog() {
    final lang = Provider.of<LanguageService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1a2a4a),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium, color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              Text(
                _getCertificateText(lang),
                style: lang.getTextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
              const SizedBox(height: 8),
              Text(
                _getCompletedChallengeText(lang),
                style: lang.getTextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // User info would go here (Name, Date, etc.)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 40)),
                     const SizedBox(height: 8),
                    Text('WARRIOR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                // Simulating share/close since sharing requires more setup
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.share),
                label: Text(_getCloseText(lang)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRestartCompleteChallengeText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish
      ? 'دووبارە دەستپێکردنەوەی تحدی'
      : lang.currentLanguage == AppLanguage.arabic
          ? 'إعادة بدء التحدي'
          : 'Restart Challenge';

  void _showRestartChallengeDialog(LanguageService lang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_getRestartCompleteChallengeText(lang), style: lang.getTextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          lang.currentLanguage == AppLanguage.kurdish 
            ? 'ئایا دڵنیای دەتەوێت دووبارە تحدیەکە دەستپێبکەیتەوە؟ لیدەربۆردەکەت پارێزراو دەبێت.'
            : lang.currentLanguage == AppLanguage.arabic
              ? 'هل أنت متأكد أنك تريد بدء التحدي مرة أخرى؟ ترتيبك في لوحة الصدارة سيكون محفوظاً.'
              : 'Are you sure you want to restart the challenge? Your leaderboard rank will be saved.',
          style: lang.getTextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_getCloseText(lang), style: lang.getTextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _challengeService.resetChallenge();
              await _challengeService.startChallenge();
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text(_getRestartCompleteChallengeText(lang), style: lang.getTextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

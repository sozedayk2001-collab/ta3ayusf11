import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'supabase_service.dart';
import '../data/daily_tasks_90.dart' as tasks90;

/// Hero levels with their names and requirements
class HeroLevel {
  final int level;
  final String nameEn;
  final String nameAr;
  final String nameKu;
  final int daysRequired;
  final IconData icon;
  final Color color;
  final String emoji;

  const HeroLevel({
    required this.level,
    required this.nameEn,
    required this.nameAr,
    required this.nameKu,
    required this.daysRequired,
    required this.icon,
    required this.color,
    required this.emoji,
  });
}

/// Journey stages - 18 stages (every 5 days)
class JourneyStage {
  final int stage;
  final String nameEn;
  final String nameAr;
  final String nameKu;
  final int startDay;
  final int endDay;
  final Color color;
  final IconData icon;
  final String emoji;
  final String descriptionEn;
  final String descriptionAr;
  final String descriptionKu;

  const JourneyStage({
    required this.stage,
    required this.nameEn,
    required this.nameAr,
    required this.nameKu,
    required this.startDay,
    required this.endDay,
    required this.color,
    required this.icon,
    required this.emoji,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.descriptionKu,
  });
}

/// Daily task model
class DailyTask {
  final String id;
  final int day;
  final String titleEn;
  final String titleAr;
  final String titleKu;
  final String descriptionEn;
  final String descriptionAr;
  final String descriptionKu;
  final int xpReward;
  final TaskType type;
  final int stageRequired;
  final int? durationMinutes; // For timed tasks
  bool isCompleted;

  DailyTask({
    required this.id,
    required this.day,
    required this.titleEn,
    required this.titleAr,
    required this.titleKu,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.descriptionKu,
    required this.xpReward,
    required this.type,
    this.stageRequired = 1,
    this.durationMinutes,
    this.isCompleted = false,
  });

  DailyTask copyWith({String? id, int? day, bool? isCompleted}) {
    return DailyTask(
      id: id ?? this.id,
      day: day ?? this.day,
      titleEn: titleEn,
      titleAr: titleAr,
      titleKu: titleKu,
      descriptionEn: descriptionEn,
      descriptionAr: descriptionAr,
      descriptionKu: descriptionKu,
      xpReward: xpReward,
      type: type,
      stageRequired: stageRequired,
      durationMinutes: durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

enum TaskType { physical, mental, spiritual, social, discipline }

/// Challenge completer for hall of fame
class ChallengeCompleter {
  final String oderId;
  final String displayName;
  final String? photoURL;
  final DateTime completedAt;
  final int totalXP;
  final int totalDays;
  final int completionsCount;

  ChallengeCompleter({
    required this.oderId,
    required this.displayName,
    this.photoURL,
    required this.completedAt,
    required this.totalXP,
    required this.totalDays,
    this.completionsCount = 1,
  });

  factory ChallengeCompleter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChallengeCompleter(
      oderId: doc.id,
      displayName: data['displayName'] ?? 'Unknown',
      photoURL: data['photoURL'],
      completedAt: (data['completedAt'] as Timestamp).toDate(),
      totalXP: data['totalXP'] ?? 0,
      totalDays: data['totalDays'] ?? 90,
      completionsCount: data['completionsCount'] ?? 1,
    );
  }
}

/// Badge for achievements
class ChallengeBadge {
  final String id;
  final String nameEn;
  final String nameAr;
  final String nameKu;
  final String emoji;
  final Color color;
  final int stageRequired;
  final String descriptionEn;
  final String descriptionAr;
  final String descriptionKu;

  const ChallengeBadge({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.nameKu,
    required this.emoji,
    required this.color,
    required this.stageRequired,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.descriptionKu,
  });
}

/// All available badges
const List<ChallengeBadge> allBadges = [
  ChallengeBadge(id: 'first_day', nameEn: 'First Step', nameAr: 'الخطوة الأولى', nameKu: 'یەکەم هەنگاو', emoji: '🚶', color: Color(0xFF4CAF50), stageRequired: 1, descriptionEn: 'Complete day 1', descriptionAr: 'أكمل اليوم الأول', descriptionKu: 'ڕۆژی یەکەم تەواو بکە'),
  ChallengeBadge(id: 'week_warrior', nameEn: 'Week Warrior', nameAr: 'محارب الأسبوع', nameKu: 'جەنگاوەری هەفتە', emoji: '⚔️', color: Color(0xFF2196F3), stageRequired: 2, descriptionEn: 'Complete 1 week', descriptionAr: 'أكمل أسبوعاً', descriptionKu: 'یەک هەفتە تەواو بکە'),
  ChallengeBadge(id: 'desert_survivor', nameEn: 'Desert Survivor', nameAr: 'ناجي الصحراء', nameKu: 'دەربازبووی چۆڵەوانی', emoji: '🏜️', color: Color(0xFFFF9800), stageRequired: 4, descriptionEn: 'Survive the desert', descriptionAr: 'انجُ من الصحراء', descriptionKu: 'لە چۆڵەوانی دەربازببە'),
  ChallengeBadge(id: 'oasis_finder', nameEn: 'Oasis Finder', nameAr: 'مكتشف الواحة', nameKu: 'دۆزەرەوەی ئۆئازیس', emoji: '💧', color: Color(0xFF14B8A6), stageRequired: 5, descriptionEn: 'Find the oasis', descriptionAr: 'اكتشف الواحة', descriptionKu: 'ئۆئازیس بدۆزەرەوە'),
  ChallengeBadge(id: 'month_master', nameEn: 'Month Master', nameAr: 'سيد الشهر', nameKu: 'مەستەری مانگ', emoji: '📅', color: Color(0xFF9C27B0), stageRequired: 6, descriptionEn: 'Complete 1 month', descriptionAr: 'أكمل شهراً', descriptionKu: 'یەک مانگ تەواو بکە'),
  ChallengeBadge(id: 'forest_navigator', nameEn: 'Forest Navigator', nameAr: 'ملاح الغابة', nameKu: 'ڕێنمای دارستان', emoji: '🌲', color: Color(0xFF4CAF50), stageRequired: 7, descriptionEn: 'Navigate the forest', descriptionAr: 'تنقل في الغابة', descriptionKu: 'لە دارستان تێپەڕە'),
  ChallengeBadge(id: 'river_crosser', nameEn: 'River Crosser', nameAr: 'عابر النهر', nameKu: 'تێپەڕەری ڕووبار', emoji: '🌊', color: Color(0xFF03A9F4), stageRequired: 9, descriptionEn: 'Cross the river', descriptionAr: 'اعبر النهر', descriptionKu: 'لە ڕووبار تێپەڕە'),
  ChallengeBadge(id: 'mountain_climber', nameEn: 'Mountain Climber', nameAr: 'متسلق الجبال', nameKu: 'سەرکەوەری چیا', emoji: '⛰️', color: Color(0xFF795548), stageRequired: 10, descriptionEn: 'Reach the mountain', descriptionAr: 'وصل للجبل', descriptionKu: 'بگەیە چیا'),
  ChallengeBadge(id: 'summit_conqueror', nameEn: 'Summit Conqueror', nameAr: 'فاتح القمة', nameKu: 'داگیرکەری لووتکە', emoji: '🏔️', color: Color(0xFF0D9488), stageRequired: 13, descriptionEn: 'Reach the summit', descriptionAr: 'وصل للقمة', descriptionKu: 'بگەیە لووتکە'),
  ChallengeBadge(id: 'light_seeker', nameEn: 'Light Seeker', nameAr: 'باحث النور', nameKu: 'گەڕانەوەی ڕوناکی', emoji: '✨', color: Color(0xFF673AB7), stageRequired: 15, descriptionEn: 'Find the light', descriptionAr: 'جِد النور', descriptionKu: 'ڕوناکی بدۆزەرەوە'),
  ChallengeBadge(id: 'golden_gate', nameEn: 'Golden Gate', nameAr: 'البوابة الذهبية', nameKu: 'دەروازەی زێڕین', emoji: '🏰', color: Color(0xFFFFD700), stageRequired: 16, descriptionEn: 'Enter golden gates', descriptionAr: 'ادخل البوابة الذهبية', descriptionKu: 'بچۆرە دەروازەی زێڕین'),
  ChallengeBadge(id: 'throne_claimer', nameEn: 'Throne Claimer', nameAr: 'مُدّعي العرش', nameKu: 'داواکەری تەخت', emoji: '🪑', color: Color(0xFFFFD700), stageRequired: 17, descriptionEn: 'Claim the throne', descriptionAr: 'طالب بالعرش', descriptionKu: 'داوای تەخت بکە'),
  ChallengeBadge(id: 'king', nameEn: 'The King', nameAr: 'الملك', nameKu: 'پاشا', emoji: '👑', color: Color(0xFFFFD700), stageRequired: 18, descriptionEn: 'Become the King!', descriptionAr: 'أصبح الملك!', descriptionKu: 'ببە بە پاشا!'),
];

/// Challenge service to manage 90-day challenge
class ChallengeService extends ChangeNotifier {
  static const String _storageKey = 'challenge_data_v2';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _random = Random();

  bool get _isLoggedIn => _auth.currentUser != null && !_auth.currentUser!.isAnonymous;
  
  DateTime? _startDate;
  int _totalXP = 0;
  int _currentStreak = 0;
  Map<String, bool> _completedTaskIds = {};
  bool _isActive = false;
  bool _isCompleted = false;
  List<DailyTask>? _cachedDailyTasks;
  int _cachedDay = -1;
  
  // New feature fields
  String? _selfMessage; // Message to self on day 1
  int _lastCelebratedStage = 0; // Last stage that was celebrated
  int _taskSwapsToday = 0; // Task swaps used today
  int _lastSwapDay = 0; // Day when swap counter was reset
  Set<int> _celebratedStages = {}; // Stages already celebrated
  String? _taskSetDate; // Local calendar date (yyyy-MM-dd) of the current task set
  bool _isGeneratingTasks = false; // Re-entrancy guard for task generation

  DateTime? get startDate => _startDate;
  int get totalXP => _totalXP;
  /// Current streak - counts consecutive days from today backwards with at least 1 task done
  int get currentStreak {
    if (!_isActive || _startDate == null) return 0;
    int streak = 0;
    for (int day = realDay; day >= 1; day--) {
      if (hasAnyTaskDone(day)) {
        streak++;
      } else {
        break; // Streak broken
      }
    }
    return streak;
  }
  bool get isActive => _isActive;
  bool get isCompleted => _isCompleted;
  String? get selfMessage => _selfMessage;
  
  /// Check if should show celebration for current stage
  int? checkNewStageCelebration() {
    final stageNum = getCurrentStageNumber();
    if (stageNum > 0 && !_celebratedStages.contains(stageNum)) {
      _celebratedStages.add(stageNum);
      _saveData();
      return stageNum;
    }
    return null;
  }
  
  /// Get story for a stage
  String getStageStory(int stage, String lang) {
    final story = stageStories[stage];
    if (story != null) {
      return story[lang] ?? story['en'] ?? '';
    }
    return '';
  }
  
  /// Save self message (on day 1)
  Future<void> saveSelfMessage(String message) async {
    _selfMessage = message;
    await _saveData();
    notifyListeners();
  }
  
  /// Check if can swap task today
  bool get canSwapTask {
    if (_lastSwapDay != currentDay) {
      _lastSwapDay = currentDay;
      _taskSwapsToday = 0;
    }
    return _taskSwapsToday < 1;
  }
  
  /// Use a task swap
  void useTaskSwap() {
    if (_lastSwapDay != currentDay) {
      _lastSwapDay = currentDay;
      _taskSwapsToday = 0;
    }
    _taskSwapsToday++;
    _cachedDailyTasks = null;
    _cachedDay = -1;
    _saveData();
    notifyListeners();
  }
  
  /// Check for hidden reward (7 day streak)
  bool get hasHiddenReward => currentStreak >= 7 && currentStreak % 7 == 0;

  /// Clear cached daily tasks so they reload on next access
  void clearTaskCache() {
    _cachedDailyTasks = null;
    _cachedDay = -1;
  }

  /// Local calendar date key (yyyy-MM-dd) for a given date-time.
  /// Used to detect whether the current task set belongs to today or a past day.
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Ensures the task set for the current local calendar day exists exactly once.
  ///
  /// Idempotent: if the task set for today already exists it does nothing.
  /// Protected against race conditions (opening the screen quickly multiple
  /// times, or the day watcher firing several times) via [_isGeneratingTasks].
  ///
  /// Returns `true` if a new day's tasks were generated.
  Future<bool> ensureTasksForToday() async {
    if (!_isActive || _startDate == null) return false;
    if (_isGeneratingTasks) return false; // Re-entrancy guard

    final today = _dateKey(DateTime.now());
    if (_taskSetDate == today) return false; // Already generated for today

    _isGeneratingTasks = true;
    try {
      _taskSetDate = today;
      clearTaskCache();
      await _saveData();
      notifyListeners();
      return true;
    } finally {
      _isGeneratingTasks = false;
    }
  }

  /// The actual elapsed recovery days based on local calendar days.
  ///
  /// Day 0 = the calendar day the challenge started. The day advances at local
  /// midnight (the start of a new calendar day), not after a fixed number of
  /// hours. This makes daily tasks regenerate at the correct day boundary.
  int get realDay {
    if (_startDate == null) return 0;

    final now = DateTime.now();
    final start = _startDate!;
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(start.year, start.month, start.day);
    return today.difference(startDay).inDays;
  }

  /// The effective challenge day.
  /// Day 1 starts on the calendar day the challenge began, then advances at
  /// each local midnight.
  int get currentDay {
    if (_startDate == null) return 0;

    return realDay + 1;
  }


  /// Check if all tasks for a specific day are completed
  bool isDayCompleted(int day) {
    final rawTasks = tasks90.getDailyTasks(day);
    return rawTasks.every((t) => isTaskCompleted('day_${day}_${t['id']}'));
  }

  /// Check if at least one task was completed on a specific day
  bool hasAnyTaskDone(int day) {
    final rawTasks = tasks90.getDailyTasks(day);
    return rawTasks.any((t) => isTaskCompleted('day_${day}_${t['id']}'));
  }

  /// Check for consecutive days of inactivity (no tasks at all)
  int get consecutiveInactiveDays {
    if (_startDate == null || !_isActive) return 0;
    
    final real = realDay;
    int inactiveDays = 0;
    
    // Check from today backwards
    for (int day = real; day >= 1; day--) {
      if (hasAnyTaskDone(day)) {
        break; // Found activity, stop counting
      }
      inactiveDays++;
    }
    return inactiveDays;
  }

  /// Check if ever completed any task in the journey
  bool get hasEverDoneAnyTask {
    for (int day = 1; day <= realDay; day++) {
      if (hasAnyTaskDone(day)) return true;
    }
    return false;
  }

  /// Check if should reset due to inactivity
  /// - 3 days at start (never did any task)
  /// - 5 days during journey (after first completion)
  bool get shouldResetDueToInactivity {
    if (!hasEverDoneAnyTask) {
      // At start - 3 days with nothing
      return consecutiveInactiveDays >= 3;
    } else {
      // During journey - 5 days with nothing
      return consecutiveInactiveDays >= 5;
    }
  }

  /// Check if user is blocked (can't progress)
  bool get isBlocked => realDay > currentDay;

  /// Get all earned badges based on current stage
  List<ChallengeBadge> getEarnedBadges() {
    final stageNum = getCurrentStageNumber();
    return allBadges.where((badge) => badge.stageRequired <= stageNum).toList();
  }

  /// Get total completed tasks count
  int get totalCompletedTasks => _completedTaskIds.length;

  /// Get highest streak achieved
  int get highestStreak {
    int highest = 0;
    int current = 0;
    
    for (int day = 1; day <= currentDay; day++) {
      if (hasAnyTaskDone(day)) {
        current++;
        if (current > highest) highest = current;
      } else {
        current = 0;
      }
    }
    return highest;
  }

  /// Get progress stats
  Map<String, dynamic> getStats() {
    return {
      'currentDay': currentDay,
      'totalXP': totalXP,
      'currentStreak': currentStreak,
      'highestStreak': highestStreak,
      'totalTasks': totalCompletedTasks,
      'currentStage': getCurrentStageNumber(),
      'earnedBadges': getEarnedBadges().length,
      'totalBadges': allBadges.length,
      'progressPercent': (currentDay / 90 * 100).round(),
    };
  }


  /// 18 Journey stages (every 5 days)
  static const List<JourneyStage> journeyStages = [
    JourneyStage(stage: 1, nameEn: 'The Awakening', nameAr: 'الصحوة', nameKu: 'هەستانەوە', startDay: 1, endDay: 5, color: Color(0xFF424242), icon: Icons.visibility, emoji: '👁️', descriptionEn: 'Opening your eyes to reality', descriptionAr: 'فتح عينيك على الحقيقة', descriptionKu: 'کردنەوەی چاوت بۆ ڕاستی'),
    JourneyStage(stage: 2, nameEn: 'Breaking Chains', nameAr: 'كسر القيود', nameKu: 'شکاندنی زنجیر', startDay: 6, endDay: 10, color: Color(0xFF5D4037), icon: Icons.link_off, emoji: '⛓️', descriptionEn: 'Breaking free from old habits', descriptionAr: 'التحرر من العادات القديمة', descriptionKu: 'ئازادبوون لە نەخۆشی کۆن'),
    JourneyStage(stage: 3, nameEn: 'First Steps', nameAr: 'الخطوات الأولى', nameKu: 'یەکەم هەنگاو', startDay: 11, endDay: 15, color: Color(0xFF795548), icon: Icons.directions_walk, emoji: '🚶', descriptionEn: 'Taking your first real steps', descriptionAr: 'اتخاذ خطواتك الأولى الحقيقية', descriptionKu: 'هەڵگرتنی یەکەم هەنگاوی ڕاستەقینە'),
    JourneyStage(stage: 4, nameEn: 'The Desert', nameAr: 'الصحراء', nameKu: 'چۆڵەوانی', startDay: 16, endDay: 20, color: Color(0xFFFF8F00), icon: Icons.wb_sunny, emoji: '🏜️', descriptionEn: 'Crossing the hardest terrain', descriptionAr: 'عبور أصعب التضاريس', descriptionKu: 'تێپەڕینی سەختترین ڕێگا'),
    JourneyStage(stage: 5, nameEn: 'The Oasis', nameAr: 'الواحة', nameKu: 'ئۆئازیس', startDay: 21, endDay: 25, color: Color(0xFF14B8A6), icon: Icons.water_drop, emoji: '💧', descriptionEn: 'Finding peace within', descriptionAr: 'إيجاد السلام الداخلي', descriptionKu: 'دۆزینەوەی ئاشتی لە ناوەوە'),
    JourneyStage(stage: 6, nameEn: 'Rising Strength', nameAr: 'القوة الصاعدة', nameKu: 'هێزی بەرزبوو', startDay: 26, endDay: 30, color: Color(0xFF4CAF50), icon: Icons.fitness_center, emoji: '💪', descriptionEn: 'Feeling your power grow', descriptionAr: 'الشعور بنمو قوتك', descriptionKu: 'هەستکردن بە گەشەی هێزت'),
    JourneyStage(stage: 7, nameEn: 'The Forest', nameAr: 'الغابة', nameKu: 'دارستان', startDay: 31, endDay: 35, color: Color(0xFF2E7D32), icon: Icons.forest, emoji: '🌲', descriptionEn: 'Navigating through confusion', descriptionAr: 'التنقل عبر الارتباك', descriptionKu: 'تێپەڕین لە ناو تەگەرەدا'),
    JourneyStage(stage: 8, nameEn: 'Clear Path', nameAr: 'الطريق الواضح', nameKu: 'ڕێگای ڕوون', startDay: 36, endDay: 40, color: Color(0xFF8BC34A), icon: Icons.alt_route, emoji: '🛤️', descriptionEn: 'Seeing the way clearly', descriptionAr: 'رؤية الطريق بوضوح', descriptionKu: 'بینینی ڕێگاکە بە ڕوونی'),
    JourneyStage(stage: 9, nameEn: 'The River', nameAr: 'النهر', nameKu: 'ڕووبار', startDay: 41, endDay: 45, color: Color(0xFF03A9F4), icon: Icons.waves, emoji: '🌊', descriptionEn: 'Flowing with life', descriptionAr: 'التدفق مع الحياة', descriptionKu: 'بەجووڵەبوون لەگەڵ ژیان'),
    JourneyStage(stage: 10, nameEn: 'Mountain Base', nameAr: 'قاعدة الجبل', nameKu: 'بنەی چیا', startDay: 46, endDay: 50, color: Color(0xFF607D8B), icon: Icons.landscape, emoji: '⛰️', descriptionEn: 'Preparing for the climb', descriptionAr: 'التحضير للتسلق', descriptionKu: 'ئامادەبوون بۆ سەرکەوتن'),
    JourneyStage(stage: 11, nameEn: 'The Climb', nameAr: 'الصعود', nameKu: 'سەرکەوتن', startDay: 51, endDay: 55, color: Color(0xFF795548), icon: Icons.hiking, emoji: '🧗', descriptionEn: 'Conquering your fears', descriptionAr: 'التغلب على مخاوفك', descriptionKu: 'سەرکەوتن بەسەر ترسەکانت'),
    JourneyStage(stage: 12, nameEn: 'Above Clouds', nameAr: 'فوق الغيوم', nameKu: 'سەرووی هەور', startDay: 56, endDay: 60, color: Color(0xFF9C27B0), icon: Icons.cloud, emoji: '☁️', descriptionEn: 'Rising above problems', descriptionAr: 'الارتفاع فوق المشاكل', descriptionKu: 'بەرزبوون لەسەروی کێشەکان'),
    JourneyStage(stage: 13, nameEn: 'The Summit', nameAr: 'القمة', nameKu: 'لووتکە', startDay: 61, endDay: 65, color: Color(0xFF0D9488), icon: Icons.flag, emoji: '🏔️', descriptionEn: 'Reaching new heights', descriptionAr: 'الوصول إلى ارتفاعات جديدة', descriptionKu: 'گەیشتن بە بەرزایی نوێ'),
    JourneyStage(stage: 14, nameEn: 'Inner Peace', nameAr: 'السلام الداخلي', nameKu: 'ئاشتی ناوخۆ', startDay: 66, endDay: 70, color: Color(0xFF3F51B5), icon: Icons.self_improvement, emoji: '🧘', descriptionEn: 'Finding true calm', descriptionAr: 'إيجاد الهدوء الحقيقي', descriptionKu: 'دۆزینەوەی ئارامی ڕاستەقینە'),
    JourneyStage(stage: 15, nameEn: 'The Light', nameAr: 'النور', nameKu: 'ڕوناکی', startDay: 71, endDay: 75, color: Color(0xFF673AB7), icon: Icons.auto_awesome, emoji: '✨', descriptionEn: 'Spiritual elevation', descriptionAr: 'الارتقاء الروحي', descriptionKu: 'بەرزبوونی ڕۆحی'),
    JourneyStage(stage: 16, nameEn: 'Golden Gates', nameAr: 'البوابات الذهبية', nameKu: 'دەروازەی زێڕین', startDay: 76, endDay: 80, color: Color(0xFFFF9800), icon: Icons.castle, emoji: '🏰', descriptionEn: 'Entering the kingdom', descriptionAr: 'دخول المملكة', descriptionKu: 'چوونە ناو پاشایەتی'),
    JourneyStage(stage: 17, nameEn: 'The Throne', nameAr: 'العرش', nameKu: 'تەخت', startDay: 81, endDay: 85, color: Color(0xFFFFD700), icon: Icons.chair, emoji: '🪑', descriptionEn: 'Claiming your power', descriptionAr: 'المطالبة بقوتك', descriptionKu: 'داواکردنی هێزت'),
    JourneyStage(stage: 18, nameEn: 'The Crown', nameAr: 'التاج', nameKu: 'تاج', startDay: 86, endDay: 90, color: Color(0xFFFFD700), icon: Icons.workspace_premium, emoji: '👑', descriptionEn: 'Victory is yours!', descriptionAr: 'النصر لك!', descriptionKu: 'سەرکەوتن هی تۆیە!'),
  ];

  /// Stage stories for celebration
  static const Map<int, Map<String, String>> stageStories = {
    1: {'en': 'You opened your eyes to reality. The journey begins...', 'ar': 'فتحت عينيك على الحقيقة. تبدأ الرحلة...', 'ku': 'چاوت کردەوە بۆ ڕاستی. گەشت دەستپێدەکات...'},
    2: {'en': 'The chains of addiction begin to weaken. Keep pushing!', 'ar': 'قيود الإدمان تبدأ بالضعف. استمر!', 'ku': 'زنجیرەکانی ئالوودەبوون لاوازدەبن. بەردەوام بە!'},
    3: {'en': 'Your first real steps toward freedom. You are walking!', 'ar': 'خطواتك الأولى الحقيقية نحو الحرية. أنت تمشي!', 'ku': 'یەکەم هەنگاوی ڕاستەقینەت بۆ ئازادی. تۆ دەڕۆیت!'},
    4: {'en': 'The desert is hard, but you survived! You are stronger than you think.', 'ar': 'الصحراء صعبة، لكنك نجوت! أنت أقوى مما تظن.', 'ku': 'چۆڵەوانی سەختە، بەڵام دەربازبوویت! بەهێزتریت لەوەی پێت وایە.'},
    5: {'en': 'You found the oasis of peace. Rest and prepare for more.', 'ar': 'وجدت واحة السلام. استرح واستعد للمزيد.', 'ku': 'ئۆئازیسی ئاشتیت دۆزیەوە. پشوو وەربگرە و ئامادەبە بۆ زیاتر.'},
    6: {'en': 'One month complete! Your strength is growing day by day.', 'ar': 'شهر كامل! قوتك تنمو يومًا بعد يوم.', 'ku': 'یەک مانگ تەواو! هێزت ڕۆژ بەدوای ڕۆژ گەشە دەکات.'},
    7: {'en': 'The forest of confusion is behind you. You see clearer now.', 'ar': 'غابة الارتباك خلفك. ترى بوضوح الآن.', 'ku': 'دارستانی تەگەرە لە پشتتە. ئێستا ڕوونتر دەبینیت.'},
    8: {'en': 'The path ahead is clear. Nothing can stop you now!', 'ar': 'الطريق أمامك واضح. لا شيء يمكن أن يوقفك الآن!', 'ku': 'ڕێگا لە پێشتەوە ڕوونە. هیچ ناتوانێت ڕاتگرێت ئێستا!'},
    9: {'en': 'You flow like a river, unstoppable and free.', 'ar': 'تتدفق مثل النهر، لا يمكن إيقافك وحر.', 'ku': 'دەڕۆیت وەک ڕووبار، ناوەستێنراو و ئازاد.'},
    10: {'en': 'Halfway there! You stand at the base of the mountain, ready to climb.', 'ar': 'في منتصف الطريق! تقف عند قاعدة الجبل، مستعد للتسلق.', 'ku': 'لە نیوەڕێدایت! لە بنەی چیا وەستاویت، ئامادەیت بۆ سەرکەوتن.'},
    11: {'en': 'You are climbing! Each day brings you closer to the peak.', 'ar': 'أنت تتسلق! كل يوم يقربك من القمة.', 'ku': 'دەسەرکەویت! هەر ڕۆژ نزیکترت دەکاتەوە لە لووتکە.'},
    12: {'en': 'You are above the clouds now. Problems seem so small from here.', 'ar': 'أنت فوق الغيوم الآن. المشاكل تبدو صغيرة جدًا من هنا.', 'ku': 'ئێستا لە سەروی هەوردایت. کێشەکان زۆر بچووک دیارن لێرەوە.'},
    13: {'en': 'The summit is yours! You conquered your greatest enemy - yourself.', 'ar': 'القمة لك! تغلبت على أعظم عدو لك - نفسك.', 'ku': 'لووتکە هی تۆیە! سەرکەوتیت بە گەورەترین دوژمنت - خۆت.'},
    14: {'en': 'Inner peace achieved. You are no longer fighting, you are living.', 'ar': 'تحقق السلام الداخلي. لم تعد تقاتل، أنت تعيش.', 'ku': 'ئاشتی ناوخۆ دەستکەوت. چیتر ناشەڕیت، دەژیت.'},
    15: {'en': 'The light of wisdom shines within you. You are transformed.', 'ar': 'نور الحكمة يشرق داخلك. لقد تحولت.', 'ku': 'ڕوناکی دانایی لە ناوتدا دەدرەوشێتەوە. گۆڕانکاریت کردووە.'},
    16: {'en': 'The golden gates open before you. The kingdom awaits its king.', 'ar': 'البوابات الذهبية تفتح أمامك. المملكة تنتظر ملكها.', 'ku': 'دەروازەی زێڕین لە بەرامبەرتدا دەکرێتەوە. پاشایەتی چاوەڕوانی پاشای خۆیەتی.'},
    17: {'en': 'You claim the throne that was always meant for you.', 'ar': 'تطالب بالعرش الذي كان مقدرًا لك دائمًا.', 'ku': 'داوای ئەو تەختەت کردووە کە هەمیشە بۆ تۆ بوو.'},
    18: {'en': '👑 VICTORY! You are the KING! 90 days of pure strength and willpower!', 'ar': '👑 النصر! أنت الملك! ٩٠ يومًا من القوة والإرادة!', 'ku': '👑 سەرکەوتن! تۆ پاشایت! ٩٠ ڕۆژ هێز و ئیرادەی بێهاوتا!'},
  };

  /// Hero levels
  static const List<HeroLevel> heroLevels = [
    HeroLevel(level: 0, nameEn: 'Prisoner', nameAr: 'أسير', nameKu: 'دیل', daysRequired: 0, icon: Icons.lock, color: Color(0xFF616161), emoji: '⛓️'),
    HeroLevel(level: 1, nameEn: 'Escapee', nameAr: 'هارب', nameKu: 'هەڵاتوو', daysRequired: 5, icon: Icons.directions_run, color: Color(0xFF795548), emoji: '🏃'),
    HeroLevel(level: 2, nameEn: 'Traveler', nameAr: 'مسافر', nameKu: 'گەشتیار', daysRequired: 15, icon: Icons.explore, color: Color(0xFF4CAF50), emoji: '🧭'),
    HeroLevel(level: 3, nameEn: 'Fighter', nameAr: 'مقاتل', nameKu: 'جەنگاوەر', daysRequired: 30, icon: Icons.shield, color: Color(0xFF2196F3), emoji: '⚔️'),
    HeroLevel(level: 4, nameEn: 'Warrior', nameAr: 'محارب', nameKu: 'پاڵەوان', daysRequired: 50, icon: Icons.military_tech, color: Color(0xFF9C27B0), emoji: '🛡️'),
    HeroLevel(level: 5, nameEn: 'Champion', nameAr: 'بطل', nameKu: 'شاهزادە', daysRequired: 70, icon: Icons.stars, color: Color(0xFFFF9800), emoji: '⭐'),
    HeroLevel(level: 6, nameEn: 'King', nameAr: 'ملك', nameKu: 'پاشا', daysRequired: 90, icon: Icons.workspace_premium, color: Color(0xFFFFD700), emoji: '👑'),
  ];

  /// Get current hero level
  HeroLevel getCurrentLevel() {
    final days = currentDay;
    HeroLevel result = heroLevels[0];
    for (var level in heroLevels) {
      if (days >= level.daysRequired) {
        result = level;
      }
    }
    return result;
  }

  /// Get next hero level
  HeroLevel? getNextLevel() {
    final current = getCurrentLevel();
    final nextIndex = heroLevels.indexOf(current) + 1;
    if (nextIndex < heroLevels.length) {
      return heroLevels[nextIndex];
    }
    return null;
  }

  /// Get current journey stage
  JourneyStage getCurrentStage() {
    final days = currentDay;
    for (var stage in journeyStages.reversed) {
      if (days >= stage.startDay) {
        return stage;
      }
    }
    return journeyStages[0];
  }

  /// Get stage number (1-18)
  int getCurrentStageNumber() {
    final day = currentDay <= 0 ? 1 : currentDay;
    return ((day - 1) ~/ 5) + 1;
  }

  /// Get daily tasks for a specific day (3 tasks per day, unique for 90 days)
  List<DailyTask> getDailyTasks(int day) {
    if (_cachedDay == day && _cachedDailyTasks != null) {
      for (var task in _cachedDailyTasks!) {
        task.isCompleted = isTaskCompleted(task.id);
      }
      return _cachedDailyTasks!;
    }

    final rawTasks = tasks90.getDailyTasks(day);
    
    _cachedDailyTasks = rawTasks.map((t) {
      final taskId = 'day_${day}_${t['id']}';
      TaskType type;
      switch (t['type']) {
        case 'physical': type = TaskType.physical; break;
        case 'mental': type = TaskType.mental; break;
        case 'spiritual': type = TaskType.spiritual; break;
        case 'social': type = TaskType.social; break;
        case 'discipline': type = TaskType.discipline; break;
        default: type = TaskType.physical;
      }
      return DailyTask(
        id: taskId,
        day: day,
        titleEn: t['titleEn'] ?? '',
        titleAr: t['titleAr'] ?? '',
        titleKu: t['titleKu'] ?? '',
        descriptionEn: t['descriptionEn'] ?? '',
        descriptionAr: t['descriptionAr'] ?? '',
        descriptionKu: t['descriptionKu'] ?? '',
        xpReward: t['xpReward'] ?? 30,
        type: type,
        stageRequired: ((day - 1) ~/ 5) + 1,
        isCompleted: isTaskCompleted(taskId),
      );
    }).toList();
    _cachedDay = day;
    
    return _cachedDailyTasks!;
  }

  /// Get daily bonus tip for a specific day
  String getDailyBonus(int day) {
    return tasks90.getDailyBonus(day);
  }

  /// Get tasks appropriate for a specific stage
  List<DailyTask> _getTasksForStage(int stageNum) {
    final allTasks = _getAllTasks();
    // Filter tasks appropriate for this stage level
    return allTasks.where((t) => t.stageRequired <= stageNum).toList();
  }

  /// Load challenge data - Supabase on web, local on APK
  Future<void> loadData() async {
    // Load from local storage first
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    
    if (data != null) {
      final json = jsonDecode(data);
      _loadFromJson(json);
    }

    // Align the task set with the current local day (handles new day,
    // app reopen, and skipped days) - idempotent and race-safe.
    await ensureTasksForToday();

    notifyListeners();
    
    // Sync from Firebase in background
    if (_isLoggedIn) {
      await _syncFromFirebase(prefs);
    }
  }

  /// Parse challenge data from JSON map
  void _loadFromJson(Map<String, dynamic> json) {
    _startDate = json['startDate'] != null ? DateTime.parse(json['startDate']) : null;
    _totalXP = json['totalXP'] ?? 0;
    _currentStreak = json['currentStreak'] ?? 0;
    _completedTaskIds = Map<String, bool>.from(json['completedTaskIds'] ?? {});
    _isActive = json['isActive'] ?? false;
    _isCompleted = json['isCompleted'] ?? false;
    _selfMessage = json['selfMessage'];
    _celebratedStages = Set<int>.from((json['celebratedStages'] ?? []).map((e) => e as int));
    _taskSwapsToday = json['taskSwapsToday'] ?? 0;
    _lastSwapDay = json['lastSwapDay'] ?? 0;
    _taskSetDate = json['taskSetDate'];
  }

  /// Sync challenge data FROM Firebase (for new device / reinstall)
  Future<void> _syncFromFirebase(SharedPreferences prefs) async {
    try {
      final doc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final challengeData = data['challengeData'] as Map<String, dynamic>?;
        
        if (challengeData != null) {
          final firebaseActive = challengeData['isActive'] ?? false;
          final firebaseStartDate = challengeData['startDate'] as String?;
          
          // If local has no active challenge but Firebase does, restore from Firebase
          if (!_isActive && firebaseActive && firebaseStartDate != null) {
            _loadFromJson(Map<String, dynamic>.from(challengeData));
            // Save restored data to local storage
            await _saveToLocal(prefs);
            notifyListeners();
            debugPrint('Challenge data restored from Firebase!');
          } else if (_isActive && firebaseActive) {
            // Both have active challenges - use the one with more progress
            final localTasks = _completedTaskIds.length;
            final firebaseTasks = (challengeData['completedTaskIds'] as Map<String, dynamic>?)?.length ?? 0;
            
            if (firebaseTasks > localTasks) {
              _loadFromJson(Map<String, dynamic>.from(challengeData));
              await _saveToLocal(prefs);
              notifyListeners();
              debugPrint('Challenge data updated from Firebase (more progress)!');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Challenge Firebase sync failed: $e');
    }
  }

  /// Save challenge data to local SharedPreferences only
  Future<void> _saveToLocal(SharedPreferences prefs) async {
    final data = _toJson();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  /// Convert current state to JSON map
  Map<String, dynamic> _toJson() {
    return {
      'startDate': _startDate?.toIso8601String(),
      'totalXP': _totalXP,
      'currentStreak': _currentStreak,
      'completedTaskIds': _completedTaskIds,
      'isActive': _isActive,
      'isCompleted': _isCompleted,
      'selfMessage': _selfMessage,
      'celebratedStages': _celebratedStages.toList(),
      'taskSwapsToday': _taskSwapsToday,
      'lastSwapDay': _lastSwapDay,
      'taskSetDate': _taskSetDate,
    };
  }

  /// Sync challenge data TO Firebase (public - call after login)
  Future<void> syncToFirebase() async {
    if (!_isLoggedIn) return;
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
        'challengeData': _toJson(),
        'challengeLastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Challenge Firebase sync failed: $e');
    }
  }

  /// Save challenge data - locally AND to Firebase AND to Supabase
  Future<void> _saveData() async {
    // Save to local storage (always — web and APK)
    final prefs = await SharedPreferences.getInstance();
    await _saveToLocal(prefs);

    // Supabase: also save
    SupabaseService.saveChallengeData(_toJson()).catchError((e) {
      debugPrint('Supabase challenge sync error: $e');
    });

    // Firebase: sync if logged in
    if (_isLoggedIn) {
      syncToFirebase();
    }
  }

  /// Start the challenge
  Future<void> startChallenge() async {
    _startDate = DateTime.now();
    _totalXP = 0;
    _currentStreak = 0;
    _completedTaskIds = {};
    _isActive = true;
    _isCompleted = false;
    _cachedDailyTasks = null;
    _cachedDay = -1;
    _taskSetDate = _dateKey(DateTime.now());
    await _saveData();
    notifyListeners();
  }

  /// Toggle task completion (complete or uncomplete)
  Future<void> toggleTask(DailyTask task) async {
    if (_completedTaskIds.containsKey(task.id)) {
      // Uncomplete the task
      _completedTaskIds.remove(task.id);
      _totalXP -= task.xpReward;
      if (_totalXP < 0) _totalXP = 0;
      task.isCompleted = false;
    } else {
      // Complete the task
      _completedTaskIds[task.id] = true;
      _totalXP += task.xpReward;
      task.isCompleted = true;
      
      // Check if challenge is completed
      if (currentDay >= 90) {
        await _markAsCompleted();
      }
    }
    
    // Clear cache to refresh tasks
    _cachedDailyTasks = null;
    _cachedDay = -1;
    
    await _saveData();
    notifyListeners();
  }


  /// Check if task is completed
  bool isTaskCompleted(String taskId) {
    return _completedTaskIds[taskId] ?? false;
  }

  /// Mark challenge as completed and save to Firestore
  Future<void> _markAsCompleted() async {
    if (_isCompleted) return;
    _isCompleted = true;
    
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final docRef = _firestore.collection('challenge_completers').doc(user.uid);
        final doc = await docRef.get();
        if (doc.exists) {
            final data = doc.data()!;
            int prevCompletions = data['completionsCount'] ?? 1;
            int prevTotalXP = data['totalXP'] ?? 0;
            int prevTotalDays = data['totalDays'] ?? 90;
            
            await docRef.set({
              'displayName': user.displayName ?? 'Unknown',
              'photoURL': user.photoURL,
              'totalXP': prevTotalXP + _totalXP,
              'totalDays': prevTotalDays + currentDay,
              'completionsCount': prevCompletions + 1,
            }, SetOptions(merge: true));
        } else {
            await docRef.set({
              'displayName': user.displayName ?? 'Unknown',
              'photoURL': user.photoURL,
              'completedAt': FieldValue.serverTimestamp(),
              'totalXP': _totalXP,
              'totalDays': currentDay,
              'completionsCount': 1,
            });
        }
      } catch (e) {
        debugPrint('Error saving challenge completion: $e');
      }
    }
  }

  /// Get hall of fame completers
  Stream<List<ChallengeCompleter>> getCompletersStream() {
    return _firestore
        .collection('challenge_completers')
        .orderBy('completedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChallengeCompleter.fromFirestore(doc)).toList());
  }

  /// Reset challenge
  Future<void> resetChallenge() async {
    _startDate = null;
    _totalXP = 0;
    _currentStreak = 0;
    _completedTaskIds = {};
    _isActive = false;
    _isCompleted = false;
    _cachedDailyTasks = null;
    _cachedDay = -1;
    _taskSetDate = null;
    await _saveData();
    notifyListeners();
  }

  /// Get all possible tasks organized by type and difficulty
  List<DailyTask> _getAllTasks() {
    return [
      // ===== PHYSICAL TASKS =====
      // Stage 1-3: Easy
      DailyTask(id: 'p1', day: 0, titleEn: '10 Push-ups', titleAr: '١٠ ضغط', titleKu: '١٠ پوش ئەپ', descriptionEn: 'Start building strength', descriptionAr: 'ابدأ ببناء القوة', descriptionKu: 'دەستپێکردنی دروستکردنی هێز', xpReward: 30, type: TaskType.physical, stageRequired: 1),
      DailyTask(id: 'p2', day: 0, titleEn: '5 Min Walk', titleAr: '٥ دقائق مشي', titleKu: '٥ خولەک ڕۆشتن', descriptionEn: 'Fresh air clears the mind', descriptionAr: 'الهواء النقي يصفي العقل', descriptionKu: 'هەوای پاک مێشک پاک دەکاتەوە', xpReward: 20, type: TaskType.physical, stageRequired: 1, durationMinutes: 5),
      DailyTask(id: 'p3', day: 0, titleEn: 'Cold Face Splash', titleAr: 'رش الوجه بالماء البارد', titleKu: 'ئاوی سارد بدەرە ڕووت', descriptionEn: 'Wake up your nervous system', descriptionAr: 'أيقظ جهازك العصبي', descriptionKu: 'سیستەمی دەماری خۆت هەستە', xpReward: 15, type: TaskType.physical, stageRequired: 1),
      DailyTask(id: 'p12', day: 0, titleEn: '30 Jumping Jacks', titleAr: '٣٠ جمبينغ جاك', titleKu: '٣٠ جەمپینگ جاک', descriptionEn: 'Get your heart pumping', descriptionAr: 'اجعل قلبك يضخ', descriptionKu: 'دڵت بخەرە کار', xpReward: 25, type: TaskType.physical, stageRequired: 1),
      DailyTask(id: 'p13', day: 0, titleEn: '2 Min Plank', titleAr: 'بلانك دقيقتين', titleKu: '٢ خولەک پلانک', descriptionEn: 'Build core strength', descriptionAr: 'ابنِ قوة الجذع', descriptionKu: 'هێزی ناوەندی دروست بکە', xpReward: 35, type: TaskType.physical, stageRequired: 2),
      
      // Stage 4-6: Medium
      DailyTask(id: 'p4', day: 0, titleEn: '25 Push-ups', titleAr: '٢٥ ضغط', titleKu: '٢٥ پوش ئەپ', descriptionEn: 'Push your limits', descriptionAr: 'ادفع حدودك', descriptionKu: 'سنوورەکانت بپاشەوە', xpReward: 50, type: TaskType.physical, stageRequired: 4),
      DailyTask(id: 'p5', day: 0, titleEn: '15 Min Jog', titleAr: '١٥ دقيقة جري', titleKu: '١٥ خولەک ڕاکردن', descriptionEn: 'Run from your old self', descriptionAr: 'اركض من نفسك القديمة', descriptionKu: 'لە خۆی کۆنت ڕابکە', xpReward: 45, type: TaskType.physical, stageRequired: 4, durationMinutes: 15),
      DailyTask(id: 'p6', day: 0, titleEn: 'Cold Shower 1 Min', titleAr: 'دش بارد دقيقة', titleKu: '١ خولەک شاوەری سارد', descriptionEn: 'Embrace discomfort', descriptionAr: 'تقبّل عدم الراحة', descriptionKu: 'ناڕەحەتی قبووڵ بکە', xpReward: 60, type: TaskType.physical, stageRequired: 4),
      DailyTask(id: 'p14', day: 0, titleEn: '50 Squats', titleAr: '٥٠ سكوات', titleKu: '٥٠ سکوات', descriptionEn: 'Leg day is non-negotiable', descriptionAr: 'يوم الساق غير قابل للتفاوض', descriptionKu: 'ڕۆژی قاچ گفتوگۆی لەسەر نییە', xpReward: 55, type: TaskType.physical, stageRequired: 5),
      
      // Stage 7-12: Hard
      DailyTask(id: 'p7', day: 0, titleEn: '40 Push-ups', titleAr: '٤٠ ضغط', titleKu: '٤٠ پوش ئەپ', descriptionEn: 'Warrior strength', descriptionAr: 'قوة المحارب', descriptionKu: 'هێزی جەنگاوەر', xpReward: 70, type: TaskType.physical, stageRequired: 7),
      DailyTask(id: 'p8', day: 0, titleEn: '30 Min Run', titleAr: '٣٠ دقيقة جري', titleKu: '٣٠ خولەک ڕاکردن', descriptionEn: 'Endurance builds character', descriptionAr: 'التحمل يبني الشخصية', descriptionKu: 'خۆگرتنەوە کەسایەتی دروست دەکات', xpReward: 65, type: TaskType.physical, stageRequired: 7),
      DailyTask(id: 'p9', day: 0, titleEn: 'Cold Shower 3 Min', titleAr: 'دش بارد ٣ دقائق', titleKu: '٣ خولەک شاوەری سارد', descriptionEn: 'Master your mind', descriptionAr: 'أتقن عقلك', descriptionKu: 'مێشکت بخەرە ژێر کۆنتڕۆڵ', xpReward: 80, type: TaskType.physical, stageRequired: 8),
      DailyTask(id: 'p15', day: 0, titleEn: '100 Burpees', titleAr: '١٠٠ بوربي', titleKu: '١٠٠ بوربی', descriptionEn: 'Ultimate test', descriptionAr: 'الاختبار الأقصى', descriptionKu: 'تاقیکردنەوەی کۆتایی', xpReward: 90, type: TaskType.physical, stageRequired: 10),
      
      // Stage 13-18: Expert
      DailyTask(id: 'p10', day: 0, titleEn: '60 Push-ups', titleAr: '٦٠ ضغط', titleKu: '٦٠ پوش ئەپ', descriptionEn: 'Champion level', descriptionAr: 'مستوى البطل', descriptionKu: 'ئاستی پاڵەوان', xpReward: 100, type: TaskType.physical, stageRequired: 13),
      DailyTask(id: 'p11', day: 0, titleEn: '1 Hour Run', titleAr: 'ساعة جري', titleKu: '١ کاتژمێر ڕاکردن', descriptionEn: 'King\'s endurance', descriptionAr: 'تحمل الملك', descriptionKu: 'خۆگرتنەوەی پاشا', xpReward: 110, type: TaskType.physical, stageRequired: 15),
      DailyTask(id: 'p16', day: 0, titleEn: 'Cold Shower 5 Min', titleAr: 'دش بارد ٥ دقائق', titleKu: '٥ خولەک شاوەری سارد', descriptionEn: 'Ice king mentality', descriptionAr: 'عقلية ملك الجليد', descriptionKu: 'بیرکردنەوەی شاهی سەهۆڵ', xpReward: 120, type: TaskType.physical, stageRequired: 16),

      // ===== MENTAL TASKS =====
      // Stage 1-3
      DailyTask(id: 'm1', day: 0, titleEn: '5 Min Breathing', titleAr: '٥ دقائق تنفس', titleKu: '٥ خولەک هەناسەدان', descriptionEn: 'Breathe. Reset. Begin.', descriptionAr: 'تنفس. أعِد الضبط. ابدأ.', descriptionKu: 'هەناسە. ڕیسێت بکەرەوە. دەستپێبکە.', xpReward: 25, type: TaskType.mental, stageRequired: 1, durationMinutes: 5),
      DailyTask(id: 'm2', day: 0, titleEn: '3 Gratitudes', titleAr: '٣ نِعَم', titleKu: '٣ سوپاس', descriptionEn: 'Count your blessings', descriptionAr: 'عُدّ نِعَمك', descriptionKu: 'نیعمەتەکانت بژمێرە', xpReward: 30, type: TaskType.mental, stageRequired: 1),
      DailyTask(id: 'm3', day: 0, titleEn: 'Read 5 Pages', titleAr: '٥ صفحات قراءة', titleKu: '٥ لاپەڕە بخوێنە', descriptionEn: 'Feed your mind', descriptionAr: 'أطعِم عقلك', descriptionKu: 'مێشکت بخواردنەوە', xpReward: 25, type: TaskType.mental, stageRequired: 1),
      DailyTask(id: 'm9', day: 0, titleEn: 'Write Your Goal', titleAr: 'اكتب هدفك', titleKu: 'ئامانجت بنووسە', descriptionEn: 'Clarity creates power', descriptionAr: 'الوضوح يخلق القوة', descriptionKu: 'ڕوونی هێز دروست دەکات', xpReward: 20, type: TaskType.mental, stageRequired: 1),
      DailyTask(id: 'm10', day: 0, titleEn: 'No Complaint Day', titleAr: 'يوم بلا شكوى', titleKu: 'ڕۆژێک بێ گلەیی', descriptionEn: 'Only solutions today', descriptionAr: 'حلول فقط اليوم', descriptionKu: 'تەنها چارەسەر ئەمڕۆ', xpReward: 35, type: TaskType.mental, stageRequired: 2),
      
      // Stage 4-6
      DailyTask(id: 'm4', day: 0, titleEn: '10 Min Visualization', titleAr: '١٠ دقائق تخيّل', titleKu: '١٠ خولەک خەیاڵکردن', descriptionEn: 'See your future self', descriptionAr: 'تخيّل نفسك المستقبلية', descriptionKu: 'خۆتی داهاتوو ببینە', xpReward: 45, type: TaskType.mental, stageRequired: 4),
      DailyTask(id: 'm5', day: 0, titleEn: 'Read 15 Pages', titleAr: '١٥ صفحة قراءة', titleKu: '١٥ لاپەڕە بخوێنە', descriptionEn: 'Knowledge is power', descriptionAr: 'المعرفة قوة', descriptionKu: 'زانیاری هێزە', xpReward: 40, type: TaskType.mental, stageRequired: 4),
      DailyTask(id: 'm6', day: 0, titleEn: 'Write Journal', titleAr: 'اكتب مذكرتك', titleKu: 'ڕۆژنامە بنووسە', descriptionEn: 'Know thyself', descriptionAr: 'اعرف نفسك', descriptionKu: 'خۆت بناسە', xpReward: 35, type: TaskType.mental, stageRequired: 4),
      DailyTask(id: 'm11', day: 0, titleEn: 'Learn 5 New Words', titleAr: 'تعلم ٥ كلمات', titleKu: '٥ وشەی نوێ فێر بە', descriptionEn: 'Expand your mind', descriptionAr: 'وسّع عقلك', descriptionKu: 'مێشکت فراوان بکە', xpReward: 30, type: TaskType.mental, stageRequired: 5),
      
      // Stage 7-12
      DailyTask(id: 'm7', day: 0, titleEn: '20 Min Meditation', titleAr: '٢٠ دقيقة تأمل', titleKu: '٢٠ خولەک مێدیتەیشن', descriptionEn: 'Deep inner peace', descriptionAr: 'سلام داخلي عميق', descriptionKu: 'ئاشتی ناوخۆیی قووڵ', xpReward: 70, type: TaskType.mental, stageRequired: 7),
      DailyTask(id: 'm8', day: 0, titleEn: 'No Phone 3 Hours', titleAr: 'بدون هاتف ٣ ساعات', titleKu: '٣ کاتژمێر بێ موبایل', descriptionEn: 'Reclaim your attention', descriptionAr: 'استعد انتباهك', descriptionKu: 'ئاگاداریت بخەرەوە', xpReward: 80, type: TaskType.mental, stageRequired: 9),
      DailyTask(id: 'm12', day: 0, titleEn: 'Teach Someone', titleAr: 'علّم شخصاً', titleKu: 'کەسێک فێر بکە', descriptionEn: 'Teaching deepens learning', descriptionAr: 'التعليم يعمق التعلم', descriptionKu: 'فێرکردن فێربوون قووڵ دەکات', xpReward: 60, type: TaskType.mental, stageRequired: 10),
      
      // Stage 13-18
      DailyTask(id: 'm13', day: 0, titleEn: 'Solve a Hard Problem', titleAr: 'حُل مشكلة صعبة', titleKu: 'کێشەیەکی سەخت چارەسەر بکە', descriptionEn: 'Sharpen your mind', descriptionAr: 'اشحذ عقلك', descriptionKu: 'مێشکت تیژ بکە', xpReward: 85, type: TaskType.mental, stageRequired: 13),
      DailyTask(id: 'm14', day: 0, titleEn: 'No Internet Day', titleAr: 'يوم بلا إنترنت', titleKu: 'ڕۆژێک بێ ئینتەرنێت', descriptionEn: 'Pure focus', descriptionAr: 'تركيز صافٍ', descriptionKu: 'تەرکیزی پاک', xpReward: 100, type: TaskType.mental, stageRequired: 15),

      // ===== SPIRITUAL TASKS =====
      // Stage 1-3
      DailyTask(id: 's1', day: 0, titleEn: 'Pray Fajr on Time', titleAr: 'صلِّ الفجر في وقتها', titleKu: 'نوێژی بەیانی لە کاتیدا', descriptionEn: 'Start with Allah', descriptionAr: 'ابدأ مع الله', descriptionKu: 'بە خوا دەستپێبکە', xpReward: 50, type: TaskType.spiritual, stageRequired: 1),
      DailyTask(id: 's2', day: 0, titleEn: 'Read Quran 1 Page', titleAr: 'صفحة قرآن', titleKu: '١ لاپەڕە قورئان', descriptionEn: 'Light for your soul', descriptionAr: 'نور لروحك', descriptionKu: 'ڕوناکی بۆ گیانت', xpReward: 40, type: TaskType.spiritual, stageRequired: 1),
      DailyTask(id: 's3', day: 0, titleEn: 'Morning Adhkar', titleAr: 'أذكار الصباح', titleKu: 'ئەزکاری بەیانی', descriptionEn: 'Protection for your day', descriptionAr: 'حماية ليومك', descriptionKu: 'پاراستن بۆ ڕۆژت', xpReward: 35, type: TaskType.spiritual, stageRequired: 1),
      DailyTask(id: 's7', day: 0, titleEn: 'Evening Adhkar', titleAr: 'أذكار المساء', titleKu: 'ئەزکاری ئێوارە', descriptionEn: 'End day with remembrance', descriptionAr: 'اختم يومك بالذكر', descriptionKu: 'ڕۆژ بە یادخوا تەواو بکە', xpReward: 35, type: TaskType.spiritual, stageRequired: 2),
      DailyTask(id: 's8', day: 0, titleEn: '100 Istighfar', titleAr: '١٠٠ استغفار', titleKu: '١٠٠ ئەستغفار', descriptionEn: 'Cleanse your heart', descriptionAr: 'طهّر قلبك', descriptionKu: 'دڵت پاک بکەرەوە', xpReward: 30, type: TaskType.spiritual, stageRequired: 1),
      
      // Stage 4-6
      DailyTask(id: 's9', day: 0, titleEn: 'Pray Duha', titleAr: 'صلاة الضحى', titleKu: 'نوێژی دوحا', descriptionEn: 'Charity for your joints', descriptionAr: 'صدقة لمفاصلك', descriptionKu: 'صەدەقە بۆ مەفسەڵەکانت', xpReward: 45, type: TaskType.spiritual, stageRequired: 4),
      DailyTask(id: 's10', day: 0, titleEn: 'Memorize 1 Ayah', titleAr: 'احفظ آية', titleKu: '١ ئایەت لەبەر بکە', descriptionEn: 'Quran in your heart', descriptionAr: 'القرآن في قلبك', descriptionKu: 'قورئان لە دڵت', xpReward: 55, type: TaskType.spiritual, stageRequired: 5),
      
      // Stage 7-12
      DailyTask(id: 's4', day: 0, titleEn: 'All 5 Prayers', titleAr: 'الصلوات الخمس', titleKu: 'هەموو ٥ نوێژ', descriptionEn: 'Complete your pillars', descriptionAr: 'أكمل أركانك', descriptionKu: 'ستوونەکانت تەواو بکە', xpReward: 100, type: TaskType.spiritual, stageRequired: 7),
      DailyTask(id: 's5', day: 0, titleEn: 'Read Quran 5 Pages', titleAr: '٥ صفحات قرآن', titleKu: '٥ لاپەڕە قورئان', descriptionEn: 'Shower of mercy', descriptionAr: 'مطر الرحمة', descriptionKu: 'بارانی ڕەحمەت', xpReward: 80, type: TaskType.spiritual, stageRequired: 8),
      DailyTask(id: 's11', day: 0, titleEn: 'Pray in Masjid', titleAr: 'صلِّ في المسجد', titleKu: 'لە مزگەوت نوێژ بکە', descriptionEn: '27x reward', descriptionAr: '٢٧ ضعف الأجر', descriptionKu: '٢٧ قات پاداشت', xpReward: 70, type: TaskType.spiritual, stageRequired: 9),
      
      // Stage 13-18
      DailyTask(id: 's6', day: 0, titleEn: 'Tahajjud Prayer', titleAr: 'صلاة التهجد', titleKu: 'نوێژی تەهەجود', descriptionEn: 'Meet Allah at night', descriptionAr: 'ألتقِ بالله في الليل', descriptionKu: 'لە شەودا لەگەڵ خوا بکەوە', xpReward: 120, type: TaskType.spiritual, stageRequired: 13),
      DailyTask(id: 's12', day: 0, titleEn: 'Memorize Surah', titleAr: 'احفظ سورة', titleKu: 'سورەیەک لەبەر بکە', descriptionEn: 'Eternal treasure', descriptionAr: 'كنز أبدي', descriptionKu: 'گەنجینەی هەتاهەتایی', xpReward: 150, type: TaskType.spiritual, stageRequired: 16),

      // ===== SOCIAL TASKS =====
      // Stage 1-3
      DailyTask(id: 'so1', day: 0, titleEn: 'Call Family', titleAr: 'اتصل بالعائلة', titleKu: 'پەیوەندی بە خێزان بکە', descriptionEn: 'Strengthen bonds', descriptionAr: 'قوِّ الروابط', descriptionKu: 'پەیوەندییەکان بهێز بکە', xpReward: 35, type: TaskType.social, stageRequired: 1),
      DailyTask(id: 'so2', day: 0, titleEn: 'Help Someone', titleAr: 'ساعد شخصاً', titleKu: 'یارمەتی کەسێک بدە', descriptionEn: 'Be useful', descriptionAr: 'كن مفيداً', descriptionKu: 'بەسودمەند بە', xpReward: 45, type: TaskType.social, stageRequired: 1),
      DailyTask(id: 'so3', day: 0, titleEn: 'Send Kind Message', titleAr: 'أرسل رسالة لطيفة', titleKu: 'پەیامی نەرم بنێرە', descriptionEn: 'Spread positivity', descriptionAr: 'انشر الإيجابية', descriptionKu: 'ئەرێنیەتی بڵاو بکەرەوە', xpReward: 30, type: TaskType.social, stageRequired: 1),
      DailyTask(id: 'so6', day: 0, titleEn: 'Smile Challenge', titleAr: 'تحدي الابتسامة', titleKu: 'چاڵینجی پێکەنین', descriptionEn: 'Make 3 people smile', descriptionAr: 'اجعل ٣ أشخاص يبتسمون', descriptionKu: '٣ کەس بخەرە پێکەنین', xpReward: 25, type: TaskType.social, stageRequired: 2),
      
      // Stage 4-6
      DailyTask(id: 'so7', day: 0, titleEn: 'Listen Deeply', titleAr: 'استمع بعمق', titleKu: 'بە قووڵی گوێ بگرە', descriptionEn: '15 min true listening', descriptionAr: '١٥ دقيقة استماع حقيقي', descriptionKu: '١٥ خولەک گوێگرتنی ڕاستەقینە', xpReward: 40, type: TaskType.social, stageRequired: 4),
      DailyTask(id: 'so8', day: 0, titleEn: 'Apologize Sincerely', titleAr: 'اعتذر بصدق', titleKu: 'بەڕاستی داوای لێبوردن بکە', descriptionEn: 'Heal a relationship', descriptionAr: 'اشفِ علاقة', descriptionKu: 'پەیوەندییەک چاک بکەرەوە', xpReward: 50, type: TaskType.social, stageRequired: 5),
      
      // Stage 7-12
      DailyTask(id: 'so4', day: 0, titleEn: 'Visit Someone', titleAr: 'زُر شخصاً', titleKu: 'سەردانی کەسێک بکە', descriptionEn: 'Quality time matters', descriptionAr: 'الوقت النوعي مهم', descriptionKu: 'کاتی کوالیتی گرنگە', xpReward: 60, type: TaskType.social, stageRequired: 7),
      DailyTask(id: 'so5', day: 0, titleEn: 'Give Charity', titleAr: 'تصدّق', titleKu: 'صەدەقە بدە', descriptionEn: 'Wealth of the heart', descriptionAr: 'ثروة القلب', descriptionKu: 'سامانی دڵ', xpReward: 70, type: TaskType.social, stageRequired: 8),
      DailyTask(id: 'so9', day: 0, titleEn: 'Mentor Someone', titleAr: 'أرشِد شخصاً', titleKu: 'کەسێک ڕێنمایی بکە', descriptionEn: 'Share your wisdom', descriptionAr: 'شارك حكمتك', descriptionKu: 'دانایی خۆت ببەخشە', xpReward: 75, type: TaskType.social, stageRequired: 10),
      
      // Stage 13-18
      DailyTask(id: 'so10', day: 0, titleEn: 'Forgive Someone', titleAr: 'سامح شخصاً', titleKu: 'لە کەسێک ببوورە', descriptionEn: 'Free yourself', descriptionAr: 'حرّر نفسك', descriptionKu: 'خۆت ئازاد بکە', xpReward: 100, type: TaskType.social, stageRequired: 14),

      // ===== DISCIPLINE TASKS =====
      // Stage 1-3
      DailyTask(id: 'd1', day: 0, titleEn: 'Wake Before 6 AM', titleAr: 'استيقظ قبل ٦', titleKu: 'پێش ٦ هەستە', descriptionEn: 'Win the morning', descriptionAr: 'اربح الصباح', descriptionKu: 'بەیانی ببەرەوە', xpReward: 50, type: TaskType.discipline, stageRequired: 1),
      DailyTask(id: 'd2', day: 0, titleEn: 'Make Your Bed', titleAr: 'رتّب سريرك', titleKu: 'جێخەوتەکەت ڕێک بخە', descriptionEn: 'First victory', descriptionAr: 'أول انتصار', descriptionKu: 'یەکەم سەرکەوتن', xpReward: 15, type: TaskType.discipline, stageRequired: 1),
      DailyTask(id: 'd7', day: 0, titleEn: 'Drink 8 Glasses Water', titleAr: '٨ أكواب ماء', titleKu: '٨ گڵاس ئاو', descriptionEn: 'Hydrate to dominate', descriptionAr: 'اشرب لتسيطر', descriptionKu: 'ئاو بخۆ بۆ سەردەست بیت', xpReward: 20, type: TaskType.discipline, stageRequired: 1),
      DailyTask(id: 'd8', day: 0, titleEn: 'No Junk Food', titleAr: 'لا وجبات سريعة', titleKu: 'فاست فوود نا', descriptionEn: 'Respect your body', descriptionAr: 'احترم جسدك', descriptionKu: 'ڕێز لە لەشت بگرە', xpReward: 35, type: TaskType.discipline, stageRequired: 2),
      
      // Stage 4-6
      DailyTask(id: 'd3', day: 0, titleEn: 'No Sugar Today', titleAr: 'بدون سكر اليوم', titleKu: 'ئەمڕۆ بێ شەکر', descriptionEn: 'Break the addiction', descriptionAr: 'اكسر الإدمان', descriptionKu: 'ئاڵوودەبوون بشکێنە', xpReward: 55, type: TaskType.discipline, stageRequired: 4),
      DailyTask(id: 'd4', day: 0, titleEn: 'Sleep Before 11 PM', titleAr: 'نَم قبل ١١', titleKu: 'پێش ١١ بخەوە', descriptionEn: 'Recovery starts in sleep', descriptionAr: 'التعافي يبدأ بالنوم', descriptionKu: 'چاکبوونەوە لە خەودا دەستپێدەکات', xpReward: 45, type: TaskType.discipline, stageRequired: 4),
      DailyTask(id: 'd9', day: 0, titleEn: 'Clean Your Room', titleAr: 'نظّف غرفتك', titleKu: 'ژوورەکەت پاک بکەرەوە', descriptionEn: 'Outer order, inner calm', descriptionAr: 'نظام خارجي، هدوء داخلي', descriptionKu: 'ڕێکخستنی دەروە، ئارامی ناوەوە', xpReward: 30, type: TaskType.discipline, stageRequired: 5),
      
      // Stage 7-12
      DailyTask(id: 'd10', day: 0, titleEn: 'No Music Day', titleAr: 'يوم بلا موسيقى', titleKu: 'ڕۆژێک بێ مۆسیقا', descriptionEn: 'Embrace silence', descriptionAr: 'تقبّل الصمت', descriptionKu: 'بێدەنگی قبوڵ بکە', xpReward: 60, type: TaskType.discipline, stageRequired: 7),
      DailyTask(id: 'd11', day: 0, titleEn: 'Eat Only 2 Meals', titleAr: 'وجبتان فقط', titleKu: 'تەنها ٢ خواردن', descriptionEn: 'Intermittent fasting', descriptionAr: 'الصيام المتقطع', descriptionKu: 'ڕۆژووی نێوانکار', xpReward: 65, type: TaskType.discipline, stageRequired: 9),
      
      // Stage 13-18
      DailyTask(id: 'd5', day: 0, titleEn: 'Full Day Fast', titleAr: 'صيام يوم كامل', titleKu: 'ڕۆژووی تەواو', descriptionEn: 'Spiritual & physical reset', descriptionAr: 'إعادة ضبط روحية وجسدية', descriptionKu: 'ڕیسێتی ڕوحی و جەستەیی', xpReward: 100, type: TaskType.discipline, stageRequired: 13),
      DailyTask(id: 'd6', day: 0, titleEn: 'Digital Detox Day', titleAr: 'يوم ديتوكس رقمي', titleKu: 'ڕۆژی دیتۆکسی دیجیتاڵ', descriptionEn: 'Full day no screens', descriptionAr: 'يوم كامل بدون شاشات', descriptionKu: 'ڕۆژێکی تەواو بێ شاشە', xpReward: 120, type: TaskType.discipline, stageRequired: 15),
      DailyTask(id: 'd12', day: 0, titleEn: 'Silence Day', titleAr: 'يوم الصمت', titleKu: 'ڕۆژی بێدەنگی', descriptionEn: 'Only essential speech', descriptionAr: 'الكلام الضروري فقط', descriptionKu: 'تەنها قسەی پێویست', xpReward: 90, type: TaskType.discipline, stageRequired: 14),
    ];
  }
}

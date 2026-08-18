import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../services/commitment_service.dart';
import '../services/auth_service.dart';

class CommitmentScreen extends StatefulWidget {
  const CommitmentScreen({super.key});

  @override
  State<CommitmentScreen> createState() => _CommitmentScreenState();
}

class _CommitmentScreenState extends State<CommitmentScreen>
    with TickerProviderStateMixin {
  final _commitmentService = CommitmentService();
  final _authService = AuthService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  bool _isWritingMode = false;
  String? _editingLetterId;
  final TextEditingController _letterController = TextEditingController();
  bool _isAutoSaving = false;
  String _autoSaveStatus = '';
  DateTime? _lastAutoSaveTime;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _loadData();
  }

  Future<void> _loadData() async {
    await _commitmentService.loadLetters();
    setState(() => _isLoading = false);
    _fadeController.forward();
  }

  String _getUserName(LanguageService lang) {
    final user = _authService.currentUser;
    if (user == null) return lang.guest;
    if (user.isAnonymous) return lang.guest;
    return user.displayName ?? user.email?.split('@').first ?? lang.guest;
  }

  void _saveLetter(LanguageService lang) async {
    if (_letterController.text.trim().isEmpty) return;

    if (_isAutoSaving) return;
    _isAutoSaving = true;

    // Editing an existing letter vs. adding a new one.
    final editingId = _editingLetterId;
    if (editingId != null) {
      await _commitmentService.updateLetter(editingId, _letterController.text.trim());
      if (mounted) {
        setState(() {
          _isWritingMode = false;
          _editingLetterId = null;
          _letterController.clear();
          _isAutoSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.currentLanguage == AppLanguage.arabic
                  ? 'تم تعديل رسالتك بنجاح!'
                  : lang.currentLanguage == AppLanguage.kurdish
                      ? 'نامەکەت نوێکرایەوە!'
                      : 'Your letter was updated!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    final success = await _commitmentService.addLetter(
      _letterController.text.trim(),
      _getUserName(lang),
    );

    if (success && mounted) {
      setState(() {
        _isWritingMode = false;
        _letterController.clear();
        _isAutoSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.currentLanguage == AppLanguage.arabic
                ? 'تم حفظ رسالتك بنجاح!'
                : lang.currentLanguage == AppLanguage.kurdish
                    ? 'نامەکەت پاشەکەوت کرا!'
                    : 'Your letter was saved!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _isAutoSaving = false;
    }
  }

  /// Start editing an existing letter.
  void _startEdit(LanguageService lang, CommitmentLetter letter) {
    setState(() {
      _editingLetterId = letter.id;
      _letterController.text = letter.content;
      _isWritingMode = true;
    });
  }

  /// Confirm and delete a letter (works offline).
  Future<void> _confirmDeleteLetter(
      LanguageService lang, CommitmentLetter letter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          lang.currentLanguage == AppLanguage.arabic
              ? 'حذف الوثيقة'
              : lang.currentLanguage == AppLanguage.kurdish
                  ? 'سڕینەوەی بەڵگەنامە'
                  : 'Delete letter',
        ),
        content: Text(
          lang.currentLanguage == AppLanguage.arabic
              ? 'هل أنت متأكد من حذف هذه الوثيقة نهائياً؟'
              : lang.currentLanguage == AppLanguage.kurdish
                  ? 'دڵنیایت لە سڕینەوەی ئەم بەڵگەنامەیە بۆ هەمیشە؟'
                  : 'Are you sure you want to permanently delete this letter?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              lang.currentLanguage == AppLanguage.arabic
                  ? 'إلغاء'
                  : lang.currentLanguage == AppLanguage.kurdish
                      ? 'پاشگەزبوونەوە'
                      : 'Cancel',
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.currentLanguage == AppLanguage.arabic
                  ? 'حذف'
                  : lang.currentLanguage == AppLanguage.kurdish
                      ? 'بیسڕەوە'
                      : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _commitmentService.deleteLetter(letter.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.currentLanguage == AppLanguage.arabic
                  ? 'تم حذف الوثيقة!'
                  : lang.currentLanguage == AppLanguage.kurdish
                      ? 'بەڵگەنامەکە سڕایەوە!'
                      : 'Letter deleted!',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Auto-save method - saves without exiting writing mode
  void _autoSaveLetter(LanguageService lang) async {
    if (_letterController.text.trim().isEmpty) return;
    if (_isAutoSaving) return;

    _isAutoSaving = true;
    setState(() {
      _autoSaveStatus = lang.currentLanguage == AppLanguage.arabic
          ? 'جاري الحفظ...'
          : lang.currentLanguage == AppLanguage.kurdish
              ? 'دەپاشەکرێت...'
              : 'Saving...';
    });

    final success = await _commitmentService.addLetter(
      _letterController.text.trim(),
      _getUserName(lang),
    );

    if (success && mounted) {
      _lastAutoSaveTime = DateTime.now();
      setState(() {
        _autoSaveStatus = lang.currentLanguage == AppLanguage.arabic
            ? 'تم الحفظ'
            : lang.currentLanguage == AppLanguage.kurdish
                ? 'پاشەکەوت کرا'
                : 'Saved';
      });
      // Clear status after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _autoSaveStatus = '');
        }
      });
    } else {
      setState(() {
        _autoSaveStatus = lang.currentLanguage == AppLanguage.arabic
            ? 'فشل الحفظ'
            : lang.currentLanguage == AppLanguage.kurdish
                ? 'هەڵە لە پاشەکەوتکردن'
                : 'Save failed';
      });
    }
    _isAutoSaving = false;
  }

  @override
  void dispose() {
    // Auto-save when leaving the screen if there's unsaved text
    if (_letterController.text.trim().isNotEmpty && _isWritingMode) {
      _commitmentService.addLetter(
        _letterController.text.trim(),
        _getUserName(Provider.of<LanguageService>(context, listen: false)),
      );
    }
    _fadeController.dispose();
    _letterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final isDark = lang.isDarkMode;

    // Colors
    const purpleColor = Color(0xFF0F766E);
    const amberColor = Color(0xFFF59E0B);

    // Translations
    String titleText;
    String subtitleText;
    String writeNewText;
    String saveText;
    String cancelText;
    String placeholderText;
    String noLettersText;
    String signatureText;

    switch (lang.currentLanguage) {
      case AppLanguage.arabic:
        titleText = 'وثيقة الالتزام';
        subtitleText = 'رسائلك لنفسك المستقبلية';
        writeNewText = 'اكتب رسالة جديدة';
        saveText = 'حفظ الرسالة';
        cancelText = 'إلغاء';
        placeholderText =
            'اكتب رسالتك هنا...\n\nتذكر أن هذه الرسالة لنفسك المستقبلية. اكتب ما تريد أن تذكر نفسك به في لحظات الضعف...';
        noLettersText =
            'لم تكتب أي رسائل بعد\nاضغط على الزر أدناه لكتابة رسالتك الأولى';
        signatureText = 'بتوقيع';
        break;
      case AppLanguage.kurdish:
        titleText = 'بەڵێننامەی پابەندبوون';
        subtitleText = 'نامەکانت بۆ داهاتووی خۆت';
        writeNewText = 'نامەی نوێ بنووسە';
        saveText = 'پاشەکەوتی نامە';
        cancelText = 'پەشیمانبوونەوە';
        placeholderText =
            'نامەکەت لێرە بنووسە...\n\nبیرت بێت ئەم نامەیە بۆ داهاتووی خۆتە. ئەوەی دەتەوێت لە کاتی لاوازییدا بیرت بێتەوە بینووسە...';
        noLettersText =
            'هێشتا هیچ نامەیەکت نەنووسیوە\nکلیک لە دوگمەی خوارەوە بکە بۆ نووسینی یەکەم نامە';
        signatureText = 'بە واژۆی';
        break;
      case AppLanguage.english:
        titleText = 'Commitment Document';
        subtitleText = 'Letters to Your Future Self';
        writeNewText = 'Write a New Letter';
        saveText = 'Save Letter';
        cancelText = 'Cancel';
        placeholderText =
            'Write your letter here...\n\nRemember, this letter is for your future self. Write what you want to remember during moments of weakness...';
        noLettersText =
            'You haven\'t written any letters yet\nTap the button below to write your first letter';
        signatureText = 'Signed by';
        break;
    }

    final letter = _commitmentService.currentLetter;

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.25, 0.55, 0.8, 1.0],
              colors: isDark
                  ? [
                      const Color(0xFF020A09),
                      const Color(0xFF051614),
                      const Color(0xFF0E2823),
                      const Color(0xFF102A27),
                      const Color(0xFF0B1F1B),
                    ]
                  : [
                      const Color(0xFFEFFFF8),
                      const Color(0xFFF4FFFB),
                      const Color(0xFFFFF7E8),
                      const Color(0xFFEAF3FF),
                      const Color(0xFFDFF1F4),
                    ],
            ),
          ),
          child: Stack(
            children: [
              // Ambient glow orbs — dramatic layered atmosphere
              Positioned(
                top: -90,
                left: -70,
                child: _buildSoftOrb(
                    isDark ? amberColor : const Color(0xFF0D9488),
                    isDark ? 0.18 : 0.22,
                    280),
              ),
              Positioned(
                bottom: -110,
                right: -80,
                child: _buildSoftOrb(
                    const Color(0xFF38BDF8), isDark ? 0.14 : 0.20, 300),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.30,
                right: -100,
                child: _buildSoftOrb(
                    isDark
                        ? const Color(0xFF34D399)
                        : const Color(0xFF5EEAD4),
                    isDark ? 0.10 : 0.16,
                    220),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.55,
                left: -90,
                child: _buildSoftOrb(
                    isDark
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFFDE68A),
                    isDark ? 0.08 : 0.14,
                    200),
              ),
              Positioned(
                bottom: 60,
                left: MediaQuery.of(context).size.width * 0.35,
                child: _buildSoftOrb(
                    isDark
                        ? const Color(0xFFA78BFA)
                        : const Color(0xFFC4B5FD),
                    isDark ? 0.07 : 0.12,
                    180),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildModernHeader(lang, isDark, titleText, subtitleText),

                    // Main content - maximized for mobile
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                  color: isDark ? amberColor : purpleColor))
                          : Padding(
                              padding: const EdgeInsets.only(
                                  left: 8, right: 8, bottom: 8),
                              child: Column(
                                children: [
                                  // Content area - fills remaining space
                                  Expanded(
                                    child: _isWritingMode
                                        ? _buildModernWritingMode(
                                            lang,
                                            isDark,
                                            placeholderText,
                                            saveText,
                                            cancelText)
                                        : _buildModernViewMode(
                                            lang,
                                            isDark,
                                            letter,
                                            noLettersText,
                                            signatureText),
                                  ),

                                  const SizedBox(height: 8),

                                  // Write new button
                                  if (!_isWritingMode)
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => _isWritingMode = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 36, vertical: 16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: isDark
                                                ? [
                                                    amberColor,
                                                    amberColor.withOpacity(0.8),
                                                    amberColor.withOpacity(0.65),
                                                  ]
                                                : [
                                                    const Color(0xFF0F766E),
                                                    purpleColor,
                                                    purpleColor.withOpacity(0.85),
                                                  ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(32),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                                isDark ? 0.18 : 0.25),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isDark
                                                      ? amberColor
                                                      : purpleColor)
                                                  .withOpacity(0.55),
                                              blurRadius: 28,
                                              spreadRadius: 2,
                                              offset: const Offset(0, 10),
                                            ),
                                            BoxShadow(
                                              color: (isDark
                                                      ? amberColor
                                                      : purpleColor)
                                                  .withOpacity(0.25),
                                              blurRadius: 12,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.edit_rounded,
                                                color: Colors.white, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              writeNewText,
                                              style: lang.getTextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 16),
                                  _buildOrnament(isDark),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
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

  Widget _buildSoftOrb(Color color, double opacity, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(opacity * 0.55),
            color.withOpacity(0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildModernHeader(
      LanguageService lang, bool isDark, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withOpacity(0.14),
                          Colors.white.withOpacity(0.06),
                        ]
                      : [
                          Colors.white.withOpacity(0.92),
                          Colors.white.withOpacity(0.65),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.white.withOpacity(0.9),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.4)
                        : const Color(0xFF0F766E).withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(isDark ? 0.06 : 0.5),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                lang.isRTL ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                color: isDark ? Colors.white70 : Colors.grey[700],
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: lang.getTextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF064E3B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: lang.getTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFFF59E0B)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildModernWritingMode(LanguageService lang, bool isDark,
      String placeholder, String saveText, String cancelText) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF0F1A18).withOpacity(0.98),
                      const Color(0xFF13201D).withOpacity(0.95),
                      const Color(0xFF0B1413).withOpacity(0.97),
                    ]
                  : [
                      Colors.white.withOpacity(1.0),
                      const Color(0xFFFFFBF2).withOpacity(0.99),
                      const Color(0xFFF5FFFB).withOpacity(1.0),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : const Color(0xFFB2DFDB),
                width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E)
                    .withOpacity(isDark ? 0.28 : 0.20),
                blurRadius: 38,
                spreadRadius: 2,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: const Color(0xFFF59E0B)
                    .withOpacity(isDark ? 0.10 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Accent glow orb inside the card
                Positioned(
                  top: -40,
                  right: -40,
                  child: _buildSoftOrb(
                      const Color(0xFF14B8A6),
                      isDark ? 0.16 : 0.22,
                      160),
                ),
                Positioned(
                  bottom: -50,
                  left: -50,
                  child: _buildSoftOrb(
                      const Color(0xFFF59E0B),
                      isDark ? 0.10 : 0.16,
                      150),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF0F766E),
                                  const Color(0xFF115E59),
                                  const Color(0xFF1F2937)
                                ]
                              : [
                                  const Color(0xFF0D9488),
                                  const Color(0xFF0F766E),
                                  const Color(0xFF14B8A6)
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F766E)
                                .withOpacity(isDark ? 0.4 : 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.22),
                                width: 1,
                              ),
                            ),
                            child: const Icon(Icons.edit_note_rounded,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.currentLanguage == AppLanguage.arabic
                                      ? 'اكتب وعدا واضحا لنفسك'
                                      : lang.currentLanguage ==
                                              AppLanguage.kurdish
                                          ? 'بەڵێنێکی ڕوون بۆ خۆت بنووسە'
                                          : 'Write a clear promise to yourself',
                                  style: lang.getTextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_autoSaveStatus.isNotEmpty)
                                  Text(
                                    _autoSaveStatus,
                                    style: lang.getTextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_autoSaveStatus.isNotEmpty)
                            Icon(
                              _autoSaveStatus.contains('...') ||
                                      _autoSaveStatus.contains('...')
                                  ? Icons.sync_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                    // Text input — fixed height, scrollable — premium parchment
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                        minHeight: 160,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF14232A).withOpacity(0.75),
                                  const Color(0xFF1A2C30).withOpacity(0.65),
                                ]
                              : [
                                  const Color(0xFFFFFDF7),
                                  const Color(0xFFFAF6EC).withOpacity(0.9),
                                ],
                        ),
                      ),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: TextField(
                          controller: _letterController,
                          maxLines: null,
                          minLines: 6,
                          expands: false,
                          textAlignVertical: TextAlignVertical.top,
                          style: lang.getTextStyle(
                            fontSize: 16,
                            height: 1.8,
                            color: isDark ? Colors.white : const Color(0xFF263238),
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF14232A).withOpacity(0.72)
                                : const Color(0xFFF8FAFC),
                            hintText: placeholder,
                            hintStyle: lang.getTextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFF78909C),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.10)
                                    : const Color(0xFFB2DFDB),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.10)
                                    : const Color(0xFFB2DFDB),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: const Color(0xFF0D9488)
                                    .withOpacity(isDark ? 0.6 : 0.7),
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            // Auto-save on text change (debounced)
                            if (value.trim().length > 20 && !_isAutoSaving) {
                              Future.delayed(
                                  const Duration(milliseconds: 700), () {
                                if (!mounted) return;
                                if (_isWritingMode &&
                                    _letterController.text.trim() ==
                                        value.trim() &&
                                    value.trim().isNotEmpty) {
                                  _autoSaveLetter(lang);
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    // Buttons — always visible above keyboard
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  Colors.black.withOpacity(0.18),
                                  Colors.black.withOpacity(0.10),
                                ]
                              : [
                                  const Color(0xFFF8FAFC),
                                  const Color(0xFFF1F8F5),
                                ],
                        ),
                        border: Border(
                            top: BorderSide(
                                color: isDark
                                    ? Colors.white10
                                    : const Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (_editingLetterId != null) {
                                  // Discard edit without saving.
                                  setState(() {
                                    _isWritingMode = false;
                                    _editingLetterId = null;
                                    _letterController.clear();
                                  });
                                } else {
                                  // Auto-save before canceling if there's text
                                  if (_letterController.text.trim().isNotEmpty) {
                                    _autoSaveLetter(lang);
                                  }
                                  setState(() {
                                    _isWritingMode = false;
                                    _letterController.clear();
                                  });
                                }
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark
                                        ? [
                                            Colors.white.withOpacity(0.08),
                                            Colors.white.withOpacity(0.04),
                                          ]
                                        : [
                                            const Color(0xFFF1F5F9),
                                            const Color(0xFFE2E8F0),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.12)
                                        : const Color(0xFFCBD5E1),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                          isDark ? 0.2 : 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(cancelText,
                                      style: lang.getTextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white60
                                              : const Color(0xFF64748B))),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: _isAutoSaving ? null : () => _saveLetter(lang),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF0D9488),
                                      Color(0xFF0F766E),
                                      Color(0xFF14B8A6)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.18),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0D9488)
                                          .withOpacity(0.45),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF14B8A6)
                                          .withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isAutoSaving
                                            ? Icons.sync_rounded
                                            : Icons.save_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(saveText,
                                          style: lang.getTextStyle(
                                              fontSize: 15,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernViewMode(LanguageService lang, bool isDark,
      CommitmentLetter? letter, String noLettersText, String signatureText) {
    if (letter == null) {
      return _buildCommitmentEmpty(lang, isDark, noLettersText);
    }

    final languageCode = lang.currentLanguage == AppLanguage.arabic
        ? 'arabic'
        : lang.currentLanguage == AppLanguage.kurdish
            ? 'kurdish'
            : 'english';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withOpacity(0.10),
                      Colors.white.withOpacity(0.06),
                      Colors.white.withOpacity(0.08),
                    ]
                  : [
                      Colors.white.withOpacity(1.0),
                      const Color(0xFFFFFBF2).withOpacity(0.98),
                      Colors.white.withOpacity(0.96),
                    ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.14)
                    : const Color(0xFFB2DFDB),
                width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E)
                    .withOpacity(isDark ? 0.30 : 0.22),
                blurRadius: 44,
                spreadRadius: 2,
                offset: const Offset(0, 22),
              ),
              BoxShadow(
                color: const Color(0xFFF59E0B)
                    .withOpacity(isDark ? 0.12 : 0.14),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                // Accent glow orbs inside the letter card
                Positioned(
                  top: -50,
                  left: -50,
                  child: _buildSoftOrb(
                      const Color(0xFF14B8A6),
                      isDark ? 0.14 : 0.18,
                      180),
                ),
                Positioned(
                  bottom: -60,
                  right: -40,
                  child: _buildSoftOrb(
                      const Color(0xFFF59E0B),
                      isDark ? 0.10 : 0.14,
                      160),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0D9488),
                              const Color(0xFF0F766E),
                              const Color(0xFFF59E0B)
                            ]),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F766E)
                                .withOpacity(isDark ? 0.5 : 0.4),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildWaxSeal(isDark, letter.userName),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _commitmentService.formatDate(
                                      letter.createdAt, languageCode),
                                  style: lang.getTextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withOpacity(0.78)),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${signatureText} ${letter.userName}',
                                  style: lang.getTextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(26),
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          letter.content,
                          style: lang.getTextStyle(
                            fontSize: 17,
                            height: 1.95,
                            color: isDark
                                ? Colors.white.withOpacity(0.92)
                                : const Color(0xFF263238),
                          ),
                        ),
                      ),
                    ),
                    // Edit / Delete actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 0, 26, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLetterActionChip(
                            lang,
                            isDark,
                            icon: Icons.edit_rounded,
                            label: lang.currentLanguage == AppLanguage.arabic
                                ? 'تعديل'
                                : lang.currentLanguage == AppLanguage.kurdish
                                    ? 'دەستکاری'
                                    : 'Edit',
                            color: const Color(0xFF0D9488),
                            onTap: () => _startEdit(lang, letter),
                          ),
                          const SizedBox(width: 12),
                          _buildLetterActionChip(
                            lang,
                            isDark,
                            icon: Icons.delete_outline_rounded,
                            label: lang.currentLanguage == AppLanguage.arabic
                                ? 'حذف'
                                : lang.currentLanguage == AppLanguage.kurdish
                                    ? 'سڕینەوە'
                                    : 'Delete',
                            color: const Color(0xFFE53935),
                            onTap: () => _confirmDeleteLetter(lang, letter),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Small pill button used for editing / deleting a letter.
  Widget _buildLetterActionChip(
    LanguageService lang,
    bool isDark, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.45), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: lang.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitmentEmpty(
      LanguageService lang, bool isDark, String noLettersText) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE0F2EF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFFF59E0B)]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.edit_document,
                  color: Colors.white, size: 42),
            ),
            const SizedBox(height: 20),
            Text(
              noLettersText,
              textAlign: TextAlign.center,
              style: lang.getTextStyle(
                fontSize: 15,
                height: 1.7,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF526D68),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerOrnament(bool isDark,
      {required bool top, required bool left}) {
    final goldColor =
        isDark ? const Color(0xFFFFD54F) : const Color(0xFFC5A059);
    return Positioned(
      top: top ? 12 : null,
      bottom: top ? null : 12,
      left: left ? 12 : null,
      right: left ? null : 12,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? BorderSide(color: goldColor.withOpacity(0.85), width: 2)
                : BorderSide.none,
            bottom: top
                ? BorderSide.none
                : BorderSide(color: goldColor.withOpacity(0.85), width: 2),
            left: left
                ? BorderSide(color: goldColor.withOpacity(0.85), width: 2)
                : BorderSide.none,
            right: left
                ? BorderSide.none
                : BorderSide(color: goldColor.withOpacity(0.85), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildWaxSeal(bool isDark, String name) {
    final sealColor =
        isDark ? const Color(0xFFB71C1C) : const Color(0xFF8B0000);
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : 'V';

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Ribbon behind seal
        Positioned(
          bottom: -15,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -0.15,
                child: Container(
                  width: 10,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFFFD54F).withOpacity(0.7)
                        : const Color(0xFFC5A059),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Transform.rotate(
                angle: 0.15,
                child: Container(
                  width: 10,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFFFD54F).withOpacity(0.5)
                        : const Color(0xFFB8860B),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Seal container
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: sealColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? const Color(0xFFFFD54F).withOpacity(0.3)
                  : const Color(0xFFC5A059).withOpacity(0.4),
              width: 1.5,
            ),
            gradient: RadialGradient(
              colors: [
                sealColor,
                sealColor.withRed(sealColor.red - 25),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF5E6C8),
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWritingMode(LanguageService lang, bool isDark,
      String placeholder, String saveText, String cancelText) {
    // Vintage colors
    const inkBrown = Color(0xFF2C1A10);
    const waxSeal = Color(0xFF8B0000);
    const candleGlow = Color(0xFFFFD54F);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? candleGlow.withOpacity(0.4)
                    : const Color(0xFFC5A059).withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.6 : 0.3),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // Parchment paper background using CustomPainter
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ParchmentPaperPainter(isDark: isDark),
                    ),
                  ),

                  // Semi-transparent parchment protection overlay (refined for gorgeous high-contrast programmatically generated background texture)
                  Positioned.fill(
                    child: Container(
                      color: isDark
                          ? const Color(0xFF160E06).withOpacity(0.72)
                          : const Color(0xFFFCF7EE).withOpacity(0.15),
                    ),
                  ),

                  // Elegant Inner Gold Frame
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                (isDark ? candleGlow : const Color(0xFFC5A059))
                                    .withOpacity(0.35),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),

                  // Corner Ornaments
                  _buildCornerOrnament(isDark, top: true, left: true),
                  _buildCornerOrnament(isDark, top: true, left: false),
                  _buildCornerOrnament(isDark, top: false, left: true),
                  _buildCornerOrnament(isDark, top: false, left: false),

                  // Quill pen decoration icon
                  Positioned(
                    top: 20,
                    right: lang.isRTL ? null : 20,
                    left: lang.isRTL ? 20 : null,
                    child: Icon(
                      Icons.edit_note,
                      size: 32,
                      color: isDark
                          ? candleGlow.withOpacity(0.4)
                          : const Color(0xFFC5A059).withOpacity(0.5),
                    ),
                  ),

                  // Content
                  Positioned.fill(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: TextField(
                            controller: _letterController,
                            maxLines: null,
                            minLines: 8,
                            expands: false,
                            textAlignVertical: TextAlignVertical.top,
                            style: lang.getTextStyle(
                              fontSize: 17,
                              height: 1.8,
                              color:
                                  isDark ? const Color(0xFFFFF1D6) : inkBrown,
                            ),
                            decoration: InputDecoration(
                              hintText: placeholder,
                              hintStyle: lang.getTextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white30
                                    : inkBrown.withOpacity(0.4),
                              ),
                              contentPadding:
                                  const EdgeInsets.fromLTRB(28, 50, 28, 20),
                              border: InputBorder.none,
                            ),
                          ),
                          ),
                        ),
                        // Bottom bar with action buttons
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.4)
                                : const Color(0xFFC5A059).withOpacity(0.08),
                            border: Border(
                              top: BorderSide(
                                color: isDark
                                    ? candleGlow.withOpacity(0.2)
                                    : const Color(0xFFC5A059).withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => setState(() {
                                  _isWritingMode = false;
                                  _letterController.clear();
                                }),
                                child: Text(
                                  cancelText,
                                  style: lang.getTextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () => _saveLetter(lang),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isDark ? candleGlow : waxSeal,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 12),
                                  elevation: 4,
                                  shadowColor: (isDark ? candleGlow : waxSeal)
                                      .withOpacity(0.3),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.save_rounded,
                                        size: 18,
                                        color: isDark
                                            ? const Color(0xFF2C1A10)
                                            : Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      saveText,
                                      style: lang.getTextStyle(
                                        color: isDark
                                            ? const Color(0xFF2C1A10)
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewMode(LanguageService lang, bool isDark,
      CommitmentLetter? letter, String noLettersText, String signatureText) {
    // Vintage colors
    const inkBrown = Color(0xFF2C1A10);
    const candleGlow = Color(0xFFFFD54F);

    if (letter == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFC5A059).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mail_outline_rounded,
                size: 64,
                color: isDark
                    ? candleGlow.withOpacity(0.7)
                    : const Color(0xFFC5A059),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              noLettersText,
              textAlign: TextAlign.center,
              style: lang.getTextStyle(
                fontSize: 15,
                color: isDark ? Colors.white60 : inkBrown.withOpacity(0.7),
                height: 1.6,
              ),
            ),
          ],
        ),
      );
    }

    final languageCode = lang.currentLanguage == AppLanguage.arabic
        ? 'arabic'
        : lang.currentLanguage == AppLanguage.kurdish
            ? 'kurdish'
            : 'english';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? candleGlow.withOpacity(0.4)
                    : const Color(0xFFC5A059).withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.6 : 0.3),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // Parchment paper background using CustomPainter
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ParchmentPaperPainter(isDark: isDark),
                    ),
                  ),

                  // Semi-transparent parchment protection overlay (refined for gorgeous high-contrast programmatically generated background texture)
                  Positioned.fill(
                    child: Container(
                      color: isDark
                          ? const Color(0xFF160E06).withOpacity(0.72)
                          : const Color(0xFFFCF7EE).withOpacity(0.15),
                    ),
                  ),

                  // Elegant Inner Gold Frame
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                (isDark ? candleGlow : const Color(0xFFC5A059))
                                    .withOpacity(0.35),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),

                  // Corner Ornaments
                  _buildCornerOrnament(isDark, top: true, left: true),
                  _buildCornerOrnament(isDark, top: true, left: false),
                  _buildCornerOrnament(isDark, top: false, left: true),
                  _buildCornerOrnament(isDark, top: false, left: false),

                  // Content Column
                  Positioned.fill(
                    child: Column(
                      children: [
                        // Date header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : const Color(0xFFC5A059).withOpacity(0.08),
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? candleGlow.withOpacity(0.15)
                                    : const Color(0xFFC5A059).withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: isDark
                                    ? candleGlow
                                    : const Color(0xFFC5A059),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _commitmentService.formatDate(
                                    letter.createdAt, languageCode),
                                style: lang.getTextStyle(
                                  fontSize: 14,
                                  color: isDark ? candleGlow : inkBrown,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Letter content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 30),
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              letter.content,
                              style: lang.getTextStyle(
                                fontSize: 17,
                                height: 1.9,
                                color:
                                    isDark ? const Color(0xFFFFF1D6) : inkBrown,
                              ),
                            ),
                          ),
                        ),

                        // Signature section with realistic wax seal stamp
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : const Color(0xFFC5A059).withOpacity(0.06),
                            border: Border(
                              top: BorderSide(
                                color: isDark
                                    ? candleGlow.withOpacity(0.15)
                                    : const Color(0xFFC5A059).withOpacity(0.15),
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Decorative elegant scroll separator
                              Container(
                                width: 80,
                                height: 1,
                                color: isDark
                                    ? candleGlow.withOpacity(0.3)
                                    : const Color(0xFFC5A059).withOpacity(0.4),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                signatureText,
                                style: lang.getTextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white38
                                      : inkBrown.withOpacity(0.5),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildWaxSeal(isDark, letter.userName),
                                  const SizedBox(width: 16),
                                  Text(
                                    letter.userName,
                                    style: lang.getTextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? candleGlow : inkBrown,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrnament(bool isDark) {
    const purpleColor = Color(0xFF6A1B9A);
    const amberColor = Color(0xFFFFB300);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                isDark
                    ? amberColor.withOpacity(0.5)
                    : purpleColor.withOpacity(0.3),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(
          Icons.edit_document,
          size: 16,
          color: isDark
              ? amberColor.withOpacity(0.5)
              : purpleColor.withOpacity(0.4),
        ),
        const SizedBox(width: 10),
        Container(
          width: 50,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isDark
                    ? amberColor.withOpacity(0.5)
                    : purpleColor.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCornerDecoration(bool isDark, bool isLeft) {
    const purpleColor = Color(0xFF6A1B9A);
    const amberColor = Color(0xFFFFB300);

    return Transform.rotate(
      angle: isLeft ? 0 : 3.14159,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark
                  ? amberColor.withOpacity(0.3)
                  : purpleColor.withOpacity(0.3),
              width: 2,
            ),
            left: BorderSide(
              color: isDark
                  ? amberColor.withOpacity(0.3)
                  : purpleColor.withOpacity(0.3),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// Parchment paper painter - creates aged paper with burnt/torn edges
class ParchmentPaperPainter extends CustomPainter {
  final bool isDark;

  ParchmentPaperPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Solid base paper color
    final basePaint = Paint()
      ..color = isDark ? const Color(0xFF1E140B) : const Color(0xFFFAF2DC);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // Burnt edge colors
    final edgeColor =
        isDark ? const Color(0xFF1A0F05) : const Color(0xFF5D4037);

    final outerBurnColor =
        isDark ? const Color(0xFF0D0705) : const Color(0xFF3E2723);

    // Create multiple layers for realistic burnt edge effect

    // Outer darkest edge (burnt)
    final outerEdgePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          outerBurnColor.withOpacity(0.6),
          Colors.transparent,
          Colors.transparent,
          outerBurnColor.withOpacity(0.6),
        ],
        stops: const [0.0, 0.08, 0.92, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), outerEdgePaint);

    // Top edge burnt gradient
    final topEdgePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          outerBurnColor.withOpacity(0.7),
          edgeColor.withOpacity(0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.05, 0.15],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.15), topEdgePaint);

    // Bottom edge burnt gradient
    final bottomEdgePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          outerBurnColor.withOpacity(0.7),
          edgeColor.withOpacity(0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.05, 0.15],
      ).createShader(
          Rect.fromLTWH(0, size.height * 0.85, size.width, size.height * 0.15));

    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.85, size.width, size.height * 0.15),
        bottomEdgePaint);

    // Add inner shadow/vignette for depth
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [
          Colors.transparent,
          edgeColor.withOpacity(isDark ? 0.2 : 0.12),
        ],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);

    // Subtle texture spots (aged paper stains)
    final stainPaint = Paint()
      ..color = edgeColor.withOpacity(isDark ? 0.08 : 0.05);

    // Random-looking spots for aged effect
    canvas.drawCircle(
        Offset(size.width * 0.15, size.height * 0.2), 25, stainPaint);
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.75), 20, stainPaint);
    canvas.drawCircle(
        Offset(size.width * 0.3, size.height * 0.85), 18, stainPaint);
    canvas.drawCircle(
        Offset(size.width * 0.7, size.height * 0.15), 22, stainPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

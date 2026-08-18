import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/language_service.dart';

/// Official support link — used everywhere.
const String kSupportUrl = 'https://creators.sa/yousifkareem';

/// Max number of times the support card is shown automatically.
const int kSupportCardMaxShows = 2;

/// Opens the support page in the device's EXTERNAL browser.
Future<void> openSupportExternal() async {
  final uri = Uri.parse(kSupportUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class WelcomeMessageWidget extends StatefulWidget {
  final Widget child;

  const WelcomeMessageWidget({super.key, required this.child});

  @override
  State<WelcomeMessageWidget> createState() => _WelcomeMessageWidgetState();
}

class _WelcomeMessageWidgetState extends State<WelcomeMessageWidget>
    with SingleTickerProviderStateMixin {
  static const String _showCountKey = 'support_card_show_count';

  bool _showMessage = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // One-shot entrance animation (short & light — no continuous animation).
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _decideWhetherToShow();
  }

  /// Show the card only on the first [kSupportCardMaxShows] app opens.
  /// The counter is persisted locally, so it survives app restarts.
  Future<void> _decideWhetherToShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_showCountKey) ?? 0;
      if (count < kSupportCardMaxShows) {
        await prefs.setInt(_showCountKey, count + 1);
        if (mounted) {
          setState(() => _showMessage = true);
          _animationController.forward();
        }
      }
    } catch (e) {
      // If storage fails, fall back to showing once for this session.
      if (mounted) {
        setState(() => _showMessage = true);
        _animationController.forward();
      }
    }
  }

  Future<void> _hideMessage() async {
    await _animationController.reverse();
    if (mounted) {
      setState(() => _showMessage = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showMessage)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: GestureDetector(
                onTap: _hideMessage,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Container(
                        color: Colors.black.withOpacity(
                          0.7 * _fadeAnimation.value,
                        ),
                        child: Center(
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            // Card tap opens the support page externally;
                            // tapping the dimmed background dismisses it.
                            child: GestureDetector(
                              onTap: openSupportExternal,
                              child: _buildSupportCard(context),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    final lang = Provider.of<LanguageService>(context, listen: false);

    final title = switch (lang.currentLanguage) {
      AppLanguage.kurdish => 'پشتیوانی بەردەوامیی ئەپ بکە',
      AppLanguage.arabic => 'ادعم استمرار التطبيق',
      AppLanguage.english => 'Support the app',
    };

    final headline = switch (lang.currentLanguage) {
      AppLanguage.kurdish =>
          'یارمەتیمان بدە ئەپەکانمان بە خۆڕایی و بەردەوام بمێننەوە بۆ هەمووان',
      AppLanguage.arabic => 'ساهم في إبقاء تطبيقاتنا مجانية ومستمرّة للجميع',
      AppLanguage.english => 'Help keep our apps free and available for everyone',
    };

    final description = switch (lang.currentLanguage) {
      AppLanguage.kurdish =>
          'ئەم ئەپە بە تەواوی خۆڕاییە، و پشتیوانی تۆ یارمەتیمان دەدات بەردەوام بین لە پەرەپێدان و باشترکردنی و زیادکردنی تایبەتمەندیی نوێ بۆ خزمەتکردنی هەمووان.',
      AppLanguage.arabic =>
          'هذا التطبيق مجاني بالكامل، ودعمك يساعدنا على الاستمرار في تطويره وتحسينه وإضافة ميزات جديدة تخدم الجميع.',
      AppLanguage.english =>
          'This app is completely free, and your support helps us keep developing it, improving it and adding new features for everyone.',
    };

    final buttonLabel = switch (lang.currentLanguage) {
      AppLanguage.kurdish => 'ساهم في استمرار التطبيق',
      AppLanguage.arabic => 'ساهم في استمرار التطبيق',
      AppLanguage.english => 'Keep the app going',
    };

    final closeLabel = switch (lang.currentLanguage) {
      AppLanguage.kurdish => 'داخستن',
      AppLanguage.arabic => 'إغلاق',
      AppLanguage.english => 'Close',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 26),
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        // Light, single shadow (no heavy blur/spread).
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Background — static gradient (no animated orbs).
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0E5A31),
                      Color(0xFF0A4524),
                      Color(0xFF072E18),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 56, 26, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Static heart icon (no continuous animation).
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3314B8A6),
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    title,
                    style: lang.getTextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Headline chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      headline,
                      style: lang.getTextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Description
                  Text(
                    description,
                    style: lang.getTextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.8,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Support button — opens externally
                  GestureDetector(
                    onTap: openSupportExternal,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0D9488),
                            Color(0xFF14B8A6),
                            Color(0xFF2DD4BF),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x330D9488),
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              buttonLabel,
                              style: lang.getTextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Close button
                  GestureDetector(
                    onTap: _hideMessage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.close_rounded,
                            color: Colors.white.withOpacity(0.65),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            closeLabel,
                            style: lang.getTextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Close button (top-right)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: _hideMessage,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

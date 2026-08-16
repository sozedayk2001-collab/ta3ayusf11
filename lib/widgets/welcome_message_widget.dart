import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/language_service.dart';

/// Official support link — used everywhere.
const String kSupportUrl = 'https://creators.sa/yousifkareem';

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
  bool _showMessage = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _heartController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _animationController.forward();
  }

  Future<void> _hideMessage() async {
    await _animationController.reverse();
    if (mounted) {
      setState(() {
        _showMessage = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _heartController.dispose();
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
                          0.75 * _fadeAnimation.value,
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
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D4F2B).withOpacity(0.65),
            blurRadius: 48,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: const Color(0xFF14B8A6).withOpacity(0.25),
            blurRadius: 60,
            spreadRadius: 2,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Stack(
          children: [
            // Background — rich layered gradient
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
                      Color(0xFF041C0F),
                    ],
                  ),
                ),
              ),
            ),
            // Decorative glowing orb (top)
            Positioned(
              top: -70,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF14B8A6).withOpacity(0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Decorative glowing orb (bottom)
            Positioned(
              bottom: -80,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2DD4BF).withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Soft glass highlight
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.07),
                      Colors.black.withOpacity(0.12),
                      Colors.black.withOpacity(0.45),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 60, 26, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Heart icon badge — animated pulse
                  AnimatedBuilder(
                    animation: _heartController,
                    builder: (context, _) {
                      final glowOpacity = 0.30 + 0.25 * _heartController.value;
                      final scale = 1.0 + 0.05 * _heartController.value;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF14B8A6)
                                    .withOpacity(glowOpacity),
                                blurRadius: 34,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(23),
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
                                size: 44,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // Title
                  Text(
                    title,
                    style: lang.getTextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Headline chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withOpacity(0.14),
                          Colors.white.withOpacity(0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
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
                  const SizedBox(height: 16),

                  // Elegant divider
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white.withOpacity(0.4),
                          size: 16,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    description,
                    style: lang.getTextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.85,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),

                  // Support button — opens externally
                  GestureDetector(
                    onTap: openSupportExternal,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
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
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withOpacity(0.55),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
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
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.14),
                        ),
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
            // Close button (top-right) — no auto-hide
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: _hideMessage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                    ),
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

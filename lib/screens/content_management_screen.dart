import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/language_service.dart';
import '../services/tips_service.dart';
import '../services/quotes_service.dart';
import '../services/stories_service.dart';
import '../services/library_service.dart';

class ContentManagementScreen extends StatelessWidget {
  const ContentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TipsService()..loadTips()),
        ChangeNotifierProvider(create: (_) => QuotesService()..loadQuotes()),
        ChangeNotifierProvider(create: (_) => StoriesService()..loadStories()),
      ],
      child: const _ContentManagementContent(),
    );
  }
}

class _ContentManagementContent extends StatefulWidget {
  const _ContentManagementContent();

  @override
  State<_ContentManagementContent> createState() => _ContentManagementContentState();
}

class _ContentManagementContentState extends State<_ContentManagementContent> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final isDark = lang.isDarkMode;
    final tipsService = Provider.of<TipsService>(context);
    final quotesService = Provider.of<QuotesService>(context);
    final storiesService = Provider.of<StoriesService>(context);

    // Get counts
    final tipsCount = tipsService.tips.length;
    final quotesCount = quotesService.quotes.length;
    final storiesCount = storiesService.stories.length;

    return Directionality(
      textDirection: lang.textDirection,
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF0a1628) : const Color(0xFFf5f5f5),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(lang.isRTL ? Icons.arrow_forward_ios : Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(_getContentManagementText(lang), style: lang.getTextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            centerTitle: true,
            bottom: TabBar(
              indicatorColor: const Color(0xFF4facfe),
              labelColor: isDark ? Colors.white : Colors.black87,
              unselectedLabelColor: Colors.grey,
              isScrollable: true,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lang.currentLanguage == AppLanguage.arabic ? 'نصائح' : lang.currentLanguage == AppLanguage.kurdish ? 'نەسیحەتەکان' : 'Tips'),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4facfe),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$tipsCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lang.currentLanguage == AppLanguage.arabic ? 'اقتباسات' : lang.currentLanguage == AppLanguage.kurdish ? 'وتەکان' : 'Quotes'),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$quotesCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lang.currentLanguage == AppLanguage.arabic ? 'قصص' : lang.currentLanguage == AppLanguage.kurdish ? 'قصەکان' : 'Stories'),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D6B4E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$storiesCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Tab(text: lang.currentLanguage == AppLanguage.arabic ? 'المكتبة' : lang.currentLanguage == AppLanguage.kurdish ? 'کتێبخانە' : 'Library'),
              ],
            ),
          ),
          floatingActionButton: Builder(
            builder: (context) => FloatingActionButton(
              onPressed: () {
                final index = DefaultTabController.of(context).index;
                if (index == 0) {
                  _showAddTipDialog(context, lang);
                } else if (index == 1) {
                  _showAddQuoteDialog(context, lang);
                } else {
                  _showAddStoryDialog(context, lang);
                }
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
          body: const TabBarView(
            children: [
              _TipsManagementTab(),
              _QuotesManagementTab(),
              _StoriesManagementTab(),
              _LibraryManagementTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== DIALOGS ====================

  void _showAddTipDialog(BuildContext context, LanguageService lang) {
    final tipsService = Provider.of<TipsService>(context, listen: false);
    final arController = TextEditingController();
    final kuController = TextEditingController();
    final enController = TextEditingController();
    bool autoTranslate = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: lang.textDirection,
          child: AlertDialog(
            backgroundColor: lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_rounded, color: Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: Text(_getAddTipText(lang), style: lang.getTextStyle(fontWeight: FontWeight.bold, color: lang.isDarkMode ? Colors.white : Colors.black87))),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.translate, color: lang.isDarkMode ? Colors.white54 : Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_getAutoTranslateText(lang), style: lang.getTextStyle(fontSize: 13, color: lang.isDarkMode ? Colors.white70 : Colors.black54))),
                      Switch(value: autoTranslate, onChanged: (val) => setDialogState(() => autoTranslate = val), activeColor: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(arController, 'العربية (مطلوب)', lang, TextDirection.rtl),
                  if (!autoTranslate) ...[
                    const SizedBox(height: 12),
                    _buildTextField(kuController, 'کوردی سۆرانی', lang, TextDirection.rtl),
                    const SizedBox(height: 12),
                    _buildTextField(enController, 'English', lang, TextDirection.ltr),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: _isProcessing ? null : () async {
                  if (arController.text.trim().isEmpty) return;
                  setDialogState(() => _isProcessing = true);
                  final success = await tipsService.addTip(arController.text, textKu: autoTranslate ? null : kuController.text, textEn: autoTranslate ? null : enController.text);
                  setDialogState(() => _isProcessing = false);
                  if (success && mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getTipAddedText(lang)), backgroundColor: Colors.green));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_getSaveText(lang), style: lang.getTextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddQuoteDialog(BuildContext context, LanguageService lang) {
    final quotesService = Provider.of<QuotesService>(context, listen: false);
    final arController = TextEditingController();
    final kuController = TextEditingController();
    final enController = TextEditingController();
    // Default to manual entry for now as QuotesService auto-translate might be placeholder
    // But UI can offer toggles if supported.
    bool autoTranslate = true; 

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: lang.textDirection,
          child: AlertDialog(
            backgroundColor: lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.format_quote_rounded, color: Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: Text(_getAddTipText(lang).replaceAll('نصيحة', 'اقتباس'), style: lang.getTextStyle(fontWeight: FontWeight.bold, color: lang.isDarkMode ? Colors.white : Colors.black87))),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildTextField(arController, 'العربية (مطلوب)', lang, TextDirection.rtl),
                   const SizedBox(height: 12),
                  _buildTextField(kuController, 'کوردی سۆرانی', lang, TextDirection.rtl),
                  const SizedBox(height: 12),
                  _buildTextField(enController, 'English', lang, TextDirection.ltr),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: _isProcessing ? null : () async {
                  if (arController.text.trim().isEmpty) return;
                  setDialogState(() => _isProcessing = true);
                  // Pass directly to service
                  await quotesService.addQuote(arController.text, textKu: kuController.text, textEn: enController.text);
                  setDialogState(() => _isProcessing = false);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getTipAddedText(lang).replaceAll('النصيحة', 'الاقتباس')), backgroundColor: Colors.green));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_getSaveText(lang), style: lang.getTextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for text fields
  Widget _buildTextField(TextEditingController controller, String label, LanguageService lang, TextDirection direction) {
    return TextField(
      controller: controller,
      textDirection: direction,
      maxLines: 3,
      style: lang.getTextStyle(color: lang.isDarkMode ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: lang.getTextStyle(color: lang.isDarkMode ? Colors.white54 : Colors.black45),
        filled: true,
        fillColor: lang.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4facfe))),
      ),
    );
  }

  // Translations helpers
  String _getContentManagementText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'بەڕێوەبردنی ناوەڕۆک' : lang.currentLanguage == AppLanguage.arabic ? 'إدارة المحتوى' : 'Content Management';
  String _getAddTipText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'زیادکردنی نەسیحەت' : lang.currentLanguage == AppLanguage.arabic ? 'إضافة نصيحة' : 'Add Tip';
  String _getAutoTranslateText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'وەرگێڕانی ئۆتۆماتیکی' : lang.currentLanguage == AppLanguage.arabic ? 'ترجمة تلقائية' : 'Auto Translate';
  String _getTipAddedText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'زیادکرا بە سەرکەوتوویی' : lang.currentLanguage == AppLanguage.arabic ? 'تمت الإضافة بنجاح' : 'Added Successfully';
  String _getSaveText(LanguageService lang) => lang.currentLanguage == AppLanguage.kurdish ? 'پاشەکەوتکردن' : lang.currentLanguage == AppLanguage.arabic ? 'حفظ' : 'Save';

  void _showAddStoryDialog(BuildContext context, LanguageService lang) {
    final storiesService = Provider.of<StoriesService>(context, listen: false);
    final arController = TextEditingController();
    final kuController = TextEditingController();
    final enController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: lang.textDirection,
          child: AlertDialog(
            backgroundColor: lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF0D6B4E).withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF0D6B4E))),
              const SizedBox(width: 12),
              Expanded(child: Text(lang.currentLanguage == AppLanguage.arabic ? 'إضافة قصة' : lang.currentLanguage == AppLanguage.kurdish ? 'زیادکردنی قصە' : 'Add Story', style: lang.getTextStyle(fontWeight: FontWeight.bold, color: lang.isDarkMode ? Colors.white : Colors.black87))),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildTextField(arController, 'العربية (مطلوب)', lang, TextDirection.rtl),
                  const SizedBox(height: 12),
                  _buildTextField(kuController, 'کوردی سۆرانی', lang, TextDirection.rtl),
                  const SizedBox(height: 12),
                  _buildTextField(enController, 'English', lang, TextDirection.ltr),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: _isProcessing ? null : () async {
                  if (arController.text.trim().isEmpty) return;
                  setDialogState(() => _isProcessing = true);
                  await storiesService.addStory(arController.text, textKu: kuController.text, textEn: enController.text);
                  setDialogState(() => _isProcessing = false);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getTipAddedText(lang)), backgroundColor: const Color(0xFF0D6B4E)));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6B4E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_getSaveText(lang), style: lang.getTextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _TipsManagementTab extends StatelessWidget {
  const _TipsManagementTab();

  void _showEditTipDialog(BuildContext context, Tip tip, LanguageService lang) {
     /* Simpler generic edit dialog implementation needed or full copy of previous logic */
     // For brevity in this replacement, assume similar logic using Provider.of<TipsService>
     // Implementing a minimal version here to ensure functionality
     final tipsService = Provider.of<TipsService>(context, listen: false);
     final arController = TextEditingController(text: tip.textAr);
     final kuController = TextEditingController(text: tip.textKu);
     final enController = TextEditingController(text: tip.textEn);
     
     showDialog(context: context, builder: (ctx) => Directionality(
       textDirection: lang.textDirection,
       child: AlertDialog(
         backgroundColor: lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
         title: Text('Edit', style: TextStyle(color: lang.isDarkMode ? Colors.white : Colors.black)),
         content: Column(mainAxisSize: MainAxisSize.min, children: [
           TextField(controller: arController, style: TextStyle(color: lang.isDarkMode ? Colors.white : Colors.black), decoration: const InputDecoration(labelText: 'Arabic')),
           TextField(controller: kuController, style: TextStyle(color: lang.isDarkMode ? Colors.white : Colors.black), decoration: const InputDecoration(labelText: 'Kurdish')),
           TextField(controller: enController, style: TextStyle(color: lang.isDarkMode ? Colors.white : Colors.black), decoration: const InputDecoration(labelText: 'English')),
         ]),
         actions: [
           ElevatedButton(onPressed: () {
             tipsService.updateTip(tip.id, arController.text, textKu: kuController.text, textEn: enController.text);
             Navigator.pop(ctx);
           }, child: const Text('Save')),
         ],
       ),
     ));
  }

  void _showDeleteTipDialog(BuildContext context, Tip tip, LanguageService lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
        title: Text('Delete?', style: TextStyle(color: lang.isDarkMode ? Colors.white : Colors.black)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            Provider.of<TipsService>(context, listen: false).deleteTip(tip.id);
            Navigator.pop(ctx);
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final isDark = lang.isDarkMode;
    final tipsService = Provider.of<TipsService>(context);

    // Tip color
    const tipColor = Color(0xFF4facfe);

    if (tipsService.tips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 60, color: tipColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(lang.currentLanguage == AppLanguage.arabic ? 'لا توجد نصائح' : lang.currentLanguage == AppLanguage.kurdish ? 'هیچ نەسیحەتێک نییە' : 'No tips', style: lang.getTextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            Text(lang.currentLanguage == AppLanguage.arabic ? 'اضغط على + لإضافة نصيحة جديدة' : lang.currentLanguage == AppLanguage.kurdish ? 'کلیک لەسەر + بکە بۆ زیادکردنی نەسیحەت' : 'Tap + to add a tip', style: lang.getTextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
        itemCount: tipsService.tips.length,
        itemBuilder: (context, index) {
          final tip = tipsService.tips[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: isDark 
                  ? [const Color(0xFF1a2a4a), const Color(0xFF243656)]
                  : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tipColor.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: tipColor.withOpacity(isDark ? 0.15 : 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tipColor.withOpacity(0.2), tipColor.withOpacity(0.05)],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tipColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const Spacer(),
                      Icon(Icons.lightbulb_outline_rounded, size: 18, color: tipColor.withOpacity(0.7)),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.textAr,
                        style: GoogleFonts.amiri(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFE8DCC8) : const Color(0xFF1A237E),
                          height: 1.6,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      if (tip.textKu.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          tip.textKu,
                          style: GoogleFonts.vazirmatn(fontSize: 13, color: isDark ? Colors.white60 : Colors.black45, height: 1.5),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                      if (tip.textEn.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          tip.textEn,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38, fontStyle: FontStyle.italic),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ],
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEditTipDialog(context, tip, lang),
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4facfe)),
                        label: Text(lang.currentLanguage == AppLanguage.arabic ? 'تعديل' : lang.currentLanguage == AppLanguage.kurdish ? 'دەستکاری' : 'Edit', style: lang.getTextStyle(color: const Color(0xFF4facfe), fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _showDeleteTipDialog(context, tip, lang),
                        icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                        label: Text(lang.currentLanguage == AppLanguage.arabic ? 'حذف' : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوە' : 'Delete', style: lang.getTextStyle(color: Colors.red[400], fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuotesManagementTab extends StatelessWidget {
  const _QuotesManagementTab();

  void _showEditQuoteDialog(BuildContext context, Quote quote, LanguageService lang) {
     final quotesService = Provider.of<QuotesService>(context, listen: false);
     final arController = TextEditingController(text: quote.textAr);
     final kuController = TextEditingController(text: quote.textKu);
     final enController = TextEditingController(text: quote.textEn);
     
     showDialog(context: context, builder: (ctx) => Directionality(
       textDirection: TextDirection.rtl,
       child: AlertDialog(
         backgroundColor: lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
         title: Row(children: [
           Container(
             padding: const EdgeInsets.all(10),
             decoration: BoxDecoration(
               gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8860B)]),
               borderRadius: BorderRadius.circular(12),
             ),
             child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
           ),
           const SizedBox(width: 12),
           Text('تعديل الاقتباس', style: lang.getTextStyle(fontWeight: FontWeight.bold, color: lang.isDarkMode ? Colors.white : Colors.black87)),
         ]),
         content: SingleChildScrollView(
           child: Column(mainAxisSize: MainAxisSize.min, children: [
             _buildArabicTextField(arController, 'النص العربي (مطلوب)', lang),
             const SizedBox(height: 12),
             _buildArabicTextField(kuController, 'النص الكوردي', lang),
             const SizedBox(height: 12),
             _buildArabicTextField(enController, 'النص الإنجليزي', lang, isEnglish: true),
           ]),
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(ctx),
             child: Text('إلغاء', style: lang.getTextStyle(color: Colors.grey)),
           ),
           Container(
             decoration: BoxDecoration(
               gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8860B)]),
               borderRadius: BorderRadius.circular(10),
             ),
             child: ElevatedButton(
               onPressed: () {
                 quotesService.updateQuote(quote.id, arController.text, textKu: kuController.text, textEn: enController.text);
                 Navigator.pop(ctx);
               },
               style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
               child: Text('حفظ', style: lang.getTextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
             ),
           ),
         ],
       ),
     ));
  }

  Widget _buildArabicTextField(TextEditingController controller, String label, LanguageService lang, {bool isEnglish = false}) {
    return TextField(
      controller: controller,
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      maxLines: 2,
      style: lang.getTextStyle(color: lang.isDarkMode ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: lang.getTextStyle(color: lang.isDarkMode ? Colors.white54 : Colors.black45, fontSize: 13),
        filled: true,
        fillColor: lang.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37))),
      ),
    );
  }

  void _showDeleteQuoteDialog(BuildContext context, Quote quote, LanguageService lang) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Text('حذف الاقتباس', style: lang.getTextStyle(fontWeight: FontWeight.bold, color: lang.isDarkMode ? Colors.white : Colors.black87)),
          ]),
          content: Text('هل أنت متأكد من حذف هذا الاقتباس؟', style: lang.getTextStyle(color: lang.isDarkMode ? Colors.white70 : Colors.black54)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: lang.getTextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<QuotesService>(context, listen: false).deleteQuote(quote.id);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text('حذف', style: lang.getTextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final isDark = lang.isDarkMode;
    final quotesService = Provider.of<QuotesService>(context);

    // Islamic gold color
    const islamicGold = Color(0xFFD4AF37);

    if (quotesService.quotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.format_quote_rounded, size: 60, color: islamicGold.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('لا توجد اقتباسات', style: lang.getTextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            Text('اضغط على + لإضافة اقتباس جديد', style: lang.getTextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
        itemCount: quotesService.quotes.length,
        itemBuilder: (context, index) {
          final quote = quotesService.quotes[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: isDark 
                  ? [const Color(0xFF1a2a4a), const Color(0xFF243656)]
                  : [const Color(0xFFFFFDF5), const Color(0xFFFFF8E7)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: islamicGold.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: islamicGold.withOpacity(isDark ? 0.15 : 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [islamicGold.withOpacity(0.2), islamicGold.withOpacity(0.05)],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: islamicGold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const Spacer(),
                      Icon(Icons.format_quote_rounded, size: 18, color: islamicGold.withOpacity(0.7)),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.textAr,
                        style: GoogleFonts.amiri(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFE8DCC8) : const Color(0xFF2C3E2D),
                          height: 1.6,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      if (quote.textKu.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          quote.textKu,
                          style: GoogleFonts.vazirmatn(fontSize: 13, color: isDark ? Colors.white60 : Colors.black45, height: 1.5),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                      if (quote.textEn.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          quote.textEn,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38, fontStyle: FontStyle.italic),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ],
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEditQuoteDialog(context, quote, lang),
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFD4AF37)),
                        label: Text('تعديل', style: lang.getTextStyle(color: const Color(0xFFD4AF37), fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _showDeleteQuoteDialog(context, quote, lang),
                        icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                        label: Text('حذف', style: lang.getTextStyle(color: Colors.red[400], fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoriesManagementTab extends StatelessWidget {
  const _StoriesManagementTab();

  void _showEditStoryDialog(BuildContext context, Story story, LanguageService lang) {
    final storiesService = Provider.of<StoriesService>(context, listen: false);
    final arController = TextEditingController(text: story.textAr);
    final kuController = TextEditingController(text: story.textKu);
    final enController = TextEditingController(text: story.textEn);
    
    showDialog(context: context, builder: (ctx) => Directionality(
      textDirection: lang.textDirection,
      child: AlertDialog(
        backgroundColor: lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF0D6B4E).withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_rounded, color: Color(0xFF0D6B4E))),
          const SizedBox(width: 12),
          Text(lang.currentLanguage == AppLanguage.arabic ? 'تعديل القصة' : lang.currentLanguage == AppLanguage.kurdish ? 'دەستکاری قصە' : 'Edit Story', style: lang.getTextStyle(fontWeight: FontWeight.bold, color: lang.isDarkMode ? Colors.white : Colors.black87)),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: arController, textDirection: TextDirection.rtl, maxLines: 3, style: TextStyle(color: lang.isDarkMode ? Colors.white : Colors.black), decoration: const InputDecoration(labelText: 'العربية')),
          const SizedBox(height: 8),
          TextField(controller: kuController, textDirection: TextDirection.rtl, maxLines: 3, style: TextStyle(color: lang.isDarkMode ? Colors.white : Colors.black), decoration: const InputDecoration(labelText: 'کوردی')),
          const SizedBox(height: 8),
          TextField(controller: enController, maxLines: 3, style: TextStyle(color: lang.isDarkMode ? Colors.white : Colors.black), decoration: const InputDecoration(labelText: 'English')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              storiesService.updateStory(story.id, arController.text, textKu: kuController.text, textEn: enController.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6B4E)),
            child: Text(lang.currentLanguage == AppLanguage.arabic ? 'حفظ' : lang.currentLanguage == AppLanguage.kurdish ? 'پاشەکەوتکردن' : 'Save', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ));
  }

  void _showDeleteStoryDialog(BuildContext context, Story story, LanguageService lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lang.isDarkMode ? const Color(0xFF1a2a4a) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_outline_rounded, color: Colors.red)),
          const SizedBox(width: 12),
          Text(lang.currentLanguage == AppLanguage.arabic ? 'حذف القصة' : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوەی قصە' : 'Delete Story', style: lang.getTextStyle(fontWeight: FontWeight.bold, color: lang.isDarkMode ? Colors.white : Colors.black87)),
        ]),
        content: Text(lang.currentLanguage == AppLanguage.arabic ? 'هل أنت متأكد من حذف هذه القصة؟' : lang.currentLanguage == AppLanguage.kurdish ? 'ئایا دڵنیایت لە سڕینەوەی ئەم قصەیە؟' : 'Are you sure you want to delete this story?', style: lang.getTextStyle(color: lang.isDarkMode ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Provider.of<StoriesService>(context, listen: false).deleteStory(story.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lang.currentLanguage == AppLanguage.arabic ? 'حذف' : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوە' : 'Delete', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final isDark = lang.isDarkMode;
    final storiesService = Provider.of<StoriesService>(context);

    const islamicGreen = Color(0xFF0D6B4E);
    const islamicGold = Color(0xFFD4AF37);

    if (storiesService.stories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories_rounded, size: 60, color: islamicGreen.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(lang.currentLanguage == AppLanguage.arabic ? 'لا توجد قصص' : lang.currentLanguage == AppLanguage.kurdish ? 'هیچ قصەیەک نییە' : 'No stories', style: lang.getTextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            Text(lang.currentLanguage == AppLanguage.arabic ? 'اضغط على + لإضافة قصة جديدة' : lang.currentLanguage == AppLanguage.kurdish ? 'کلیک لەسەر + بکە بۆ زیادکردنی قصە' : 'Tap + to add a story', style: lang.getTextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
        itemCount: storiesService.stories.length,
        itemBuilder: (context, index) {
          final story = storiesService.stories[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: isDark 
                  ? [const Color(0xFF1a3d2e), const Color(0xFF243656)]
                  : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: islamicGreen.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: islamicGreen.withOpacity(isDark ? 0.15 : 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [islamicGreen.withOpacity(0.2), islamicGreen.withOpacity(0.05)]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: islamicGreen, borderRadius: BorderRadius.circular(8)),
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const Spacer(),
                      Icon(Icons.auto_stories_rounded, size: 18, color: islamicGreen.withOpacity(0.7)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.textAr,
                        style: GoogleFonts.amiri(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFE8DCC8) : islamicGreen, height: 1.6),
                        textDirection: TextDirection.rtl,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (story.textKu.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(story.textKu, style: GoogleFonts.vazirmatn(fontSize: 13, color: isDark ? Colors.white60 : Colors.black45), textDirection: TextDirection.rtl, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEditStoryDialog(context, story, lang),
                        icon: Icon(Icons.edit_outlined, size: 18, color: islamicGreen),
                        label: Text(lang.currentLanguage == AppLanguage.arabic ? 'تعديل' : lang.currentLanguage == AppLanguage.kurdish ? 'دەستکاری' : 'Edit', style: lang.getTextStyle(color: islamicGreen, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _showDeleteStoryDialog(context, story, lang),
                        icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                        label: Text(lang.currentLanguage == AppLanguage.arabic ? 'حذف' : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوە' : 'Delete', style: lang.getTextStyle(color: Colors.red[400], fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Library Management Tab
class _LibraryManagementTab extends StatefulWidget {
  const _LibraryManagementTab();

  @override
  State<_LibraryManagementTab> createState() => _LibraryManagementTabState();
}

class _LibraryManagementTabState extends State<_LibraryManagementTab> {
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LibraryService>(context, listen: false).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final isDark = lang.isDarkMode;
    final languageCode = lang.currentLanguage == AppLanguage.arabic 
        ? 'arabic' 
        : lang.currentLanguage == AppLanguage.kurdish 
            ? 'kurdish' 
            : 'english';

    return Consumer<LibraryService>(
      builder: (context, libraryService, child) {
        if (libraryService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categories Section
              _buildSectionHeader(
                lang.currentLanguage == AppLanguage.arabic ? 'الأقسام' 
                    : lang.currentLanguage == AppLanguage.kurdish ? 'پۆلەکان' 
                    : 'Categories',
                Icons.folder_open_rounded,
                const Color(0xFF0D9488),
                () => _showAddCategoryDialog(lang, isDark),
                isDark,
                lang,
              ),
              const SizedBox(height: 12),
              if (libraryService.categories.isEmpty)
                _buildEmptyState(
                  lang.currentLanguage == AppLanguage.arabic ? 'لا توجد أقسام' 
                      : lang.currentLanguage == AppLanguage.kurdish ? 'هیچ پۆلێک نییە' 
                      : 'No categories',
                  Icons.folder_off_outlined,
                  isDark,
                  lang,
                )
              else
                ...libraryService.categories.map((cat) => _buildCategoryCard(cat, languageCode, isDark, lang)),
              
              const SizedBox(height: 32),
              
              // Books Section
              _buildSectionHeader(
                lang.currentLanguage == AppLanguage.arabic ? 'الكتب' 
                    : lang.currentLanguage == AppLanguage.kurdish ? 'کتێبەکان' 
                    : 'Books',
                Icons.menu_book_rounded,
                const Color(0xFF4CAF50),
                () => _showAddBookDialog(lang, isDark, languageCode),
                isDark,
                lang,
              ),
              // Delete all books button
              if (libraryService.books.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmDeleteAllBooks(lang, isDark),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_sweep, color: Colors.white),
                    label: Text(
                      lang.currentLanguage == AppLanguage.arabic ? 'حذف جميع الكتب' 
                          : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوەی هەموو کتێبەکان' 
                          : 'Delete All Books',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              if (libraryService.books.isEmpty)
                _buildEmptyState(
                  lang.currentLanguage == AppLanguage.arabic ? 'لا توجد كتب' 
                      : lang.currentLanguage == AppLanguage.kurdish ? 'هیچ کتێبێک نییە' 
                      : 'No books',
                  Icons.book_outlined,
                  isDark,
                  lang,
                )
              else
                ...libraryService.books.map((book) => _buildBookCard(book, languageCode, isDark, lang)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, VoidCallback onAdd, bool isDark, LanguageService lang) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: lang.getTextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: onAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: Text(
            lang.currentLanguage == AppLanguage.arabic ? 'إضافة' 
                : lang.currentLanguage == AppLanguage.kurdish ? 'زیادکردن' 
                : 'Add',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String text, IconData icon, bool isDark, LanguageService lang) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: isDark ? Colors.white24 : Colors.grey[400]),
            const SizedBox(height: 12),
            Text(text, style: lang.getTextStyle(color: isDark ? Colors.white38 : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BookCategory category, String languageCode, bool isDark, LanguageService lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2a4a) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.category_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.getName(languageCode),
                  style: lang.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (category.nameAr.isNotEmpty && languageCode != 'arabic')
                  Text(
                    category.nameAr,
                    style: lang.getTextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                  ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            onPressed: () => _showEditCategoryDialog(category, lang, isDark),
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF0D9488)),
            tooltip: lang.currentLanguage == AppLanguage.arabic ? 'تعديل' : lang.currentLanguage == AppLanguage.kurdish ? 'دەستکاری' : 'Edit',
          ),
          // Delete button
          IconButton(
            onPressed: () => _confirmDeleteCategory(category, lang, isDark),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: lang.currentLanguage == AppLanguage.arabic ? 'حذف' : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوە' : 'Delete',
          ),
        ],
      ),
    );
  }


  Widget _buildBookCard(Book book, String languageCode, bool isDark, LanguageService lang) {
    final libraryService = Provider.of<LibraryService>(context, listen: false);
    final category = libraryService.categories.where((c) => c.id == book.categoryId).firstOrNull;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2a4a) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: book.coverUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(book.coverUrl!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.menu_book_rounded, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: lang.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  book.author,
                  style: lang.getTextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey),
                ),
                if (category != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category.getName(languageCode),
                      style: const TextStyle(fontSize: 10, color: Color(0xFF0D9488)),
                    ),
                  ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            onPressed: () => _showEditBookDialog(book, lang, isDark, languageCode),
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF4CAF50)),
            tooltip: lang.currentLanguage == AppLanguage.arabic ? 'تعديل' : lang.currentLanguage == AppLanguage.kurdish ? 'دەستکاری' : 'Edit',
          ),
          // Delete button
          IconButton(
            onPressed: () => _confirmDeleteBook(book, lang, isDark),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: lang.currentLanguage == AppLanguage.arabic ? 'حذف' : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوە' : 'Delete',
          ),
        ],
      ),
    );
  }


  void _showAddCategoryDialog(LanguageService lang, bool isDark) {
    final arController = TextEditingController();
    final kuController = TextEditingController();
    final enController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: lang.textDirection,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            lang.currentLanguage == AppLanguage.arabic ? 'إضافة قسم' 
                : lang.currentLanguage == AppLanguage.kurdish ? 'زیادکردنی پۆل' 
                : 'Add Category',
            style: lang.getTextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: arController,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'العربية',
                  labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                ),
              ),
              TextField(
                controller: kuController,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'کوردی',
                  labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                ),
              ),
              TextField(
                controller: enController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'English',
                  labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
              onPressed: () async {
                if (arController.text.isNotEmpty || kuController.text.isNotEmpty || enController.text.isNotEmpty) {
                  await Provider.of<LibraryService>(context, listen: false).addCategory(
                    arController.text,
                    kuController.text,
                    enController.text,
                  );
                  if (mounted) Navigator.pop(ctx);
                }
              },
              child: Text(
                lang.currentLanguage == AppLanguage.arabic ? 'إضافة' 
                    : lang.currentLanguage == AppLanguage.kurdish ? 'زیادکردن' 
                    : 'Add',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBookDialog(LanguageService lang, bool isDark, String languageCode) {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final pdfUrlController = TextEditingController();
    final coverUrlController = TextEditingController();
    final downloadUrlController = TextEditingController();
    String? selectedCategoryId;
    bool isAdding = false;
    
    // File upload state
    Uint8List? pdfBytes;
    String? pdfFileName;
    Uint8List? coverBytes;
    String? coverFileName;
    bool useFileUpload = true; // Default to file upload mode

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: lang.textDirection,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF4CAF50)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.currentLanguage == AppLanguage.arabic ? 'إضافة كتاب' 
                        : lang.currentLanguage == AppLanguage.kurdish ? 'زیادکردنی کتێب' 
                        : 'Add Book',
                    style: lang.getTextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle between file upload and URL mode
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => useFileUpload = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: useFileUpload ? const Color(0xFF4CAF50) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload_file, size: 18, color: useFileUpload ? Colors.white : Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    lang.currentLanguage == AppLanguage.arabic ? 'رفع ملف' 
                                        : lang.currentLanguage == AppLanguage.kurdish ? 'ئەپڵۆدی فایل' 
                                        : 'Upload File',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: useFileUpload ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => useFileUpload = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !useFileUpload ? const Color(0xFF0D9488) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.link, size: 18, color: !useFileUpload ? Colors.white : Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    lang.currentLanguage == AppLanguage.arabic ? 'رابط' 
                                        : lang.currentLanguage == AppLanguage.kurdish ? 'لینک' 
                                        : 'URL',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: !useFileUpload ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: lang.currentLanguage == AppLanguage.arabic ? 'عنوان الكتاب *' 
                          : lang.currentLanguage == AppLanguage.kurdish ? 'ناوی کتێب *' 
                          : 'Book Title *',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                      prefixIcon: Icon(Icons.title, color: isDark ? Colors.white38 : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Author
                  TextField(
                    controller: authorController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: lang.currentLanguage == AppLanguage.arabic ? 'المؤلف' 
                          : lang.currentLanguage == AppLanguage.kurdish ? 'نووسەر' 
                          : 'Author',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                      prefixIcon: Icon(Icons.person, color: isDark ? Colors.white38 : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Category
                  Consumer<LibraryService>(
                    builder: (context, libraryService, child) {
                      return DropdownButtonFormField<String>(
                        value: selectedCategoryId,
                        dropdownColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                        decoration: InputDecoration(
                          labelText: lang.currentLanguage == AppLanguage.arabic ? 'القسم *' 
                              : lang.currentLanguage == AppLanguage.kurdish ? 'پۆل *' 
                              : 'Category *',
                          labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                          prefixIcon: Icon(Icons.folder, color: isDark ? Colors.white38 : Colors.grey),
                        ),
                        items: libraryService.categories.map((cat) => DropdownMenuItem(
                          value: cat.id,
                          child: Text(cat.getName(languageCode), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        )).toList(),
                        onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  if (useFileUpload) ...[
                    // PDF File Picker
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: pdfBytes != null ? const Color(0xFF4CAF50) : Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                        color: pdfBytes != null ? const Color(0xFF4CAF50).withOpacity(0.1) : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pdfBytes != null ? Icons.check_circle : Icons.picture_as_pdf,
                            color: pdfBytes != null ? const Color(0xFF4CAF50) : Colors.red[400],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.currentLanguage == AppLanguage.arabic ? 'ملف PDF *' 
                                      : lang.currentLanguage == AppLanguage.kurdish ? 'فایلی PDF *' 
                                      : 'PDF File *',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (pdfFileName != null)
                                  Text(
                                    pdfFileName!,
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf'],
                                  withData: true,
                                );
                                if (result != null && result.files.single.bytes != null) {
                                  setDialogState(() {
                                    pdfBytes = result.files.single.bytes;
                                    pdfFileName = result.files.single.name;
                                  });
                                }
                              },
                              child: Text(
                                pdfBytes != null 
                                    ? (lang.currentLanguage == AppLanguage.arabic ? 'تغيير' : lang.currentLanguage == AppLanguage.kurdish ? 'گۆڕین' : 'Change')
                                    : (lang.currentLanguage == AppLanguage.arabic ? 'اختيار' : lang.currentLanguage == AppLanguage.kurdish ? 'هەڵبژێرە' : 'Choose'),
                                style: const TextStyle(color: Color(0xFF4CAF50)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Cover Image Picker
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: coverBytes != null ? const Color(0xFF0D9488) : Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                        color: coverBytes != null ? const Color(0xFF0D9488).withOpacity(0.1) : null,
                      ),
                      child: Row(
                        children: [
                          if (coverBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(coverBytes!, width: 40, height: 50, fit: BoxFit.cover),
                            )
                          else
                            Icon(Icons.image, color: const Color(0xFF0D9488)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.currentLanguage == AppLanguage.arabic ? 'صورة الغلاف' 
                                      : lang.currentLanguage == AppLanguage.kurdish ? 'وێنەی بەرگ' 
                                      : 'Cover Image',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (coverFileName != null)
                                  Text(
                                    coverFileName!,
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else
                                  Text(
                                    lang.currentLanguage == AppLanguage.arabic ? '(اختياري)' 
                                        : lang.currentLanguage == AppLanguage.kurdish ? '(ئیختیاری)' 
                                        : '(Optional)',
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                  withData: true,
                                );
                                if (result != null && result.files.single.bytes != null) {
                                  setDialogState(() {
                                    coverBytes = result.files.single.bytes;
                                    coverFileName = result.files.single.name;
                                  });
                                }
                              },
                              child: Text(
                                coverBytes != null 
                                    ? (lang.currentLanguage == AppLanguage.arabic ? 'تغيير' : lang.currentLanguage == AppLanguage.kurdish ? 'گۆڕین' : 'Change')
                                    : (lang.currentLanguage == AppLanguage.arabic ? 'اختيار' : lang.currentLanguage == AppLanguage.kurdish ? 'هەڵبژێرە' : 'Choose'),
                                style: const TextStyle(color: Color(0xFF0D9488)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // URL Mode Info box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF0D9488), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang.currentLanguage == AppLanguage.arabic 
                                  ? 'ارفع الملفات إلى Google Drive واحصل على رابط المشاركة'
                                  : lang.currentLanguage == AppLanguage.kurdish 
                                      ? 'فایلەکان ئەپڵۆد بکە بۆ Google Drive و لینکەکەی بخەرەوە'
                                      : 'Upload files to Google Drive and paste the link',
                              style: lang.getTextStyle(fontSize: 12, color: const Color(0xFF0D9488)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // PDF URL
                    TextField(
                      controller: pdfUrlController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: lang.currentLanguage == AppLanguage.arabic ? 'رابط PDF / داونلود *' 
                            : lang.currentLanguage == AppLanguage.kurdish ? 'لینکی PDF / داونلۆد *' 
                            : 'PDF / Download Link *',
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                        prefixIcon: Icon(Icons.link, color: Colors.red[400]),
                        hintText: 'https://drive.google.com/...',
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Cover URL
                    TextField(
                      controller: coverUrlController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: lang.currentLanguage == AppLanguage.arabic ? 'رابط صورة الغلاف' 
                            : lang.currentLanguage == AppLanguage.kurdish ? 'لینکی وێنەی بەرگ' 
                            : 'Cover Image Link',
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                        prefixIcon: Icon(Icons.image, color: const Color(0xFF0D9488)),
                        hintText: 'https://...',
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Download URL (MediaFire, etc.)
                    TextField(
                      controller: downloadUrlController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: lang.currentLanguage == AppLanguage.arabic ? 'رابط التنزيل (MediaFire)' 
                            : lang.currentLanguage == AppLanguage.kurdish ? 'لینکی داوەنلۆد (MediaFire)' 
                            : 'Download Link (MediaFire)',
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                        prefixIcon: Icon(Icons.download, color: Colors.orange),
                        hintText: 'https://www.mediafire.com/...',
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isAdding ? null : () => Navigator.pop(ctx),
                child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
                onPressed: isAdding || titleController.text.isEmpty || selectedCategoryId == null || 
                    (useFileUpload ? pdfBytes == null : pdfUrlController.text.isEmpty)
                    ? null
                    : () async {
                        setDialogState(() => isAdding = true);
                        
                        final libraryService = Provider.of<LibraryService>(context, listen: false);
                        bool success = false;
                        
                        if (useFileUpload) {
                          // Upload files to Cloudflare R2
                          success = await libraryService.addBookWithFiles(
                            title: titleController.text,
                            author: authorController.text,
                            categoryId: selectedCategoryId!,
                            pdfBytes: pdfBytes,
                            pdfFileName: pdfFileName,
                            coverBytes: coverBytes,
                            coverFileName: coverFileName,
                          );
                        } else {
                          // Use URLs directly
                          success = await libraryService.addBook(
                            title: titleController.text,
                            author: authorController.text,
                            categoryId: selectedCategoryId!,
                            pdfUrl: pdfUrlController.text.trim(),
                            coverUrl: coverUrlController.text.isNotEmpty ? coverUrlController.text.trim() : null,
                            downloadUrl: downloadUrlController.text.isNotEmpty ? downloadUrlController.text.trim() : null,
                          );
                        }

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success 
                                  ? (lang.currentLanguage == AppLanguage.arabic ? 'تمت الإضافة بنجاح!' : 'بە سەرکەوتوویی زیادکرا!')
                                  : (lang.currentLanguage == AppLanguage.arabic ? 'حدث خطأ' : 'هەڵەیەک ڕوویدا')),
                              backgroundColor: success ? const Color(0xFF4CAF50) : Colors.red,
                            ),
                          );
                        }
                      },
                child: isAdding
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        lang.currentLanguage == AppLanguage.arabic ? 'إضافة' 
                            : lang.currentLanguage == AppLanguage.kurdish ? 'زیادکردن' 
                            : 'Add',
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }




  void _confirmDeleteCategory(BookCategory category, LanguageService lang, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: lang.textDirection,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            lang.currentLanguage == AppLanguage.arabic ? 'حذف القسم' 
                : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوەی پۆل' 
                : 'Delete Category',
            style: lang.getTextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                await Provider.of<LibraryService>(this.context, listen: false).deleteCategory(category.id);
              },
              child: Text(
                lang.currentLanguage == AppLanguage.arabic ? 'حذف' 
                    : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوە' 
                    : 'Delete',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteBook(Book book, LanguageService lang, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: lang.textDirection,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_forever, color: Colors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lang.currentLanguage == AppLanguage.arabic ? 'حذف الكتاب' 
                      : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوەی کتێب' 
                      : 'Delete Book',
                  style: lang.getTextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.currentLanguage == AppLanguage.arabic 
                    ? 'هل أنت متأكد من حذف هذا الكتاب؟' 
                    : lang.currentLanguage == AppLanguage.kurdish 
                        ? 'دڵنیایت لە سڕینەوەی ئەم کتێبە؟' 
                        : 'Are you sure you want to delete this book?',
                style: lang.getTextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  book.title,
                  style: lang.getTextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                _performDeleteBook(book.id, lang);
              },
              icon: const Icon(Icons.delete, color: Colors.white, size: 18),
              label: Text(
                lang.currentLanguage == AppLanguage.arabic ? 'حذف' 
                    : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوە' 
                    : 'Delete',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performDeleteBook(String bookId, LanguageService lang) async {
    debugPrint('🗑️ Starting delete for book: $bookId');
    
    try {
      final libraryService = Provider.of<LibraryService>(context, listen: false);
      debugPrint('🗑️ Calling deleteBook...');
      
      final success = await libraryService.deleteBook(bookId);
      debugPrint('🗑️ Delete result: $success');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(success ? Icons.check_circle : Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  success 
                      ? (lang.currentLanguage == AppLanguage.arabic ? 'تم الحذف بنجاح!' : lang.currentLanguage == AppLanguage.kurdish ? 'بە سەرکەوتوویی سڕایەوە!' : 'Deleted successfully!')
                      : (lang.currentLanguage == AppLanguage.arabic ? 'فشل الحذف' : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوە سەرکەوتوو نەبوو' : 'Delete failed'),
                ),
              ],
            ),
            backgroundColor: success ? const Color(0xFF4CAF50) : Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Delete all books confirmation dialog
  void _confirmDeleteAllBooks(LanguageService lang, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: lang.textDirection,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_sweep, color: Colors.red, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lang.currentLanguage == AppLanguage.arabic ? 'حذف جميع الكتب' 
                      : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوەی هەموو کتێبەکان' 
                      : 'Delete All Books',
                  style: lang.getTextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            lang.currentLanguage == AppLanguage.arabic 
                ? '⚠️ هل أنت متأكد من حذف جميع الكتب؟ لا يمكن التراجع عن هذا!' 
                : lang.currentLanguage == AppLanguage.kurdish 
                    ? '⚠️ دڵنیایت لە سڕینەوەی هەموو کتێبەکان؟ ناتوانرێت بگەڕێنرێتەوە!' 
                    : '⚠️ Are you sure you want to delete ALL books? This cannot be undone!',
            style: lang.getTextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        const SizedBox(width: 16),
                        Text(lang.currentLanguage == AppLanguage.arabic ? 'جاري الحذف...' : lang.currentLanguage == AppLanguage.kurdish ? 'دەسڕێتەوە...' : 'Deleting...'),
                      ],
                    ),
                    duration: const Duration(seconds: 30),
                    backgroundColor: Colors.orange,
                  ),
                );
                
                final libraryService = Provider.of<LibraryService>(context, listen: false);
                final success = await libraryService.deleteAllBooks();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(success ? Icons.check_circle : Icons.error, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            success 
                                ? (lang.currentLanguage == AppLanguage.arabic ? 'تم حذف جميع الكتب!' : lang.currentLanguage == AppLanguage.kurdish ? 'هەموو کتێبەکان سڕانەوە!' : 'All books deleted!')
                                : (lang.currentLanguage == AppLanguage.arabic ? 'فشل الحذف' : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوە سەرکەوتوو نەبوو' : 'Delete failed'),
                          ),
                        ],
                      ),
                      backgroundColor: success ? const Color(0xFF4CAF50) : Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: Text(
                lang.currentLanguage == AppLanguage.arabic ? 'حذف الكل' 
                    : lang.currentLanguage == AppLanguage.kurdish ? 'سڕینەوەی هەموو' 
                    : 'Delete All',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showEditCategoryDialog(BookCategory category, LanguageService lang, bool isDark) {
    final arController = TextEditingController(text: category.nameAr);
    final kuController = TextEditingController(text: category.nameKu);
    final enController = TextEditingController(text: category.nameEn);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: lang.textDirection,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Color(0xFF0D9488)),
              ),
              const SizedBox(width: 12),
              Text(
                lang.currentLanguage == AppLanguage.arabic ? 'تعديل القسم' 
                    : lang.currentLanguage == AppLanguage.kurdish ? 'دەستکاریکردنی پۆل' 
                    : 'Edit Category',
                style: lang.getTextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: arController,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'العربية',
                  labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                  prefixIcon: const Icon(Icons.translate, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kuController,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'کوردی',
                  labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                  prefixIcon: const Icon(Icons.translate, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: enController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'English',
                  labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                  prefixIcon: const Icon(Icons.translate, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
              onPressed: () async {
                if (arController.text.isNotEmpty || kuController.text.isNotEmpty || enController.text.isNotEmpty) {
                  Navigator.pop(ctx);
                  await Provider.of<LibraryService>(this.context, listen: false).updateCategory(
                    category.id,
                    arController.text,
                    kuController.text,
                    enController.text,
                  );
                }
              },
              child: Text(
                lang.currentLanguage == AppLanguage.arabic ? 'حفظ' 
                    : lang.currentLanguage == AppLanguage.kurdish ? 'خەزنکردن' 
                    : 'Save',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Book Dialog
  void _showEditBookDialog(Book book, LanguageService lang, bool isDark, String languageCode) {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author);
    final pdfUrlController = TextEditingController(text: book.pdfUrl);
    final coverUrlController = TextEditingController(text: book.coverUrl ?? '');
    final downloadUrlController = TextEditingController(text: book.downloadUrl ?? '');
    String? selectedCategoryId = book.categoryId;
    final libraryService = Provider.of<LibraryService>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: lang.textDirection,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit, color: Color(0xFF4CAF50)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.currentLanguage == AppLanguage.arabic ? 'تعديل الكتاب' 
                        : lang.currentLanguage == AppLanguage.kurdish ? 'دەستکاریکردنی کتێب' 
                        : 'Edit Book',
                    style: lang.getTextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: lang.currentLanguage == AppLanguage.arabic ? 'عنوان الكتاب *' 
                          : lang.currentLanguage == AppLanguage.kurdish ? 'ناوی کتێب *' 
                          : 'Book Title *',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: authorController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: lang.currentLanguage == AppLanguage.arabic ? 'المؤلف' 
                          : lang.currentLanguage == AppLanguage.kurdish ? 'نووسەر' 
                          : 'Author',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategoryId,
                    dropdownColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: lang.currentLanguage == AppLanguage.arabic ? 'القسم *' 
                          : lang.currentLanguage == AppLanguage.kurdish ? 'پۆل *' 
                          : 'Category *',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                    ),
                    items: libraryService.categories.map((cat) => DropdownMenuItem(
                      value: cat.id,
                      child: Text(cat.getName(languageCode)),
                    )).toList(),
                    onChanged: (value) => setDialogState(() => selectedCategoryId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pdfUrlController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: lang.currentLanguage == AppLanguage.arabic ? 'رابط PDF *' 
                          : lang.currentLanguage == AppLanguage.kurdish ? 'لینکی PDF *' 
                          : 'PDF URL *',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: coverUrlController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: lang.currentLanguage == AppLanguage.arabic ? 'رابط الغلاف' 
                          : lang.currentLanguage == AppLanguage.kurdish ? 'لینکی بەرگ' 
                          : 'Cover URL',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: downloadUrlController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: lang.currentLanguage == AppLanguage.arabic ? 'رابط التنزيل (MediaFire)' 
                          : lang.currentLanguage == AppLanguage.kurdish ? 'لینکی داوەنلۆد (MediaFire)' 
                          : 'Download URL (MediaFire)',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                      prefixIcon: Icon(Icons.download, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(lang.cancel, style: lang.getTextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
                onPressed: () async {
                  if (titleController.text.isNotEmpty && pdfUrlController.text.isNotEmpty && selectedCategoryId != null) {
                    Navigator.pop(ctx);
                    await Provider.of<LibraryService>(this.context, listen: false).updateBook(
                      book.id,
                      titleController.text,
                      authorController.text,
                      selectedCategoryId!,
                      pdfUrlController.text,
                      coverUrlController.text.isNotEmpty ? coverUrlController.text : null,
                      downloadUrlController.text.isNotEmpty ? downloadUrlController.text : null,
                    );
                  }
                },
                child: Text(
                  lang.currentLanguage == AppLanguage.arabic ? 'حفظ' 
                      : lang.currentLanguage == AppLanguage.kurdish ? 'خەزنکردن' 
                      : 'Save',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


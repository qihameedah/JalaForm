// lib/services/web_pdf_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;


class WebPdfService {
  static final WebPdfService _instance = WebPdfService._internal();
  bool _initialized = false;
  pw.Font? arabicFont;
  pw.Font? arabicFontBold;

  // Professional color scheme (matching mobile)
  final PdfColor primaryColor = PdfColors.blue800;
  final PdfColor accentColor = PdfColors.orange600;
  final PdfColor textColor = PdfColors.grey800;
  final PdfColor lightGrey = PdfColors.grey300;
  final PdfColor backgroundColor = PdfColors.grey50;

  factory WebPdfService() {
    return _instance;
  }

  WebPdfService._internal();

  // Check if Arabic fonts are available
  bool get hasArabicSupport => _initialized && arabicFont != null;

  // Get current initialization status
  bool get isInitialized => _initialized;

  // Initialize with proper Arabic font support
  Future<void> _initialize() async {
    if (_initialized) return;

    try {
      // Load Arabic fonts - using Noto Sans Arabic which has excellent shaping
      final regularFontData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      arabicFont = pw.Font.ttf(regularFontData);

      // Try to load bold font, fallback to regular if not available
      try {
        final boldFontData =
            await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
        arabicFontBold = pw.Font.ttf(boldFontData);
      } catch (e) {
        debugPrint('Bold Arabic font not found, using regular font');
        arabicFontBold = arabicFont;
      }

      _initialized = true;
      debugPrint('Arabic fonts loaded successfully for web');
    } catch (e) {
      debugPrint('Error loading Arabic fonts for web: $e');
      // Try alternative font names
      try {
        final fontData = await rootBundle.load('assets/fonts/arabic.ttf');
        arabicFont = pw.Font.ttf(fontData);
        arabicFontBold = arabicFont;
        _initialized = true;
        debugPrint('Alternative Arabic font loaded successfully for web');
      } catch (e2) {
        debugPrint('Failed to load any Arabic font for web: $e2');
        // Set to null to indicate no Arabic font available
        arabicFont = null;
        arabicFontBold = null;
        _initialized = false;
      }
    }
  }

  // Enhanced Arabic text detection
  bool _isArabicText(String text) {
    if (text.isEmpty) return false;

    int arabicChars = 0;
    int totalChars = 0;

    for (int rune in text.runes) {
      if (rune >= 32) {
        // Skip control characters
        totalChars++;
        if ((rune >= 0x0600 && rune <= 0x06FF) || // Arabic
            (rune >= 0x0750 && rune <= 0x077F) || // Arabic Supplement
            (rune >= 0x08A0 && rune <= 0x08FF) || // Arabic Extended-A
            (rune >= 0xFB50 && rune <= 0xFDFF) || // Arabic Presentation Forms-A
            (rune >= 0xFE70 && rune <= 0xFEFF)) {
          // Arabic Presentation Forms-B
          arabicChars++;
        }
      }
    }

    return totalChars > 0 &&
        (arabicChars / totalChars) > 0.2; // 20% threshold for mixed content
  }

  // Create properly shaped Arabic text widget
  pw.Widget _createArabicText({
    required String text,
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
    bool isBold = false,
    bool forceRtl = false,
  }) {
    final isArabic = _isArabicText(text) || forceRtl;

    // Determine text alignment
    pw.TextAlign finalAlign;
    if (textAlign != null) {
      finalAlign = textAlign;
    } else if (isArabic) {
      finalAlign = pw.TextAlign.right;
    } else {
      finalAlign = pw.TextAlign.left;
    }

    // Choose appropriate font
    pw.Font? selectedFont;
    if (_initialized && isArabic && arabicFont != null) {
      selectedFont =
          isBold && arabicFontBold != null ? arabicFontBold! : arabicFont!;
    }

    // For Arabic text, we need to ensure the string is in logical order
    // The font should handle the visual shaping
    String displayText = text;

    return pw.Text(
      displayText,
      style: (style ?? pw.TextStyle()).copyWith(
        font: selectedFont,
        fontWeight: isBold ? pw.FontWeight.bold : null,
      ),
      textAlign: finalAlign,
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    );
  }

  // Create bilingual text with proper direction
  pw.Widget _createBilingualText({
    required String arabicText,
    required String englishText,
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
    bool isBold = false,
  }) {
    // Use Arabic text if fonts are available, otherwise fall back to English
    final displayText = hasArabicSupport ? arabicText : englishText;
    return _createArabicText(
      text: displayText,
      style: style,
      textAlign: textAlign,
      isBold: isBold,
      forceRtl: hasArabicSupport,
    );
  }

  // Create RTL-aware row for Arabic content
  pw.Widget _createDirectionalRow({
    required String referenceText,
    required List<pw.Widget> children,
    pw.MainAxisAlignment? mainAxisAlignment,
    pw.CrossAxisAlignment? crossAxisAlignment,
  }) {
    final isArabic = _isArabicText(referenceText);

    // For RTL languages, we need to reverse the children and use right alignment
    final effectiveChildren = isArabic ? children.reversed.toList() : children;
    final effectiveAlignment = isArabic
        ? (mainAxisAlignment ?? pw.MainAxisAlignment.end)
        : (mainAxisAlignment ?? pw.MainAxisAlignment.start);

    return pw.Row(
      mainAxisAlignment: effectiveAlignment,
      crossAxisAlignment: crossAxisAlignment ?? pw.CrossAxisAlignment.center,
      children: effectiveChildren,
    );
  }

  // Get field type icon color
  PdfColor _getIconColor(dynamic fieldType) {
    String typeStr = fieldType.toString().toLowerCase();

    if (typeStr.contains('text')) return primaryColor;
    if (typeStr.contains('email')) return PdfColors.green600;
    if (typeStr.contains('number')) return PdfColors.purple600;
    if (typeStr.contains('multiline')) return PdfColors.blue500;
    if (typeStr.contains('dropdown')) return PdfColors.teal600;
    if (typeStr.contains('radio')) return PdfColors.brown600;
    if (typeStr.contains('date')) return PdfColors.red600;
    if (typeStr.contains('time')) return PdfColors.deepOrange600;
    if (typeStr.contains('likert')) return PdfColors.purple700;
    if (typeStr.contains('checkbox')) return PdfColors.indigo600;
    if (typeStr.contains('image')) return PdfColors.cyan600;

    return accentColor;
  }

  // Get field type icon text
  String _getIconText(dynamic fieldType) {
    String typeStr = fieldType.toString().toLowerCase();

    if (typeStr.contains('text')) return 'T';
    if (typeStr.contains('email')) return '@';
    if (typeStr.contains('number')) return '#';
    if (typeStr.contains('multiline')) return 'P';
    if (typeStr.contains('dropdown')) return 'D';
    if (typeStr.contains('radio')) return 'R';
    if (typeStr.contains('date')) return 'D';
    if (typeStr.contains('time')) return 'T';
    if (typeStr.contains('likert')) return 'L';
    if (typeStr.contains('checkbox')) return 'C';
    if (typeStr.contains('image')) return 'I';

    return '?';
  }

  // Field type checkers
  bool _isImageField(dynamic fieldType) {
    return fieldType.toString().toLowerCase().contains('image');
  }

  bool _isLikertField(dynamic fieldType) {
    return fieldType.toString().toLowerCase().contains('likert');
  }

  bool _isCheckboxField(dynamic fieldType) {
    return fieldType.toString().toLowerCase().contains('checkbox');
  }

  // Safe field property getters
  String _getFieldLabel(dynamic field) {
    try {
      return field.label?.toString() ??
          field.title?.toString() ??
          field.name?.toString() ??
          'Untitled Field';
    } catch (e) {
      return 'Untitled Field';
    }
  }

  String _getFieldId(dynamic field) {
    try {
      return field.id?.toString() ??
          field.fieldId?.toString() ??
          field.name?.toString() ??
          '';
    } catch (e) {
      return '';
    }
  }

  dynamic _getFieldType(dynamic field) {
    try {
      return field.type ?? field.fieldType ?? 'text';
    } catch (e) {
      return 'text';
    }
  }

  List<String> _getFieldOptions(dynamic field) {
    try {
      if (field.options != null) {
        return List<String>.from(field.options);
      }
      if (field.choices != null) {
        return List<String>.from(field.choices);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  List<String> _getLikertQuestions(dynamic field) {
    try {
      if (field.likertQuestions != null) {
        return List<String>.from(field.likertQuestions);
      }
      if (field.questions != null) {
        return List<String>.from(field.questions);
      }
      if (field.subFields != null) {
        return List<String>.from(field.subFields);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Format date with Arabic support
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  // Generate and download PDF (main method)
  Future<void> generateAndDownloadPdf(
      CustomForm form, FormResponse response) async {
    try {
      await _initialize();
      debugPrint(
          'Web PDF Service initialized: $_initialized, Arabic support: $hasArabicSupport');
    } catch (e) {
      debugPrint('Error during web PDF service initialization: $e');
    }

    final pdf = pw.Document();

    // Create theme with proper font handling
    final theme = _initialized && arabicFont != null
        ? pw.ThemeData.withFont(
            base: arabicFont!,
            bold: arabicFontBold ?? arabicFont!,
            italic: arabicFont!,
            boldItalic: arabicFontBold ?? arabicFont!,
          )
        : pw.ThemeData.base();

    try {
      // Add cover page
      _addEnhancedCoverPage(pdf, form, response, theme);

      // Add content pages
      await _addEnhancedContentPages(pdf, form, response, theme);

      // Add image pages
      await _addEnhancedImagePages(pdf, form, response, theme);

      // Generate PDF bytes and download
      final pdfBytes = await pdf.save();
      await _downloadPdfInBrowser(
          pdfBytes, form.title, response.id);

      debugPrint('Web PDF generated and download initiated successfully');
    } catch (e) {
      debugPrint('Error generating web PDF content: $e');
      rethrow;
    }
  }

  // Download PDF in browser
  Future<void> _downloadPdfInBrowser(
      Uint8List pdfBytes, String formTitle, String responseId) async {
    try {
      // Create blob from bytes
      final blob = html.Blob([pdfBytes], 'application/pdf');

      // Create URL for the blob
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Create filename
      final fileName =
          '${formTitle.replaceAll(' ', '_')}_response_${responseId.length > 8 ? responseId.substring(0, 8) : responseId}.pdf';

      // Create anchor element with download attribute
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();

      // Clean up
      html.Url.revokeObjectUrl(url);

      debugPrint('PDF download initiated: $fileName');
    } catch (e) {
      debugPrint('Error downloading PDF: $e');
      rethrow;
    }
  }

  // ENHANCED COVER PAGE WITH PROPER ARABIC SUPPORT
  void _addEnhancedCoverPage(pw.Document pdf, CustomForm form,
      FormResponse response, pw.ThemeData theme) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header section with proper Arabic support
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  children: [
                    // App icon
                    pw.Container(
                      height: 60,
                      width: 60,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        shape: pw.BoxShape.circle,
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'F',
                        style: pw.TextStyle(
                          fontSize: 28,
                          color: primaryColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 20),

                    // Form title with proper Arabic rendering
                    _createArabicText(
                      text: form.title ?? 'نموذج بلا عنوان',
                      style: pw.TextStyle(
                        fontSize: 22,
                        color: PdfColors.white,
                      ),
                      textAlign: pw.TextAlign.center,
                      isBold: true,
                      forceRtl: true,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 40),

              // Metadata section with Arabic support
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  color: backgroundColor,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: lightGrey),
                ),
                child: pw.Column(
                  children: [
                    // Submission date
                    _createEnhancedMetadataRow(
                      icon: 'D',
                      iconColor: PdfColors.green600,
                      labelEn: 'Submission Date',
                      labelAr: 'تاريخ الإرسال',
                      value:
                          _formatDate(response.submitted_at ?? DateTime.now()),
                    ),

                    pw.SizedBox(height: 16),

                    // Response ID
                    _createEnhancedMetadataRow(
                      icon: 'ID',
                      iconColor: PdfColors.blue600,
                      labelEn: 'Response ID',
                      labelAr: 'معرف الاستجابة',
                      value: (response.id ?? 'N/A').length > 12
                          ? '${response.id.substring(0, 12)}...'
                          : response.id ?? 'N/A',
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer with bilingual support
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12),
                child: _createArabicText(
                  text: 'تم إنشاؤه بواسطة تطبيق منشئ النماذج',
                  style: pw.TextStyle(
                    color: PdfColors.grey500,
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                  forceRtl: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Enhanced metadata row with bilingual support
  pw.Widget _createEnhancedMetadataRow({
    required String icon,
    required PdfColor iconColor,
    required String labelEn,
    required String labelAr,
    required String value,
  }) {
    return _createDirectionalRow(
      referenceText: labelAr,
      children: [
        pw.Container(
          width: 32,
          height: 32,
          decoration: pw.BoxDecoration(
            color: iconColor,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            icon,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _createBilingualText(
                arabicText: '$labelAr: ',
                englishText: '$labelEn: ',
                style: pw.TextStyle(
                  fontSize: 13,
                  color: textColor,
                ),
                isBold: true,
              ),
              pw.SizedBox(height: 2),
              _createArabicText(
                text: value,
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ENHANCED CONTENT PAGES WITH PROPER ARABIC SUPPORT
  Future<void> _addEnhancedContentPages(pw.Document pdf, CustomForm form,
      FormResponse response, pw.ThemeData theme) async {
    final List<pw.Widget> contentWidgets = [];

    // Enhanced header with Arabic support
    contentWidgets.add(
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        margin: const pw.EdgeInsets.only(bottom: 24),
        decoration: pw.BoxDecoration(
          color: primaryColor,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: _createArabicText(
          text: form.title ?? 'استجابة النموذج',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 18,
          ),
          textAlign: pw.TextAlign.center,
          isBold: true,
          forceRtl: true,
        ),
      ),
    );

    // Process fields with enhanced Arabic support
    for (var field in form.fields) {
      if (_isImageField(_getFieldType(field))) continue;

      String fieldId = _getFieldId(field);
      dynamic value = response.responses[fieldId];

      // Handle different field types
      if (_isLikertField(_getFieldType(field)) && value is Map) {
        Map<String, dynamic> likertMap = Map<String, dynamic>.from(value);
        contentWidgets.add(_createEnhancedLikertField(field, likertMap));
      } else if (_isCheckboxField(_getFieldType(field)) && value is List) {
        contentWidgets.add(
            _createEnhancedCheckboxField(field, List<String>.from(value)));
      } else {
        contentWidgets.add(_createEnhancedRegularField(field, value));
      }

      contentWidgets.add(pw.SizedBox(height: 16));
    }
  
    if (contentWidgets.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          theme: theme,
          build: (pw.Context context) => contentWidgets,
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(top: 12),
              child: _createBilingualText(
                arabicText:
                    'صفحة ${context.pageNumber} من ${context.pagesCount}',
                englishText:
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(
                  color: PdfColors.grey500,
                  fontSize: 9,
                ),
              ),
            );
          },
        ),
      );
    }
  }

  // Enhanced regular field with proper Arabic support
  pw.Widget _createEnhancedRegularField(dynamic field, dynamic value) {
    final fieldLabel = _getFieldLabel(field);
    final fieldType = _getFieldType(field);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: backgroundColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: lightGrey),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Question header with proper direction
          _createDirectionalRow(
            referenceText: fieldLabel,
            children: [
              pw.Container(
                width: 24,
                height: 24,
                decoration: pw.BoxDecoration(
                  color: _getIconColor(fieldType),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  _getIconText(fieldType),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _createArabicText(
                  text: fieldLabel,
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                  isBold: true,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 12),

          // Answer with proper Arabic support
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            margin: const pw.EdgeInsets.only(left: 36),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: _createArabicText(
              text: value?.toString() ?? 'لم يتم تقديم إجابة',
              style: pw.TextStyle(
                fontSize: 13,
                color: PdfColors.grey700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced checkbox field
  pw.Widget _createEnhancedCheckboxField(
      dynamic field, List<String> selectedOptions) {
    final fieldLabel = _getFieldLabel(field);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: backgroundColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: lightGrey),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Question header
          _createDirectionalRow(
            referenceText: fieldLabel,
            children: [
              pw.Container(
                width: 24,
                height: 24,
                decoration: pw.BoxDecoration(
                  color: _getIconColor(_getFieldType(field)),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  _getIconText(_getFieldType(field)),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _createArabicText(
                  text: fieldLabel,
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                  isBold: true,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 12),

          // Selected options with proper Arabic support
          ...selectedOptions.map((option) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6, left: 36),
                child: _createDirectionalRow(
                  referenceText: option,
                  children: [
                    pw.Container(
                      width: 14,
                      height: 14,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green600,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        '✓',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: _createArabicText(
                        text: option,
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // Enhanced Likert field (NEW - matching mobile implementation)
  pw.Widget _createEnhancedLikertField(
      dynamic field, Map<String, dynamic> likertResponses) {
    final questions = _getLikertQuestions(field);
    final options = _getFieldOptions(field);
    final fieldLabel = _getFieldLabel(field);

    // Parse options
    final Map<String, String> optionLabels = {};
    for (String option in options) {
      if (option.contains('|')) {
        final parts = option.split('|');
        optionLabels[parts.length > 1 ? parts[1] : parts[0]] = parts[0];
      } else {
        optionLabels[option] = option;
      }
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.purple50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.purple200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Likert header with Arabic support
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.purple700,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: _createDirectionalRow(
              referenceText: fieldLabel,
              children: [
                pw.Container(
                  width: 24,
                  height: 24,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'L',
                    style: pw.TextStyle(
                      color: PdfColors.purple700,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _createArabicText(
                    text: fieldLabel,
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                    ),
                    isBold: true,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // Questions and answers with Arabic support
          ...questions.asMap().entries.map((entry) {
            final questionIndex = entry.key;
            final question = entry.value;
            final selectedValue = likertResponses[questionIndex.toString()];
            final selectedLabel = selectedValue != null
                ? (optionLabels[selectedValue.toString()] ??
                    selectedValue.toString())
                : 'لم يتم الإجابة';

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.purple200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Question with proper direction
                  _createDirectionalRow(
                    referenceText: question,
                    children: [
                      pw.Container(
                        width: 18,
                        height: 18,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.purple600,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          '${questionIndex + 1}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: _createArabicText(
                          text: question,
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: textColor,
                          ),
                          isBold: true,
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 6),

                  // Answer with Arabic support
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 6, horizontal: 8),
                    margin: const pw.EdgeInsets.only(left: 26),
                    decoration: pw.BoxDecoration(
                      color: selectedValue != null
                          ? PdfColors.purple100
                          : PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: _createArabicText(
                      text: selectedLabel,
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: selectedValue != null
                            ? PdfColors.purple800
                            : PdfColors.grey600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ENHANCED IMAGE PAGES
  Future<void> _addEnhancedImagePages(pw.Document pdf, CustomForm form,
      FormResponse response, pw.ThemeData theme) async {
    for (var field in form.fields) {
      if (_isImageField(_getFieldType(field))) {
        String fieldId = _getFieldId(field);
        dynamic value = response.responses[fieldId];

        if (value != null && value.toString().isNotEmpty) {
          try {
            var imgData = await _getImageDataFromUrl(value.toString());
            if (imgData != null) {
              final image = pw.MemoryImage(imgData);
              final fieldLabel = _getFieldLabel(field);

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  margin: const pw.EdgeInsets.all(20),
                  theme: theme,
                  build: (context) {
                    return pw.Column(
                      children: [
                        // Enhanced header with Arabic support
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: _createDirectionalRow(
                            referenceText: fieldLabel,
                            children: [
                              pw.Container(
                                width: 24,
                                height: 24,
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius: pw.BorderRadius.circular(6),
                                ),
                                alignment: pw.Alignment.center,
                                child: pw.Text(
                                  'I',
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              pw.SizedBox(width: 12),
                              pw.Expanded(
                                child: _createArabicText(
                                  text: fieldLabel,
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 14,
                                  ),
                                  isBold: true,
                                ),
                              ),
                            ],
                          ),
                        ),

                        pw.SizedBox(height: 20),

                        // Image container
                        pw.Expanded(
                          child: pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(16),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(8),
                              border: pw.Border.all(color: lightGrey),
                            ),
                            child: pw.Center(
                              child: pw.Image(
                                image,
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                          ),
                        ),

                        pw.SizedBox(height: 12),

                        // Footer with bilingual support
                        _createBilingualText(
                          arabicText: 'استجابة الصورة',
                          englishText: 'Image Response',
                          style: pw.TextStyle(
                            color: PdfColors.grey500,
                            fontSize: 10,
                            fontStyle: pw.FontStyle.italic,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              );
            }
          } catch (e) {
            debugPrint('Error adding image page: $e');
          }
        }
      }
    }
    }

  // Helper method to get image data from URL
  Future<Uint8List?> _getImageDataFromUrl(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        debugPrint('Failed to load image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error loading image: $e');
      return null;
    }
  }
}

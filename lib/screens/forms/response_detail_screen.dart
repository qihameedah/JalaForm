import 'dart:io';

import 'package:flutter/material.dart';
import '../../models/custom_form.dart';
import '../../models/form_response.dart';
import '../../models/form_field.dart';
import '../../services/pdf_service.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class ResponseDetailScreen extends StatefulWidget {
  final CustomForm form;
  final FormResponse response;

  const ResponseDetailScreen({
    super.key,
    required this.form,
    required this.response,
  });

  @override
  State<ResponseDetailScreen> createState() => _ResponseDetailScreenState();
}

class _ResponseDetailScreenState extends State<ResponseDetailScreen> {
  final _pdfService = PdfService();
  bool _isPdfGenerating = false;

// 1. REPLACE THE BUILD METHOD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF3F51B5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Response Details',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF3F51B5),
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _isPdfGenerating ? null : _generateAndShowOptions,
              icon: Icon(
                Icons.picture_as_pdf_outlined,
                size: 18,
                color: _isPdfGenerating ? Colors.grey : const Color(0xFF5C6BC0),
              ),
              label: Text(
                'PDF',
                style: TextStyle(
                  color:
                      _isPdfGenerating ? Colors.grey : const Color(0xFF5C6BC0),
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: _isPdfGenerating
                    ? Colors.grey.withOpacity(0.1)
                    : const Color(0xFF5C6BC0).withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isPdfGenerating
          ? _buildLoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormHeader(),
                  const SizedBox(height: 20),
                  _buildResponseFields(),
                  const SizedBox(height: 24),
                  _buildGeneratePdfButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

// 7. GENERATE PDF BUTTON
  Widget _buildGeneratePdfButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: _isPdfGenerating ? null : _generateAndShowOptions,
        icon: Icon(
          Icons.picture_as_pdf_outlined,
          size: 18,
          color: _isPdfGenerating ? Colors.grey : Colors.white,
        ),
        label: Text(
          _isPdfGenerating ? 'Generating...' : 'Generate PDF',
          style: TextStyle(
            color: _isPdfGenerating ? Colors.grey : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isPdfGenerating ? Colors.grey[300] : const Color(0xFF5C6BC0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

// 8. REPLACE THE PDF OPTIONS BOTTOM SHEET
  void _showPdfOptionsBottomSheet(File pdfFile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF3F51B5).withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3F51B5).withOpacity(0.15),
              blurRadius: 25,
              offset: const Offset(0, 10),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF3F51B5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PDF Ready!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Choose what to do next',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Options
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionButton(
                    icon: Icons.visibility_outlined,
                    label: 'View',
                    color: const Color(0xFF3F51B5),
                    onTap: () {
                      Navigator.pop(context);
                      _openPdf(pdfFile);
                    },
                  ),
                  _buildOptionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    color: const Color(0xFF5C6BC0),
                    onTap: () {
                      Navigator.pop(context);
                      _sharePdf(pdfFile);
                    },
                  ),
                  _buildOptionButton(
                    icon: Icons.download_outlined,
                    label: 'Save',
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.pop(context);
                      _savePdf(pdfFile);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// 2. NEW METHOD - PDF button in app bar
  Widget _buildPdfButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isPdfGenerating ? null : _generateAndShowOptions,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: _isPdfGenerating
                  ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                  : const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isPdfGenerating
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf_rounded,
                    color: _isPdfGenerating ? Colors.white54 : Colors.white,
                    size: 16),
                const SizedBox(width: 6),
                Text(
                  'PDF',
                  style: TextStyle(
                    color: _isPdfGenerating ? Colors.white54 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// 2. LOADING STATE
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3F51B5)),
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            'Generating PDF...',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

// 4. NEW METHOD - Main content
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Form header card
          _buildFormHeaderCard(),
          const SizedBox(height: 16),

          // Response fields in a grid layout
          _buildResponseFields(),

          const SizedBox(height: 24),

          // Bottom PDF button
          _buildBottomPdfButton(),
        ],
      ),
    );
  }

// 3. FORM HEADER
  Widget _buildFormHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF3F51B5).withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3F51B5).withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F51B5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.form.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    Text(
                      'Submitted ${_formatDate(widget.response.submitted_at)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.form.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.form.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

// 5. NEW METHOD - Form header card
  Widget _buildFormHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF475569)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.form.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Submitted ${_formatDate(widget.response.submitted_at)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.form.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF475569)),
              ),
              child: Text(
                widget.form.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

// 4. RESPONSE FIELDS
  Widget _buildResponseFields() {
    return Column(
      children: widget.form.fields.asMap().entries.map((entry) {
        final index = entry.key;
        final field = entry.value;

        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 200 + (index * 50)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 10 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: _buildResponseField(field),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

// 5. SINGLE RESPONSE FIELD
  Widget _buildResponseField(FormFieldModel field) {
    final value = widget.response.responses[field.id];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF3F51B5).withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3F51B5).withOpacity(0.06),
            offset: const Offset(0, 3),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field header
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _getColorForFieldType(field.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _getIconForFieldType(field.type),
                  color: _getColorForFieldType(field.type),
                  size: 12,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  field.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE3F2FD)),
                ),
                child: Text(
                  _getFieldTypeLabel(field.type),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF5C6BC0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Response value
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF3F51B5).withOpacity(0.15), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3F51B5).withOpacity(0.03),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: _buildResponseValue(field, value),
          ),
        ],
      ),
    );
  }

// 7. UPDATED METHOD - Replace the existing _buildResponseItem method
  Widget _buildResponseFieldCard(FormFieldModel field, int index) {
    final response = widget.response.responses[field.id];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF475569)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Field header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getColorForFieldType(field.type).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _getColorForFieldType(field.type),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _getIconForFieldType(field.type),
                    color: _getColorForFieldType(field.type),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getColorForFieldType(field.type)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getFieldTypeLabel(field.type),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getColorForFieldType(field.type),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Response value
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: _buildCompactResponseValue(field, response),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactResponseValue(FormFieldModel field, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      return const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.remove_circle_outline_rounded,
                size: 16, color: Colors.white54),
            SizedBox(width: 8),
            Text(
              'No response',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    switch (field.type) {
      case FieldType.likert:
        if (value is Map) {
          final responses = Map<String, dynamic>.from(value);
          final answeredCount = responses.values.where((v) => v != null).length;
          final totalQuestions =
              field.likertQuestions?.length ?? responses.length;

          return Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getColorForFieldType(field.type)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _getColorForFieldType(field.type)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.poll_outlined,
                              size: 12,
                              color: _getColorForFieldType(field.type),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$answeredCount/$totalQuestions',
                              style: TextStyle(
                                fontSize: 11,
                                color: _getColorForFieldType(field.type),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'responses',
                        style: TextStyle(
                          fontSize: 10,
                          color: _getColorForFieldType(field.type),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        break;

      case FieldType.image:
        if (value is String && value.isNotEmpty) {
          return Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    value,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: Colors.red, size: 24),
                              SizedBox(height: 4),
                              Text(
                                'Failed to load',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        }
        break;

      case FieldType.checkbox:
        if (value is List && value.isNotEmpty) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: value
                  .map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded,
                                size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item.toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          );
        }
        break;

      case FieldType.radio:
      case FieldType.dropdown:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _getColorForFieldType(field.type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _getColorForFieldType(field.type).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                _getIconForFieldType(field.type),
                size: 14,
                color: _getColorForFieldType(field.type),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getColorForFieldType(field.type),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

      case FieldType.date:
      case FieldType.time:
      case FieldType.email:
      case FieldType.number:
        return Row(
          children: [
            Icon(
              _getIconForFieldType(field.type),
              size: 14,
              color: _getColorForFieldType(field.type),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: _getColorForFieldType(field.type),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      default:
        return SingleChildScrollView(
          child: Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        );
    }

    return Text(
      value.toString(),
      style: const TextStyle(
        fontSize: 12,
        color: Colors.white,
        height: 1.3,
      ),
    );
  }

// 9. NEW METHOD - Bottom PDF button
  Widget _buildBottomPdfButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _isPdfGenerating
            ? const LinearGradient(colors: [Colors.grey, Colors.grey])
            : const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isPdfGenerating
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isPdfGenerating ? null : _generateAndShowOptions,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 20,
                  color: _isPdfGenerating ? Colors.white54 : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _isPdfGenerating ? 'Generating...' : 'Generate PDF',
                  style: TextStyle(
                    color: _isPdfGenerating ? Colors.white54 : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponseItem(FormFieldModel field) {
    final response = widget.response.responses[field.id];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getColorForFieldType(field.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForFieldType(field.type),
                  color: _getColorForFieldType(field.type),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  field.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getFieldTypeLabel(field.type),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Response Value
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _buildResponseValue(field, response),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseValue(FormFieldModel field, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      return const Row(
        children: [
          Icon(Icons.remove_circle_outline, size: 14, color: Color(0xFF999999)),
          SizedBox(width: 8),
          Text(
            'No response provided',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF999999),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    switch (field.type) {
      case FieldType.likert:
        if (value is Map) {
          final responses = Map<String, dynamic>.from(value);
          final questions = field.likertQuestions ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.poll_outlined,
                      size: 14, color: _getColorForFieldType(field.type)),
                  const SizedBox(width: 8),
                  Text(
                    'Likert Scale Responses:',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getColorForFieldType(field.type),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getColorForFieldType(field.type).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          _getColorForFieldType(field.type).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scale info
                    if (field.likertScale != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getColorForFieldType(field.type)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${field.likertScale}-point scale',
                              style: TextStyle(
                                fontSize: 10,
                                color: _getColorForFieldType(field.type),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (field.likertStartLabel != null &&
                              field.likertEndLabel != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${field.likertStartLabel} → ${field.likertEndLabel}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF666666),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Questions and responses
                    ...questions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final question = entry.value;
                      final response = responses[index.toString()];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. $question',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (response != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getColorForFieldType(field.type)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Response: $response',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getColorForFieldType(field.type),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'No response',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF999999),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          );
        }
        break;

      case FieldType.image:
        if (value is String && value.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.image_outlined,
                      size: 14, color: Color(0xFF5C6BC0)),
                  SizedBox(width: 8),
                  Text(
                    'Image:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5C6BC0),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: double.infinity,
                  ),
                  child: Image.network(
                    value,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red, size: 20),
                              SizedBox(height: 4),
                              Text(
                                'Failed to load image',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF3F51B5)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        }
        break;

      case FieldType.checkbox:
        if (value is List && value.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_box_outlined,
                      size: 14, color: Color(0xFF4CAF50)),
                  SizedBox(width: 8),
                  Text(
                    'Selected options:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: value
                    .map((item) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color:
                                    const Color(0xFF4CAF50).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check,
                                  size: 12, color: Color(0xFF4CAF50)),
                              const SizedBox(width: 4),
                              Text(
                                item.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          );
        }
        break;

      case FieldType.radio:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.radio_button_checked,
                  size: 12, color: Color(0xFF2196F3)),
              const SizedBox(width: 6),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

      case FieldType.dropdown:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF9C27B0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_drop_down_circle_outlined,
                  size: 12, color: Color(0xFF9C27B0)),
              const SizedBox(width: 6),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9C27B0),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

      case FieldType.date:
      case FieldType.time:
      case FieldType.email:
      case FieldType.number:
        return Row(
          children: [
            Icon(
              _getIconForFieldType(field.type),
              size: 14,
              color: _getColorForFieldType(field.type),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 13,
                  color: _getColorForFieldType(field.type),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );

      default:
        return Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF333333),
            height: 1.4,
          ),
        );
    }

    return Text(
      value.toString(),
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF333333),
        height: 1.4,
      ),
    );
  }

  // Generate PDF and show options dialog
  Future<void> _generateAndShowOptions() async {
    setState(() {
      _isPdfGenerating = true;
    });

    try {
      // Generate PDF with full-page images
      final pdfFile =
          await _pdfService.generateFormResponsePdfWithFullPageImages(
        widget.form,
        widget.response,
      );

      // Show options for the PDF
      if (mounted) {
        _showPdfOptionsBottomSheet(pdfFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPdfGenerating = false;
        });
      }
    }
  }

// 11. UPDATED METHOD - Replace the existing _buildOptionButton method
  Widget _buildEnhancedOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// 9. CLEAN OPTION BUTTON
  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForFieldType(FieldType type) {
    switch (type) {
      case FieldType.text:
      case FieldType.multiline:
      case FieldType.textarea:
        return const Color(0xFF3F51B5);
      case FieldType.number:
        return const Color(0xFFFF9800);
      case FieldType.email:
        return const Color(0xFF2196F3);
      case FieldType.dropdown:
        return const Color(0xFF9C27B0);
      case FieldType.checkbox:
        return const Color(0xFF4CAF50);
      case FieldType.radio:
        return const Color(0xFF2196F3);
      case FieldType.date:
        return const Color(0xFFFF5722);
      case FieldType.time:
        return const Color(0xFF009688);
      case FieldType.image:
        return const Color(0xFFE91E63);
      case FieldType.likert:
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF5C6BC0);
    }
  }

  String _getFieldTypeLabel(FieldType type) {
    switch (type) {
      case FieldType.text:
        return 'Text';
      case FieldType.number:
        return 'Number';
      case FieldType.email:
        return 'Email';
      case FieldType.multiline:
        return 'Multiline';
      case FieldType.textarea:
        return 'Text Area';
      case FieldType.dropdown:
        return 'Dropdown';
      case FieldType.checkbox:
        return 'Checkbox';
      case FieldType.radio:
        return 'Radio';
      case FieldType.date:
        return 'Date';
      case FieldType.time:
        return 'Time';
      case FieldType.image:
        return 'Image';
      case FieldType.likert:
        return 'Likert Scale';
      default:
        return 'Field';
    }
  }

  IconData _getIconForFieldType(FieldType type) {
    switch (type) {
      case FieldType.text:
        return Icons.text_fields;
      case FieldType.number:
        return Icons.numbers;
      case FieldType.email:
        return Icons.email_outlined;
      case FieldType.multiline:
      case FieldType.textarea:
        return Icons.subject;
      case FieldType.dropdown:
        return Icons.arrow_drop_down_circle_outlined;
      case FieldType.checkbox:
        return Icons.check_box_outlined;
      case FieldType.radio:
        return Icons.radio_button_checked;
      case FieldType.date:
        return Icons.calendar_today_outlined;
      case FieldType.time:
        return Icons.access_time_outlined;
      case FieldType.image:
        return Icons.image_outlined;
      case FieldType.likert:
        return Icons.poll_outlined;
      default:
        return Icons.input;
    }
  }

  // Open the PDF
  Future<void> _openPdf(File pdfFile) async {
    try {
      await OpenFile.open(pdfFile.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: ${e.toString()}')),
        );
      }
    }
  }

  // Share the PDF
  Future<void> _sharePdf(File pdfFile) async {
    try {
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: 'Form Response: ${widget.form.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing PDF: ${e.toString()}')),
        );
      }
    }
  }

  // Save the PDF (this is essentially the same as open in most cases,
  // as it will allow the user to then save it from their viewer)
  Future<void> _savePdf(File pdfFile) async {
    try {
      // On most platforms, opening will let the user save
      await OpenFile.open(pdfFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF ready to be saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF: ${e.toString()}')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

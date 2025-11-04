import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_field.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import 'package:jala_form/core/services/web_pdf_service.dart';
import 'package:jala_form/features/web/utils/date_formatter.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;

/// Service class for handling Excel and PDF exports
class ExportService {
  /// List to store image references for the Images_Reference sheet
  final List<Map<String, dynamic>> _imageReferences = [];

  /// Getter for image references
  List<Map<String, dynamic>> get imageReferences => _imageReferences;

  /// Clear image references
  void clearImageReferences() {
    _imageReferences.clear();
  }

  /// Export form responses to Excel
  Future<void> exportToExcel(
    CustomForm form,
    List<FormResponse> responses,
  ) async {
    _imageReferences.clear();

    // Create Excel workbook
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];

    // Build headers
    final List<String> headers = ['#', 'Submission Date', 'Respondent ID'];
    final List<FormFieldModel> expandedFields = [];

    for (var field in form.fields) {
      if (field.type == FieldType.likert && field.likertQuestions != null) {
        for (int i = 0; i < field.likertQuestions!.length; i++) {
          headers.add(
              '${field.label} - Q${i + 1}: ${field.likertQuestions![i]}');
          expandedFields.add(field);
        }
      } else {
        headers.add(field.label);
        expandedFields.add(field);
      }
    }

    // Add headers with styling
    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i])
        ..cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          backgroundColorHex: ExcelColor.fromHexString('#9C27B0'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
    }

    // Create option labels map for Likert fields
    final Map<String, Map<String, String>> likertOptionLabels = {};
    for (var field in form.fields) {
      if (field.type == FieldType.likert && field.options != null) {
        final Map<String, String> optionLabels = {};
        for (String option in field.options!) {
          if (option.contains('|')) {
            final parts = option.split('|');
            final label = parts[0];
            final value = parts.length > 1 ? parts[1] : parts[0];
            optionLabels[value] = label;
          } else {
            optionLabels[option] = option;
          }
        }
        likertOptionLabels[field.id] = optionLabels;
      }
    }

    // Add data rows
    for (var rowIndex = 0; rowIndex < responses.length; rowIndex++) {
      final response = responses[rowIndex];
      final rowStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#F5F7FA'),
      );

      // Basic columns
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex + 1))
        ..value = TextCellValue((rowIndex + 1).toString())
        ..cellStyle = rowStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex + 1))
        ..value = TextCellValue(DateFormatter.formatDateTime(response.submitted_at))
        ..cellStyle = rowStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex + 1))
        ..value = TextCellValue(response.respondent_id ?? 'Anonymous')
        ..cellStyle = rowStyle;

      // Field values
      var columnIndex = 3;

      for (var field in form.fields) {
        final value = response.responses[field.id];

        if (field.type == FieldType.likert && field.likertQuestions != null) {
          // Handle Likert fields
          final likertResponses = value is Map
              ? Map<String, dynamic>.from(value)
              : <String, dynamic>{};
          final optionLabels = likertOptionLabels[field.id] ?? <String, String>{};

          for (int questionIndex = 0;
              questionIndex < field.likertQuestions!.length;
              questionIndex++) {
            final questionKey = questionIndex.toString();
            final selectedValue = likertResponses[questionKey];

            String displayValue;
            CellStyle cellStyle;

            if (selectedValue != null) {
              displayValue =
                  optionLabels[selectedValue] ?? selectedValue.toString();
              cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString(
                    rowIndex % 2 == 0 ? '#F3E5F5' : '#FCE4EC'),
                fontColorHex: ExcelColor.fromHexString('#4A148C'),
              );
            } else {
              displayValue = 'No answer';
              cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString(
                    rowIndex % 2 == 0 ? '#F5F5F5' : '#FAFAFA'),
                fontColorHex: ExcelColor.fromHexString('#9E9E9E'),
                italic: true,
              );
            }

            sheet.cell(CellIndex.indexByColumnRow(
                columnIndex: columnIndex, rowIndex: rowIndex + 1))
              ..value = TextCellValue(displayValue)
              ..cellStyle = cellStyle;

            columnIndex++;
          }
        } else if (field.type == FieldType.image) {
          // Handle Image field with enhanced URL display
          if (value != null && value.toString().isNotEmpty) {
            final imageUrl = value.toString();
            final fileName = imageUrl.split('/').last.split('?').first;

            final cell = sheet.cell(CellIndex.indexByColumnRow(
                columnIndex: columnIndex, rowIndex: rowIndex + 1));

            cell
              ..value = TextCellValue(imageUrl)
              ..cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString(
                    rowIndex % 2 == 0 ? '#E3F2FD' : '#F1F8FF'),
                fontColorHex: ExcelColor.fromHexString('#1565C0'),
                underline: Underline.Single,
              );

            _imageReferences.add({
              'row': rowIndex + 2,
              'respondentId': response.respondent_id ?? 'Anonymous',
              'fieldLabel': field.label,
              'fileName': fileName,
              'imageUrl': imageUrl,
              'submissionDate': response.submitted_at,
            });
          } else {
            sheet.cell(CellIndex.indexByColumnRow(
                columnIndex: columnIndex, rowIndex: rowIndex + 1))
              ..value = TextCellValue('No image')
              ..cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString(
                    rowIndex % 2 == 0 ? '#F5F5F5' : '#FAFAFA'),
                fontColorHex: ExcelColor.fromHexString('#9E9E9E'),
                italic: true,
              );
          }
          columnIndex++;
        } else {
          // Handle other fields
          String displayValue;
          if (value != null) {
            if (value is List) {
              displayValue = value.join(', ');
            } else if (value is Map) {
              displayValue = value.toString();
            } else {
              displayValue = value.toString();
            }
          } else {
            displayValue = 'No answer';
          }

          final cellStyle = displayValue == 'No answer'
              ? CellStyle(
                  backgroundColorHex: ExcelColor.fromHexString(
                      rowIndex % 2 == 0 ? '#F5F5F5' : '#FAFAFA'),
                  fontColorHex: ExcelColor.fromHexString('#9E9E9E'),
                  italic: true,
                )
              : rowStyle;

          sheet.cell(CellIndex.indexByColumnRow(
              columnIndex: columnIndex, rowIndex: rowIndex + 1))
            ..value = TextCellValue(displayValue)
            ..cellStyle = cellStyle;

          columnIndex++;
        }
      }
    }

    // Auto-fit columns
    for (var i = 0; i < headers.length; i++) {
      if (i < 3) {
        sheet.setColumnWidth(i, 15.0);
      } else {
        final headerLength = headers[i].length;
        final width = (headerLength > 30)
            ? 35.0
            : (headerLength > 20)
                ? 25.0
                : 20.0;
        sheet.setColumnWidth(i, width);
      }
    }

    // Add Likert summary sheet if needed
    if (form.fields.any((field) => field.type == FieldType.likert)) {
      await addLikertSummarySheet(
          excel, form, responses, likertOptionLabels);
    }

    // Add enhanced images summary sheet
    if (_imageReferences.isNotEmpty) {
      await addEnhancedImagesSummarySheet(excel, form, responses);
    }

    // Generate and download Excel file
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${form.title}_responses_$timestamp.xlsx';
    final bytes = excel.encode();

    if (bytes != null) {
      final blob = html.Blob([
        Uint8List.fromList(bytes)
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..style.display = 'none';

      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    }
  }

  /// Add enhanced images summary sheet with better organization
  Future<void> addEnhancedImagesSummarySheet(
      Excel excel, CustomForm form, List<FormResponse> responses) async {
    const String imagesSheetName = 'Images_Reference';
    final imagesSheet = excel[imagesSheetName];

    // Headers with enhanced info
    final imageHeaders = [
      'Main Sheet Row',
      'Respondent ID',
      'Field Name',
      'Image Filename',
      'Image URL (Copy & Paste to Browser)',
      'Submission Date'
    ];

    // Add styled headers
    for (var i = 0; i < imageHeaders.length; i++) {
      imagesSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(imageHeaders[i])
        ..cellStyle = CellStyle(
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
            fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
            backgroundColorHex: ExcelColor.fromHexString('#2196F3'));
    }

    // Add image data with enhanced formatting
    int imageRowIndex = 1;
    for (var imgRef in _imageReferences) {
      final imageUrl = imgRef['imageUrl'];
      final fileName = imgRef['fileName'];

      // Main sheet row reference
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: imageRowIndex))
        ..value = TextCellValue('Row ${imgRef['row']}')
        ..cellStyle = CellStyle(
            fontColorHex: ExcelColor.fromHexString('#1565C0'), bold: true);

      // Respondent ID
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: imageRowIndex))
          .value = TextCellValue(imgRef['respondentId']);

      // Field name
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: imageRowIndex))
          .value = TextCellValue(imgRef['fieldLabel']);

      // Clean filename
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: imageRowIndex))
          .value = TextCellValue(fileName);

      // Full URL - styled as link for easy copying
      final urlCell = imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: imageRowIndex));
      urlCell.value = TextCellValue(imageUrl);
      urlCell.cellStyle = CellStyle(
        fontColorHex: ExcelColor.fromHexString('#1565C0'),
        underline: Underline.Single,
      );

      // Submission date
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: imageRowIndex))
          .value = TextCellValue(DateFormatter.formatDateTime(imgRef['submissionDate']));

      imageRowIndex++;
    }

    // Add instructions at the bottom
    final instructionRow = imageRowIndex + 2;
    imagesSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: instructionRow))
      ..value = TextCellValue('How to View Images:')
      ..cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#9C27B0'),
      );

    imagesSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: instructionRow))
      ..value = TextCellValue('1. In main sheet: Click blue URLs to open images')
      ..cellStyle = CellStyle(
        fontColorHex: ExcelColor.fromHexString('#666666'),
      );

    imagesSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: instructionRow + 1))
      ..value = TextCellValue('2. Or copy URLs from this sheet and paste in browser')
      ..cellStyle = CellStyle(
        fontColorHex: ExcelColor.fromHexString('#666666'),
      );

    imagesSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: instructionRow + 2))
      ..value = TextCellValue('3. Right-click URLs to copy link address')
      ..cellStyle = CellStyle(
        fontColorHex: ExcelColor.fromHexString('#666666'),
      );
  }

  /// Add Likert summary analysis sheet
  Future<void> addLikertSummarySheet(
    Excel excel,
    CustomForm form,
    List<FormResponse> responses,
    Map<String, Map<String, String>> likertOptionLabels,
  ) async {
    // Create summary sheet
    excel.sheets['Likert Summary'] = excel['Likert Summary'];
    final summarySheet = excel.sheets['Likert Summary']!;

    var currentRow = 0;

    // Title
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
      ..value = TextCellValue('Likert Scale Analysis Summary')
      ..cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        backgroundColorHex: ExcelColor.fromHexString('#9C27B0'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    currentRow += 2;

    // Process each Likert field
    for (var field in form.fields) {
      if (field.type == FieldType.likert && field.likertQuestions != null) {
        // Field title
        summarySheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
          ..value = TextCellValue(field.label)
          ..cellStyle = CellStyle(
            bold: true,
            fontSize: 14,
            backgroundColorHex: ExcelColor.fromHexString('#E1BEE7'),
            fontColorHex: ExcelColor.fromHexString('#4A148C'),
          );
        currentRow += 1;

        final optionLabels = likertOptionLabels[field.id] ?? <String, String>{};

        // Process each question in the Likert scale
        for (int questionIndex = 0;
            questionIndex < field.likertQuestions!.length;
            questionIndex++) {
          final question = field.likertQuestions![questionIndex];

          // Question header
          summarySheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
            ..value = TextCellValue('Q${questionIndex + 1}: $question')
            ..cellStyle = CellStyle(bold: true, fontSize: 12);
          currentRow += 1;

          // Count responses for this question
          final Map<String, int> responseCounts = {};
          final String questionKey = questionIndex.toString();

          for (var response in responses) {
            final likertData = response.responses[field.id];
            if (likertData is Map) {
              final likertResponses = Map<String, dynamic>.from(likertData);
              final selectedValue = likertResponses[questionKey];
              if (selectedValue != null) {
                final label =
                    optionLabels[selectedValue] ?? selectedValue.toString();
                responseCounts[label] = (responseCounts[label] ?? 0) + 1;
              }
            }
          }

          // Add response counts headers
          summarySheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
            ..value = TextCellValue('Response')
            ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'));
          summarySheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow))
            ..value = TextCellValue('Count')
            ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'));
          summarySheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow))
            ..value = TextCellValue('Percentage')
            ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'));
          currentRow += 1;

          final totalResponses =
              responseCounts.values.fold(0, (sum, count) => sum + count);

          for (var entry in responseCounts.entries) {
            final percentage = totalResponses > 0
                ? (entry.value / totalResponses * 100).toStringAsFixed(1)
                : '0.0';

            summarySheet
                .cell(CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: currentRow))
                .value = TextCellValue(entry.key);
            summarySheet
                .cell(CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: currentRow))
                .value = IntCellValue(entry.value);
            summarySheet
                .cell(CellIndex.indexByColumnRow(
                columnIndex: 2, rowIndex: currentRow))
                .value = TextCellValue('$percentage%');
            currentRow += 1;
          }

          currentRow += 1; // Add space between questions
        }

        currentRow += 2; // Add space between different Likert fields
      }
    }

    summarySheet.setColumnWidth(0, 300); // Question/Response column (column A)
    summarySheet.setColumnWidth(1, 80); // Count column (column B)
    summarySheet.setColumnWidth(2, 100); // Percentage column (column C)
  }

  /// Export single form response to PDF
  Future<void> exportToPdf(CustomForm form, FormResponse response) async {
    final webPdfService = WebPdfService();
    await webPdfService.generateAndDownloadPdf(form, response);
  }
}

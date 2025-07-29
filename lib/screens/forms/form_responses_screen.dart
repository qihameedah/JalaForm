import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jala_form/models/form_field.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;
import '../../models/custom_form.dart';
import '../../models/form_response.dart';
import '../../services/supabase_service.dart';
import '../../services/pdf_service.dart';
import 'response_detail_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';

class FormResponsesScreen extends StatefulWidget {
  final String form_id;
  final String formTitle;

  const FormResponsesScreen({
    super.key,
    required this.form_id,
    required this.formTitle,
  });

  @override
  State<FormResponsesScreen> createState() => _FormResponsesScreenState();
}

class _FormResponsesScreenState extends State<FormResponsesScreen> {
  final _supabaseService = SupabaseService();
  final _pdfService = PdfService();
  List<FormResponse> _responses = [];
  CustomForm? _form;
  bool _isLoading = true;
  bool _isFileGenerating = false; // Renamed to be more generic
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<FormResponse> _filteredResponses = [];

  // Sorting
  String _sortBy = 'date';
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterResponses();
    });
  }

  void _filterResponses() {
    if (_searchQuery.isEmpty) {
      _filteredResponses = List.from(_responses);
    } else {
      _filteredResponses = _responses.where((response) {
        // Search in all response values
        for (var value in response.responses.values) {
          if (value != null &&
              value.toString().toLowerCase().contains(_searchQuery)) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    // Apply sorting
    _sortResponses();
  }

  void _sortResponses() {
    switch (_sortBy) {
      case 'date':
        _filteredResponses.sort((a, b) => _sortAsc
            ? a.submitted_at.compareTo(b.submitted_at)
            : b.submitted_at.compareTo(a.submitted_at));
        break;
      case 'respondent':
        _filteredResponses.sort((a, b) {
          final aId = a.respondent_id ?? '';
          final bId = b.respondent_id ?? '';
          return _sortAsc ? aId.compareTo(bId) : bId.compareTo(aId);
        });
        break;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load form details
      _form = await _supabaseService.getFormById(widget.form_id);

      // Load responses
      _responses = await _supabaseService.getFormResponses(widget.form_id);

      // Initialize filtered responses
      _filterResponses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Generate PDF and show options
  Future<void> _generatePdfWithOptions(FormResponse response) async {
    if (_form == null) return;

    setState(() {
      _isFileGenerating = true;
    });

    try {
      // Generate PDF with full-page images
      final pdfFile = await _pdfService
          .generateFormResponsePdfWithFullPageImages(_form!, response);

      if (mounted) {
        // Show options for the generated PDF
        _showPdfOptionsBottomSheet(pdfFile, response);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFileGenerating = false;
        });
      }
    }
  }

  // Show bottom sheet with PDF options
  void _showPdfOptionsBottomSheet(File pdfFile, FormResponse response) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Text(
                  'PDF Created Successfully',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Choose what to do with the PDF:',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionButton(
                    icon: Icons.visibility,
                    label: 'View',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      _openPdf(pdfFile);
                    },
                  ),
                  _buildOptionButton(
                    icon: Icons.share,
                    label: 'Share',
                    color: AppTheme.secondaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      _sharePdf(pdfFile);
                    },
                  ),
                  _buildOptionButton(
                    icon: Icons.download,
                    label: 'Save',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pop(context);
                      _savePdf(pdfFile);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

// Add this as a class variable at the top of your widget class
  final List<Map<String, dynamic>> _imageReferences = [];

  Future<void> _exportAllResponsesToExcel() async {
    if (_form == null || _responses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No responses to export'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isFileGenerating = true;
      _imageReferences.clear(); // Clear previous image references
    });

    try {
      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel.sheets.values.first;

      // Build headers with special handling for Likert fields
      final List<String> headers = ['#', 'Submission Date', 'Respondent ID'];
      final List<FormFieldModel> expandedFields = [];

      for (var field in _form!.fields) {
        if (field.type == FieldType.likert && field.likertQuestions != null) {
          // Add separate column for each Likert question
          for (int i = 0; i < field.likertQuestions!.length; i++) {
            headers.add(
                '${field.label} - Q${i + 1}: ${field.likertQuestions![i]}');
            expandedFields.add(field); // Keep reference to original field
          }
        } else {
          headers.add(field.label);
          expandedFields.add(field);
        }
      }

      // Add the headers to the first row
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = headers[i] as CellValue?
          ..cellStyle = CellStyle(
            bold: true,
            horizontalAlign: HorizontalAlign.Center,

            backgroundColorHex: ExcelColor.fromHexString('#9C27B0'),
            fontColorHex: ExcelColor.fromHexString('#FFFFFF')

          );
      }

      // Create option labels map for Likert fields
      final Map<String, Map<String, String>> likertOptionLabels = {};
      for (var field in _form!.fields) {
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
      for (var rowIndex = 0; rowIndex < _responses.length; rowIndex++) {
        final response = _responses[rowIndex];
        final rowStyle = CellStyle(

          backgroundColorHex: ExcelColor.fromHexString(rowIndex % 2 == 0 ? '#F5F7FA' : '#FFFFFF')

        );

        // Row number
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: rowIndex + 1))
            .value = (rowIndex + 1).toString() as CellValue?;

        // Submission date
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: rowIndex + 1))
            .value = _formatDate(response.submitted_at) as CellValue?;

        // Respondent ID
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 2, rowIndex: rowIndex + 1))
            .value = (response.respondent_id ?? 'Anonymous') as CellValue?;

        // Apply style to basic columns
        for (var i = 0; i < 3; i++) {
          sheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: i, rowIndex: rowIndex + 1))
              .cellStyle = rowStyle;
        }

        // Field values with Likert expansion and proper image handling
        var columnIndex = 3;
        var fieldIndex = 0;

        for (var field in _form!.fields) {
          final value = response.responses[field.id];

          if (field.type == FieldType.likert && field.likertQuestions != null) {
            // Handle Likert field - create separate columns for each question
            final likertResponses = value is Map
                ? Map<String, dynamic>.from(value)
                : <String, dynamic>{};
            final optionLabels =
                likertOptionLabels[field.id] ?? <String, String>{};

            for (int questionIndex = 0;
                questionIndex < field.likertQuestions!.length;
                questionIndex++) {
              final questionKey = questionIndex.toString();
              final selectedValue = likertResponses[questionKey];

              String displayValue = '';
              CellStyle cellStyle = rowStyle;

              if (selectedValue != null) {
                // Show the label instead of the value
                displayValue =
                    optionLabels[selectedValue] ?? selectedValue.toString();

                // Color code based on response (optional - you can customize these colors)
                String backgroundColor = '#FFFFFF';
                if (rowIndex % 2 == 0) backgroundColor = '#F5F7FA';

                // Add light purple tint for answered Likert questions
                if (selectedValue != null) {
                  backgroundColor = rowIndex % 2 == 0 ? '#F3E5F5' : '#FCE4EC';
                }

                cellStyle = CellStyle(


                  backgroundColorHex: ExcelColor.fromHexString(backgroundColor),
                  fontColorHex: ExcelColor.fromHexString('#4A148C')

                );
              } else {
                displayValue = 'No answer';
                cellStyle = CellStyle(

                  backgroundColorHex: ExcelColor.fromHexString(rowIndex % 2 == 0 ? '#F5F5F5' : '#FAFAFA'),
                  fontColorHex: ExcelColor.fromHexString('#9E9E9E'),
                  italic: true,
                );
              }

              final cell = sheet.cell(CellIndex.indexByColumnRow(
                  columnIndex: columnIndex, rowIndex: rowIndex + 1));
              cell.value = displayValue as CellValue?;
              cell.cellStyle = cellStyle;

              columnIndex++;
            }
          } else if (field.type == FieldType.image) {
            // Handle Image field with enhanced URL display
            if (value != null && value.toString().isNotEmpty) {
              final imageUrl = value.toString();

              // Extract clean filename
              String fileName = 'image_file';
              if (imageUrl.startsWith('http')) {
                try {
                  final uri = Uri.parse(imageUrl);
                  if (uri.pathSegments.isNotEmpty) {
                    fileName = uri.pathSegments.last;
                    if (fileName.contains('?')) {
                      fileName = fileName.split('?').first;
                    }
                  }
                } catch (e) {
                  fileName = 'image_file';
                }
              }

              final cell = sheet.cell(CellIndex.indexByColumnRow(
                  columnIndex: columnIndex, rowIndex: rowIndex + 1));

              // Set the URL directly as the cell value so users can click it
              cell.value = imageUrl as CellValue?;

              // Style as clickable link
              cell.cellStyle = CellStyle(

                backgroundColorHex: ExcelColor.fromHexString(rowIndex % 2 == 0 ? '#E3F2FD' : '#F1F8FF'),
                fontColorHex: ExcelColor.fromHexString('#1565C0'),

                underline: Underline.Single, // Underlined like hyperlinks
              );

              // Store for reference sheet
              _imageReferences.add({
                'row': rowIndex + 1,
                'column': columnIndex,
                'fieldLabel': field.label,
                'imageUrl': imageUrl,
                'fileName': fileName,
                'respondentId': response.respondent_id ?? 'Anonymous',
                'submissionDate': response.submitted_at,
              });
            } else {
              // No image
              sheet.cell(CellIndex.indexByColumnRow(
                  columnIndex: columnIndex, rowIndex: rowIndex + 1))
                ..value = 'No image' as CellValue?
                ..cellStyle = CellStyle(

                  backgroundColorHex: ExcelColor.fromHexString(rowIndex % 2 == 0 ? '#F5F5F5' : '#FAFAFA'),
                  fontColorHex: ExcelColor.fromHexString('#9E9E9E'),

                  italic: true,
                );
            }

            columnIndex++;
          } else {
            // Handle other non-Likert fields (text, radio, checkbox, etc.)
            String displayValue = '';
            CellStyle cellStyle = rowStyle;

            if (value != null) {
              if (value is List) {
                // Handle list types like checkboxes
                displayValue = value.join(', ');
              } else if (value is Map) {
                // Handle unexpected Map types (shouldn't happen for non-Likert fields)
                displayValue = value.toString();
              } else {
                displayValue = value.toString();
              }
            } else {
              displayValue = 'No answer';
              cellStyle = CellStyle(

                backgroundColorHex: ExcelColor.fromHexString(rowIndex % 2 == 0 ? '#F5F5F5' : '#FAFAFA'),
                fontColorHex: ExcelColor.fromHexString('#9E9E9E'),

                italic: true,
              );
            }

            final cell = sheet.cell(CellIndex.indexByColumnRow(
                columnIndex: columnIndex, rowIndex: rowIndex + 1));
            cell.value = displayValue as CellValue?;
            cell.cellStyle = cellStyle;

            columnIndex++;
          }
          fieldIndex++;
        }
      }

      // Auto-fit columns with better width calculation
      for (var i = 0; i < headers.length; i++) {
        if (i < 3) {
          // Basic columns
          sheet.setColumnWidth(i, 15.0); // Changed from 15 to 15.0
        } else {
          // Field columns - adjust based on header length
          final headerLength = headers[i].length;
          final width = (headerLength > 30)
              ? 35.0
              : (headerLength > 20)
                  ? 25.0
                  : 20.0; // Changed to double values
          sheet.setColumnWidth(i, width);
        }
      }

      // Add a summary sheet for Likert analysis
      if (_form!.fields.any((field) => field.type == FieldType.likert)) {
        await _addLikertSummarySheet(
            excel, _form!, _responses, likertOptionLabels);
      }

      // Add images summary sheet if there are image fields
      if (_imageReferences.isNotEmpty) {
        await _addEnhancedImagesSummarySheet(excel, _form!, _responses);
      }

      // Generate Excel file with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${_form!.title}_all_responses_$timestamp.xlsx';
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final file = File('$path/$fileName');

      await file.writeAsBytes(excel.encode()!);

      // Open the file with enhanced message about images
      if (mounted) {
        if (_imageReferences.isNotEmpty) {
          // Show success message with image info
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Excel export successful with images'),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Click blue URLs in Excel to view images',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Text(
                    '• Check "Images_Reference" sheet for all URLs',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              margin: EdgeInsets.all(12),
              duration: Duration(seconds: 5),
            ),
          );
        }
        _showExcelOptionsBottomSheet(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to Excel: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFileGenerating = false;
        });
      }
    }
  }

// Enhanced images summary sheet for the export all responses function
  Future<void> _addEnhancedImagesSummarySheet(
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
        ..value = imageHeaders[i] as CellValue?
        ..cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,

          backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF')

        );
    }

    // Add image data with enhanced formatting
    int imageRowIndex = 1;
    for (var imgRef in _imageReferences) {
      final imageUrl = imgRef['imageUrl'];
      final fileName = imgRef['fileName'];

      // Main sheet row reference
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: imageRowIndex))
        ..value = 'Row ${imgRef['row']}' as CellValue?
        ..cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#1565C0')
            , bold: true);

      // Respondent ID
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: imageRowIndex))
        .value = imgRef['respondentId'];

      // Field name
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: imageRowIndex))
        .value = imgRef['fieldLabel'];

      // Clean filename
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: imageRowIndex))
        .value = fileName;

      // Full URL - styled as link for easy copying
      final urlCell = imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: imageRowIndex));
      urlCell.value = imageUrl;
      urlCell.cellStyle = CellStyle(

        fontColorHex: ExcelColor.fromHexString('#1565C0'),
        underline: Underline.Single,
      );

      // Submission date - use the same format as main sheet
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: imageRowIndex))
        .value = _formatDate(
            imgRef['submissionDate']) as CellValue?; // Use your existing _formatDate method

      imageRowIndex++;
    }

    // Auto-fit columns with better sizing
    final columnWidths = [15.0, 20.0, 25.0, 30.0, 50.0, 20.0];
    for (var i = 0; i < columnWidths.length; i++) {
      imagesSheet.setColumnWidth(i, columnWidths[i]);
    }

    // Add instructions at the bottom
    final instructionRow = imageRowIndex + 2;
    imagesSheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: instructionRow))
      ..value = 'How to View Images:' as CellValue?
      ..cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#9C27B0'));


    imagesSheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: instructionRow))
      ..value = '1. In main sheet: Click blue URLs to open images' as CellValue?
      ..cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#666666'));

    imagesSheet.cell(CellIndex.indexByColumnRow(
        columnIndex: 1, rowIndex: instructionRow + 1))
      ..value = '2. Or copy URLs from this sheet and paste in browser' as CellValue?
      ..cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#666666'));

    imagesSheet.cell(CellIndex.indexByColumnRow(
        columnIndex: 1, rowIndex: instructionRow + 2))
      ..value = '3. Right-click URLs to copy link address' as CellValue?
      ..cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#666666'));
  }

// Add this new method for Likert summary analysis
  Future<void> _addLikertSummarySheet(
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
      ..value = 'Likert Scale Analysis Summary' as CellValue?
      ..cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        backgroundColorHex: ExcelColor.fromHexString('#9C27B0'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF')
      );
    currentRow += 2;

    // Process each Likert field
    for (var field in form.fields) {
      if (field.type == FieldType.likert && field.likertQuestions != null) {
        // Field title
        summarySheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
          ..value = field.label as CellValue?
          ..cellStyle = CellStyle(
            bold: true,
            fontSize: 14,
            backgroundColorHex: ExcelColor.fromHexString('#E1BEE7'),
            fontColorHex: ExcelColor.fromHexString('#4A148C')

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
            ..value = 'Q${questionIndex + 1}: $question' as CellValue?
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

          // Add response counts
          var columnIndex = 1;
          summarySheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
            ..value = 'Response' as CellValue?
            ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'));


    summarySheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow))
            ..value = 'Count' as CellValue?
      ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'));
          summarySheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow))
            ..value = 'Percentage' as CellValue?
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
                .value = entry.key as CellValue?;
            summarySheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: 1, rowIndex: currentRow))
                .value = entry.value as CellValue?;
            summarySheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: 2, rowIndex: currentRow))
                .value = '$percentage%' as CellValue?;
            currentRow += 1;
          }

          currentRow += 1; // Add space between questions
        }

        currentRow += 2; // Add space between different Likert fields
      }
    }

    // Set column widths for summary sheet
    summarySheet.setColumnWidth(0, 40); // Question/Response column
    summarySheet.setColumnWidth(1, 10); // Count column
    summarySheet.setColumnWidth(2, 12); // Percentage column
  }

  // Show bottom sheet with Excel options
  void _showExcelOptionsBottomSheet(File excelFile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Text(
                  'Excel File Created Successfully',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Choose what to do with the Excel file:',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionButton(
                    icon: Icons.visibility,
                    label: 'Open',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      OpenFile.open(excelFile.path);
                    },
                  ),
                  _buildOptionButton(
                    icon: Icons.share,
                    label: 'Share',
                    color: AppTheme.secondaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      Share.shareXFiles(
                        [XFile(excelFile.path)],
                        text: 'All Responses: ${_form!.title}',
                      );
                    },
                  ),
                  _buildOptionButton(
                    icon: Icons.download,
                    label: 'Save',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pop(context);
                      OpenFile.open(excelFile.path);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Excel file ready to be saved'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Helper method to build option buttons
  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Open the PDF
  Future<void> _openPdf(File pdfFile) async {
    try {
      await OpenFile.open(pdfFile.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Share the PDF
  Future<void> _sharePdf(File pdfFile) async {
    try {
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: 'Form Response: ${_form!.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Save the PDF (opens file which user can then save)
  Future<void> _savePdf(File pdfFile) async {
    try {
      await OpenFile.open(pdfFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF ready to be saved'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PDF: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

// ============= CLEAN FORMRESPONSESSCREEN METHODS =============

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Responses',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_filteredResponses.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF3F51B5),
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF3F51B5),
        elevation: 0,
        centerTitle: false,
        actions: [
          if (!_isLoading && !_isFileGenerating && _responses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton.icon(
                onPressed: _exportAllResponsesToExcel,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5C6BC0),
                  backgroundColor: const Color(0xFF5C6BC0).withOpacity(0.1),
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
      body: Column(
        children: [
          // Search and Filter
          _buildSearchSection(),

          // Content
          Expanded(
            child: _isLoading || _isFileGenerating
                ? _buildLoadingState()
                : _responses.isEmpty
                    ? _buildEmptyState()
                    : _buildResponsesList(),
          ),
        ],
      ),
    );
  }

// 2. NEW SEARCH SECTION
  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE3F2FD)),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search responses...',
                  hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                  prefixIcon:
                      Icon(Icons.search, color: Color(0xFF5C6BC0), size: 18),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE3F2FD)),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.sort, color: Color(0xFF5C6BC0), size: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              offset: const Offset(0, 40),
              onSelected: (value) {
                setState(() {
                  if (_sortBy == value) {
                    _sortAsc = !_sortAsc;
                  } else {
                    _sortBy = value;
                    _sortAsc = true;
                  }
                  _sortResponses();
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'date',
                  child: Row(
                    children: [
                      Icon(
                        _sortBy == 'date'
                            ? (_sortAsc
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : Icons.schedule,
                        color: _sortBy == 'date'
                            ? const Color(0xFF3F51B5)
                            : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text('Date', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'respondent',
                  child: Row(
                    children: [
                      Icon(
                        _sortBy == 'respondent'
                            ? (_sortAsc
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : Icons.person,
                        color: _sortBy == 'respondent'
                            ? const Color(0xFF3F51B5)
                            : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text('Respondent', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// 3. REPLACE LOADING STATE
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
            'Loading responses...',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

// 7. NEW METHOD - Replace _buildResponsesList with this grid layout
  Widget _buildResponsesGrid() {
    if (_filteredResponses.isEmpty && _searchQuery.isNotEmpty) {
      return Container(
        height: 300,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF334155)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 48, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'No results found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try adjusting your search terms',
                style: TextStyle(fontSize: 14, color: Colors.white60),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => _searchController.clear(),
                icon: const Icon(Icons.clear_rounded, color: Color(0xFF3B82F6)),
                label: const Text(
                  'Clear Search',
                  style: TextStyle(
                      color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive grid columns
          int crossAxisCount = 1;
          if (constraints.maxWidth > 600) crossAxisCount = 2;
          if (constraints.maxWidth > 900) crossAxisCount = 3;

          return AnimatedList(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            initialItemCount: _filteredResponses.length,
            itemBuilder: (context, index, animation) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(1, 0), end: Offset.zero).chain(
                    CurveTween(curve: Curves.easeOutCubic),
                  ),
                ),
                child:
                    _buildCompactResponseCard(_filteredResponses[index], index),
              );
            },
          );
        },
      ),
    );
  }

// 8. NEW METHOD - Compact response card design
  Widget _buildCompactResponseCard(FormResponse response, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ResponseDetailScreen(
                form: _form!,
                response: response,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(1, 0), end: Offset.zero).chain(
                      CurveTween(curve: Curves.easeOutCubic),
                    ),
                  ),
                  child: child,
                );
              },
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '#${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Response #${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatDate(response.submitted_at),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (response.respondent_id != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF6366F1)),
                        ),
                        child: Text(
                          'ID: ${response.respondent_id!.substring(0, 6)}...',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quick preview
                if (_form != null) ..._buildCompactPreview(response, _form!),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      ResponseDetailScreen(
                                form: _form!,
                                response: response,
                              ),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                return FadeTransition(
                                    opacity: animation, child: child);
                              },
                            ),
                          ),
                          icon: const Icon(Icons.visibility_rounded, size: 16),
                          label: const Text('View',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () => _generatePdfWithOptions(response),
                          icon: const Icon(Icons.picture_as_pdf_rounded,
                              size: 16, color: Colors.white),
                          label: const Text('PDF',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
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

// 7. COMPACT PREVIEW
  List<Widget> _buildCompactPreview(FormResponse response, CustomForm form) {
    final previewFields = form.fields.take(3).toList();

    return previewFields.map((field) {
      final value = response.responses[field.id];

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: const Color(0xFF3F51B5).withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3F51B5).withOpacity(0.05),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              _getIconForFieldType(field.type),
              size: 12,
              color: const Color(0xFF5C6BC0),
            ),
            const SizedBox(width: 8),
            Text(
              field.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5C6BC0),
              ),
            ),
            const SizedBox(width: 8),
            const Text(':',
                style: TextStyle(color: Color(0xFF999999), fontSize: 11)),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCompactValue(value, field.type),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildCompactValue(dynamic value, FieldType type) {
    if (value == null || (value is String && value.isEmpty)) {
      return const Text(
        'No answer',
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: Color(0xFF999999),
        ),
      );
    }

    if (type == FieldType.image && value.toString().isNotEmpty) {
      return const Text(
        'Image attached',
        style: TextStyle(
          fontSize: 11,
          color: Color(0xFF5C6BC0),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (type == FieldType.likert) {
      if (value is Map) {
        final responses = Map<String, dynamic>.from(value);
        final answeredCount = responses.values.where((v) => v != null).length;
        return Text(
          '$answeredCount responses',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9C27B0),
            fontWeight: FontWeight.w500,
          ),
        );
      }
    }

    String displayText = '';
    if (value is List) {
      displayText = value.join(', ');
    } else {
      displayText = value.toString();
    }

    if (displayText.length > 25) {
      displayText = '${displayText.substring(0, 25)}...';
    }

    return Text(
      displayText,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF333333),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

// 10. NEW METHOD - Compact value preview
  Widget _buildCompactValuePreview(dynamic value, FieldType type) {
    if (value == null || (value is String && value.isEmpty)) {
      return const Text(
        'No answer',
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: Colors.white54,
        ),
      );
    }

    if (type == FieldType.image && value.toString().isNotEmpty) {
      return const Row(
        children: [
          Icon(Icons.image_rounded, size: 12, color: Colors.white60),
          SizedBox(width: 4),
          Text(
            'Image attached',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white60,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    String displayText = '';
    if (value is List) {
      displayText = value.join(', ');
    } else {
      displayText = value.toString();
    }

    if (displayText.length > 30) {
      displayText = '${displayText.substring(0, 30)}...';
    }

    return Text(
      displayText,
      style: const TextStyle(
        fontSize: 12,
        color: Colors.white,
        height: 1.2,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

// 2. NEW METHOD - Add this method for the export button
  Widget _buildExportButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _exportAllResponsesToExcel,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.download_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Export',
                  style: TextStyle(
                    color: Colors.white,
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

// 3. NEW METHOD - Add this method for search and filter
  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF475569),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search responses...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.white54, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: PopupMenuButton<String>(
              icon:
                  const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: const Color(0xFF1E293B),
              onSelected: (value) {
                setState(() {
                  if (_sortBy == value) {
                    _sortAsc = !_sortAsc;
                  } else {
                    _sortBy = value;
                    _sortAsc = true;
                  }
                  _sortResponses();
                });
              },
              itemBuilder: (context) => [
                _buildSortMenuItem('date', 'Date', Icons.schedule_rounded),
                _buildSortMenuItem(
                    'respondent', 'Respondent', Icons.person_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

// 4. NEW METHOD - Add this method for sort menu items
  PopupMenuItem<String> _buildSortMenuItem(
      String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? (_sortAsc
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded)
                  : icon,
              color: isSelected ? const Color(0xFF3B82F6) : Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

// 4. REPLACE EMPTY STATE
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 32,
                color: Color(0xFF3F51B5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No responses yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your form to start collecting responses',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3F51B5),
                backgroundColor: const Color(0xFF3F51B5).withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

// 5. REPLACE RESPONSES LIST
  Widget _buildResponsesList() {
    if (_filteredResponses.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Color(0xFFBBBBBB)),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search terms',
              style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _searchController.clear(),
              child: const Text('Clear Search'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredResponses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(20 * (1 - value), 0),
              child: Opacity(
                opacity: value,
                child: _buildResponseCard(_filteredResponses[index], index),
              ),
            );
          },
        );
      },
    );
  }

// 6. REPLACE RESPONSE CARD
  Widget _buildResponseCard(FormResponse response, int index) {
    return Container(
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
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F51B5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Response #${index + 1}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      Text(
                        _formatDate(response.submitted_at),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                if (response.respondent_id != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C6BC0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ID: ${response.respondent_id!.substring(0, 6)}...',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF5C6BC0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Preview Content
          if (_form != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _buildCompactPreview(response, _form!),
              ),
            ),

          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFF),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  ResponseDetailScreen(
                                      form: _form!, response: response),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return SlideTransition(
                              position: animation.drive(
                                Tween(
                                        begin: const Offset(1, 0),
                                        end: Offset.zero)
                                    .chain(
                                        CurveTween(curve: Curves.easeOutQuart)),
                              ),
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('View', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3F51B5),
                      side: const BorderSide(color: Color(0xFF3F51B5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _generatePdfWithOptions(response),
                    icon: const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: const Text('PDF', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C6BC0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResponsePreview(FormResponse response, CustomForm form) {
    List<Widget> previewWidgets = [];

    // Get first 2 fields for cleaner preview
    final previewFields = form.fields.take(2).toList();

    for (int i = 0; i < previewFields.length; i++) {
      final field = previewFields[i];
      final value = response.responses[field.id];

      previewWidgets.add(
        Container(
          margin:
              EdgeInsets.only(bottom: i == previewFields.length - 1 ? 0 : 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _getIconForFieldType(field.type),
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildValuePreview(value, field.type),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Add "more fields" indicator if there are more
    if (form.fields.length > 2) {
      previewWidgets.add(
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.more_horiz,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                '+${form.fields.length - 2} more fields',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return previewWidgets;
  }

  Widget _buildValuePreview(dynamic value, FieldType type) {
    if (value == null || (value is String && value.isEmpty)) {
      return Text(
        'No answer',
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: Colors.grey[500],
        ),
      );
    }

    if (type == FieldType.image && value.toString().isNotEmpty) {
      return Row(
        children: [
          Icon(
            Icons.image_outlined,
            size: 14,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            'Image attached',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    String displayText = '';
    if (value is List) {
      displayText = value.join(', ');
    } else {
      displayText = value.toString();
    }

    // Truncate long text
    if (displayText.length > 60) {
      displayText = '${displayText.substring(0, 60)}...';
    }

    return Text(
      displayText,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF1A1A1A),
        height: 1.3,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildLikertValuePreview(dynamic value, FormFieldModel field) {
    if (value == null || (value is Map && value.isEmpty)) {
      return Text(
        'No responses',
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: Colors.grey[500],
        ),
      );
    }

    if (value is Map) {
      final responses = Map<String, dynamic>.from(value);
      final answeredCount = responses.values.where((v) => v != null).length;
      final totalQuestions = field.likertQuestions?.length ?? responses.length;

      return Text(
        '$answeredCount/$totalQuestions answered',
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF9C27B0),
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Text(
      value.toString(),
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF333333),
      ),
    );
  }

  IconData _getIconForFieldType(FieldType type) {
    switch (type) {
      case FieldType.text:
        return Icons.text_fields;
      case FieldType.number:
        return Icons.numbers;
      case FieldType.email:
        return Icons.email;
      case FieldType.multiline:
        return Icons.subject;
      case FieldType.textarea:
        return Icons.notes;
      case FieldType.dropdown:
        return Icons.arrow_drop_down_circle;
      case FieldType.checkbox:
        return Icons.check_box;
      case FieldType.radio:
        return Icons.radio_button_checked;
      case FieldType.date:
        return Icons.calendar_today;
      case FieldType.time:
        return Icons.access_time;
      case FieldType.image:
        return Icons.image;
      case FieldType.likert:
        return Icons.poll_outlined;
      default:
        return Icons.input;
    }
  }
}

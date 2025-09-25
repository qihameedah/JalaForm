import 'package:flutter/material.dart';

class AppBottomSheetTheme {

  AppBottomSheetTheme._();

  static BottomSheetThemeData lightAppBottomSheetTheme = BottomSheetThemeData(
    showDragHandle: true,
    backgroundColor: Colors.white,
    modalBackgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: double.infinity ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))

  );

  static BottomSheetThemeData darkAppBottomSheetTheme = BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: Colors.black,
      modalBackgroundColor: Colors.black,
      constraints: const BoxConstraints(maxWidth: double.infinity ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))

  );

}
import 'package:flutter/material.dart';

/// Helper class for showing standard dialogs throughout the app
class DialogHelper {
  /// Shows a standardized dialog with consistent styling
  static void showStandardDialog({
    required BuildContext context,
    required String title,
    required String message,
    String positiveButtonText = 'OK',
    String? negativeButtonText,
    String? positiveButtonIcon,
    String? negativeButtonIcon,
    VoidCallback? onPositivePressed,
    VoidCallback? onNegativePressed,
    bool barrierDismissible = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 326,
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                    SizedBox(height: 16),

                    // Message
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        fontFamily: 'SF Pro Display',
                        color: Colors.black.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Negative button (if provided)
                        if (negativeButtonText != null)
                          Expanded(
                            child: Container(
                              height: 50,
                              margin: EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  if (onNegativePressed != null) {
                                    onNegativePressed();
                                  }
                                },
                                style: ButtonStyle(
                                  overlayColor: MaterialStateProperty.all(
                                      Colors.transparent),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (negativeButtonIcon != null) ...[
                                      Image.asset(
                                        negativeButtonIcon,
                                        width: 18,
                                        height: 18,
                                      ),
                                      SizedBox(width: 8),
                                    ],
                                    Text(
                                      negativeButtonText,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                        fontFamily: 'SF Pro Display',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Positive button
                        Expanded(
                          child: Container(
                            height: 50,
                            margin: EdgeInsets.only(
                                left: negativeButtonText != null ? 8 : 0),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                if (onPositivePressed != null) {
                                  onPositivePressed();
                                }
                              },
                              style: ButtonStyle(
                                overlayColor: MaterialStateProperty.all(
                                    Colors.transparent),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (positiveButtonIcon != null) ...[
                                    Image.asset(
                                      positiveButtonIcon,
                                      width: 18,
                                      height: 18,
                                    ),
                                    SizedBox(width: 8),
                                  ],
                                  Text(
                                    positiveButtonText,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      fontFamily: 'SF Pro Display',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Close button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/images/closeicon.png',
                      width: 19,
                      height: 19,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:rpmlauncher/Utility/I18n.dart';
import 'package:flutter/material.dart';

class CheckDialog extends StatelessWidget {
  final VoidCallback? onPressedOK;
  final String title;
  final String content;

  const CheckDialog({
    required this.title,
    required this.content,
    required this.onPressedOK,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          child: Text(I18n.format("gui.cancel")),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
            child: Text(I18n.format("gui.confirm")), onPressed: onPressedOK),
      ],
    );
  }
}

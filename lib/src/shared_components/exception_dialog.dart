import 'package:flutter/material.dart';
import 'package:footprint/src/app/common/colors.dart';

class ExceptionDialog extends StatelessWidget {
  const ExceptionDialog({
    super.key,
    VoidCallback? onTryAgain,
    required this.onDismiss,
    required this.message,
  }) : _onTryAgain = onTryAgain;

  final VoidCallback? _onTryAgain;
  final VoidCallback onDismiss;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: const Key('exception-dialog'),
      direction: DismissDirection.horizontal,
      onDismissed: (action) {
        Navigator.of(context).pop();
        onDismiss();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          shape: BoxShape.rectangle,
          color: trueWhite,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.deepOrangeAccent,
                  size: 40,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                  child: Center(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: grayBlue,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Builder(
                  builder: (BuildContext context) {
                    if (_onTryAgain == null) {
                      return TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDismiss();
                        },
                        child: const Text(
                          'Hide',
                          style: TextStyle(fontSize: 18),
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        SizedBox(
                          width: 120,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onDismiss();
                            },
                            child: const Text(
                              'Hide',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _onTryAgain();
                            },
                            child: const Text(
                              'Try again',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

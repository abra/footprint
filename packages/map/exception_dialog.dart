import 'package:flutter/material.dart';

import '../app/common/colors.dart';
import '../component_library/exception_icon.dart';

class ExceptionDialog extends StatelessWidget {
  const ExceptionDialog({
    super.key,
    VoidCallback? onTryAgain,
    required void Function() onDismiss,
    required this.message,
  })  : _onDismiss = onDismiss,
        _onTryAgain = onTryAgain;

  final VoidCallback? _onTryAgain;
  final VoidCallback _onDismiss;
  final String message;

  @override
  Widget build(BuildContext context) => Dismissible(
        key: const Key('exception-dialog'),
        direction: DismissDirection.horizontal,
        onDismissed: (action) {
          Navigator.of(context).pop();
          _onDismiss();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30.0),
            shape: BoxShape.rectangle,
            color: AppColors.simpleWhite,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Add red circle
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.1),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.2),
                          ),
                        ),
                      ),
                      const ExceptionIcon(),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Center(
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.grayBlue,
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
                            _onDismiss();
                          },
                          child: const Text(
                            'Hide',
                            style: TextStyle(
                              color: AppColors.grayBlue,
                              fontSize: 16,
                            ),
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
                                _onDismiss();
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Hide',
                                style: TextStyle(
                                  color: AppColors.grayBlue,
                                  fontSize: 16,
                                ),
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
                                style: TextStyle(
                                  color: AppColors.darkPurple,
                                  fontSize: 16,
                                ),
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

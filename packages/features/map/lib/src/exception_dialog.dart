import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

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
            color: context.appColors.simpleWhite,
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
                      // TODO: Move to component library
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: context.appColors.grayBlue,
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
                          // TODO: Move to component library
                          child: Text(
                            'Hide',
                            style: TextStyle(
                              color: context.appColors.grayBlue,
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
                              // TODO: Move to component library
                              child: Text(
                                'Hide',
                                style: TextStyle(
                                  color: context.appColors.grayBlue,
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
                              // TODO: Move to component library
                              child: Text(
                                'Try again',
                                style: TextStyle(
                                  color: context.appColors.darkPurple,
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

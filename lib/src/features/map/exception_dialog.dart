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
          borderRadius: BorderRadius.circular(30.0),
          shape: BoxShape.rectangle,
          color: AppColors.trueWhite,
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
                    const Icon(
                      Icons.location_off_outlined,
                      color: Colors.red,
                      size: 36,
                    ),
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
                          onDismiss();
                        },
                        child: const Text(
                          'Hide',
                          style: TextStyle(
                            color: AppColors.grayBlue,
                            fontSize: 18,
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
                              onDismiss();
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Hide',
                              style: TextStyle(
                                color: AppColors.grayBlue,
                                fontSize: 18,
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
                                fontSize: 18,
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
}

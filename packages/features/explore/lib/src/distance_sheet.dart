import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

Future<double?> showDistanceSheet(BuildContext context, double distance) =>
    showAppSheet<double>(
      context: context,
      builder: (_) => _DistanceSheet(distance: distance),
    );

class _DistanceSheet extends StatefulWidget {
  const _DistanceSheet({required this.distance});
  final double distance;
  @override
  State<_DistanceSheet> createState() => _DistanceSheetState();
}

class _DistanceSheetState extends State<_DistanceSheet> {
  late final _controller = TextEditingController(
    text: (widget.distance / 1000).toString(),
  );
  final _form = GlobalKey<FormState>();
  double? _kilometers(String? text) =>
      double.tryParse((text ?? '').trim().replaceAll(',', '.'));

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _kilometers(_controller.text)! * 1000);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
    ),
    child: SingleChildScrollView(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Custom distance',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                FTextFormField(
                  control: FTextFieldControl.managed(controller: _controller),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  label: const Text('Distance (km)'),
                  validator: (text) {
                    final value = _kilometers(text);
                    return value == null ||
                            !value.isFinite ||
                            value < 1 ||
                            value > 20
                        ? 'Enter a distance between 1 and 20 km'
                        : null;
                  },
                  onSubmit: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                AppButton(
                  onPressed: _submit,
                  prefix: const Icon(FLucideIcons.check),
                  label: 'Set distance',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

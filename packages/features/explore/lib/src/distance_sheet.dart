import 'package:flutter/material.dart';

Future<double?> showDistanceSheet(BuildContext context, double distance) =>
    showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(
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
                    'Walking distance',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  for (final km in [1, 3, 5, 10])
                    ListTile(
                      title: Text('$km km'),
                      trailing: widget.distance == km * 1000
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, km * 1000.0),
                    ),
                  const Divider(),
                  TextFormField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Custom distance',
                      suffixText: 'km',
                      errorMaxLines: 3,
                    ),
                    validator: (text) {
                      final value = _kilometers(text);
                      return value == null ||
                              !value.isFinite ||
                              value < 1 ||
                              value > 20
                          ? 'Enter a distance between 1 and 20 km'
                          : null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: const Text('Set distance'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

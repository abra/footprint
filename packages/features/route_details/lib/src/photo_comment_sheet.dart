import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

Future<String?> showPhotoCommentSheet(
  BuildContext context, {
  required RoutePhotoDM photo,
  required Future<bool> Function(String) onSave,
}) => showAppSheet<String>(
  context: context,
  builder: (_) => _PhotoCommentSheet(photo: photo, onSave: onSave),
);

class _PhotoCommentSheet extends StatefulWidget {
  const _PhotoCommentSheet({required this.photo, required this.onSave});
  final RoutePhotoDM photo;
  final Future<bool> Function(String) onSave;

  @override
  State<_PhotoCommentSheet> createState() => _PhotoCommentSheetState();
}

class _PhotoCommentSheetState extends State<_PhotoCommentSheet> {
  late final _controller = TextEditingController(text: widget.photo.comment);
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final comment = _controller.text.trim();
    if (comment == widget.photo.comment) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      saved = await widget.onSave(comment);
    } on Object {
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, comment);
    } else {
      setState(() {
        _saving = false;
        _error = 'Comment could not be saved. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Photo comment',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              FTextFormField(
                control: FTextFieldControl.managed(controller: _controller),
                enabled: !_saving,
                label: const Text('Comment'),
                minLines: 3,
                maxLines: 5,
                maxLength: RoutePhotoDM.maxCommentLength,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) =>
                    (value ?? '').trim().characters.length >
                        RoutePhotoDM.maxCommentLength
                    ? 'Use up to ${RoutePhotoDM.maxCommentLength} characters.'
                    : null,
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(color: context.theme.colors.error),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AppButton(
                onPressed: _saving ? null : _save,
                preserveDisabledAppearance: true,
                prefix: const Icon(FLucideIcons.check),
                label: 'Save comment',
              ),
              const SizedBox(height: 8),
              AppButton(
                variant: FButtonVariant.ghost,
                onPressed: _saving ? null : () => Navigator.pop(context),
                label: 'Cancel',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

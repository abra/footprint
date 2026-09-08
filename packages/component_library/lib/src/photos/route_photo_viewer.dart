import 'package:domain_models/domain_models.dart';

import '../app_button.dart';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../route_labels.dart';
import '../action_sheet.dart';
import 'route_photo_image.dart';

Future<void> showRoutePhotoViewer(
  BuildContext context, {
  required List<RoutePhotoDM> photos,
  required RoutePhotoDM selected,
  Future<bool> Function(RoutePhotoDM)? onDelete,
  Future<String?> Function(BuildContext, RoutePhotoDM)? onEditComment,
}) async {
  final index = photos.indexWhere((photo) => photo.id == selected.id);
  if (index < 0) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PhotoViewer(
        photos: List.unmodifiable(photos),
        initialIndex: index,
        onDelete: onDelete,
        onEditComment: onEditComment,
      ),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.photos,
    required this.initialIndex,
    this.onDelete,
    this.onEditComment,
  });
  final List<RoutePhotoDM> photos;
  final int initialIndex;
  final Future<bool> Function(RoutePhotoDM)? onDelete;
  final Future<String?> Function(BuildContext, RoutePhotoDM)? onEditComment;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late int _index = widget.initialIndex;
  late final _pages = PageController(initialPage: _index);
  late final _photos = List<RoutePhotoDM>.of(widget.photos);
  bool _deleting = false;
  bool _editing = false;
  bool get _busy => _deleting || _editing;
  String? _error;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showAppActionSheet<bool>(
      context,
      title: 'Delete photo?',
      message: 'Only the copy attached to this route will be removed.',
      actions: const [
        SheetAction(
          value: true,
          label: 'Delete',
          icon: FLucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final deleted = await widget.onDelete!(_photos[_index]);
      if (!mounted) return;
      if (deleted) {
        Navigator.pop(context);
      } else {
        setState(() => _error = 'Photo could not be deleted.');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _editComment() async {
    if (_busy) return;
    setState(() {
      _editing = true;
      _error = null;
    });
    try {
      final comment = await widget.onEditComment!(context, _photos[_index]);
      if (!mounted || comment == null) return;
      setState(
        () => _photos[_index] = _photos[_index].copyWith(comment: comment),
      );
    } on Object {
      if (mounted) setState(() => _error = 'Comment could not be saved.');
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          tooltip: 'Close photo',
          onPressed: _busy ? null : () => Navigator.pop(context),
          icon: const Icon(FLucideIcons.x),
        ),
        title: Text('${_index + 1} / ${_photos.length}'),
        actions: [
          if (widget.onEditComment != null)
            AppIconButton(
              tooltip: _photos[_index].comment.isEmpty
                  ? 'Add comment'
                  : 'Edit comment',
              onPressed: _busy ? null : _editComment,
              icon: const Icon(FLucideIcons.messageSquare),
            ),
          if (widget.onDelete != null)
            AppIconButton(
              tooltip: 'Delete photo',
              onPressed: _busy ? null : _delete,
              icon: const Icon(FLucideIcons.trash2),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                physics: _busy ? const NeverScrollableScrollPhysics() : null,
                itemCount: _photos.length,
                onPageChanged: (index) => setState(() {
                  _index = index;
                  _error = null;
                }),
                itemBuilder: (context, index) => InteractiveViewer(
                  key: ValueKey(_photos[index].id),
                  maxScale: 5,
                  child: RoutePhotoImage(
                    photo: _photos[index],
                    thumbnail: false,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            if (_photos[_index].comment.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.25,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(_photos[_index].comment),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error ?? RouteLabels.date(context, _photos[_index].capturedAt),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

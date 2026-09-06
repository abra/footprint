import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import '../route_labels.dart';
import 'route_photo_image.dart';

Future<void> showRoutePhotoViewer(
  BuildContext context, {
  required List<RoutePhotoDM> photos,
  required RoutePhotoDM selected,
  Future<bool> Function(RoutePhotoDM)? onDelete,
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
      ),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.photos,
    required this.initialIndex,
    this.onDelete,
  });
  final List<RoutePhotoDM> photos;
  final int initialIndex;
  final Future<bool> Function(RoutePhotoDM)? onDelete;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late int _index = widget.initialIndex;
  late final _pages = PageController(initialPage: _index);
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Delete photo?'),
        content: const Text(
          'Only the copy attached to this route will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final deleted = await widget.onDelete!(widget.photos[_index]);
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close photo',
          onPressed: _deleting ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: Text('${_index + 1} / ${widget.photos.length}'),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              tooltip: 'Delete photo',
              onPressed: _deleting ? null : _delete,
              icon: _deleting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                physics: _deleting
                    ? const NeverScrollableScrollPhysics()
                    : null,
                itemCount: widget.photos.length,
                onPageChanged: (index) => setState(() {
                  _index = index;
                  _error = null;
                }),
                itemBuilder: (context, index) => InteractiveViewer(
                  key: ValueKey(widget.photos[index].id),
                  maxScale: 5,
                  child: RoutePhotoImage(
                    photo: widget.photos[index],
                    thumbnail: false,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error ??
                    RouteLabels.date(context, widget.photos[_index].capturedAt),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

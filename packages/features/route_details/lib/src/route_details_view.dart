import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'route_details_cubit.dart';
import 'route_photo_gallery.dart';

class RouteDetailsView extends StatelessWidget {
  const RouteDetailsView({
    super.key,
    required this.config,
    required this.onClosed,
    required this.justRecorded,
  });
  final MapTileConfig config;
  final ValueChanged<bool> onClosed;
  final bool justRecorded;

  Future<void> _close(BuildContext context) async {
    final state = context.read<RouteDetailsCubit>().state;
    if (state case RouteDetailsReady(:final dirty, :final saving)) {
      if (saving) return;
      if (dirty) {
        final discard = await showAppActionSheet<bool>(
          context,
          title: 'Discard name changes?',
          message: 'The recorded route will be kept.',
          cancelLabel: 'Keep editing',
          actions: const [
            SheetAction(
              value: true,
              label: 'Discard changes',
              icon: Icons.undo,
              destructive: true,
            ),
          ],
        );
        if (discard != true || !context.mounted) return;
      }
    }
    onClosed(false);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<RouteDetailsCubit, RouteDetailsState>(
    listenWhen: (before, after) =>
        after is RouteDetailsReady &&
        after.saved &&
        (before is! RouteDetailsReady || !before.saved),
    listener: (context, state) => onClosed(true),
    builder: (context, state) {
      final ready = state is RouteDetailsReady ? state : null;
      return PopScope(
        canPop: ready == null || ready.saved || (!ready.dirty && !ready.saving),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_close(context));
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(justRecorded ? 'SAVE ROUTE' : 'ROUTE'),
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: ready?.saving == true
                  ? null
                  : () => unawaited(_close(context)),
            ),
            actions: [
              if (ready != null && ready.route.status == Status.completed)
                IconButton(
                  tooltip: 'Save route name',
                  onPressed: ready.saving
                      ? null
                      : () =>
                            unawaited(context.read<RouteDetailsCubit>().save()),
                  icon: ready.saving
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.check,
                          color: Color(0xFF2196F3),
                          size: 30,
                        ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: switch (state) {
              RouteDetailsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              RouteDetailsFailure(:final message) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    TextButton.icon(
                      onPressed: context.read<RouteDetailsCubit>().load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              RouteDetailsReady() => _RouteContent(
                state: state,
                config: config,
              ),
            },
          ),
        ),
      );
    },
  );
}

class _RouteContent extends StatelessWidget {
  const _RouteContent({required this.state, required this.config});
  final RouteDetailsReady state;
  final MapTileConfig config;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.route.status == Status.completed) ...[
            const Text(
              'ROUTE NAME',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _NameField(state: state),
          ] else ...[
            Text(
              RouteLabels.title(context, state.route),
              style: const TextStyle(fontSize: 22),
            ),
            const Text('Recording', style: TextStyle(color: AppTheme.coral)),
          ],
          if (state.error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          const SizedBox(height: 24),
          RouteStats(metrics: state.route.metrics),
          if (state.walk case final walk?) ...[
            const SizedBox(height: 24),
            WalkSummary(progress: walk),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: (constraints.maxHeight - 260).clamp(280, 800),
            child: RoutePreview(
              route: state.route,
              config: config,
              interactive: true,
              photos: state.photos,
            ),
          ),
          RoutePhotoGallery(state: state),
        ],
      ),
    ),
  );
}

class _NameField extends StatefulWidget {
  const _NameField({required this.state});
  final RouteDetailsReady state;
  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _controller = TextEditingController(text: widget.state.name);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    enabled: !widget.state.saving,
    maxLength: 80,
    maxLines: 1,
    textCapitalization: TextCapitalization.sentences,
    textInputAction: TextInputAction.done,
    onChanged: context.read<RouteDetailsCubit>().changeName,
    onSubmitted: (_) => unawaited(context.read<RouteDetailsCubit>().save()),
    decoration: InputDecoration(
      hintText: RouteLabels.title(context, widget.state.route),
      counterText: '',
      suffixIcon: IconButton(
        tooltip: 'Clear name',
        icon: const Icon(Icons.close),
        onPressed: widget.state.saving
            ? null
            : () {
                _controller.clear();
                context.read<RouteDetailsCubit>().changeName('');
              },
      ),
    ),
  );
}

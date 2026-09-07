import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routes_repository/routes_repository.dart';

import 'statistics_cubit.dart';
import 'statistics_view.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({
    super.key,
    required this.repository,
    required this.onBack,
  });

  final RoutesRepository repository;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => StatisticsCubit(repository: repository)..load(),
    child: _Lifecycle(child: StatisticsView(onBack: onBack)),
  );
}

class _Lifecycle extends StatefulWidget {
  const _Lifecycle({required this.child});
  final Widget child;
  @override
  State<_Lifecycle> createState() => _LifecycleState();
}

class _LifecycleState extends State<_Lifecycle> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<StatisticsCubit>().load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

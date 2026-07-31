import 'package:flutter/material.dart';
import 'schedule_store.dart';



class BlockStore {
  final ScheduleStore schedule;
  BlockStore({required this.schedule});
  Future<void> init() async {}
  void dispose() {}
}

class BlockScope extends StatelessWidget {
  final BlockStore store;
  final Widget child;
  const BlockScope({super.key, required this.store, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

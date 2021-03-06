import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'package:repairman/app/app.dart';
import 'package:repairman/app/models/component.dart';
import 'package:repairman/app/models/component_group.dart';
import 'package:repairman/app/models/defect.dart';
import 'package:repairman/app/models/location.dart';
import 'package:repairman/app/models/repair.dart';
import 'package:repairman/app/models/task.dart';
import 'package:repairman/app/models/task_defect_link.dart';
import 'package:repairman/app/models/task_repair_link.dart';
import 'package:repairman/app/models/terminal.dart';
import 'package:repairman/app/models/terminal_component_link.dart';
import 'package:repairman/app/models/terminal_worktime.dart';
import 'package:repairman/app/models/user.dart';
import 'package:repairman/app/modules/api.dart';

enum SyncEvent {
  syncStarted,
  syncCompleted,
  locationExportCompleted
}

class DataSync {
  StreamController<SyncEvent> _streamController = StreamController<SyncEvent>();
  Stream<SyncEvent> stream;
  Timer syncTimer;
  String syncErrors;
  String exportLocationErrors;
  bool _isSyncing = false;
  bool _isSyncingLocations = false;

  static const Duration kSyncTimerPeriod = Duration(minutes: 10);

  DataSync() {
    stream = _streamController.stream.asBroadcastStream();
  }

  DateTime get lastSyncTime {
    String time = App.application.data.prefs.getString('lastSyncTime');
    return time != null ? DateTime.parse(time) : null;
  }
  set lastSyncTime(val) => App.application.data.prefs.setString('lastSyncTime', val.toString());

  void startSyncTimer() {
    syncTimer = _startTimer(syncTimer, _syncTimerCallback);
  }

  void stopSyncTimer() {
    _stopTimer(syncTimer);
  }

  void _syncTimerCallback(Timer curTimer) async {
    try {
      await syncData();
    } on ApiException {}
  }

  Timer _startTimer(Timer timer, Function callback) {
    if (timer == null || !timer.isActive) {
      timer = Timer.periodic(kSyncTimerPeriod, callback);
    }

    return timer;
  }

  void _stopTimer(Timer timer) {
    if (timer != null && timer.isActive) {
      timer.cancel();
    }
  }

  Future<void> syncData() async {
    if (_isSyncing) return;

    try {
      _streamController.add(SyncEvent.syncStarted);
      _isSyncing = true;
      bool needImport = App.application.config.autoRefresh;
      Map<String, dynamic> exportData = await _dataForExport();

      if (exportData.values.any((val) => val.isNotEmpty)) {
        await _exportData(exportData);
        needImport = true;
      }

      if (needImport) {
        await _importData();
      }

      syncErrors = null;
    } on ApiException catch(e) {
      syncErrors = e.errorMsg;
      rethrow;
    } finally {
      lastSyncTime = DateTime.now();
      _isSyncing = false;
      _streamController.add(SyncEvent.syncCompleted);
    }
  }

  Future<void> _importData() async {
    Map<String, dynamic> importData = await App.application.api.get('v2/repairman');

    Batch batch = App.application.data.db.batch();
    await App.application.config.importRemote(importData['app']);
    await User.import(importData['user']);
    await Component.import(importData['components'], batch);
    await ComponentGroup.import(importData['component_groups'], batch);
    await Defect.import(importData['defects'], batch);
    await Repair.import(importData['repairs'], batch);
    await Terminal.import(importData['terminals'], batch);
    await TerminalComponentLink.import(importData['terminal_component_links'], batch);
    await TerminalWorktime.import(importData['terminal_worktimes'], batch);
    await Task.import(importData['tasks'], batch);
    await TaskDefectLink.import(importData['task_defect_links'], batch);
    await TaskRepairLink.import(importData['task_repair_links'], batch);
    await batch.commit();
  }

  Future<Map<String, dynamic>> _dataForExport() async {
    return {
      'tasks': await Task.export(),
      'terminal_component_links': await TerminalComponentLink.export(),
      'task_defect_links': await TaskDefectLink.export(),
      'task_repair_links': await TaskRepairLink.export(),
    };
  }

  Future<void> _exportData(Map<String, dynamic> exportData) async {
    await App.application.api.post('v2/repairman/save', body: exportData);
  }

  Future<void> exportLocations() async {
    if (_isSyncingLocations) return;

    try {
      _isSyncingLocations = true;
      await _syncLocations();
    } finally {
      _isSyncingLocations = false;
    }

    _streamController.add(SyncEvent.locationExportCompleted);
  }

  Future<void> _syncLocations() async {
    while (await Location.hasNew()) {
      List<Location> locations = await Location.allNew();

      try {
        await App.application.api.post('v2/repairman/locations', body: {
          'locations': locations.map((req) => req.toExportMap()).toList()
        });

        exportLocationErrors = null;
        await Future.wait(locations.map((location) async => await location.markInserted(false)));
      } on ApiException catch(e) {
        exportLocationErrors = e.errorMsg;
        await Future.wait(locations.map((location) async => await location.markInserted(true)));
      }
    }
  }
}

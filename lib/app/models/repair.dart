import 'dart:async';

import 'package:repairman/app/app.dart';
import 'package:repairman/app/models/database_model.dart';
import 'package:repairman/app/utils/nullify.dart';

class Repair extends DatabaseModel {
  static final String _tableName = 'repairs';
  int localId;
  DateTime localTs;

  int id;
  String name;

  get tableName => _tableName;

  Repair(Map<String, dynamic> values) {
    build(values);
  }

  void build(Map<String, dynamic> values) {
    id = values['id'];
    name = values['name'];
    localId = values['local_id'];
    localTs = Nullify.parseDate(values['local_ts']);
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = Map<String, dynamic>();
    map['id'] = id;
    map['name'] = name;

    return map;
  }

  static Future<Repair> create(Map<String, dynamic> values) async {
    Repair rec = Repair(values);
    await rec.insert();
    await rec.reload();
    return rec;
  }

  static Future<void> deleteAll() async {
    await App.application.data.db.delete(_tableName);
  }

  static Future<List<Repair>> all() async {
    return (await App.application.data.db.query(_tableName)).map((rec) => Repair(rec)).toList();
  }

  static Future<void> import(List<dynamic> recs) async {
    await Repair.deleteAll();
    await Future.wait(recs.map((rec) => Repair.create(rec)));
  }
}
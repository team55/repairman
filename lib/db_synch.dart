import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:great_circle_distance/great_circle_distance.dart';

//следует получше понеймить роуты
const String taskPageRoute = "/tasks";
const String terminalsPageRoute = "/terminals";
const String taskSubpageRoute = "/tasks/one";
const String taskSubpageRouteComment = "/tasks/one/comment";
const String taskSubpageCgroupRoute = "/tasks/one/cgroup";
const String taskSubpageComponentRoute = "/tasks/one/cgroup/component";
const String terminalPageRoute = "/terminal";

const String taskDefectsSubpageRoute = "/tasks/one/defects";
const String taskRepairsSubpageRoute = "/tasks/one/repairs";

final dateFormat = new DateFormat("HH:mm dd.MM.yy") ;
final numFormat = new NumberFormat("#,##0.00", "ru_RU");


String fmtSrok(DateTime date) {

  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  if (date==null) {
    return "";
  }
  else
  {
    DateTime today = new DateTime(new DateTime.now().year, new DateTime.now().month, new DateTime.now().day);
    DateTime yesterday = today.subtract(new Duration(days:1));
    DateTime yesterday2 = today.subtract(new Duration(days:2));
    DateTime tomorrow = today.add(new Duration(days:1));
    DateTime tomorrow2 = today.add(new Duration(days:2));
    DateTime tomorrow3 = today.add(new Duration(days:3));
    String strdate;

    if ((date.isAfter(yesterday2))&&(date.isBefore(yesterday))) {strdate="Позавчера, ";}
    if ((date.isAfter(yesterday))&&(date.isBefore(today))) {strdate="Вчера, ";}
    if ((date.isAfter(today))&&(date.isBefore(tomorrow))) {strdate="";}
    if ((date.isAfter(tomorrow))&&(date.isBefore(tomorrow2))) {strdate="Завтра, ";}
    if ((date.isAfter(tomorrow2))&&(date.isBefore(tomorrow3))) {strdate="Послезавтра, ";}
    if (strdate==null) {strdate = _twoDigits(date.day)+"."+_twoDigits(date.month)+" ";}

    return strdate+date.hour.toString()+":"+_twoDigits(date.minute);
  }

}

class DbSynch {
  Database db;
  String login;
  String password;
  String clientId = "repairman";
  String server;
  String token;
  int dbTerminalId=0;
  String clientName="";
  int closed=0;
  Location location = new Location();

  int curTask;
  String curCGroup;
  String curComment="";

  Future<Null> saveGeo() async {
    List<Map> locations;
    var response;
    var data;
    bool isError = false;
    try {
      locations = await db.rawQuery("select latitude, longitude, accuracy, altitude, ts from location");
      if (token==null) {
        String s = (await makeConnection());
        if (s != null) {
          print("Connection error! $s");
          isError = true;
        }
      }
      if (!isError) {
        var httpClient = createHttpClient();
        String url = server + "repairman/locations";
        try {
          response = await httpClient.post(url,
            headers: {"Authorization": "RApi client_id=$clientId,token=$token",
                      "Accept": "application/json", "Content-Type": "application/json"},
            body: JSON.encode(locations)
          );
        } catch(exception) {
          print('Сервер $server недоступен!\n$exception');
          isError = true;
        }
      }
      if (!isError) {
        try {
          data = JSON.decode(response.body);
          if (data["error"] != null) {
              print(data["error"]);
              isError = true;
          }
        } catch(exception) {
          print('Ответ сервера: ${response.body}\n$exception');
          isError = true;
        }
      }
      if (!isError) {
        print("Ok Save!");
        double distance = await getDistance();
        await db.execute("UPDATE info SET value = $distance WHERE name = 'distance'");
        await db.execute("DELETE FROM location WHERE ts < (SELECT max(ts) FROM location)");
      }
    } catch(exception) {
      print("Ошибка! $exception");
    }

    new Timer(const Duration(minutes: 2), saveGeo);
    return;
  }

  Future<Null> getGeo() async {
    Map<String,double> myLocation;
    try {
      myLocation = await location.getLocation;
      await db.insert("location", {
        "latitude": myLocation["latitude"],
        "longitude": myLocation["longitude"],
        "accuracy": myLocation["accuracy"],
        "altitude": myLocation["altitude"]
      });
    } catch(exception) {
      print("Ошибка! $exception");
    }

    new Timer(const Duration(seconds: 30), getGeo);
    return;
  }

  Future<Database> initDB() async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    String path = "$dir/repairman_db.db";
    print ("$path");
    bool isUpgrage;

    location.onLocationChanged.listen((Map<String,double> result) {
    });

    do {
      isUpgrage = false;
      // open the database
      db = await openDatabase(path, version: 1,
        onCreate: (Database d, int version) async {
          await d.execute("""
            CREATE TABLE info(
              id INTEGER PRIMARY KEY,
              name TEXT,
              value TEXT,
              ts DATETIME DEFAULT CURRENT_TIMESTAMP
            )"""
          );

          await d.execute("""
            CREATE TABLE task(
              id INTEGER PRIMARY KEY,
              servstatus INTEGER,
              dobefore DATETIME,
              terminal INTEGER,
              terminalbreakname TEXT,
              routepriority INTEGER,
              terminalxid TEXT,
              comment TEXT,
              updcommentflag INTEGER DEFAULT 0,
              ts DATETIME DEFAULT CURRENT_TIMESTAMP
            )"""
          );

          await d.execute("""
            CREATE TABLE terminal(
              id INTEGER PRIMARY KEY,
              xid TEXT,
              code TEXT,
              address TEXT,
              lastactivitytime DATETIME,
              lastpaymenttime DATETIME,
              errortext TEXT,
              src_system_name TEXT,
              latitude DECIMAL,
              longitude DECIMAL,
              mobileop TEXT
            )"""
          );

          await d.execute("""
            CREATE TABLE component(
              id INTEGER PRIMARY KEY,
              short_name TEXT,
              serial TEXT,
              xid TEXT,
              componentgroupxid TEXT
            )"""
          );

          //Некоторые поля, возможно, бесполезны. Непонятно с PK
          await d.execute("""
            CREATE TABLE taskcomponent(
              taskid INTEGER,
              taskxid TEXT,
              component INT,
              componentxid TEXT,
              xid TEXT,
              terminalId INT,
              terminalxid TEXT,
              isBroken INT,
              id INT
            )"""
          );

          await d.execute("""
            CREATE TABLE terminalcomponent(
              terminalid INT,
              componentid INT,
              componentgroupxid TEXT,
              short_name TEXT,
              serial TEXT
            )"""
          );

          await d.execute("""
            CREATE TABLE componentgroup(
              id INTEGER PRIMARY KEY,
              xid TEXT,
              name TEXT,
              isManualReplacement INT
            )"""
          );

          await d.execute("""
            CREATE TABLE repairs(
              id INTEGER PRIMARY KEY,
              name TEXT
            )"""
          );

          await d.execute("""
            CREATE TABLE defects(
              id INTEGER PRIMARY KEY,
              name TEXT
            )"""
          );

          await d.execute("""
            CREATE TABLE taskdefectlink(
              id INTEGER PRIMARY KEY DEFAULT AUTO_INCREMENT,
              task_id INTEGER,
              defect_id INTEGER,
              syncstatus INTEGER DEFAULT 0
            )"""
          );

          await d.execute("""
            CREATE TABLE taskrepairlink(
              id INTEGER PRIMARY KEY DEFAULT AUTO_INCREMENT,
              task_id INTEGER,
              repair_id INTEGER,
              syncstatus INTEGER DEFAULT 0
            )"""
          );

          await d.execute("""
            CREATE TABLE terminalcomponentlink(
              id INT PRIMARY KEY DEFAULT AUTO_INCREMENT,
              comp_id INT,
              task_id INT,
              is_removed INT,
              syncstatus INTEGER DEFAULT 0
            )"""
          );

          await d.execute("""
            CREATE TABLE location(
              latitude  DECIMAL(18,10),
              longitude DECIMAL(18,10),
              accuracy  DECIMAL(18,10),
              altitude  DECIMAL(18,10),
              ts        DATETIME DEFAULT CURRENT_TIMESTAMP
            )"""
          );

          await d.insert("info", {"name":"server", "value":"http://localhost:3000/api/v1/"});
          await d.insert("info", {"name":"client_id", "value":clientId});
          await d.insert("info", {"name":"login"});
          await d.insert("info", {"name":"password"});
          await d.insert("info", {"name":"token"});
          await d.insert("info", {"name":"distance", "value": "0"});
        },
        onUpgrade: (Database database, int oldVersion, int newVersion) async {
          isUpgrage = true;
        },
        onDowngrade: (Database database, int oldVersion, int version) async {
          isUpgrage = true;
        },
      );
      if (isUpgrage) {
        db.close;
        await deleteDatabase(path);
      }
    } while (isUpgrage);

    List<Map> list = await db.rawQuery("""
      select (select value from info where name = 'login') login,
             (select value from info where name = 'password') password,
             (select value from info where name = 'client_id') client_id,
             (select value from info where name = 'server') server,
             (select value from info where name = 'token') token
    """);
    login = list[0]['login'];
    password = list[0]['password'];
    clientId = list[0]['client_id'];
    server = list[0]['server'];
    token = list[0]['token'];
    await makeConnection();
    return db;
  }


  Future<Null> updateLogin(String s) async {
    login = s.trim();
    await db.execute("UPDATE info SET value = '$login' WHERE name = 'login'");
  }

  Future<Null> updatePwd(String s) async {
    password = s.trim();
    await db.execute("UPDATE info SET value = '$password' WHERE name = 'password'");
  }

  Future<Null> updateSrv(String s) async {
    server = s.trim();
    await db.execute("UPDATE info SET value = '$server' WHERE name = 'server'");
  }

  Future<Null> updateComment(String s) async {
    await db.execute("UPDATE task SET updcommentflag = 1, comment = '$s' WHERE id = $curTask");
    curComment = s;
  }


  Future<String> makeConnection() async {
    var httpClient = createHttpClient();
    String url = server + "authenticate";
    var response;

    try {
      response = await httpClient.post(url,
        headers: {"Authorization": "RApi login=$login,client_id=$clientId,password=$password"}
      );
    } catch(exception) {
      return 'Сервер $server недоступен!\n$exception';
    }
    Map data;
    try {
      data = JSON.decode(response.body);
    } catch(exception) {
      return 'Ответ сервера: ${response.body}\n$exception';
    }
    token = data["token"];
    await db.execute("UPDATE info SET value = '$token' WHERE name = 'token'");
    return data["error"];
  }

  Future<String> resetPassword() async {
    var httpClient = createHttpClient();
    String url = server + "reset_password";
    var response;
    try {
      response = await httpClient.post(url,
        headers: {"Authorization": "RApi login=$login,client_id=$clientId"}
      );
    } catch(exception) {
      return 'Сервер $server недоступен!\n$exception';
    }
    Map data;
    try {
      data = JSON.decode(response.body);
    } catch(exception) {
      return 'Ответ сервера: ${response.body}\n$exception';
    }
    return data["error"];
  }


Future<String> fillDB() async {
  String s;
  int i = 0;
  var data;
  var response;

  do {
    if (token==null) {
      s = (await makeConnection());
      if (s != null) {
        return s;
      }
    }
    var httpClient = createHttpClient();
    String url = server + "repairman";
    try {
      print("url = $url i = $i");
      print("RApi client_id=$clientId,token=$token");
      response = await httpClient.get(url,
        headers: {"Authorization": "RApi client_id=$clientId,token=$token"}
      );
    } catch(exception) {
      return 'Сервер $server недоступен!\n$exception';
    }


    data = JSON.decode(response.body);
//Пока без этого, но ошибку обработать будет нужно
/*
    try {
      data = JSON.decode(response.body);
      if (data["error"] != null) {
        if (i == 1) {
          return data["error"];
        }
        token = null;
        i++;
      } if(data["closed"] == null) {
        return 'Ответ сервера: ${response.body}';
      }
    } catch(exception) {
      return 'Ответ сервера: ${response.body}\n$exception';
    }
  */
  } while (i == 1);


  await db.execute("DELETE FROM task");
  await db.execute("DELETE FROM terminal");
  await db.execute("DELETE FROM componentgroup");
  await db.execute("DELETE FROM component");
  await db.execute("DELETE FROM taskcomponent");
  await db.execute("DELETE FROM terminalcomponent");


  await db.execute("DELETE FROM repairs");
  await db.execute("DELETE FROM defects");
  await db.execute("DELETE FROM taskdefectlink");
  await db.execute("DELETE FROM taskrepairlink");


  for (var tasks in data["tasks"]) {
    await db.execute("""
      INSERT INTO task (id, servstatus, dobefore, terminalbreakname, routepriority, terminal, terminalxid, comment)
      VALUES(${tasks["id"]},
             ${tasks["servstatus"]},
             '${tasks["dobefore"]}',
             '${tasks["terminal_break_name"]}',
             '${tasks["route_priority"]}',
             '${tasks["terminal"]}',
             '${tasks["terminal_xid"]}',
             '${tasks["comm"]}')
    """);
  }

  for (var terminals in data["terminals"]) {
    await db.execute("""
      INSERT INTO terminal (id, xid, code, address, lastactivitytime, lastpaymenttime, errortext, src_system_name, latitude, longitude, mobileop)
      VALUES(${terminals["id"]},
             '${terminals["xid"]}',
             '${terminals["code"]}',
             '${terminals["address"]}',
             '${terminals["lastactivitytime"]}',
             '${terminals["lastpaymenttime"]}',
             '${terminals["errortext"]}',
             '${terminals["src_system_name"]}',
             ${terminals["latitude"]},
             ${terminals["longitude"]},
             '${terminals["mobileop"]}')
    """);
  }

  for (var componentgroups in data["componentgroups"]) {
    await db.execute("""
      INSERT INTO componentgroup (id, xid, name, isManualReplacement)
      VALUES(${componentgroups["id"]},
             '${componentgroups["xid"]}',
             '${componentgroups["name"]}',
             ${componentgroups["isManualReplacement"]})
    """);
  }

  for (var components in data["components"]) {
    await db.execute("""
      INSERT INTO component (id,short_name,serial,xid,componentgroupxid)
      VALUES(${components["id"]},
             '${components["short_name"]}',
             '${components["serial"]}',
             '${components["xid"]}',
             '${components["componentgroupxid"]}')
    """);
  }

  for (var terminalcomponents in data["terminalcomponents"]) {
    await db.execute("""
      INSERT INTO terminalcomponent(terminalid,componentid,componentgroupxid,short_name,serial)
      VALUES(${terminalcomponents["terminalid"]},
             ${terminalcomponents["componentid"]},
             '${terminalcomponents["componentgroupxid"]}',
             '${terminalcomponents["short_name"]}',
             '${terminalcomponents["serial"]}')
    """);
  }


  for (var repairs in data["repairs"]) {
    await db.execute("""
      INSERT INTO repairs (id,name)
      VALUES(${repairs["id"]},
             '${repairs["repair_name"]}')
    """);
  }

  for (var defects in data["defects"]) {
    await db.execute("""
      INSERT INTO defects (id,name)
      VALUES(${defects["id"]},
             '${defects["name"]}')
    """);
  }

  for (var taskdefectlink in data["taskdefectlink"]) {
    await db.execute("""
      INSERT INTO taskdefectlink (task_id,defect_id)
      VALUES(${taskdefectlink["task_id"]},
             ${taskdefectlink["defect_id"]})
    """);
  }

    for (var taskrepairlink in data["taskrepairlink"]) {
      await db.execute("""
        INSERT INTO taskrepairlink (task_id,repair_id)
        VALUES(${taskrepairlink["task_id"]},
               ${taskrepairlink["repair_id"]})
      """);
  }




for (var taskcomponents in data["taskcomponents"]) {
  await db.execute("""
    INSERT INTO taskcomponent(taskid,taskxid,component,componentxid,xid,terminalId,terminalxid,isBroken,id)
    VALUES(${taskcomponents["taskid"]},
           '${taskcomponents["taskxid"]}',
           ${taskcomponents["component"]},
           '${taskcomponents["componentxid"]}',
           '${taskcomponents["xid"]}',
           ${taskcomponents["terminalId"]},
           '${taskcomponents["terminalxid"]}',
           ${taskcomponents["isBroken"]},
           ${taskcomponents["id"]})
  """);
}


  return null;

}

Future<List<Map>> getTasks() async {
  List<Map> list;
  list = await db.rawQuery("""
    select
      task.id,
      task.servstatus,
      task.dobefore,
      task.terminalbreakname,
      task.routepriority,
      terminal.code,
      terminal.address
   from task
        left outer join terminal on terminal.id = task.terminal
   order by servstatus, routepriority DESC, dobefore
  """);
  //Еще нужна сортировка по tt.code
  //Нужна ли какая-то проверка на случай если таск есть а терминала нет?
  return list;
}

Future<List<Map>> getTerminals() async {
  List<Map> list;
  list = await db.rawQuery("""
    select
           id,
           code,
           address,
           lastactivitytime,
           lastpaymenttime,
           errortext,
           src_system_name,
           latitude,
           longitude,
           mobileop
      from terminal
    where errortext<>'null'
  """); //Нулл в кавычках - АД. Но пока работает только так.
//Нет сортировки, какая-то нужна
  return list;
}

Future<List<Map>> getComponent(int taskId, String cgroupXid) async {
  List<Map> list;

  list = await db.rawQuery("""
   select short_name, serial, 1 preinstflag,
          (select count(1) from terminalcomponentlink tcl where tcl.comp_id = terminalcomponent.componentid and tcl.task_id = $taskId) chflag
     from terminalcomponent
    where componentgroupxid = '$cgroupXid' and
          terminalid = (select terminal from task where id = $taskId)
union all
    select short_name, serial, 0 preinstflag,
           (select count(1) from terminalcomponentlink tcl where tcl.comp_id = component.id and tcl.task_id = $taskId) chflag
      from component
     where componentgroupxid = '$cgroupXid'
order by preinstflag DESC
  """);

  return list;

}

Future<List<Map>> getCGroups(int taskId) async {
  List<Map> list;
  ////not exists (select * from taskcomponent where componentxid = c.xid and coalesce(removed, '0') <> '1') and
  list = await db.rawQuery("""
    select
           id,
           xid,
           name,
           isManualReplacement,
           (select count(*) from component c
            where c.componentgroupxid = cg.xid) freeremains,
           (select count(*)
              from terminalcomponent tc
             where tc.componentgroupxid = cg.xid and
                   tc.terminalid = (select terminal from task where id = $taskId)) preinstcnt
   from componentgroup cg
  where freeremains > 0
  """);

  return list;
}

Future<List<Map>> getTerminal() async {
  List<Map> list;
  list = await db.rawQuery("""
    select
           id,
           code,
           address,
           lastactivitytime,
           lastpaymenttime,
           errortext,
           src_system_name,
           latitude,
           longitude,
           mobileop
      from terminal
    where id = $dbTerminalId
  """);
  return list;
}

Future<List<Map>> getTerminalTasks() async {
  List<Map> list;
  list = await db.rawQuery("""
    select
      id,
      servstatus,
      dobefore,
      terminalbreakname,
      routepriority
   from
      task
  where
      terminal = $dbTerminalId
   order by servstatus, routepriority DESC, dobefore
  """);
  return list;
}

//Нужно отобрать весь справочник дефектов, передав status=1 там, где была вставлена запись.. гм.. оч понятно =)
Future<List<Map>> getDefects(int taskId) async {
  List<Map> list;

  //СОРТИРОВКА?!
  list = await db.rawQuery("""
    select
           defects.id defect_id,
           defects.name,
           CASE WHEN taskdefectlink.id IS NOT NULL THEN 1 ELSE 0 END status
   from defects
        left outer join taskdefectlink on taskdefectlink.task_id = $taskId and
                                          taskdefectlink.defect_id = defects.id and
                                          taskdefectlink.syncstatus <> -1
  """);

  //if taskdefectlink.id is not null then 1 else 0 endif status
  return list;
}

Future<List<Map>> getOneTask(int taskId) async {
  List<Map> list;

  list = await db.rawQuery("""
    select (select count(*)
              from taskdefectlink
             where taskdefectlink.task_id = task.id and
                   taskdefectlink.syncstatus <> -1) defectcnt,
           (select count(*)
              from taskrepairlink
             where taskrepairlink.task_id = task.id and
                   taskrepairlink.syncstatus <> -1) repaircnt,
           task.terminalbreakname terminalbreakname,
           terminal.code code,
           task.dobefore dobefore,
           task.servstatus servstatus,
           task.routepriority routepriority,
           terminal.latitude latitude,
           terminal.longitude longitude,
           task.comment comm
      from task
           left outer join terminal on terminal.id = task.terminal
     where task.id = $taskId
  """);

  return list;

}

Future<double> getDistance() async {
  double distance = 0.0;
  double lat1 = 0.0;
  double lon1 = 0.0;

  double lat2 = 0.0;
  double lon2 = 0.0;

  List<Map> ld = await db.rawQuery("select value from info where name = 'distance'");
  if (ld.length > 0) {
    distance = double.parse(ld[0]['value']);
  }

  List<Map> list = await db.rawQuery("select latitude, longitude from location order by ts");
  int i = 0;
  for(Map r in list) {
    if (i > 0) {
      lat1 = lat2;
      lon1 = lon2;
      lat2 = r["latitude"];
      lon2 = r["longitude"];
      distance += new GreatCircleDistance.fromDegrees(
            latitude1: lat1, longitude1: lon1, latitude2: lat2, longitude2: lon2).haversineDistance() / 1000.0;
    }
    else {
      lat2 = r["latitude"];
      lon2 = r["longitude"];
    }
    i++;
  }
  return distance;
}




Future<Null> updateComponent(int compId, int taskId, int preinstflag, int status) async {


}


//List<Map> list = await widget.cfg.database.rawQuery("SELECT MAX(ts) mts FROM schedule_requests");
//DateTime ts = DateTime.parse(list[0]['mts']).add(new Duration(hours: 3));

//Как-то стремно в целом выглядит вся эта процедура О_О
Future<String> updateDefect(int taskId, int defectId, bool status) async {
int id;
int syncstatus;
//Возможно стоит сделать проверку на странное сочетание статусов,
//типа поставить 1 когда уже стоит 1

print("updateDefect. task_id=$taskId  defect_id=$defectId  newstatus = $status");

List<Map> list = await db.rawQuery("SELECT id, syncstatus FROM taskdefectlink WHERE task_id = $taskId and defect_id = $defectId");
print("Лок. запись: id = $id  syncstatus = $syncstatus");
  if (list.length > 0) {
    id = list[0]['id'];
    syncstatus = list[0]['syncstatus'];
  }
  if (status == true) {
    if (syncstatus==null) {
      print("  <1> вставляем в # с сюнкстатусом 1");
      await db.execute("insert into taskdefectlink (task_id, defect_id, syncstatus) select $taskId, $defectId, 1");
    } else {
      print("  <2> апдейтим в # на сюнкстатус 0");
      await db.execute("update taskdefectlink set syncstatus = 0 where id = $id");
    }
  } else {
    if (syncstatus==0) {
      print("  <3> апдейтим в # на сюнкстатус -1");
      await db.execute("update taskdefectlink set syncstatus = -1 where id = $id");
    } else {
      print("  <4> удаляем запись из #");
      await db.execute("delete from taskdefectlink where id = $id");
    }
  }

  return null;
}


Future<String> synchDB() async {
  //var response;
  List<Map> taskdefectlink;
  List<Map> info;
  List<Map> comments;

  taskdefectlink = await db.rawQuery("select task_id, defect_id, syncstatus from taskdefectlink where syncstatus <> 0");
  info = await db.rawQuery("select id, name from info");
  comments = await db.rawQuery("select id, comment from task where updcommentflag = 1");

  var httpClient = createHttpClient();
  String url = server + "repairman/save";
  try {
    print("url = $url");
    print("RApi client_id=$clientId,token=$token");
    /*response =*/ await httpClient.post(url,
      headers: {"Authorization": "RApi client_id=$clientId,token=$token",
                "Accept": "application/json", "Content-Type": "application/json"},
      body: JSON.encode({"taskdefectlink": taskdefectlink, "info": info, "comments": comments})
    );

    //После успешного выполнения надо удалить со статусом -1 а статус 1 перебросить на 0
    //Либо же запросить заново всю БД, как?
  } catch(exception) {
    return 'Сервер $server недоступен!\n$exception';
  }


  return null;

/*
  String s;
  int i = 0;
  var data;
  list = await db.rawQuery("select * from repayment r");

  do {
    if (token==null) {
      s = (await makeConnection());
      if (s != null) {
        return s;
      }
    }
    var httpClient = createHttpClient();
    String url = server + "forwarder/save";
    try {
      print("url = $url");
      print("RApi client_id=$clientId,token=$token");
      response = await httpClient.post(url,
        headers: {"Authorization": "RApi client_id=$clientId,token=$token",
                  "Accept": "application/json", "Content-Type": "application/json"},
        body: JSON.encode(list)
      );
    } catch(exception) {
      return 'Сервер $server недоступен!\n$exception';
    }
    try {
      data = JSON.decode(response.body);
      if (data["error"] != null) {
        if (i == 1) {
          return data["error"];
        }
        token = null;
        i++;
      }
    } catch(exception) {
      return 'Ответ сервера: ${response.body}\n$exception';
    }
  } while (i == 1);

  for (var i = 0; i < list.length; i++) {
    list[i]["repayment_id"] = data["repayment"][i];
    await db.execute("""
      UPDATE repayment
      SET repayment_id = ${list[i]["repayment_id"]}
      WHERE debt_id=${list[i]["debt_id"]}
    """);
  }
  return null;
*/
}





}

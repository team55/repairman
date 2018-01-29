import 'package:flutter/material.dart';
import 'db_synch.dart';


Widget oneTerminal(DbSynch cfg, BuildContext context, String code, DateTime lastactivitytime, String address, int terminalId) {


return new GestureDetector(
           onTap: () async
           {
              cfg.dbTerminalId = terminalId;
              await Navigator.of(context).pushNamed(terminalPageRoute);
           },
           child: new Container(
                height: 48.0,
                decoration: const BoxDecoration(
                  border: const Border(
                        bottom: const BorderSide(width: 1.0, color: const Color(0xFFFF000000))
                )),
                child:
                   new Column(
                     children: <Widget>[
                       new Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: <Widget>[
                           new Text(code),
                           new Text(dateFormat.format(lastactivitytime), style: new TextStyle(color: Colors.blue)),
                         ]
                       ),
                       new Text(address, style: new TextStyle(color: Colors.green, fontSize: 12.0))
                     ]
                   )
                )
         );
}





class TerminalsPage extends StatefulWidget {
  TerminalsPage({Key key, this.cfg}) : super(key: key);
  final DbSynch cfg;
  @override
  _TerminalsPageState createState() => new _TerminalsPageState(cfg: cfg);
}

class _TerminalsPageState extends State<TerminalsPage> {
  _TerminalsPageState({this.cfg});
  DbSynch cfg;
  List<Widget> terminallist;
  List<Map> _terminals=[];

  @override
  void initState() {
    super.initState();
    cfg.getTerminals().then((List<Map> list){
      setState((){
        _terminals = list;
      });
    });
  }

  @override
  Widget build(BuildContext context) {

    terminallist = [];
    for (var r in _terminals) {

      print(r["errortext"]);
      print("---------");
      terminallist.add(oneTerminal(cfg, context,r["code"],DateTime.parse(r["lastactivitytime"]),r["address"], r["id"] ));

    }


    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Терминалы")
      ),
      body: new ListView(
      shrinkWrap: true,
      children: terminallist,
    )
    );
  }
}

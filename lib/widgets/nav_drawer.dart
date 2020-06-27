import 'package:flutter/material.dart';

class NavDrawer extends StatelessWidget {
  final List<String> entries = <String>['sA', 'sB', 'sC'];
  final List<int> colorCodes = <int>[100, 100, 100];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            child: Text(
              'Side menu',
              style: TextStyle(color: Colors.white, fontSize: 25),
            ),
            decoration: BoxDecoration(
              color: Colors.green,
            ),
          ),
          ListView.separated(
            padding: const EdgeInsets.all(8),
            scrollDirection: Axis.vertical,
            shrinkWrap: true,
            itemCount: entries.length,
            itemBuilder: (BuildContext context, int index) {
              return Container(
                height: 30,
                color: Colors.amber[colorCodes[index]],
                child: Text('Entry ${entries[index]}'),
              );
            },
            separatorBuilder: (BuildContext context, int index) => Divider(
              color: Colors.grey[300],
              height: 5,
              thickness: 2,
            ),
          ),
        ],
      ),
    );
  }
}
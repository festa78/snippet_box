import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NavDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: ListView(padding: EdgeInsets.zero, children: <Widget>[
      DrawerHeader(
        child: Text(
          'Tag list',
          style: TextStyle(color: Colors.white, fontSize: 25),
        ),
        decoration: BoxDecoration(
          color: Colors.green,
        ),
      ),
      StreamBuilder<QuerySnapshot>(
          stream: Firestore.instance.collection('tag_list').snapshots(),
          builder:
              (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) return new Text('Error: ${snapshot.error}');
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return new Text('Loading...');
              default:
                return new ListView(
                  shrinkWrap: true,
                  children:
                      snapshot.data.documents.map((DocumentSnapshot document) {
                    return new GestureDetector(
                        child: new Card(
                            child: ListTile(
                                title: new Text(document.documentID),
                                subtitle: new Text(
                                    '(${document['documents'].length})'))));
                  }).toList(),
                );
            }
          })
    ]));
  }
}

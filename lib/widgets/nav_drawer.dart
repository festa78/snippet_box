import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/models/user.dart';

class NavDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<SnippetBoxUser>(context);

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
          stream: FirebaseFirestore.instance
              .collection('user_data')
              .doc(userData.uid)
              .collection('tags')
              .snapshots(),
          builder:
              (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) return new Text('Error: ${snapshot.error}');
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return new Text('Loading...');
              default:
                return new ListView(
                  shrinkWrap: true,
                  children: snapshot.data.docs.map((DocumentSnapshot document) {
                    return new GestureDetector(
                        child: new Card(
                            child: ListTile(
                                title: new Text(document.id),
                                subtitle: new Text(
                                    '(${document['documents'].length})'))));
                  }).toList(),
                );
            }
          })
    ]));
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ItemList extends StatelessWidget {
  _navigate(context, document) async {
    if (await canLaunch(document['uri'])) {
      await launch(document['uri']);
    } else {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (
            context,
          ) =>
                  SecondRoute()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: Firestore.instance.collection('test_list').snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
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
                    onTap: () => _navigate(context, document),
                    child: new Card(
                        child: ListTile(
                      title: new Text(document['title']),
                      subtitle: new Text(document['tags'].join(',')),
                    )));
              }).toList(),
            );
        }
      },
    );
  }
}

class SecondRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Second Route"),
      ),
      body: Center(child: Text('Go back!')),
    );
  }
}

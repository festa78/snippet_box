import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ItemList extends StatelessWidget {
  _navigate(context, document) async {
    if (await canLaunch(document['uri'])) {
      await launch(document['uri']);
    } else if (!document['text'].isEmpty) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (
            context,
          ) =>
                  SecondRoute(document)));
    } else {
      throw 'Cannot read document $document';
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
  const SecondRoute(this.document);

  final DocumentSnapshot document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(this.document['title']),
      ),
      // Needs to relocate \n to enable Text to recognize.
      body: Center(child: Text(this.document['text'].replaceAll('\\n', '\n'))),
    );
  }
}

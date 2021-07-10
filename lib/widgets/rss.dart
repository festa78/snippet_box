import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:webfeed/webfeed.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:myapp/models/user.dart';

enum FeedTypes {
  ATOM,
  RSS,
}

_createDialogOption(BuildContext context, FeedTypes feedType, String str) {
  return new SimpleDialogOption(
    child: new Text(str),
    onPressed: () {
      Navigator.pop(context, feedType);
    },
  );
}

_saveUrlToFirestore(BuildContext context, FeedTypes feedType) {
  final contentController = TextEditingController();

  return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Provide URL'),
          content: TextField(
            controller: contentController,
            decoration: InputDecoration(hintText: "URL path"),
          ),
          actions: <Widget>[
            new TextButton(
              child: new Text('Add'),
              onPressed: () async {
                print('Add new feed ${contentController.text}');
                final userData = Provider.of<MyUser>(context, listen: false);
                await FirebaseFirestore.instance
                    .collection('user_data')
                    .doc(userData.uid)
                    .collection('feeds')
                    .add({
                  'type': feedType.toString(),
                  'uri': contentController.text,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                Navigator.of(context).pop();
              },
            ),
            new TextButton(
              child: new Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      });
}

_addFeedDialog(BuildContext context) {
  showDialog<FeedTypes>(
    context: context,
    builder: (BuildContext context) => new SimpleDialog(
      title: new Text('Select the content type'),
      children: <Widget>[
        _createDialogOption(context, FeedTypes.ATOM, 'Atom'),
        _createDialogOption(context, FeedTypes.RSS, 'Rss')
      ],
    ),
  ).then((feedType) {
    return _saveUrlToFirestore(context, feedType);
  });
}

class RssListPage extends StatefulWidget {
  final String title;

  RssListPage({@required this.title});

  @override
  _RssListPageState createState() => _RssListPageState(title: title);
}

class _RssListPageState extends State<RssListPage> {
  final String _rssUrl = "https://future-architect.github.io/atom.xml";
  final String title;
  List<Widget> _items = [];

  _RssListPageState({@required this.title}) {
    convertItemFromXML();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(this.title),
      ),
      body: Center(
        child: ListView(
          padding: EdgeInsets.all(10.0),
          children: _items,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _addFeedDialog(context);
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void convertItemFromXML() async {
    List<Widget> list = [];
    Response res = await get(Uri.parse(_rssUrl));
    var atomFeed = new AtomFeed.parse(res.body);
    for (AtomItem item in atomFeed.items) {
      list.add(ListTile(
        contentPadding: EdgeInsets.all(10.0),
        title: Text(
          utf8.decode(item.title.runes.toList()),
        ),
        subtitle: Text(item.published),
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ItemDetailPage(
                        item: item,
                      )));
        },
      ));
    }
    setState(() {
      _items = list;
    });
  }
}

class ItemDetailPage extends StatefulWidget {
  final AtomItem item;

  ItemDetailPage({@required this.item});

  @override
  _ItemDetailPageState createState() => _ItemDetailPageState(item: item);
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  AtomItem item;

  _ItemDetailPageState({@required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
      ),
      body: Center(child: Text(item.title)),
    );
  }
}

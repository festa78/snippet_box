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
  UNKNOWN,
}

FeedTypes getFeedType(String xmlString) {
  try {
    RssFeed.parse(xmlString);
    return FeedTypes.RSS;
  } catch (e) {
    print(e);
  }

  try {
    AtomFeed.parse(xmlString);
    return FeedTypes.ATOM;
  } catch (e) {
    print(e);
  }

  throw 'Given XML string is not ATOM nor XML';
}

abstract class FeedItems {
  FeedItems(String xmlString) {
    parse(xmlString);
  }

  parse(String xmlString);
  List<Widget> getItems();
}

class RssFeedItems extends FeedItems {
  RssFeed _rssFeeds;

  RssFeedItems(String xmlString) : super(xmlString);

  @override
  parse(String xmlString) {
    _rssFeeds = RssFeed.parse(xmlString);
  }

  @override
  List<Widget> getItems() {
    List<Widget> list = [];
    for (RssItem item in _rssFeeds.items) {
      list.add(ListTile(
        contentPadding: EdgeInsets.all(10.0),
        title: Text(
          utf8.decode(item.title.runes.toList()),
        ),
      ));
    }

    return list;
  }
}

class AtomFeedItems extends FeedItems {
  AtomFeed _atomFeeds;

  AtomFeedItems(String xmlString) : super(xmlString);

  @override
  parse(String xmlString) {
    _atomFeeds = AtomFeed.parse(xmlString);
  }

  @override
  List<Widget> getItems() {
    List<Widget> list = [];
    for (AtomItem item in _atomFeeds.items) {
      list.add(ListTile(
        contentPadding: EdgeInsets.all(10.0),
        title: Text(
          utf8.decode(item.title.runes.toList()),
        ),
      ));
    }

    return list;
  }
}

_saveUrlToFirestore(BuildContext context) {
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
                final Response res =
                    await get(Uri.parse(contentController.text));
                final FeedTypes feedType = getFeedType(res.body);
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

class FeedListPage extends StatefulWidget {
  final String title;

  FeedListPage({@required this.title});

  @override
  _FeedListPageState createState() => _FeedListPageState(title: title);
}

class _FeedListPageState extends State<FeedListPage> {
  final String _feedUrl = "https://future-architect.github.io/atom.xml";
  final String title;
  List<Widget> _items = [];

  _FeedListPageState({@required this.title}) {
    convertItemFromXML();
  }

  void convertItemFromXML() async {
    List<Widget> list = [];

    Response res = await get(Uri.parse(_feedUrl));
    FeedTypes feedType = getFeedType(res.body);
    switch (feedType) {
      case FeedTypes.RSS:
        list = RssFeedItems(res.body).getItems();
        break;
      case FeedTypes.ATOM:
        list = AtomFeedItems(res.body).getItems();
        break;
      default:
        throw 'Unsupported feed type $feedType';
    }

    setState(() {
      _items = list;
    });
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
          _saveUrlToFirestore(context);
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
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

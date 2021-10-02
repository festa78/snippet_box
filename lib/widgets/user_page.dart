import 'package:flutter/material.dart';

import 'package:myapp/models/feed.dart';
import 'package:myapp/widgets/feed.dart';
import 'package:myapp/widgets/saved_page.dart';

class UserPage extends StatefulWidget {
  UserPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  int _currentIndex = 0;
  final _pageWidgets = [
    SavedPage(title: 'Saved page'),
    FeedListPage(
      title: 'News feed page',
      rssUrlParser: RssUrlParser(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pageWidgets.elementAt(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'News Feed'),
        ],
        currentIndex: _currentIndex,
        fixedColor: Colors.blueAccent,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  void _onItemTapped(int index) => setState(() => _currentIndex = index);
}

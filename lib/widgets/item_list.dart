import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_web_view/easy_web_view.dart';

class ItemList extends StatelessWidget {
  ItemList(this.queryTags, this.queryTerms);

  final List<String> queryTags;
  final List<String> queryTerms;

  _navigate(context, document) async {
    final content = await _getContent(document);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContentViewer(
          document,
          content,
        ),
      ),
    );
  }

  _getContent(document) async {
    if (await canLaunch(document['uri'])) {
      return EasyWebView(
        src: document['uri'],
        onLoaded: () => (print('loaded uri')),
      );
    } else if (!document['html'].isEmpty) {
      return EasyWebView(
        src: document['html'],
        isHtml: true,
        onLoaded: () => (print('loaded html')),
      );
    } else if (!document['text'].isEmpty) {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Text(document['text']),
      );
    } else {
      throw 'Cannot read document $document';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: Firestore.instance
          .collection('test_list')
          .orderBy('timestamp', descending: true)
          .where('tags', arrayContainsAny: this.queryTags)
          .snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          print(snapshot.error);
          return new Text('Error: ${snapshot.error}');
        }
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            return new Text('Loading...');
          default:
            return new ListView(
              shrinkWrap: true,
              children: snapshot.data.documents
                  .where((document) =>
                      document['tags'].toSet().containsAll(this.queryTags))
                  .where((document) => this
                      .queryTerms
                      .every((term) => document['title'].contains(term)))
                  .map((DocumentSnapshot document) {
                return new GestureDetector(
                  onTap: () => _navigate(context, document),
                  child: new Card(
                    child: ListTile(
                      title: new Text(document['title']),
                      subtitle: new Text(document['tags']
                              .where((tag) => tag != '__all__')
                              .join(',') +
                          ',__all__'),
                    ),
                  ),
                );
              }).toList(),
            );
        }
      },
    );
  }
}

class ContentViewer extends StatelessWidget {
  const ContentViewer(this.document, this.content);

  final DocumentSnapshot document;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(this.document['title']),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.list,
              size: 24.0,
            ),
            onPressed: () async => await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TagEditor(this.document.documentID),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete,
              size: 24.0,
            ),
            onPressed: () async {
              print('Delete document ${this.document.documentID}');
              await Firestore.instance
                  .collection('test_list')
                  .document(this.document.documentID)
                  .delete();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: this.content,
    );
  }
}

class TagEditor extends StatefulWidget {
  TagEditor(this.documentID);

  final String documentID;

  @override
  _TagEditorState createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  Future<List<dynamic>> _tags;

  @override
  void initState() {
    super.initState();

    this._tags = Firestore.instance
        .collection('test_list')
        .document(widget.documentID)
        .get()
        .then((doc) {
      var tags = doc.data['tags'];
      tags.sort();
      tags.removeAt(tags.indexOf('__all__'));
      tags.add('__all__');
      return tags;
    });
  }

  void _removeTag(int index) {
    // Needs at least '__all__' tag to avoid filter error.
    // Do not allow to delete.
    setState(() {
      this._tags = this._tags.then((tags) {
        if (tags[index] != '__all__') {
          tags.removeAt(index);
        }
        return tags;
      });
    });
  }

  void _addTag(String tagName) {
    setState(() {
      this._tags = this._tags.then((tags) {
        tags.add(tagName);
        tags.sort();
        tags.removeAt(tags.indexOf('__all__'));
        tags.add('__all__');
        return tags;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: this._tags,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text(snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return Text('Missing data');
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Edit tags'),
            actions: <Widget>[
              IconButton(
                icon: Icon(
                  Icons.update,
                  size: 24.0,
                ),
                onPressed: () {
                  print(
                      'Assign tags ${snapshot.data} to document ${widget.documentID}');
                  Firestore.instance
                      .collection('test_list')
                      .document(widget.documentID)
                      .updateData({
                    'tags': snapshot.data,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              TextField(
                textInputAction: TextInputAction.done,
                onSubmitted: (String tagName) {
                  if (tagName.isNotEmpty && !snapshot.data.contains(tagName)) {
                    this._addTag(tagName);
                  }
                },
                decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter a tag name to add'),
              ),
              ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data.length,
                itemBuilder: (BuildContext context, int index) {
                  return new GestureDetector(
                    onTap: () => this._removeTag(index),
                    child: new Card(
                      child: ListTile(
                        title: new Text(snapshot.data[index]),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

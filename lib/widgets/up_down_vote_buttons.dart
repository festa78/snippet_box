import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/models/user.dart';
import 'package:myapp/widgets/feed.dart';

class UpDownVoteButtons extends StatefulWidget {
  final FirebaseFirestore firestoreInstance;
  final VotedUri initialVotedUri;

  UpDownVoteButtons({@required this.firestoreInstance, this.initialVotedUri});

  @override
  UpDownVoteButtonsState createState() =>
      UpDownVoteButtonsState(votedUri: this.initialVotedUri);
}

class UpDownVoteButtonsState extends State<UpDownVoteButtons> {
  VotedUri votedUri;

  UpDownVoteButtonsState({this.votedUri});

  @override
  Widget build(BuildContext context) {
    return ButtonBar(
      children: [
        IconButton(
          icon: Icon(Icons.thumb_up),
          color: this.votedUri.state > 0 ? Colors.blueAccent : Colors.grey,
          onPressed: () {
            final userData = Provider.of<MyUser>(context, listen: false);

            final collectionRef = this
                .widget
                .firestoreInstance
                .collection('user_data')
                .doc(userData.uid)
                .collection('votes');

            if (this.votedUri.docId == null) {
              collectionRef.add({
                'state': 1,
                'uri': this.votedUri.uri,
                'uriCreatedAt': this.votedUri.uriCreatedAt,
              }).then((DocumentReference docRef) {
                setState(() {
                  this.votedUri = VotedUri(
                      docId: docRef.id,
                      state: 1,
                      uri: this.votedUri.uri,
                      uriCreatedAt: this.votedUri.uriCreatedAt);
                });
              });

              return;
            }

            final newState = this.votedUri.state == 1 ? 0 : 1;
            collectionRef.doc(this.votedUri.docId).update(
                {'state': newState}).then((value) {
              setState(() {
                this.votedUri = VotedUri(
                    uri: this.votedUri.uri,
                    state: newState,
                    uriCreatedAt: this.votedUri.uriCreatedAt);
              });
            }).catchError(
                (error) => print('Failed to delete docId on unvote: $error'));
          },
        ),
        IconButton(
          icon: Icon(Icons.thumb_down),
          color: this.votedUri.state < 0 ? Colors.blueAccent : Colors.grey,
          onPressed: () {
            final userData = Provider.of<MyUser>(context, listen: false);

            final collectionRef = this
                .widget
                .firestoreInstance
                .collection('user_data')
                .doc(userData.uid)
                .collection('votes');

            if (this.votedUri.docId == null) {
              collectionRef.add({
                'state': -1,
                'uri': this.votedUri.uri,
                'uriCreatedAt': this.votedUri.uriCreatedAt,
              }).then((DocumentReference docRef) {
                setState(() {
                  this.votedUri = VotedUri(
                      docId: docRef.id,
                      state: -1,
                      uri: this.votedUri.uri,
                      uriCreatedAt: this.votedUri.uriCreatedAt);
                });
              });

              return;
            }

            final newState = this.votedUri.state == -1 ? 0 : -1;
            collectionRef.doc(this.votedUri.docId).update(
                {'state': newState}).then((value) {
              setState(() {
                this.votedUri = VotedUri(
                    uri: this.votedUri.uri,
                    state: newState,
                    uriCreatedAt: this.votedUri.uriCreatedAt);
              });
            }).catchError(
                (error) => print('Failed to delete docId on unvote: $error'));
          },
        ),
      ],
    );
  }
}

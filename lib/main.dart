import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:myapp/widgets/snippet_box.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const firestoreEmulatorHost =
      String.fromEnvironment('FIRESTORE_EMULATOR_HOST', defaultValue: null);
  if (firestoreEmulatorHost != null) {
    print('useFirestoreEmulator');
    FirebaseFirestore.instance
        .useFirestoreEmulator('localhost', int.parse(firestoreEmulatorHost));
  }

  runApp(SnippetBox());
}

import firebase from 'firebase/app';
import { firebaseConfig } from './firebase-config';
firebase.initializeApp(firebaseConfig());

import 'firebase/auth';
import 'firebase/functions';
var auth = firebase.auth();
var functions = firebase.functions();

if (true) {
  console.log("use emulator");
  functions.useEmulator("localhost", 5001);
} else {
  console.log("Do not use emulator");
}

chrome.runtime.onMessage.addListener(
  function (request, sender, sendResponse) {
    if (request.name === "login") {
      var provider = new firebase.auth.GoogleAuthProvider();
      provider.addScope('https://www.googleapis.com/auth/contacts.readonly');
      firebase.auth().signInWithPopup(provider).then(function (result) {
        var user = result.user;
        var status = 200;
        sendResponse({ user, status });
      }).catch(function (error) {
        // Handle Errors here.
        var errorCode = error.code;
        if (errorCode === 'auth/account-exists-with-different-credential') {
          alert('You have already signed up with a different auth provider for that email.');
          // If you are using multiple auth providers on your app you should handle linking
          // the user's accounts here.
        } else {
          console.error(error);
        }
        var status = '400';
        sendResponse({ error, status });
      });
    } else if (request.name === "saveUri") {
      let uri = request.uri;
      chrome.storage.sync.get("uid", ({ uid }) => {
        let sendUrlToDb = functions.httpsCallable('sendUrlToDb');
        sendUrlToDb({ uid, uri })
          .catch((error) => console.log('error saving url:', error));
      });
    } else {
      var error = "unknown request: " + request.name;
      console.error("unknown request", request.name);
      var status = '400';
      sendResponse({ error, status });
    }

    return true;
  });

function initApp() {
  // Listening for auth state changes.
  auth.onAuthStateChanged(function (user: firebase.User | null) {
    if (user) {
      // User is signed in.
      let displayName = user.displayName;
      let email = user.email;
      let uid = user.uid;
      chrome.storage.sync.set({ displayName, email, uid }, () => {
        console.log('Value is set to ', displayName, email, uid);
      });
    } else {
      // User is signed out.
      let displayName = '';
      let email = '';
      let uid = '';
      chrome.storage.sync.set({ displayName, email, uid }, () => {
        console.log('Value is set to ', displayName, email, uid);
      });
    }
  });
}

initApp();

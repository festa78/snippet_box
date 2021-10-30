// The Cloud Functions for Firebase SDK to create Cloud Functions and setup triggers.
const firebase = require("firebase");
// Required for side-effects
require("firebase/firestore");

// The Firebase Admin SDK to access Cloud Firestore.
const admin = require('firebase-admin');
const functions = require('firebase-functions');
admin.initializeApp({credential: admin.credential.applicationDefault()})

const fetch = require('node-fetch');

exports.getRssContent = functions.https.onCall((data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('permission-denied', 'Auth Error');
  }

  return fetch(data)
    .then(response => {
      return response.text();
    })
    .catch((error) => { throw new functions.https.HttpsError(error) });
});

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import fetch, { Response } from 'node-fetch';

admin.initializeApp();

exports.getRssContent = functions.https.onCall(
  (data: string, context: functions.https.CallableContext) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('permission-denied', 'Auth Error');
    }

    return fetch(data)
      .then((response: Response) => {
        return response.text();
      })
      .catch((error: functions.https.FunctionsErrorCode) => {
        throw new functions.https.HttpsError(error, `Error fetching ${data}`);
      });
  }
);

exports.getRssContent = functions.https.onCall(
  (context: functions.https.CallableContext) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('permission-denied', 'Auth Error');
    }

    const userDataRef = admin.firestore().collection('user_data');

    userDataRef.get().then((snapshot) => {
      snapshot.forEach((doc) => {
        console.log(doc.id);
      });
    });
  }
);

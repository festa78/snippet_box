import * as functions from 'firebase-functions';
import fetch, { Response } from 'node-fetch';

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

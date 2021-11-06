"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const admin = require("firebase-admin");
const functions = require("firebase-functions");
const node_fetch_1 = require("node-fetch");
admin.initializeApp();
exports.getRssContent = functions.https.onCall((data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('permission-denied', 'Auth Error');
    }
    return (0, node_fetch_1.default)(data)
        .then((response) => {
        return response.text();
    })
        .catch((error) => {
        throw new functions.https.HttpsError(error, `Error fetching ${data}`);
    });
});
exports.getRssContent = functions.https.onCall((context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('permission-denied', 'Auth Error');
    }
    const userDataRef = admin.firestore().collection('user_data');
    userDataRef.get().then((snapshot) => {
        snapshot.forEach((doc) => {
            console.log(doc.id);
        });
    });
});
//# sourceMappingURL=index.js.map
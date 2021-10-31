"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const functions = require("firebase-functions");
const node_fetch_1 = require("node-fetch");
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
//# sourceMappingURL=index.js.map
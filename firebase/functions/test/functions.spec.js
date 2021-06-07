const fs = require('fs');

const firebase = require("firebase");
const admin = require('firebase-admin');
// admin.initializeApp({credential: admin.credential.applicationDefault()})

var runtimeconfig = JSON.parse(fs.readFileSync('.runtimeconfig.json'))
runtimeconfig['is_test'] = true;

const test = require('firebase-functions-test')({
    projectId: "flutter-myapp-test",
}, "test/flutter-myapp-test-294ee9d498d1.json");

test.mockConfig(runtimeconfig)

const myFunctions = require("../index");
const chai = require('chai');
const assert = chai.assert;

describe("addMessage", () => {
    const boundary = '---------------------------paZqsnEHRufoShdX6fh0lUhXBP4k'
    const req = {
        headers: {
            'content-type': 'multipart/form-data; boundary=' + boundary
        },
        rawBody:
            ['-----------------------------paZqsnEHRufoShdX6fh0lUhXBP4k',
            'Content-Disposition: form-data; name="envelope"',
            '',
            '{ "from": "nonamehorses78@gmail.com" }',
            '-----------------------------paZqsnEHRufoShdX6fh0lUhXBP4k',
            'Content-Disposition: form-data; name="subject"',
            '',
            'this is an addMessage test',
            '-----------------------------paZqsnEHRufoShdX6fh0lUhXBP4k--'
            ].join('\r\n')
    };

    afterEach(() => {
        return admin.auth().getUserByEmail('nonamehorses78@gmail.com')
            .then(userRecord => {
                return admin.firestore().collection('user_data/' + userRecord.uid + '/snippets')
                    .where("title", '==', 'this is an addMessage test')
                    .get();
            })
            .then((querySnapshot) => {
                querySnapshot.forEach(doc => {
                    console.log('delete doc', doc.id);
                    doc.ref.delete();
                })
            })
        });

    it("return 200", function () {
        return new Promise((resolve, reject) => {
            const res = {
                send: (code) => {
                    try {
                        assert.equal(code, 200);
                        resolve();
                    } catch (error) {
                        reject(error);
                    }
                }
            };
            myFunctions.addMessage(req, res);
        });
    });

    it("Properly parse and add email message", function () {
        return new Promise((resolve, reject) => {
            const res = {
                send: (code) => {
                    console.log(code);
                    admin.auth().getUserByEmail('nonamehorses78@gmail.com')
                        .then((userRecord) => {
                            return admin.firestore()
                                .collection('user_data/' + userRecord.uid + '/snippets')
                                .where("title", '==', 'this is an addMessage test')
                                .get();
                        })
                        .then((querySnapshot) => {
                            let idList = [];
                            querySnapshot.forEach((doc) => {
                                console.log(doc.id, " => ", doc.data());
                                idList.push(doc.id);
                            })
                            console.log('num id list', idList.length);
                            assert.equal(idList.length, 1);
                            resolve();
                        })
                        .catch((error) => {
                            console.log('Error at addMessage test assertions:', error);
                            reject(error);
                        });

                }
            };
            myFunctions.addMessage(req, res);
        });
    });
});

test.cleanup();
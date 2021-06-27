const fs = require('fs');

const firebase = require("firebase");
const admin = require('firebase-admin');

// Needs to prepare project JSON information.
// Also needs to set env.process.GCLOUD_PROJECT.
const test = require('firebase-functions-test')({
    projectId: "flutter-myapp-test",
}, "test/flutter-myapp-test-294ee9d498d1.json");

const runtimeconfig = JSON.parse(fs.readFileSync('.runtimeconfig.json'))
test.mockConfig(runtimeconfig)

const myFunctions = require("../index");
const chai = require('chai');
const sinon = require('sinon');
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
                return Promise.all(querySnapshot.docs.map(doc => {
                    console.log('delete doc', doc.id);
                    doc.ref.delete();
                }));
            })
            .then(() => console.log('deleted all docs'))
            .catch((error) => { throw(error); });
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
                                idList.push(doc.id);
                            })
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

describe("snippetsOnCreated", () => {
    process.env.GCLOUD_PROJECT = "flutter-myapp-test-294ee9d498d1.json"
    const dummy_input = {
        tags: ['__all__'],
        email: 'dummy@email.addr',
        title: 'dummy title',
    }
    const snap = test.firestore.makeDocumentSnapshot(dummy_input,
        'user_data/dummy_user/snippets/dummy_doc');

    it("Properly call algoria client", () => {
        const indexStub = sinon.fake();
        indexStub.saveObject = sinon.fake.resolves();
        sinon.replace(myFunctions, 'getAlgoliaIndex', sinon.fake.returns(indexStub));

        const wrapped = test.wrap(myFunctions.snippetsOnCreated);
        wrapped(snap, {
            params: {
                docId: 'dummy_doc',
            }
        });

        let expected = Object.assign({objectID: 'dummy_doc'}, dummy_input);
        assert.deepEqual(indexStub.saveObject.lastCall.lastArg, expected);

        sinon.restore();
    })
});

describe("snippetsOnUpdate", () => {
    const dummy_input_before = {
        tags: ['__all__'],
        email: 'dummy@email.addr',
        title: 'dummy title',
    }
    const dummy_input_after = {
        tags: ['new_dummy_tag', '__all__'],
        email: 'dummy@email.addr',
        title: 'dummy title',
    }
    const beforeSnap = test.firestore.makeDocumentSnapshot(dummy_input_before,
        'user_data/dummy_user/snippets/dummy_doc');
    const afterSnap = test.firestore.makeDocumentSnapshot(dummy_input_after,
        'user_data/dummy_user/snippets/dummy_doc');
    const change = test.makeChange(beforeSnap, afterSnap);

    afterEach(() => {
        admin.firestore()
            .collection('user_data').doc('dummy_user')
            .collection('tags').doc('new_dummy_tag')
            .delete()
            .then(() => console.log('deleted new_dummy_tag'))
            .catch(() => { throw('failed te delete new_dummy_tag') });
    });

    it("Properly add tags", () => {
        return new Promise((resolve, reject) => {
            try {
                const indexStub = sinon.fake();
                indexStub.saveObject = sinon.fake.resolves();
                sinon.replace(myFunctions, 'getAlgoliaIndex', sinon.fake.returns(indexStub));

                const wrapped = test.wrap(myFunctions.snippetsOnUpdate);
                wrapped(change, {
                    params: {
                        docId: 'dummy_doc',
                        userId: 'dummy_user',
                    }
                }).then((res) => {
                    sinon.restore();
                    resolve();
                });
            } catch (e) {
                reject(e);
            }
        });
    });
});

test.cleanup();
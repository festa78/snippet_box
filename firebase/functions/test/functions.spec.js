const fs = require('fs');

var runtimeconfig = JSON.parse(fs.readFileSync('.runtimeconfig.json'))
runtimeconfig['is_test'] = true;

const test = require('firebase-functions-test')({
    projectId: "flutter-myapp-test",
}, "test/flutter-myapp-test-294ee9d498d1.json");

test.mockConfig(runtimeconfig)

const myFunctions = require("../index");

describe("addMessage", () => {
    it("Properly parse and add email message", async () => {
        const boundary = '---------------------------paZqsnEHRufoShdX6fh0lUhXBP4k'
        const req = {
            headers: {
                'content-type': 'multipart/form-data; boundary=' + boundary
            },
            rawBody:
                ['-----------------------------paZqsnEHRufoShdX6fh0lUhXBP4k',
                'Content-Disposition: form-data; name="file_name_0"',
                '',
                'super alpha file',
                '-----------------------------paZqsnEHRufoShdX6fh0lUhXBP4k',
                'Content-Disposition: form-data; name="file_name_1"',
                '',
                'super beta file',
                '-----------------------------paZqsnEHRufoShdX6fh0lUhXBP4k--'
                ].join('\r\n')
        };

        const res = {
            send: (code) => {
                console.log(code);
                assert.equal(code, 200);
                done();
            }
        };

        myFunctions.addMessage(req, res);
    });
});

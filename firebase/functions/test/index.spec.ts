import { assert, expect } from 'chai';
import * as functions from 'firebase-functions';
import * as firebaseFunctionsTest from 'firebase-functions-test';
import { describe, it } from 'mocha';

import * as sut from '../src/index';

const test = firebaseFunctionsTest(
  {
    projectId: 'flutter-myapp-test',
  },
  './test/flutter-myapp-test-559e258b7bd5.json'
);

describe('getRssContent', () => {
  it('Throw error with un-authorized request', () => {
    const wrapped = test.wrap(sut.getRssContent);
    assert.throws(
      () => wrapped('example.com', {}),
      functions.https.HttpsError,
      'Auth Error'
    );
  });

  it('Throw error with wrong input to fetch', (done) => {
    const wrapped = test.wrap(sut.getRssContent);
    wrapped('wrongurl', { auth: true }).catch((error: TypeError) => {
      expect(error.message).to.have.string('TypeError');
      done();
    });
  });
});

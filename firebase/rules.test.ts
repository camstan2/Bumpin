import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { setLogLevel } from 'firebase/app';
import { collection, deleteDoc, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  setLogLevel('error');
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-bumpin',
    firestore: { rules: (await import('fs/promises')).readFile('./firestore.rules', 'utf8') }
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

function authed(uid: string) {
  return testEnv.authenticatedContext(uid).firestore();
}

test('speakerRequests: user can create pending request for self; non-host cannot approve', async () => {
  const db = authed('userA');
  const partyRef = doc(db, 'parties/p1');
  await assertSucceeds(setDoc(partyRef, { hostId: 'host', coHostIds: [] }));

  const reqRef = doc(collection(partyRef, 'speakerRequests'));
  await assertSucceeds(setDoc(reqRef, { userId: 'userA', userName: 'A', status: 'pending', timestamp: new Date() }));

  // Try to approve as a non-host
  await assertFails(updateDoc(reqRef, { status: 'approved' }));
});

test('speakerRequests: host can approve and delete', async () => {
  const dbHost = authed('host');
  const partyRef = doc(dbHost, 'parties/p2');
  await assertSucceeds(setDoc(partyRef, { hostId: 'host', coHostIds: [] }));
  const reqRef = doc(collection(partyRef, 'speakerRequests'));
  await assertSucceeds(setDoc(reqRef, { userId: 'userB', userName: 'B', status: 'pending', timestamp: new Date() }));
  await assertSucceeds(updateDoc(reqRef, { status: 'approved' }));
  await assertSucceeds(deleteDoc(reqRef));
});

test('parties: co-host may update party fields', async () => {
  const db = authed('host');
  const partyRef = doc(db, 'parties/p3');
  await assertSucceeds(setDoc(partyRef, { hostId: 'host', coHostIds: ['co1'], name: 'X' }));

  // As co-host, update name
  const dbCo = authed('co1');
  await assertSucceeds(updateDoc(doc(dbCo, 'parties/p3'), { name: 'Y' }));

  // Random user cannot update
  const dbOther = authed('other');
  await assertFails(updateDoc(doc(dbOther, 'parties/p3'), { name: 'Z' }));
});

import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';

let testEnv: any;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'bumpin-test',
    firestore: {
      rules: readFileSync(new URL('./firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

function authedContext(uid: string) {
  return testEnv.authenticatedContext(uid).firestore();
}

test('listener can create and update own presence doc', async () => {
  const db = authedContext('userA');
  const ref = db.collection('liveDJSessions').doc('s1').collection('listeners').doc('userA');
  await assertSucceeds(ref.set({ isActive: true }));
  await assertSucceeds(ref.update({ lastSeenAt: new Date() }));
});

test('listener cannot write someone else\'s presence doc', async () => {
  const db = authedContext('userA');
  const ref = db.collection('liveDJSessions').doc('s1').collection('listeners').doc('userB');
  await assertFails(ref.set({ isActive: true }));
});

test('only DJ can update session doc', async () => {
  const djDb = authedContext('dj1');
  const listenerDb = authedContext('userA');
  const sessionRefDj = djDb.collection('liveDJSessions').doc('s2');
  await assertSucceeds(sessionRefDj.set({ djId: 'dj1', title: 'test' }));
  const sessionRefListener = listenerDb.collection('liveDJSessions').doc('s2');
  await assertFails(sessionRefListener.update({ title: 'hijack' }));
});



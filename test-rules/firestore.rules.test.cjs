const { readFileSync } = require('node:fs');
const {
  after,
  before,
  beforeEach,
  test,
} = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-cercly',
    firestore: {
      host: '127.0.0.1',
      port: 8085,
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

async function crearPerfilInicial() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'usuarios', 'anthony'), {
      nombre: 'Anthony',
      creadoEn: new Date(),
    });
  });
}

test('permite crear el perfil propio', async () => {
  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertSucceeds(
    setDoc(doc(db, 'usuarios', 'anthony'), {
      nombre: 'Anthony',
      creadoEn: serverTimestamp(),
    }),
  );
});

test('impide crear el perfil de otro usuario', async () => {
  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertFails(
    setDoc(doc(db, 'usuarios', 'carlos'), {
      nombre: 'Carlos',
      creadoEn: serverTimestamp(),
    }),
  );
});

test('permite leer el perfil propio', async () => {
  await crearPerfilInicial();
  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertSucceeds(
    getDoc(doc(db, 'usuarios', 'anthony')),
  );
});

test('impide leer el perfil de otro usuario', async () => {
  await crearPerfilInicial();
  const db = testEnv.authenticatedContext('carlos').firestore();

  await assertFails(
    getDoc(doc(db, 'usuarios', 'anthony')),
  );
});

test('permite cambiar únicamente el nombre propio', async () => {
  await crearPerfilInicial();
  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertSucceeds(
    updateDoc(doc(db, 'usuarios', 'anthony'), {
      nombre: 'Anthony López',
    }),
  );
});

test('impide modificar la fecha de creación', async () => {
  await crearPerfilInicial();
  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertFails(
    updateDoc(doc(db, 'usuarios', 'anthony'), {
      creadoEn: serverTimestamp(),
    }),
  );
});
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

function datosCategoria({
  activa = true,
  usarFechaServidor = true,
} = {}) {
  const fecha = usarFechaServidor
    ? serverTimestamp()
    : new Date();

  return {
    nombre: 'Cafeterías',
    icono: 'coffee',
    activa,
    orden: 1,
    creadoEn: fecha,
    actualizadoEn: fecha,
  };
}

async function guardarCategoria(activa) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'categorias', 'cafeterias'),
      datosCategoria({
        activa,
        usarFechaServidor: false,
      }),
    );
  });
}

test('un administrador puede crear una categoría', async () => {
  const db = testEnv
    .authenticatedContext('administrador', { admin: true })
    .firestore();

  await assertSucceeds(
    setDoc(
      doc(db, 'categorias', 'cafeterias'),
      datosCategoria(),
    ),
  );
});

test('un usuario normal no puede crear categorías', async () => {
  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertFails(
    setDoc(
      doc(db, 'categorias', 'cafeterias'),
      datosCategoria(),
    ),
  );
});

test('el público puede leer una categoría activa', async () => {
  await guardarCategoria(true);
  const db = testEnv.unauthenticatedContext().firestore();

  await assertSucceeds(
    getDoc(doc(db, 'categorias', 'cafeterias')),
  );
});

test('el público no puede leer una categoría inactiva', async () => {
  await guardarCategoria(false);
  const db = testEnv.unauthenticatedContext().firestore();

  await assertFails(
    getDoc(doc(db, 'categorias', 'cafeterias')),
  );
});

test('un administrador puede leer una categoría inactiva', async () => {
  await guardarCategoria(false);
  const db = testEnv
    .authenticatedContext('administrador', { admin: true })
    .firestore();

  await assertSucceeds(
    getDoc(doc(db, 'categorias', 'cafeterias')),
  );
});
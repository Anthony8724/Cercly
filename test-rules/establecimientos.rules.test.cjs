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
  GeoPoint,
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

function horarioCompleto() {
  return {
    lunes: [],
    martes: [],
    miercoles: [],
    jueves: [],
    viernes: [],
    sabado: [],
    domingo: [],
  };
}

function datosEstablecimiento({
  propietarioId = 'anthony',
  estado = 'pendiente',
  usarFechaServidor = true,
} = {}) {
  const fecha = usarFechaServidor
    ? serverTimestamp()
    : new Date();

  return {
    propietarioId,
    nombre: 'Cafetería de prueba',
    descripcion: 'Establecimiento ficticio',
    categoriaId: 'cafeterias',
    direccion: 'Dirección de prueba',
    ubicacion: new GeoPoint(0, 0),
    telefonoPublico: '',
    horario: horarioCompleto(),
    zonaHoraria: 'America/Guayaquil',
    estado,
    creadoEn: fecha,
    actualizadoEn: fecha,
  };
}

async function guardarNegocio(estado = 'pendiente') {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(
        context.firestore(),
        'establecimientos',
        'negocio-prueba',
      ),
      datosEstablecimiento({
        estado,
        usarFechaServidor: false,
      }),
    );
  });
}

test('el propietario puede crear un negocio pendiente', async () => {
  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertSucceeds(
    setDoc(
      doc(db, 'establecimientos', 'negocio-prueba'),
      datosEstablecimiento(),
    ),
  );
});

test('el propietario no puede crear un negocio aprobado', async () => {
  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertFails(
    setDoc(
      doc(db, 'establecimientos', 'negocio-prueba'),
      datosEstablecimiento({ estado: 'aprobado' }),
    ),
  );
});

test('otro usuario no puede leer un negocio pendiente', async () => {
  await guardarNegocio();
  const db = testEnv.authenticatedContext('carlos').firestore();

  await assertFails(
    getDoc(doc(db, 'establecimientos', 'negocio-prueba')),
  );
});

test('el público puede leer un negocio aprobado', async () => {
  await guardarNegocio('aprobado');
  const db = testEnv.unauthenticatedContext().firestore();

  await assertSucceeds(
    getDoc(doc(db, 'establecimientos', 'negocio-prueba')),
  );
});

test('el propietario puede editar el nombre de su negocio', async () => {
  await guardarNegocio();
  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertSucceeds(
    updateDoc(doc(db, 'establecimientos', 'negocio-prueba'), {
      nombre: 'Nuevo nombre',
      actualizadoEn: serverTimestamp(),
    }),
  );
});

test('el propietario no puede aprobar su propio negocio', async () => {
  await guardarNegocio();
  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertFails(
    updateDoc(doc(db, 'establecimientos', 'negocio-prueba'), {
      estado: 'aprobado',
      actualizadoEn: serverTimestamp(),
    }),
  );
});

test('un administrador puede aprobar el negocio', async () => {
  await guardarNegocio();
  const db = testEnv
    .authenticatedContext('administrador', { admin: true })
    .firestore();

  await assertSucceeds(
    updateDoc(doc(db, 'establecimientos', 'negocio-prueba'), {
      estado: 'aprobado',
      actualizadoEn: serverTimestamp(),
    }),
  );
});
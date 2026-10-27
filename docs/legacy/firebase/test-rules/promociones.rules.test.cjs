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
  deleteDoc,
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

function datosPromocion({
  establecimientoId = 'negocio-anthony',
  activa = true,
  fechaInicio,
  fechaFin,
  usarFechaServidor = true,
} = {}) {
  const ahora = Date.now();
  const fechaRegistro = usarFechaServidor
    ? serverTimestamp()
    : new Date();

  return {
    establecimientoId,
    titulo: 'Descuento del 20 por ciento',
    descripcion: 'Promocion disponible por tiempo limitado.',
    fechaInicio:
      fechaInicio ?? new Date(ahora - 60 * 60 * 1000),
    fechaFin:
      fechaFin ?? new Date(ahora + 60 * 60 * 1000),
    radioAlertaMetros: 200,
    activa,
    creadoEn: fechaRegistro,
    actualizadoEn: fechaRegistro,
  };
}

async function guardarEstablecimiento(
  id,
  propietarioId,
  estado = 'aprobado',
) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'establecimientos', id),
      {
        propietarioId,
        nombre: 'Negocio de prueba',
        descripcion: 'Establecimiento ficticio',
        categoriaId: 'cafeterias',
        direccion: 'Direccion de prueba',
        ubicacion: {
          latitude: 0,
          longitude: 0,
        },
        telefonoPublico: '',
        horario: {},
        zonaHoraria: 'America/Guayaquil',
        estado,
        creadoEn: new Date(),
        actualizadoEn: new Date(),
      },
    );
  });
}

async function guardarPromocion({
  activa = true,
  fechaInicio,
  fechaFin,
} = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'promociones', 'promo-prueba'),
      datosPromocion({
        activa,
        fechaInicio,
        fechaFin,
        usarFechaServidor: false,
      }),
    );
  });
}

test('el propietario puede crear una promocion', async () => {
  await guardarEstablecimiento('negocio-anthony', 'anthony');

  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertSucceeds(
    setDoc(
      doc(db, 'promociones', 'promo-prueba'),
      datosPromocion(),
    ),
  );
});

test('otro usuario no puede crear la promocion', async () => {
  await guardarEstablecimiento('negocio-anthony', 'anthony');

  const db = testEnv.authenticatedContext('carlos').firestore();

  await assertFails(
    setDoc(
      doc(db, 'promociones', 'promo-prueba'),
      datosPromocion(),
    ),
  );
});

test('el publico puede leer una promocion vigente', async () => {
  await guardarPromocion();

  const db = testEnv.unauthenticatedContext().firestore();

  await assertSucceeds(
    getDoc(doc(db, 'promociones', 'promo-prueba')),
  );
});

test('el publico no puede leer una promocion inactiva', async () => {
  await guardarPromocion({ activa: false });

  const db = testEnv.unauthenticatedContext().firestore();

  await assertFails(
    getDoc(doc(db, 'promociones', 'promo-prueba')),
  );
});

test('el publico no puede leer una promocion vencida', async () => {
  const ahora = Date.now();

  await guardarPromocion({
    fechaInicio: new Date(ahora - 2 * 60 * 60 * 1000),
    fechaFin: new Date(ahora - 60 * 60 * 1000),
  });

  const db = testEnv.unauthenticatedContext().firestore();

  await assertFails(
    getDoc(doc(db, 'promociones', 'promo-prueba')),
  );
});

test('el propietario puede editar su promocion', async () => {
  await guardarEstablecimiento('negocio-anthony', 'anthony');
  await guardarPromocion();

  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertSucceeds(
    updateDoc(doc(db, 'promociones', 'promo-prueba'), {
      titulo: 'Nuevo descuento',
      actualizadoEn: serverTimestamp(),
    }),
  );
});

test('el propietario no puede trasladar la promocion', async () => {
  await guardarEstablecimiento('negocio-anthony', 'anthony');
  await guardarEstablecimiento('otro-negocio', 'anthony');
  await guardarPromocion();

  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertFails(
    updateDoc(doc(db, 'promociones', 'promo-prueba'), {
      establecimientoId: 'otro-negocio',
      actualizadoEn: serverTimestamp(),
    }),
  );
});

test('un administrador puede eliminar una promocion', async () => {
  await guardarPromocion();

  const db = testEnv
    .authenticatedContext('administrador', { admin: true })
    .firestore();

  await assertSucceeds(
    deleteDoc(doc(db, 'promociones', 'promo-prueba')),
  );
});
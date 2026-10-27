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

function datosSolicitud({
  solicitanteId = 'anthony',
  establecimientoId = 'negocio-anthony',
  estado = 'pendiente',
  motivoRespuesta = '',
  usarFechaServidor = true,
} = {}) {
  const fecha = usarFechaServidor
    ? serverTimestamp()
    : new Date();

  return {
    solicitanteId,
    establecimientoId,
    mensaje: 'Solicito revisar mi establecimiento.',
    estado,
    motivoRespuesta,
    creadoEn: fecha,
    actualizadoEn: fecha,
  };
}

async function guardarEstablecimiento(
  id = 'negocio-anthony',
  propietarioId = 'anthony',
) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'establecimientos', id),
      {
        propietarioId,
        nombre: 'Negocio de prueba',
      },
    );
  });
}

async function guardarSolicitud(estado = 'pendiente') {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(
        context.firestore(),
        'solicitudes_establecimientos',
        'solicitud-prueba',
      ),
      datosSolicitud({
        estado,
        usarFechaServidor: false,
      }),
    );
  });
}

test('el propietario puede crear una solicitud pendiente', async () => {
  await guardarEstablecimiento();

  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertSucceeds(
    setDoc(
      doc(
        db,
        'solicitudes_establecimientos',
        'solicitud-prueba',
      ),
      datosSolicitud(),
    ),
  );
});

test('el propietario no puede crear una solicitud aprobada', async () => {
  await guardarEstablecimiento();

  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertFails(
    setDoc(
      doc(
        db,
        'solicitudes_establecimientos',
        'solicitud-prueba',
      ),
      datosSolicitud({ estado: 'aprobada' }),
    ),
  );
});

test('otro usuario no puede solicitar un negocio ajeno', async () => {
  await guardarEstablecimiento();

  const db = testEnv.authenticatedContext('carlos').firestore();

  await assertFails(
    setDoc(
      doc(
        db,
        'solicitudes_establecimientos',
        'solicitud-prueba',
      ),
      datosSolicitud({ solicitanteId: 'carlos' }),
    ),
  );
});

test('el solicitante puede leer su propia solicitud', async () => {
  await guardarSolicitud();

  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertSucceeds(
    getDoc(
      doc(
        db,
        'solicitudes_establecimientos',
        'solicitud-prueba',
      ),
    ),
  );
});

test('otro usuario no puede leer la solicitud', async () => {
  await guardarSolicitud();

  const db = testEnv.authenticatedContext('carlos').firestore();

  await assertFails(
    getDoc(
      doc(
        db,
        'solicitudes_establecimientos',
        'solicitud-prueba',
      ),
    ),
  );
});

test('el propietario no puede aprobar su solicitud', async () => {
  await guardarSolicitud();

  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertFails(
    updateDoc(
      doc(
        db,
        'solicitudes_establecimientos',
        'solicitud-prueba',
      ),
      {
        estado: 'aprobada',
        actualizadoEn: serverTimestamp(),
      },
    ),
  );
});

test('un administrador puede aprobar una solicitud', async () => {
  await guardarSolicitud();

  const db = testEnv
    .authenticatedContext('administrador', { admin: true })
    .firestore();

  await assertSucceeds(
    updateDoc(
      doc(
        db,
        'solicitudes_establecimientos',
        'solicitud-prueba',
      ),
      {
        estado: 'aprobada',
        motivoRespuesta: 'Solicitud verificada.',
        actualizadoEn: serverTimestamp(),
      },
    ),
  );
});

test('el propietario puede eliminar una solicitud pendiente', async () => {
  await guardarSolicitud();

  const db = testEnv.authenticatedContext('anthony').firestore();

  await assertSucceeds(
    deleteDoc(
      doc(
        db,
        'solicitudes_establecimientos',
        'solicitud-prueba',
      ),
    ),
  );
});
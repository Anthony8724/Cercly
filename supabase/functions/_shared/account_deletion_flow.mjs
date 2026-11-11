// Parte sin dependencias externas: permite probar fallos parciales sin tocar Auth.
async function complete(decision, userId, admin, verifiedAccessToken, validationRpc) {
  if (decision === 'revision') {
    return { status: 202, body: { estado: 'revision', mensaje: 'Solicitud recibida para revisión.' } };
  }
  if (decision !== 'pendiente' && decision !== 'aprobada') {
    return { status: 503, body: { estado: 'estado_desconocido' } };
  }
  const { data: allowed, error: validationError } = await admin.rpc(
    validationRpc, { p_usuario_id: userId },
  );
  if (validationError) {
    return { status: 503, body: { estado: 'estado_desconocido' } };
  }
  if (allowed !== true) {
    return { status: 202, body: { estado: 'revision', mensaje: 'Solicitud pendiente de revisión.' } };
  }
  // Solo se recibe el token que getUser ya verificó en el servidor. Revocar
  // refresh tokens no invalida JWT emitidos: las operaciones sensibles siguen
  // necesitando comprobar identidad/sesión vigente en la base.
  if (typeof verifiedAccessToken !== 'string' || !verifiedAccessToken) {
    return { status: 503, body: { estado: 'estado_desconocido' } };
  }
  const { error: signOutError } = await admin.auth.admin.signOut(
    verifiedAccessToken, 'global',
  );
  if (signOutError) {
    return { status: 503, body: { estado: 'solicitud_pendiente' } };
  }
  // La revocación y Auth no participan en la transacción de revisión. Se
  // revalida por si apareció una dependencia mientras se revocaban sesiones.
  const { data: stillAllowed, error: secondValidationError } = await admin.rpc(
    validationRpc, { p_usuario_id: userId },
  );
  if (secondValidationError) {
    return { status: 503, body: { estado: 'solicitud_pendiente' } };
  }
  if (stillAllowed !== true) {
    return { status: 202, body: { estado: 'revision', mensaje: 'Solicitud pendiente de revisión.' } };
  }
  const { error: deletionError } = await admin.auth.admin.deleteUser(userId, false);
  if (deletionError) {
    return { status: 503, body: { estado: 'solicitud_pendiente' } };
  }
  const { error: finalizeError } = await admin.rpc('finalizar_eliminacion_cuenta', {
    p_usuario_id: userId,
  });
  return {
    status: 200,
    body: {
      estado: 'eliminada',
      ...(finalizeError ? { registro_pendiente: true } : {}),
    },
  };
}

// Solo los entrypoints del servidor eligen estas rutas fijas.
export function completeDeletion(decision, userId, admin, verifiedAccessToken) {
  return complete(decision, userId, admin, verifiedAccessToken, 'validar_eliminacion_cuenta');
}
export function completeQaDeletion(decision, userId, admin, verifiedAccessToken) {
  return complete(decision, userId, admin, verifiedAccessToken, 'validar_eliminacion_cuenta_qa');
}

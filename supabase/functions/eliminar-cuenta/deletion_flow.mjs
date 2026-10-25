// Parte sin dependencias externas: permite probar fallos parciales sin tocar Auth.
export async function completeDeletion(decision, userId, admin) {
  if (decision === 'revision') {
    return { status: 202, body: { estado: 'revision', mensaje: 'Solicitud recibida para revisión.' } };
  }
  if (decision !== 'pendiente') {
    return { status: 503, body: { estado: 'estado_desconocido' } };
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

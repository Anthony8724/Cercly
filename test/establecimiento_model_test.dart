import 'package:cercly/features/establecimientos/models/establecimiento_model.dart';
import 'package:cercly/features/establecimientos/models/turno_horario.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, List<TurnoHorario>> horarioCompleto() {
  return {
    for (final dia in EstablecimientoModel.diasSemana) dia: <TurnoHorario>[],
  };
}

EstablecimientoModel crearEstablecimiento({
  String nombre = 'Cafetería de prueba',
  Map<String, List<TurnoHorario>>? horario,
}) {
  return EstablecimientoModel(
    id: 'negocio-prueba',
    propietarioId: 'uid-prueba',
    nombre: nombre,
    descripcion: 'Negocio ficticio para pruebas',
    categoriaId: 'cafeterias',
    direccion: 'Dirección de prueba',
    ubicacion: const GeoPoint(0, 0),
    telefonoPublico: '',
    horario: horario ?? horarioCompleto(),
    zonaHoraria: 'America/Guayaquil',
  );
}

void main() {
  test('prepara un negocio pendiente con fechas del servidor', () {
    final datos = crearEstablecimiento().toFirestoreParaCrear();

    expect(datos['estado'], 'pendiente');
    expect(datos['propietarioId'], 'uid-prueba');
    expect(datos['creadoEn'], isA<FieldValue>());
    expect(datos['actualizadoEn'], isA<FieldValue>());
  });

  test('rechaza un nombre vacío', () {
    expect(() => crearEstablecimiento(nombre: '   '), throwsArgumentError);
  });

  test('rechaza un horario sin los siete días', () {
    final horario = horarioCompleto()..remove('domingo');

    expect(() => crearEstablecimiento(horario: horario), throwsArgumentError);
  });

  test('convierte los turnos y conserva los días cerrados', () {
    final horario = horarioCompleto();
    horario['lunes'] = [
      TurnoHorario(aperturaMinutos: 480, cierreMinutos: 1080),
    ];

    final datos = crearEstablecimiento(horario: horario).toFirestoreParaCrear();

    final guardado = datos['horario'] as Map<String, dynamic>;

    expect(guardado['lunes'], [
      {
        'aperturaMinutos': 480,
        'cierreMinutos': 1080,
        'cierraAlDiaSiguiente': false,
      },
    ]);
    expect(guardado['domingo'], isEmpty);
  });

  test('el modelo conserva una copia independiente del horario', () {
    final horario = horarioCompleto();
    final negocio = crearEstablecimiento(horario: horario);

    horario['lunes']!.add(
      TurnoHorario(aperturaMinutos: 480, cierreMinutos: 720),
    );

    expect(negocio.horario['lunes'], isEmpty);
  });
}

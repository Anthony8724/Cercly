import 'package:cercly/features/establecimientos/models/establecimiento_model.dart';
import 'package:cercly/features/establecimientos/models/turno_horario.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, List<TurnoHorario>> horarioCompleto() {
  return {
    for (final dia in EstablecimientoModel.diasSemana) dia: <TurnoHorario>[],
  };
}

EstablecimientoModel crearEstablecimiento({
  String nombre = 'Cafetería de prueba',
  double latitud = 0.8119,
  double longitud = -77.7173,
  Map<String, List<TurnoHorario>>? horario,
}) {
  return EstablecimientoModel(
    id: '',
    propietarioId: '00000000-0000-0000-0000-000000000001',
    nombre: nombre,
    descripcion: 'Negocio ficticio para pruebas',
    categoriaId: '00000000-0000-0000-0000-000000000002',
    direccion: 'Dirección de prueba',
    latitud: latitud,
    longitud: longitud,
    telefonoPublico: '',
    horario: horario ?? horarioCompleto(),
    zonaHoraria: 'America/Guayaquil',
  );
}

void main() {
  test('prepara un establecimiento pendiente para Supabase', () {
    final datos = crearEstablecimiento().toSupabaseParaCrear();

    expect(datos['estado'], 'pendiente');
    expect(datos['propietario_id'], '00000000-0000-0000-0000-000000000001');
    expect(datos['categoria_id'], '00000000-0000-0000-0000-000000000002');
    expect(datos['latitud'], 0.8119);
    expect(datos['longitud'], -77.7173);
    expect(datos.containsKey('creado_en'), isFalse);
    expect(datos.containsKey('actualizado_en'), isFalse);
  });

  test('rechaza un nombre vacío', () {
    expect(() => crearEstablecimiento(nombre: '   '), throwsArgumentError);
  });

  test('rechaza una latitud fuera del rango permitido', () {
    expect(() => crearEstablecimiento(latitud: 91), throwsArgumentError);
  });

  test('rechaza una longitud fuera del rango permitido', () {
    expect(() => crearEstablecimiento(longitud: -181), throwsArgumentError);
  });

  test('rechaza un horario sin los siete días', () {
    final horario = horarioCompleto()..remove('domingo');

    expect(() => crearEstablecimiento(horario: horario), throwsArgumentError);
  });

  test('convierte los turnos al formato de Supabase', () {
    final horario = horarioCompleto();

    horario['lunes'] = [
      TurnoHorario(aperturaMinutos: 480, cierreMinutos: 1080),
    ];

    final establecimiento = crearEstablecimiento(horario: horario);

    final filas = establecimiento.horariosParaSupabase(
      '00000000-0000-0000-0000-000000000003',
    );

    expect(filas, [
      {
        'establecimiento_id': '00000000-0000-0000-0000-000000000003',
        'dia_semana': 1,
        'apertura_minutos': 480,
        'cierre_minutos': 1080,
        'cierra_al_dia_siguiente': false,
      },
    ]);
  });

  test('los días cerrados no generan filas de horario', () {
    final establecimiento = crearEstablecimiento();

    final filas = establecimiento.horariosParaSupabase(
      '00000000-0000-0000-0000-000000000003',
    );

    expect(filas, isEmpty);
  });

  test('el modelo conserva una copia independiente del horario', () {
    final horario = horarioCompleto();
    final establecimiento = crearEstablecimiento(horario: horario);

    horario['lunes']!.add(
      TurnoHorario(aperturaMinutos: 480, cierreMinutos: 720),
    );

    expect(establecimiento.horario['lunes'], isEmpty);
  });
}

import 'package:flutter/material.dart';

import '../models/establecimiento_model.dart';
import '../models/turno_horario.dart';
import '../services/horario_establecimiento_service.dart';

class HorariosEstablecimientoScreen extends StatefulWidget {
  const HorariosEstablecimientoScreen({
    required this.establecimiento,
    super.key,
  });

  final EstablecimientoModel establecimiento;

  @override
  State<HorariosEstablecimientoScreen> createState() =>
      _HorariosEstablecimientoScreenState();
}

class _HorariosEstablecimientoScreenState
    extends State<HorariosEstablecimientoScreen> {
  final _service = HorarioEstablecimientoService();

  final Map<String, List<_TurnoEditable>> _horario = {
    for (final dia in EstablecimientoModel.diasSemana) dia: <_TurnoEditable>[],
  };

  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final horario = await _service.obtener(widget.establecimiento.id);

      for (final dia in EstablecimientoModel.diasSemana) {
        _horario[dia] = horario[dia]!
            .map(
              (turno) => _TurnoEditable(
                apertura: _desdeMinutos(turno.aperturaMinutos),
                cierre: _desdeMinutos(turno.cierreMinutos),
                cierraAlDiaSiguiente: turno.cierraAlDiaSiguiente,
              ),
            )
            .toList();
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  TimeOfDay _desdeMinutos(int minutos) {
    return TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60);
  }

  int _aMinutos(TimeOfDay hora) {
    return hora.hour * 60 + hora.minute;
  }

  String _nombreDia(String dia) {
    switch (dia) {
      case 'miercoles':
        return 'Miércoles';
      case 'sabado':
        return 'Sábado';
      default:
        return '${dia[0].toUpperCase()}${dia.substring(1)}';
    }
  }

  String _formatearHora(TimeOfDay hora) {
    return hora.format(context);
  }

  void _cambiarEstadoDia(String dia, bool abierto) {
    setState(() {
      if (abierto) {
        _horario[dia] = [
          _TurnoEditable(
            apertura: const TimeOfDay(hour: 8, minute: 0),
            cierre: const TimeOfDay(hour: 18, minute: 0),
          ),
        ];
      } else {
        _horario[dia] = [];
      }
    });
  }

  void _agregarTurno(String dia) {
    setState(() {
      _horario[dia]!.add(
        _TurnoEditable(
          apertura: const TimeOfDay(hour: 8, minute: 0),
          cierre: const TimeOfDay(hour: 18, minute: 0),
        ),
      );
    });
  }

  void _eliminarTurno(String dia, int indice) {
    setState(() {
      _horario[dia]!.removeAt(indice);
    });
  }

  Future<void> _seleccionarHora({
    required String dia,
    required int indice,
    required bool esApertura,
  }) async {
    final turno = _horario[dia]![indice];

    final seleccionada = await showTimePicker(
      context: context,
      initialTime: esApertura ? turno.apertura : turno.cierre,
    );

    if (seleccionada == null) {
      return;
    }

    setState(() {
      if (esApertura) {
        turno.apertura = seleccionada;
      } else {
        turno.cierre = seleccionada;
      }
    });
  }

  Future<void> _guardar() async {
    if (_guardando) {
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      final horarioParaGuardar = {
        for (final dia in EstablecimientoModel.diasSemana)
          dia: _horario[dia]!.map((turno) {
            return TurnoHorario(
              aperturaMinutos: _aMinutos(turno.apertura),
              cierreMinutos: _aMinutos(turno.cierre),
              cierraAlDiaSiguiente: turno.cierraAlDiaSiguiente,
            );
          }).toList(),
      };

      await _service.guardar(
        establecimientoId: widget.establecimiento.id,
        horario: horarioParaGuardar,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horarios guardados correctamente.')),
      );

      Navigator.of(context).pop(true);
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron guardar los horarios: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Horarios de atención')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _VistaError(onReintentar: _cargar)
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    Text(
                      widget.establecimiento.nombre,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Activa los días de atención y configura '
                      'uno o varios turnos.',
                    ),
                    const SizedBox(height: 20),
                    for (final dia in EstablecimientoModel.diasSemana)
                      _construirDia(dia),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar horarios'),
                    ),
                  ],
                ),
                if (_guardando)
                  const ColoredBox(
                    color: Color(0x55000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _construirDia(String dia) {
    final turnos = _horario[dia]!;
    final abierto = turnos.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: abierto,
        leading: Icon(abierto ? Icons.schedule : Icons.event_busy),
        title: Text(
          _nombreDia(dia),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(abierto ? '${turnos.length} turno(s)' : 'Cerrado'),
        trailing: Switch(
          value: abierto,
          onChanged: _guardando
              ? null
              : (valor) {
                  _cambiarEstadoDia(dia, valor);
                },
        ),
        children: [
          if (abierto) ...[
            for (var indice = 0; indice < turnos.length; indice++)
              _construirTurno(dia: dia, indice: indice, turno: turnos[indice]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: _guardando ? null : () => _agregarTurno(dia),
                icon: const Icon(Icons.add),
                label: const Text('Agregar otro turno'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirTurno({
    required String dia,
    required int indice,
    required _TurnoEditable turno,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _guardando
                          ? null
                          : () => _seleccionarHora(
                              dia: dia,
                              indice: indice,
                              esApertura: true,
                            ),
                      child: Text('Abre: ${_formatearHora(turno.apertura)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _guardando
                          ? null
                          : () => _seleccionarHora(
                              dia: dia,
                              indice: indice,
                              esApertura: false,
                            ),
                      child: Text('Cierra: ${_formatearHora(turno.cierre)}'),
                    ),
                  ),
                  IconButton(
                    onPressed: _guardando
                        ? null
                        : () => _eliminarTurno(dia, indice),
                    tooltip: 'Eliminar turno',
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cierra al día siguiente'),
                subtitle: const Text(
                  'Úsalo para negocios que cierran después '
                  'de la medianoche.',
                ),
                value: turno.cierraAlDiaSiguiente,
                onChanged: _guardando
                    ? null
                    : (valor) {
                        setState(() {
                          turno.cierraAlDiaSiguiente = valor;
                        });
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnoEditable {
  _TurnoEditable({
    required this.apertura,
    required this.cierre,
    this.cierraAlDiaSiguiente = false,
  });

  TimeOfDay apertura;
  TimeOfDay cierre;
  bool cierraAlDiaSiguiente;
}

class _VistaError extends StatelessWidget {
  const _VistaError({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No se pudieron cargar los horarios.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

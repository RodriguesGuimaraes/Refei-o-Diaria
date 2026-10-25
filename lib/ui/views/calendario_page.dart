import 'package:flutter/material.dart';

import '../viewmodels/home_viewmodel.dart';
import 'historico_page.dart';

class CalendarioPage extends StatefulWidget {
  const CalendarioPage({
    super.key,
    required this.viewModel,
    this.cameraBuilder,
  });

  final HomeViewModel viewModel;
  final WidgetBuilder? cameraBuilder;

  @override
  State<CalendarioPage> createState() => _CalendarioPageState();
}

class _CalendarioPageState extends State<CalendarioPage> {
  static const _verde = Color(0xFF2A7A5C);
  late DateTime _selecionada;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _selecionada = DateTime(agora.year, agora.month, agora.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAF8),
        title: const Text(
          'Histórico',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF34474F),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final doDia = widget.viewModel.refeicoes
              .where(
                (r) =>
                    r.data.year == _selecionada.year &&
                    r.data.month == _selecionada.month &&
                    r.data.day == _selecionada.day,
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme
                        .copyWith(primary: _verde),
                  ),
                  child: CalendarDatePicker(
                    initialDate: _selecionada,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    onDateChanged: (d) => setState(() => _selecionada = d),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Refeições do dia selecionado',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF34474F),
                ),
              ),
              const SizedBox(height: 10),
              if (doDia.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nenhuma refeição neste dia.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final r in doDia)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RefeicaoTile(
                      refeicao: r,
                      mostrarData: false,
                      onTap: () => abrirDetalhe(
                        context,
                        widget.viewModel,
                        r,
                        widget.cameraBuilder,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

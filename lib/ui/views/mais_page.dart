import 'package:flutter/material.dart';

import '../../models/configuracoes_lembretes.dart';
import '../viewmodels/home_viewmodel.dart';

/// Mantenha igual ao campo `version` do pubspec.yaml.
const versaoApp = '1.0.0';

const _fundo = Color(0xFFFAFAF8);
const _titulo = Color(0xFF34474F);
const _secundario = Color(0xFF667A82);

class MaisPage extends StatefulWidget {
  const MaisPage({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  State<MaisPage> createState() => _MaisPageState();
}

class _MaisPageState extends State<MaisPage> with WidgetsBindingObserver {
  HomeViewModel get viewModel => widget.viewModel;
  bool _incluirFotos = true;
  bool _incluirSemMalEstar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    viewModel.verificarPermissao();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A pessoa pode ter liberado as notificações nas configurações do Android.
    if (state == AppLifecycleState.resumed) viewModel.verificarPermissao();
  }

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _alterarLembrete(TipoLembrete tipo, Lembrete lembrete) async {
    final ok = await viewModel.alterarLembrete(tipo, lembrete);
    if (!ok) {
      _mensagem('Não foi possível salvar o lembrete. Tente novamente.');
    } else if (lembrete.ativo && viewModel.notificacoesPermitidas == false) {
      _mensagem('Lembrete salvo, mas as notificações estão bloqueadas.');
    }
  }

  Future<void> _escolherHorario(TipoLembrete tipo) async {
    final atual = viewModel.lembretes.obter(tipo);
    final horario = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: atual.hora, minute: atual.minuto),
      helpText: 'Horário do lembrete',
    );
    if (horario == null || !mounted) return;
    await _alterarLembrete(
      tipo,
      atual.copyWith(ativo: true, hora: horario.hour, minuto: horario.minute),
    );
  }

  Future<void> _permitirNotificacoes() async {
    try {
      final permitido = await viewModel.notificacoes.solicitarPermissao();
      if (!permitido) {
        await viewModel.notificacoes.abrirConfiguracoesNotificacao();
      }
    } catch (_) {
      _mensagem('Não foi possível abrir as configurações.');
    }
    await viewModel.verificarPermissao();
    if (viewModel.notificacoesPermitidas == true) {
      await viewModel.alterarLembrete(
        TipoLembrete.noite,
        viewModel.lembretes.noite,
      );
    }
  }

  Future<void> _abrirBateria() async {
    try {
      await viewModel.notificacoes.abrirConfiguracoesBateria();
    } catch (_) {
      _mensagem('Não foi possível abrir as configurações.');
    }
  }

  Future<void> _relatorio() async {
    final dias = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Qual período deseja enviar ao médico?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _titulo,
                    ),
                  ),
                ),
                const SwitchListTile(
                  secondary: Icon(Icons.warning_rounded, color: Colors.red),
                  title: Text('Refeições em que passou mal'),
                  subtitle: Text('Sempre incluídas'),
                  value: true,
                  onChanged: null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.check_circle_outline),
                  title: const Text('Incluir refeições sem mal-estar'),
                  subtitle: const Text('Em que passou bem ou sem resposta'),
                  value: _incluirSemMalEstar,
                  onChanged: (valor) {
                    setSheetState(() {});
                    setState(() => _incluirSemMalEstar = valor);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.photo_library_outlined),
                  title: const Text('Incluir fotos'),
                  subtitle: const Text('Miniatura de cada refeição no PDF'),
                  value: _incluirFotos,
                  onChanged: (valor) {
                    setSheetState(() {});
                    setState(() => _incluirFotos = valor);
                  },
                ),
                const Divider(height: 1),
                for (final (rotulo, valor) in const [
                  ('Últimos 7 dias', 7),
                  ('Últimos 15 dias', 15),
                  ('Últimos 30 dias', 30),
                  ('Últimos 90 dias', 90),
                  ('Todo o período', 0),
                ])
                  ListTile(
                    leading: const Icon(Icons.date_range_outlined),
                    title: Text(rotulo),
                    onTap: () => Navigator.pop(sheetContext, valor),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (dias == null || !mounted) return;
    final ok = await viewModel.compartilharRelatorio(
      dias: dias == 0 ? null : dias,
      incluirFotos: _incluirFotos,
      incluirSemMalEstar: _incluirSemMalEstar,
    );
    if (!ok) _mensagem('Não foi possível gerar o relatório. Tente novamente.');
  }

  void _sobre(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Meu Almoço',
      applicationVersion: 'Versão $versaoApp',
      applicationIcon: Image.asset(
        'assets/Ícone de refeição — círculo verde.png',
        width: 48,
        height: 48,
      ),
      children: const [
        Text('Registre suas refeições com foto e acompanhe seu histórico.'),
      ],
    );
  }

  Future<void> _limpar(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar dados?'),
        content: const Text(
          'Todas as refeições e fotos salvas no aplicativo serão apagadas. '
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await viewModel.limparTudo();
    if (!context.mounted) return;
    if (ok) {
      // Telas abertas podem mostrar registros que não existem mais.
      Navigator.of(context).popUntil((rota) => rota.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text('Todos os dados foram apagados.')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível limpar os dados. Tente novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final ocupado =
            viewModel.atualizando ||
            viewModel.salvando ||
            viewModel.gerandoRelatorio;
        return Scaffold(
          backgroundColor: _fundo,
          appBar: AppBar(
            backgroundColor: _fundo,
            title: const Text(
              'Mais',
              style: TextStyle(fontWeight: FontWeight.w700, color: _titulo),
            ),
            actions: [
              IconButton(
                tooltip: 'Sobre',
                icon: const Icon(Icons.info_outline),
                onPressed: () => _sobre(context),
              ),
            ],
            bottom: ocupado
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _Secao('Lembretes'),
                if (viewModel.notificacoesPermitidas == false) ...[
                  _AvisoPermissao(onPermitir: _permitirNotificacoes),
                  const SizedBox(height: 12),
                ],
                for (final (tipo, titulo) in const [
                  (TipoLembrete.noite, 'Como foi seu dia?'),
                  (TipoLembrete.almoco, 'Registrar o almoço'),
                  (TipoLembrete.jantar, 'Registrar o jantar'),
                ]) ...[
                  _LembreteTile(
                    titulo: titulo,
                    lembrete: viewModel.lembretes.obter(tipo),
                    onAtivo: (ativo) => _alterarLembrete(
                      tipo,
                      viewModel.lembretes.obter(tipo).copyWith(ativo: ativo),
                    ),
                    onHorario: () => _escolherHorario(tipo),
                  ),
                  const SizedBox(height: 12),
                ],
                _Opcao(
                  icone: Icons.battery_alert_outlined,
                  titulo: 'Os lembretes não chegam?',
                  subtitulo:
                      'Abra "Bateria" e escolha "Sem restrições" para o '
                      'Meu Almoço',
                  onTap: _abrirBateria,
                ),
                const SizedBox(height: 8),
                const _Secao('Médico'),
                _Opcao(
                  icone: Icons.picture_as_pdf_outlined,
                  titulo: 'Relatório para o médico',
                  subtitulo: viewModel.gerandoRelatorio
                      ? 'Gerando relatório...'
                      : 'Gerar PDF e enviar por WhatsApp ou e-mail',
                  onTap: viewModel.gerandoRelatorio ? null : _relatorio,
                ),
                const SizedBox(height: 8),
                const _Secao('Aplicativo'),
                _Opcao(
                  icone: Icons.info_outline,
                  titulo: 'Sobre o app',
                  subtitulo: 'Versão $versaoApp',
                  onTap: () => _sobre(context),
                ),
                const SizedBox(height: 12),
                _Opcao(
                  icone: Icons.storage_outlined,
                  titulo: 'Limpar dados',
                  subtitulo: 'Remover todas as refeições',
                  onTap: ocupado ? null : () => _limpar(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _secundario,
        ),
      ),
    );
  }
}

class _AvisoPermissao extends StatelessWidget {
  const _AvisoPermissao({required this.onPermitir});

  final VoidCallback onPermitir;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFDECEA),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notifications_off_outlined, color: Colors.red),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'As notificações estão bloqueadas',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _titulo,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Sem elas os lembretes não aparecem no celular.',
              style: TextStyle(fontSize: 12, color: _secundario),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onPermitir,
              child: const Text('Permitir notificações'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LembreteTile extends StatelessWidget {
  const _LembreteTile({
    required this.titulo,
    required this.lembrete,
    required this.onAtivo,
    required this.onHorario,
  });

  final String titulo;
  final Lembrete lembrete;
  final ValueChanged<bool> onAtivo;
  final VoidCallback onHorario;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: onHorario,
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(
          lembrete.ativo
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          color: lembrete.ativo ? const Color(0xFF2A7A5C) : _secundario,
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w700, color: _titulo),
        ),
        subtitle: Text(
          lembrete.ativo
              ? 'Todos os dias às ${lembrete.horario}'
              : 'Desligado (${lembrete.horario})',
          style: const TextStyle(fontSize: 12, color: _secundario),
        ),
        trailing: Switch(value: lembrete.ativo, onChanged: onAtivo),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icone, color: _secundario),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w700, color: _titulo),
        ),
        subtitle: Text(
          subtitulo,
          style: const TextStyle(fontSize: 12, color: _secundario),
        ),
        trailing: const Icon(Icons.chevron_right, color: _secundario),
      ),
    );
  }
}

/// Botão de três pontos da app bar com a opção "Mais" e, opcionalmente, "Excluir".
class MenuMais extends StatelessWidget {
  const MenuMais({super.key, required this.viewModel, this.onExcluir});

  final HomeViewModel viewModel;
  final VoidCallback? onExcluir;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Mais opções',
      onSelected: (opcao) {
        if (opcao == 'excluir') {
          onExcluir?.call();
          return;
        }
        Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => MaisPage(viewModel: viewModel)),
        );
      },
      itemBuilder: (_) => [
        if (onExcluir != null)
          const PopupMenuItem(
            value: 'excluir',
            child: Text(
              'Excluir registro',
              style: TextStyle(color: Colors.red),
            ),
          ),
        const PopupMenuItem(value: 'mais', child: Text('Mais')),
      ],
    );
  }
}

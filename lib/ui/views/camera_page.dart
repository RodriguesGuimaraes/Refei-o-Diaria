import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

typedef ListarCameras = Future<List<CameraDescription>> Function();
typedef SelecionarDaGaleria = Future<XFile?> Function();

/// Tela cheia de camera. Fecha devolvendo o caminho da foto ou null se cancelada.
class CameraPage extends StatefulWidget {
  const CameraPage({super.key, this.listarCameras, this.selecionarDaGaleria});

  final ListarCameras? listarCameras;
  final SelecionarDaGaleria? selecionarDaGaleria;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  static const _fundo = Color(0xFF0E1416);

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _indice = 0;
  bool _iniciando = true;
  bool _ocupado = false;
  bool _flashLigado = false;
  bool _flashSuportado = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregarCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameras.isEmpty) return;
    if (state == AppLifecycleState.inactive) {
      final antigo = _controller;
      _controller = null;
      if (antigo != null) {
        antigo.dispose();
        if (mounted) setState(() {});
      }
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _iniciar();
    }
  }

  Future<void> _carregarCameras() async {
    try {
      _cameras = await (widget.listarCameras ?? availableCameras)();
    } catch (_) {
      _cameras = [];
    }
    if (!mounted) return;
    if (_cameras.isEmpty) {
      setState(() {
        _iniciando = false;
        _erro = 'Nenhuma câmera disponível. Você pode usar a galeria.';
      });
      return;
    }
    final traseira = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    _indice = traseira >= 0 ? traseira : 0;
    await _iniciar();
  }

  Future<void> _iniciar() async {
    final anterior = _controller;
    _controller = null;
    await anterior?.dispose();
    if (!mounted) return;
    setState(() {
      _iniciando = true;
      _erro = null;
    });
    final controller = CameraController(
      _cameras[_indice],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      var suportado = true;
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        suportado = false;
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _flashLigado = false;
        _flashSuportado = suportado;
        _iniciando = false;
      });
    } on CameraException catch (e) {
      await controller.dispose();
      if (!mounted) return;
      final negada = e.code.toLowerCase().contains('permission');
      setState(() {
        _iniciando = false;
        _erro = negada
            ? 'Permissão da câmera negada. Libere o acesso nas configurações ou use a galeria.'
            : 'Não foi possível abrir a câmera. Você pode usar a galeria.';
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _iniciando = false;
        _erro = 'Não foi possível abrir a câmera. Você pode usar a galeria.';
      });
    }
  }

  Future<void> _alternarFlash() async {
    final controller = _controller;
    if (controller == null || !_flashSuportado || _ocupado) return;
    final ligar = !_flashLigado;
    try {
      await controller.setFlashMode(ligar ? FlashMode.always : FlashMode.off);
      if (mounted) setState(() => _flashLigado = ligar);
    } catch (_) {
      if (mounted) {
        setState(() => _flashSuportado = false);
        _aviso('Flash indisponível nesta câmera.');
      }
    }
  }

  Future<void> _trocarCamera() async {
    if (_cameras.length < 2 || _ocupado || _iniciando) return;
    _indice = (_indice + 1) % _cameras.length;
    await _iniciar();
  }

  Future<void> _fotografar() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _ocupado ||
        controller.value.isTakingPicture) {
      return;
    }
    setState(() => _ocupado = true);
    try {
      final foto = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(foto.path);
    } catch (_) {
      if (mounted) {
        setState(() => _ocupado = false);
        _aviso('Não foi possível tirar a foto. Tente novamente.');
      }
    }
  }

  Future<void> _abrirGaleria() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final foto =
          await (widget.selecionarDaGaleria ??
              () => ImagePicker().pickImage(source: ImageSource.gallery))();
      if (!mounted) return;
      if (foto != null) {
        Navigator.of(context).pop(foto.path);
        return;
      }
    } catch (_) {
      if (mounted) _aviso('Não foi possível abrir a galeria.');
    }
    if (mounted) setState(() => _ocupado = false);
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final podeFotografar = _controller != null && !_ocupado && !_iniciando;
    return Scaffold(
      backgroundColor: _fundo,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Fechar',
                    color: Colors.white,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  const Expanded(
                    child: Text(
                      'Registrar refeição',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _flashLigado ? 'Desligar flash' : 'Ligar flash',
                    color: Colors.white,
                    disabledColor: Colors.white38,
                    onPressed: _flashSuportado && !_ocupado
                        ? _alternarFlash
                        : null,
                    icon: Icon(_flashLigado ? Icons.flash_on : Icons.flash_off),
                  ),
                ],
              ),
            ),
            Expanded(child: _previa()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: _AcaoRodape(
                      icone: Icons.photo_library_outlined,
                      rotulo: 'Galeria',
                      onPressed: _ocupado ? null : _abrirGaleria,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Tirar foto',
                    child: GestureDetector(
                      onTap: podeFotografar ? _fotografar : null,
                      child: Opacity(
                        opacity: podeFotografar ? 1 : .4,
                        child: Container(
                          width: 76,
                          height: 76,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _AcaoRodape(
                      icone: Icons.flip_camera_android_outlined,
                      rotulo: 'Trocar câmera',
                      onPressed: _cameras.length > 1 && !_ocupado && !_iniciando
                          ? _trocarCamera
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previa() {
    final controller = _controller;
    if (_iniciando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _erro ?? 'Câmera indisponível.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
      );
    }
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 100,
            height: 100 * controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _AcaoRodape extends StatelessWidget {
  const _AcaoRodape({
    required this.icone,
    required this.rotulo,
    required this.onPressed,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cor = onPressed == null ? Colors.white38 : Colors.white;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: cor),
            const SizedBox(height: 6),
            Text(
              rotulo,
              textAlign: TextAlign.center,
              style: TextStyle(color: cor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

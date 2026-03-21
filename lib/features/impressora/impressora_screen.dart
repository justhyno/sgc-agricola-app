import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../core/services/impressora_service.dart';
import '../../shared/theme.dart';

class ImpressoraScreen extends StatefulWidget {
  const ImpressoraScreen({super.key});
  @override
  State<ImpressoraScreen> createState() => _ImpressoraScreenState();
}

class _ImpressoraScreenState extends State<ImpressoraScreen> {
  final _svc = ImpressoraService.instance;

  List<BluetoothInfo> _dispositivos = [];
  String? _macActual;
  String? _nomeActual;
  bool _conectado = false;
  bool _carregando = false;
  bool _aConectar = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final mac    = await _svc.macGuardado;
    final nome   = await _svc.nomeGuardado;
    final status = await _svc.estaConectado;
    if (mounted) setState(() { _macActual = mac; _nomeActual = nome; _conectado = status; });
    await _carregarDispositivos();
  }

  Future<void> _carregarDispositivos() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      final lista = await _svc.listarDispositivosPareados();
      if (mounted) setState(() { _dispositivos = lista; _carregando = false; });
    } catch (e) {
      if (mounted) setState(() { _erro = 'Erro ao listar dispositivos: $e'; _carregando = false; });
    }
  }

  Future<void> _conectar(BluetoothInfo info) async {
    setState(() { _aConectar = true; _erro = null; });
    try {
      final ok = await _svc.conectar(info.macAdress);
      await _svc.guardarNome(info.macAdress, info.name);
      if (mounted) {
        setState(() {
          _conectado  = ok;
          _macActual  = info.macAdress;
          _nomeActual = info.name;
          _aConectar  = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Conectado a ${info.name}' : 'Falha na ligação'),
          backgroundColor: ok ? kVerde : Colors.red.shade700,
        ));
      }
    } catch (e) {
      if (mounted) setState(() { _erro = e.toString(); _aConectar = false; });
    }
  }

  Future<void> _desconectar() async {
    await _svc.desconectar();
    if (mounted) setState(() => _conectado = false);
  }

  Future<void> _testePage() async {
    if (!_conectado) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ligue-se a uma impressora primeiro'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final ok = await _svc.imprimirTestePage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Página de teste impressa!' : 'Falha ao imprimir'),
        backgroundColor: ok ? kVerde : Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impressora Bluetooth'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregarDispositivos),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // Estado actual
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Estado da ligação',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCinza)),
              const SizedBox(height: 12),
              Row(children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _conectado ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _conectado
                      ? 'Conectado: ${_nomeActual ?? _macActual ?? '—'}'
                      : _nomeActual != null
                          ? 'Desconectado (última: $_nomeActual)'
                          : 'Sem impressora configurada',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _conectado ? kVerde : kCinza,
                  ),
                )),
              ]),
              if (_conectado) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testePage,
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Imprimir Teste'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _desconectar,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Desligar'),
                  ),
                ]),
              ],
            ]),
          ),
        ),

        const SizedBox(height: 20),

        // Info sobre pareamento
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Para aparecer na lista, a impressora deve estar ligada e '
              'previamente pareada nas Definições Bluetooth do Android.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            )),
          ]),
        ),

        const SizedBox(height: 16),

        // Lista de dispositivos
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Dispositivos pareados',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kVerdeClaro)),
          if (_carregando)
            const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: kVerde)),
        ]),
        const SizedBox(height: 8),

        if (_erro != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),

        if (!_carregando && _dispositivos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Nenhum dispositivo BT pareado',
              style: TextStyle(color: kCinza))),
          )
        else
          ...(_dispositivos.map((d) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: d.macAdress == _macActual ? kVerdeLight : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.print,
                  color: d.macAdress == _macActual ? kVerde : kCinza, size: 22),
              ),
              title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(d.macAdress,
                style: const TextStyle(fontSize: 11, color: kCinza, fontFamily: 'monospace')),
              trailing: d.macAdress == _macActual && _conectado
                  ? const Chip(label: Text('Activa', style: TextStyle(fontSize: 11)))
                  : _aConectar
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kVerde))
                      : TextButton(
                          onPressed: () => _conectar(d),
                          child: const Text('Ligar'),
                        ),
            ),
          ))),
      ]),
    );
  }
}

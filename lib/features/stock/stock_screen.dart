import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/sync_provider.dart';
import '../../shared/theme.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});
  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  List<Map<String, dynamic>> _produtos = [];
  bool _loading = true;
  String? _erro;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() { _loading = true; _erro = null; });
    try {
      final data = await ApiClient.instance.stock();
      setState(() {
        _produtos = List<Map<String, dynamic>>.from(data['produtos'] ?? []);
        _loading  = false;
      });
    } catch (e) {
      setState(() { _erro = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filtro.isEmpty) return _produtos;
    final t = _filtro.toLowerCase();
    return _produtos.where((p) =>
      (p['nome_comercial'] as String).toLowerCase().contains(t) ||
      (p['categoria'] as String? ?? '').toLowerCase().contains(t)
    ).toList();
  }

  Color _corEstado(String estado) {
    return switch (estado) {
      'esgotado' => Colors.red.shade600,
      'critico'  => Colors.orange.shade700,
      _          => Colors.green.shade600,
    };
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            icon: sync.status == SyncStatus.syncing
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: () {
              ref.read(syncProvider.notifier).tentarSincronizar();
              _carregar();
            },
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _filtro = v),
            decoration: const InputDecoration(
              hintText: 'Filtrar por produto ou categoria...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: kVerde)))
        else if (_erro != null)
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Sem ligação — a mostrar dados locais', style: TextStyle(color: kCinza)),
          ])))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _filtrados.length,
              itemBuilder: (_, i) {
                final p = _filtrados[i];
                final estado = p['estado'] as String? ?? 'ok';
                final stock  = (p['stock'] as num? ?? 0).toDouble();
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _corEstado(estado).withOpacity(.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                      color: _corEstado(estado), size: 22),
                  ),
                  title: Text(p['nome_comercial'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(p['categoria'] as String? ?? '',
                    style: const TextStyle(fontSize: 12, color: kCinza)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${stock.toStringAsFixed(estado == 'ok' ? 0 : 2)} ${p['unidade'] ?? ''}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: _corEstado(estado))),
                      Text('MT ${(p['preco_venda'] as num? ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11, color: kCinza)),
                    ],
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}

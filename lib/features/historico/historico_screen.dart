import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/db/database.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/theme.dart';
import 'venda_detalhe_screen.dart';

class HistoricoScreen extends ConsumerStatefulWidget {
  const HistoricoScreen({super.key});
  @override
  ConsumerState<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends ConsumerState<HistoricoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _pendentes  = [];
  List<Map<String, dynamic>> _vendas     = [];
  bool _loadingPend = true;
  bool _loadingVend = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _carregarPendentes();
    _carregarVendas();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _carregarPendentes() async {
    setState(() => _loadingPend = true);
    final lista = await DatabaseHelper.instance.vendasNaoSincronizadas();
    if (mounted) setState(() { _pendentes = lista; _loadingPend = false; });
  }

  Future<void> _carregarVendas() async {
    setState(() => _loadingVend = true);
    try {
      final data = await ApiClient.instance.listarVendas();
      final lista = List<Map<String, dynamic>>.from(data['data'] ?? []);
      if (mounted) setState(() { _vendas = lista; _loadingVend = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingVend = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_carregarPendentes(), _carregarVendas()]);
  }

  @override
  Widget build(BuildContext context) {
    final operador = ref.watch(authProvider).userName ?? '—';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Vendas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshAll),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Pendentes${_pendentes.isNotEmpty ? ' (${_pendentes.length})' : ''}'),
            const Tab(text: 'Sincronizadas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _PendentesTab(
            pendentes: _pendentes,
            loading: _loadingPend,
            operador: operador,
            onRefresh: _carregarPendentes,
          ),
          _SincronizadasTab(
            vendas: _vendas,
            loading: _loadingVend,
            onRefresh: _carregarVendas,
          ),
        ],
      ),
    );
  }
}

// ─── Tab: Pendentes ───────────────────────────────────────────────────────────

class _PendentesTab extends StatelessWidget {
  final List<Map<String, dynamic>> pendentes;
  final bool loading;
  final String operador;
  final VoidCallback onRefresh;

  const _PendentesTab({
    required this.pendentes, required this.loading,
    required this.operador, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: kVerde));
    if (pendentes.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_done_outlined, size: 56, color: Colors.green.shade300),
        const SizedBox(height: 12),
        const Text('Sem vendas pendentes', style: TextStyle(color: kCinza, fontSize: 16)),
      ],
    ));

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: kVerde,
      child: ListView.builder(
        itemCount: pendentes.length,
        itemBuilder: (ctx, i) {
          final pend = pendentes[i];
          final dados = jsonDecode(pend['dados'] as String) as Map<String, dynamic>;
          final itens = List<Map<String, dynamic>>.from(dados['items'] ?? []);
          final pags  = List<Map<String, dynamic>>.from(dados['pagamentos'] ?? []);
          final total = pags.fold<double>(0, (s, p) => s + (p['valor'] as num).toDouble());
          final criadaEm = pend['criada_em'] as String;
          final erroSinc = pend['erro_sinc'] as String?;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: erroSinc != null
                      ? Colors.red.shade50 : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  erroSinc != null ? Icons.error_outline : Icons.cloud_upload_outlined,
                  color: erroSinc != null ? Colors.red : const Color(0xFFB45309),
                  size: 22,
                ),
              ),
              title: Row(children: [
                Text('Venda #${pend['device_sale_id']}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: erroSinc != null
                        ? Colors.red.shade100 : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    erroSinc != null ? 'Erro' : 'Pendente',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: erroSinc != null
                          ? Colors.red.shade700 : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ]),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${itens.length} produto(s) • $criadaEm',
                  style: const TextStyle(fontSize: 12, color: kCinza)),
                if (erroSinc != null)
                  Text('Erro: $erroSinc',
                    style: const TextStyle(fontSize: 11, color: Colors.red)),
              ]),
              trailing: Text('MT ${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: kVerde)),
            ),
          );
        },
      ),
    );
  }
}

// ─── Tab: Sincronizadas ───────────────────────────────────────────────────────

class _SincronizadasTab extends StatelessWidget {
  final List<Map<String, dynamic>> vendas;
  final bool loading;
  final VoidCallback onRefresh;

  const _SincronizadasTab({
    required this.vendas, required this.loading, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: kVerde));
    if (vendas.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('Sem vendas sincronizadas', style: TextStyle(color: kCinza)),
        const SizedBox(height: 8),
        const Text('Verifique a ligação ao servidor',
          style: TextStyle(color: kCinza, fontSize: 12)),
      ],
    ));

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: kVerde,
      child: ListView.builder(
        itemCount: vendas.length,
        itemBuilder: (ctx, i) {
          final v    = vendas[i];
          final itens = List<Map<String, dynamic>>.from(v['itens'] ?? []);
          final pags  = List<Map<String, dynamic>>.from(v['pagamentos'] ?? []);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => VendaDetalheScreen(venda: v))),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kVerdeLight, borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_outlined, color: kVerde, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v['numero_venda'] as String? ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${itens.length} produto(s)'
                      '${v['cliente'] != null ? ' • ${v['cliente']}' : ''}',
                      style: const TextStyle(fontSize: 12, color: kCinza),
                    ),
                    Text(_formatarData(v['finalizada_em'] as String?),
                      style: const TextStyle(fontSize: 11, color: kCinza)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('MT ${(v['total'] as num? ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: kVerde)),
                    if (pags.isNotEmpty)
                      Text(_metodoLabel(pags.first['metodo'] as String? ?? ''),
                        style: const TextStyle(fontSize: 11, color: kCinza)),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatarData(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'
             ' ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  String _metodoLabel(String m) => switch (m) {
    'dinheiro' => 'Dinheiro', 'mpesa' => 'M-Pesa', 'emola' => 'e-Mola',
    'pos' => 'POS', 'transferencia' => 'Transferência', _ => m,
  };
}

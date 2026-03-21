import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/theme.dart';

class AlertasScreen extends ConsumerStatefulWidget {
  const AlertasScreen({super.key});
  @override
  ConsumerState<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends ConsumerState<AlertasScreen> {
  Map<String, dynamic>? _dados;
  bool _loading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() { _loading = true; _erro = null; });
    try {
      final data = await ApiClient.instance.alertas();
      setState(() { _dados = data; _loading = false; });
    } catch (e) {
      setState(() { _erro = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de Validade'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kVerde))
          : _erro != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Sem ligação ao servidor', style: TextStyle(color: kCinza)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _carregar, child: const Text('Tentar novamente')),
                ]))
              : _buildConteudo(),
    );
  }

  Widget _buildConteudo() {
    final lotes = List<Map<String, dynamic>>.from(_dados?['lotes'] ?? []);
    final vencidos  = (_dados?['vencidos']  as int? ?? 0);
    final criticos  = (_dados?['criticos']  as int? ?? 0);
    final urgentes  = (_dados?['urgentes']  as int? ?? 0);

    return Column(children: [
      // Resumo
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorda),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _Stat(label: 'Vencidos', value: vencidos, color: Colors.red.shade600),
          _Stat(label: 'Críticos', value: criticos, color: Colors.orange.shade700),
          _Stat(label: 'Urgentes', value: urgentes, color: Colors.amber.shade700),
        ]),
      ),

      if (lotes.isEmpty)
        Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline, size: 56, color: Colors.green.shade400),
          const SizedBox(height: 12),
          const Text('Sem alertas activos', style: TextStyle(color: kCinza, fontSize: 16)),
        ])))
      else
        Expanded(
          child: ListView.builder(
            itemCount: lotes.length,
            itemBuilder: (_, i) => _LoteAlertaTile(lote: lotes[i]),
          ),
        ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontSize: 12, color: kCinza)),
  ]);
}

class _LoteAlertaTile extends StatelessWidget {
  final Map<String, dynamic> lote;
  const _LoteAlertaTile({required this.lote});

  static const _cores = {
    'vencido': Color(0xFFdc2626),
    'critico': Color(0xFFd97706),
    'urgente': Color(0xFFca8a04),
  };

  static const _icons = {
    'vencido': Icons.dangerous_outlined,
    'critico': Icons.warning_outlined,
    'urgente': Icons.warning_amber_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final estado = lote['estado'] as String? ?? 'urgente';
    final cor    = _cores[estado] ?? Colors.orange;
    final dias   = lote['dias_para_vencer'] as int?;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cor.withOpacity(.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_icons[estado] ?? Icons.warning_outlined, color: cor, size: 22),
      ),
      title: Text(lote['produto'] as String? ?? '—',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
        'Lote: ${lote['numero_lote'] ?? '—'} • '
        'Val: ${lote['data_validade'] ?? '—'} • '
        'Qty: ${(lote['quantidade'] as num? ?? 0).toStringAsFixed(0)} ${lote['unidade'] ?? ''}',
        style: const TextStyle(fontSize: 12, color: kCinza),
      ),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(
          dias != null ? (dias < 0 ? 'VENCIDO' : '${dias}d') : '—',
          style: TextStyle(fontWeight: FontWeight.w800, color: cor, fontSize: 13),
        ),
        Text(estado.toUpperCase(), style: TextStyle(fontSize: 9, color: cor)),
      ]),
    );
  }
}

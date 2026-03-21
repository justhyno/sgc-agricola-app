import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/impressora_service.dart';
import '../../shared/theme.dart';

class VendaDetalheScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> venda;
  const VendaDetalheScreen({super.key, required this.venda});

  @override
  ConsumerState<VendaDetalheScreen> createState() => _VendaDetalheScreenState();
}

class _VendaDetalheScreenState extends ConsumerState<VendaDetalheScreen> {
  bool _imprimindo = false;

  Future<void> _imprimir() async {
    final svc     = ImpressoraService.instance;
    final conectado = await svc.estaConectado;
    if (!conectado) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sem impressora ligada. Configure em PDV → Impressora.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _imprimindo = true);

    final v       = widget.venda;
    final auth    = ref.read(authProvider);
    final itens   = List<Map<String, dynamic>>.from(v['itens']      ?? []);
    final pags    = List<Map<String, dynamic>>.from(v['pagamentos'] ?? []);
    final total   = (v['total']    as num? ?? 0).toDouble();
    final troco   = (v['troco']    as num? ?? 0).toDouble();

    final recibo = Recibo(
      empresa:  'SGC Agrícola',
      numVenda: v['numero_venda'] as String? ?? '—',
      dataHora: _parseData(v['finalizada_em'] as String?),
      operador: auth.userName ?? '—',
      cliente:  v['cliente']  as String?,
      itens: itens.map((i) => ReciboItem(
        nome:       i['produto']   as String? ?? '—',
        quantidade: (i['quantidade'] as num? ?? 1).toDouble(),
        unidade:    i['unidade']   as String? ?? 'un',
        preco:      (i['preco']    as num? ?? 0).toDouble(),
        total:      (i['total']    as num? ?? 0).toDouble(),
      )).toList(),
      subtotal: total,
      totalIva: 0,
      total:    total,
      pagamentos: pags.map((p) => ReciboPagamento(
        metodo:     p['metodo']     as String? ?? '—',
        valor:      (p['valor']     as num? ?? 0).toDouble(),
        referencia: p['referencia'] as String?,
      )).toList(),
      troco: troco,
    );

    final ok = await svc.imprimirRecibo(recibo);
    if (mounted) {
      setState(() => _imprimindo = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Recibo impresso com sucesso!' : 'Falha ao imprimir'),
        backgroundColor: ok ? kVerde : Colors.red.shade700,
      ));
    }
  }

  DateTime _parseData(String? iso) {
    if (iso == null) return DateTime.now();
    try { return DateTime.parse(iso).toLocal(); } catch (_) { return DateTime.now(); }
  }

  String _formatarData(String? iso) {
    final d = _parseData(iso);
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'
           ' ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  String _metodoLabel(String m) => switch (m) {
    'dinheiro' => 'Dinheiro', 'mpesa' => 'M-Pesa', 'emola' => 'e-Mola',
    'pos' => 'POS', 'transferencia' => 'Transferência', 'credito' => 'Crédito', _ => m,
  };

  @override
  Widget build(BuildContext context) {
    final v     = widget.venda;
    final itens = List<Map<String, dynamic>>.from(v['itens']      ?? []);
    final pags  = List<Map<String, dynamic>>.from(v['pagamentos'] ?? []);
    final total = (v['total'] as num? ?? 0).toDouble();
    final troco = (v['troco'] as num? ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(v['numero_venda'] as String? ?? 'Detalhe'),
        actions: [
          _imprimindo
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.print_outlined),
                  tooltip: 'Imprimir recibo',
                  onPressed: _imprimir,
                ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // Cabeçalho
        _Secao(
          titulo: 'Dados da Venda',
          child: Column(children: [
            _InfoRow('Número',    v['numero_venda']   as String? ?? '—'),
            _InfoRow('Data',      _formatarData(v['finalizada_em'] as String?)),
            _InfoRow('Estado',    (v['estado'] as String? ?? '—').toUpperCase()),
            if (v['cliente'] != null) _InfoRow('Cliente', v['cliente'] as String),
          ]),
        ),
        const SizedBox(height: 12),

        // Produtos
        _Secao(
          titulo: 'Produtos',
          child: Column(children: [
            Row(children: const [
              Expanded(flex: 4, child: Text('Produto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kCinza))),
              Expanded(flex: 2, child: Text('Qtd.',    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kCinza), textAlign: TextAlign.right)),
              Expanded(flex: 3, child: Text('Total',   style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kCinza), textAlign: TextAlign.right)),
            ]),
            const Divider(height: 12),
            ...itens.map((i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(flex: 4, child: Text(i['produto'] as String? ?? '—',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text(
                  (i['quantidade'] as num? ?? 0).toStringAsFixed(
                    (i['quantidade'] as num? ?? 0) == (i['quantidade'] as num? ?? 0).truncate() ? 0 : 2),
                  textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                Expanded(flex: 3, child: Text(
                  'MT ${(i['total'] as num? ?? 0).toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kVerde))),
              ]),
            )),
          ]),
        ),
        const SizedBox(height: 12),

        // Totais
        _Secao(
          titulo: 'Totais',
          child: Column(children: [
            _InfoRow('TOTAL', 'MT ${total.toStringAsFixed(2)}',
              bold: true, cor: kVerde),
          ]),
        ),
        const SizedBox(height: 12),

        // Pagamentos
        _Secao(
          titulo: 'Pagamentos',
          child: Column(children: [
            ...pags.map((p) => _InfoRow(
              _metodoLabel(p['metodo'] as String? ?? ''),
              'MT ${(p['valor'] as num? ?? 0).toStringAsFixed(2)}',
            )),
            if (troco > 0.001)
              _InfoRow('Troco', 'MT ${troco.toStringAsFixed(2)}',
                cor: const Color(0xFFB45309)),
          ]),
        ),
        const SizedBox(height: 24),

        // Botão imprimir
        ElevatedButton.icon(
          onPressed: _imprimindo ? null : _imprimir,
          icon: const Icon(Icons.print),
          label: const Text('Imprimir Recibo'),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Secao({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorda),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: kCinza, letterSpacing: .5,
      )),
      const SizedBox(height: 10),
      child,
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? cor;
  const _InfoRow(this.label, this.value, {this.bold = false, this.cor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: kCinza)),
      Text(value, style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: cor,
      )),
    ]),
  );
}

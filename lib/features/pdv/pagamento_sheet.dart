import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/pdv_provider.dart';
import '../../core/providers/sync_provider.dart';
import '../../shared/theme.dart';

const _metodos = [
  {'id': 'dinheiro',      'label': 'Dinheiro',      'icon': Icons.payments_outlined},
  {'id': 'mpesa',         'label': 'M-Pesa',         'icon': Icons.phone_android},
  {'id': 'emola',         'label': 'e-Mola',         'icon': Icons.phone_android},
  {'id': 'pos',           'label': 'POS',             'icon': Icons.credit_card},
  {'id': 'transferencia', 'label': 'Transferência',   'icon': Icons.account_balance},
];

class PagamentoSheet extends ConsumerStatefulWidget {
  const PagamentoSheet({super.key});
  @override
  ConsumerState<PagamentoSheet> createState() => _PagamentoSheetState();
}

class _PagamentoSheetState extends ConsumerState<PagamentoSheet> {
  String _metodo     = 'dinheiro';
  final _valorCtrl   = TextEditingController();
  final _refCtrl     = TextEditingController();
  bool _confirmando  = false;

  @override
  void dispose() {
    _valorCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  double get _totalVenda => ref.read(pdvProvider).total;
  double get _valorInput => double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _troco => (_valorInput - _totalVenda).clamp(0, double.infinity);

  Future<void> _confirmar() async {
    final valor = _valorInput;
    if (valor < _totalVenda) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Valor insuficiente'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _confirmando = true);
    final pagamentos = [PagamentoItem(metodo: _metodo, valor: valor, referencia: _refCtrl.text.isNotEmpty ? _refCtrl.text : null)];
    final erro = await ref.read(pdvProvider.notifier).finalizarVenda(pagamentos);

    if (erro != null && mounted) {
      setState(() => _confirmando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(erro), backgroundColor: Colors.red,
      ));
      return;
    }

    // Tentar sincronizar em background
    ref.read(syncProvider.notifier).tentarSincronizar();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final pdv = ref.watch(pdvProvider);
    final total = pdv.total;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20, left: 20, right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          )),

          // Total
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kVerdeLight, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('TOTAL A PAGAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCinza)),
              Text('MT ${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kVerde)),
            ]),
          ),
          const SizedBox(height: 20),

          // Método
          const Text('Método de pagamento', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _metodos.map((m) {
            final sel = m['id'] == _metodo;
            return GestureDetector(
              onTap: () => setState(() => _metodo = m['id'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? kVerde : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? kVerde : Colors.grey.shade300),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(m['icon'] as IconData, size: 16, color: sel ? Colors.white : kCinza),
                  const SizedBox(width: 6),
                  Text(m['label'] as String,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : kCinza)),
                ]),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),

          // Valor recebido
          TextField(
            controller: _valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Valor recebido (MT)',
              prefixIcon: const Icon(Icons.attach_money),
              hintText: total.toStringAsFixed(2),
            ),
          ),
          const SizedBox(height: 10),

          // Referência (para mpesa/emola/transferencia)
          if (['mpesa', 'emola', 'transferencia', 'pos'].contains(_metodo))
            TextField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                labelText: 'Referência / Confirmação',
                prefixIcon: Icon(Icons.tag),
              ),
            ),

          // Troco
          if (_troco > 0.001) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Troco', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                Text('MT ${_troco.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFFB45309))),
              ]),
            ),
          ],

          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _confirmando ? null : _confirmar,
            icon: _confirmando
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle),
            label: Text(_confirmando ? 'A registar...' : 'Confirmar Venda'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/db/database.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/pdv_provider.dart';
import '../../shared/theme.dart';
import 'pagamento_sheet.dart';

class PdvScreen extends ConsumerStatefulWidget {
  const PdvScreen({super.key});
  @override
  ConsumerState<PdvScreen> createState() => _PdvScreenState();
}

class _PdvScreenState extends ConsumerState<PdvScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];
  bool _scannerAberto = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pesquisar(String termo) async {
    if (termo.length < 2) {
      setState(() => _resultados = []);
      return;
    }
    final r = await DatabaseHelper.instance.pesquisarProdutos(termo);
    if (mounted) setState(() => _resultados = r);
  }

  void _onBarcode(BarcodeCapture capture) async {
    final barras = capture.barcodes.firstOrNull?.rawValue;
    if (barras == null) return;

    setState(() => _scannerAberto = false);
    final produto = await DatabaseHelper.instance.produtoPorBarras(barras);
    if (produto == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produto não encontrado: $barras'),
          backgroundColor: Colors.orange.shade700));
      return;
    }
    if (produto != null) _adicionarProduto(produto);
  }

  void _adicionarProduto(Map<String, dynamic> produto) {
    final lotes = _parseLotes(produto['lotes_raw'] as String?);
    if (lotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sem stock disponível para este produto'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    // Primeiro lote com stock (FEFO)
    final lote = lotes.first;
    ref.read(pdvProvider.notifier).adicionarItem(ItemCarrinho(
      produtoId:     produto['id'] as int,
      loteId:        lote['id'] as int,
      nome:          produto['nome_comercial'] as String,
      unidade:       produto['unidade_medida'] as String,
      numeroLote:    lote['numero_lote'] as String?,
      precoUnitario: (produto['preco_venda'] as num).toDouble(),
      taxaIva:       (produto['taxa_iva'] as num? ?? 0).toDouble(),
    ));

    _searchCtrl.clear();
    setState(() => _resultados = []);
  }

  List<Map<String, dynamic>> _parseLotes(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw.split(';;').map((s) {
      final parts = s.split('|');
      if (parts.length < 6) return null;
      return {
        'id':                  int.tryParse(parts[0]),
        'numero_lote':         parts[1].isNotEmpty ? parts[1] : null,
        'quantidade_actual':   double.tryParse(parts[2]) ?? 0,
        'preco_custo_unitario': double.tryParse(parts[3]) ?? 0,
        'data_validade':       parts[4].isNotEmpty ? parts[4] : null,
        'estado':              parts[5],
      };
    }).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _checkout() async {
    final pdv = ref.read(pdvProvider);
    if (pdv.vazio) return;

    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PagamentoSheet(),
    );

    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 8),
          Text('Venda registada! A sincronizar...'),
        ]),
        backgroundColor: kVerde,
        duration: Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final pdv  = ref.watch(pdvProvider);

    if (_scannerAberto) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ler Código de Barras'),
          leading: BackButton(onPressed: () => setState(() => _scannerAberto = false)),
        ),
        body: MobileScanner(onDetect: _onBarcode),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.lojaNome ?? 'PDV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Impressora',
            onPressed: () => context.push('/impressora'),
          ),
          if (!pdv.vazio)
            TextButton.icon(
              onPressed: () => ref.read(pdvProvider.notifier).limparCarrinho(),
              icon: const Icon(Icons.clear_all, color: Colors.white70, size: 18),
              label: const Text('Limpar', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
        ],
      ),
      body: Column(children: [
        // Barra de pesquisa + scanner
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _pesquisar,
                decoration: const InputDecoration(
                  hintText: 'Pesquisar produto...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => setState(() => _scannerAberto = true),
              icon: const Icon(Icons.qr_code_scanner),
              style: IconButton.styleFrom(backgroundColor: kVerde, foregroundColor: Colors.white),
            ),
          ]),
        ),

        // Resultados de pesquisa
        if (_resultados.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _resultados.length,
              itemBuilder: (_, i) => _ProdutoTile(
                produto: _resultados[i],
                onTap: () => _adicionarProduto(_resultados[i]),
              ),
            ),
          )
        else if (pdv.vazio)
          Expanded(
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('Pesquise ou leia o código\nde um produto para adicionar',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ]),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: pdv.carrinho.length,
              itemBuilder: (_, i) => _ItemCarrinhoTile(item: pdv.carrinho[i]),
            ),
          ),

        // Rodapé com total + botão
        if (!pdv.vazio)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: kBorda)),
            ),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${pdv.carrinho.length} item(s)',
                  style: const TextStyle(fontSize: 12, color: kCinza)),
                Text('MT ${pdv.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kVerde)),
              ]),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _checkout,
                icon: const Icon(Icons.payment),
                label: const Text('Cobrar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _ProdutoTile extends StatelessWidget {
  final Map<String, dynamic> produto;
  final VoidCallback onTap;
  const _ProdutoTile({required this.produto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: kVerdeLight, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.inventory_2_outlined, color: kVerde, size: 22),
      ),
      title: Text(produto['nome_comercial'] as String,
        style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${produto['categoria'] ?? ''} • MT ${(produto['preco_venda'] as num).toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 12, color: kCinza)),
      trailing: const Icon(Icons.add_circle, color: kVerde),
      onTap: onTap,
    );
  }
}

class _ItemCarrinhoTile extends ConsumerWidget {
  final ItemCarrinho item;
  const _ItemCarrinhoTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(item.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('MT ${item.precoUnitario.toStringAsFixed(2)} / ${item.unidade}'
        '${item.numeroLote != null ? ' • Lote: ${item.numeroLote}' : ''}',
        style: const TextStyle(fontSize: 12, color: kCinza)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: () => ref.read(pdvProvider.notifier)
              .alterarQuantidade(item.loteId, item.quantidade - 1),
          color: kCinza,
          padding: EdgeInsets.zero,
        ),
        SizedBox(width: 36, child: Text(item.quantidade.toStringAsFixed(
          item.quantidade == item.quantidade.truncate() ? 0 : 2),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: () => ref.read(pdvProvider.notifier)
              .alterarQuantidade(item.loteId, item.quantidade + 1),
          color: kVerde,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: 8),
        Text('MT ${item.total.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w700, color: kVerde, fontSize: 13)),
      ]),
    );
  }
}

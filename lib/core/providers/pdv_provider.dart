import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';

class ItemCarrinho {
  final int produtoId;
  final int loteId;
  final String nome;
  final String unidade;
  final String? numeroLote;
  final double precoUnitario;
  final double taxaIva;
  double quantidade;
  double desconto; // %

  ItemCarrinho({
    required this.produtoId,
    required this.loteId,
    required this.nome,
    required this.unidade,
    this.numeroLote,
    required this.precoUnitario,
    required this.taxaIva,
    this.quantidade = 1,
    this.desconto = 0,
  });

  double get subtotal => quantidade * precoUnitario * (1 - desconto / 100);
  double get totalIva  => subtotal * (taxaIva / 100);
  double get total     => subtotal + totalIva;
}

class PagamentoItem {
  final String metodo;
  final double valor;
  final String? referencia;
  PagamentoItem({required this.metodo, required this.valor, this.referencia});
}

class PdvState {
  final List<ItemCarrinho> carrinho;
  final int? clienteId;
  final String? clienteNome;
  final double descontoGeral; // %
  final bool processando;
  final String? erro;

  const PdvState({
    this.carrinho = const [],
    this.clienteId,
    this.clienteNome,
    this.descontoGeral = 0,
    this.processando = false,
    this.erro,
  });

  double get subtotal => carrinho.fold(0, (s, i) => s + i.subtotal);
  double get totalIva  => carrinho.fold(0, (s, i) => s + i.totalIva) * (1 - descontoGeral / 100);
  double get descontoValor => subtotal * descontoGeral / 100;
  double get total => subtotal - descontoValor + totalIva;
  bool   get vazio => carrinho.isEmpty;

  PdvState copyWith({
    List<ItemCarrinho>? carrinho, int? clienteId, String? clienteNome,
    double? descontoGeral, bool? processando, String? erro,
  }) => PdvState(
    carrinho:     carrinho     ?? this.carrinho,
    clienteId:    clienteId   ?? this.clienteId,
    clienteNome:  clienteNome ?? this.clienteNome,
    descontoGeral: descontoGeral ?? this.descontoGeral,
    processando:  processando  ?? this.processando,
    erro:         erro,
  );
}

class PdvNotifier extends StateNotifier<PdvState> {
  final _storage = const FlutterSecureStorage();
  final _db = DatabaseHelper.instance;
  static int _saleCounter = 0;

  PdvNotifier() : super(const PdvState());

  void adicionarItem(ItemCarrinho item) {
    final lista = [...state.carrinho];
    final idx = lista.indexWhere((i) => i.loteId == item.loteId);
    if (idx >= 0) {
      lista[idx].quantidade += item.quantidade;
    } else {
      lista.add(item);
    }
    state = state.copyWith(carrinho: lista);
  }

  void removerItem(int loteId) {
    state = state.copyWith(
      carrinho: state.carrinho.where((i) => i.loteId != loteId).toList(),
    );
  }

  void alterarQuantidade(int loteId, double qty) {
    if (qty <= 0) return removerItem(loteId);
    final lista = [...state.carrinho];
    final idx = lista.indexWhere((i) => i.loteId == loteId);
    if (idx >= 0) lista[idx].quantidade = qty;
    state = state.copyWith(carrinho: lista);
  }

  void definirCliente(int? id, String? nome) {
    state = state.copyWith(clienteId: id, clienteNome: nome);
  }

  void definirDesconto(double pct) {
    state = state.copyWith(descontoGeral: pct.clamp(0, 100));
  }

  void limparCarrinho() => state = const PdvState();

  Future<String?> finalizarVenda(List<PagamentoItem> pagamentos) async {
    if (state.carrinho.isEmpty) return 'Carrinho vazio';

    state = state.copyWith(processando: true);

    try {
      // Obter device_uuid (gerado uma vez por instalação)
      String? deviceUuid = await _storage.read(key: 'device_uuid');
      if (deviceUuid == null) {
        deviceUuid = const Uuid().v4();
        await _storage.write(key: 'device_uuid', value: deviceUuid);
      }
      _saleCounter++;

      final payload = {
        'device_uuid':    deviceUuid,
        'device_sale_id': _saleCounter,
        'customer_id':    state.clienteId,
        'desconto_percentagem': state.descontoGeral,
        'pagamentos': pagamentos.map((p) => {
          'metodo': p.metodo, 'valor': p.valor, 'referencia': p.referencia,
        }).toList(),
        'items': state.carrinho.map((i) => {
          'product_id':          i.produtoId,
          'batch_id':            i.loteId,
          'quantidade':          i.quantidade,
          'preco_unitario':      i.precoUnitario,
          'taxa_iva':            i.taxaIva,
          'desconto_percentagem': i.desconto,
        }).toList(),
      };

      // Guardar localmente (offline-first)
      await _db.inserirVendaPendente(deviceUuid, _saleCounter, jsonEncode(payload));

      state = const PdvState(); // limpar após guardar
      return null; // null = sucesso
    } catch (e) {
      state = state.copyWith(processando: false, erro: e.toString());
      return e.toString();
    }
  }
}

final pdvProvider = StateNotifierProvider<PdvNotifier, PdvState>(
  (_) => PdvNotifier(),
);

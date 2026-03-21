import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class Recibo {
  final String empresa;
  final String nif;
  final String morada;
  final String telefone;
  final String numVenda;
  final DateTime dataHora;
  final String operador;
  final String? cliente;
  final List<ReciboItem> itens;
  final double subtotal;
  final double descontoValor;
  final double descontoPercentagem;
  final double totalIva;
  final double total;
  final List<ReciboPagamento> pagamentos;
  final double troco;

  const Recibo({
    required this.empresa,
    this.nif = '',
    this.morada = '',
    this.telefone = '',
    required this.numVenda,
    required this.dataHora,
    required this.operador,
    this.cliente,
    required this.itens,
    required this.subtotal,
    this.descontoValor = 0,
    this.descontoPercentagem = 0,
    required this.totalIva,
    required this.total,
    required this.pagamentos,
    this.troco = 0,
  });
}

class ReciboItem {
  final String nome;
  final double quantidade;
  final String unidade;
  final String? lote;
  final double preco;
  final double total;
  const ReciboItem({
    required this.nome, required this.quantidade,
    required this.unidade, this.lote,
    required this.preco, required this.total,
  });
}

class ReciboPagamento {
  final String metodo;
  final double valor;
  final String? referencia;
  const ReciboPagamento({required this.metodo, required this.valor, this.referencia});
}

class ImpressoraService {
  static final ImpressoraService instance = ImpressoraService._();
  ImpressoraService._();

  final _storage = const FlutterSecureStorage();

  Future<List<BluetoothInfo>> listarDispositivosPareados() async {
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> conectar(String mac) async {
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    if (ok) await _storage.write(key: 'impressora_mac', value: mac);
    return ok;
  }

  Future<bool> desconectar() => PrintBluetoothThermal.disconnect;

  Future<bool> get estaConectado => PrintBluetoothThermal.connectionStatus;

  Future<String?> get macGuardado => _storage.read(key: 'impressora_mac');

  Future<String?> get nomeGuardado => _storage.read(key: 'impressora_nome');

  Future<void> guardarNome(String mac, String nome) async {
    await _storage.write(key: 'impressora_mac', value: mac);
    await _storage.write(key: 'impressora_nome', value: nome);
  }

  Future<bool> imprimirRecibo(Recibo r) async {
    try {
      final profile = await CapabilityProfile.load();
      final gen     = Generator(PaperSize.mm80, profile);
      final bytes   = <int>[];

      // ── Cabeçalho ──────────────────────────────────────────────────────────
      bytes += gen.text(r.empresa,
          styles: const PosStyles(align: PosAlign.center, bold: true,
              height: PosTextSize.size2, width: PosTextSize.size2));
      if (r.nif.isNotEmpty)
        bytes += gen.text('NUIT: ${r.nif}',
            styles: const PosStyles(align: PosAlign.center));
      if (r.morada.isNotEmpty)
        bytes += gen.text(r.morada,
            styles: const PosStyles(align: PosAlign.center));
      if (r.telefone.isNotEmpty)
        bytes += gen.text('Tel: ${r.telefone}',
            styles: const PosStyles(align: PosAlign.center));

      bytes += gen.hr();
      bytes += gen.text('RECIBO DE VENDA',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += gen.text(r.numVenda,
          styles: const PosStyles(align: PosAlign.center));
      final d = r.dataHora;
      bytes += gen.text(
          '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'
          ' ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}',
          styles: const PosStyles(align: PosAlign.center));
      bytes += gen.hr();

      // ── Dados ───────────────────────────────────────────────────────────────
      if (r.cliente != null)
        bytes += gen.row([
          PosColumn(text: 'Cliente:', width: 4),
          PosColumn(text: r.cliente!, width: 8),
        ]);
      bytes += gen.row([
        PosColumn(text: 'Operador:', width: 4),
        PosColumn(text: r.operador, width: 8),
      ]);
      bytes += gen.hr();

      // ── Produtos ────────────────────────────────────────────────────────────
      bytes += gen.row([
        PosColumn(text: 'PRODUTO',   width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'QTD',       width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'TOTAL',     width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += gen.hr(ch: '-');

      for (final item in r.itens) {
        final nome = item.nome.length > 22 ? '${item.nome.substring(0, 22)}..' : item.nome;
        bytes += gen.row([
          PosColumn(text: nome, width: 6),
          PosColumn(text: item.quantidade.toStringAsFixed(
              item.quantidade == item.quantidade.truncateToDouble() ? 0 : 2),
              width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: 'MT ${item.total.toStringAsFixed(2)}',
              width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
        bytes += gen.text(
            '  MT ${item.preco.toStringAsFixed(2)}/${item.unidade}'
            '${item.lote != null ? '  L:${item.lote}' : ''}',
            styles: const PosStyles(fontType: PosFontType.fontB));
      }

      bytes += gen.hr();

      // ── Totais ──────────────────────────────────────────────────────────────
      bytes += gen.row([
        PosColumn(text: 'Subtotal:',   width: 7),
        PosColumn(text: 'MT ${r.subtotal.toStringAsFixed(2)}',
            width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
      if (r.descontoValor > 0.001)
        bytes += gen.row([
          PosColumn(text: 'Desconto (${r.descontoPercentagem.toStringAsFixed(0)}%):', width: 7),
          PosColumn(text: '- MT ${r.descontoValor.toStringAsFixed(2)}',
              width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
      bytes += gen.row([
        PosColumn(text: 'IVA:', width: 7),
        PosColumn(text: 'MT ${r.totalIva.toStringAsFixed(2)}',
            width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += gen.row([
        PosColumn(text: 'TOTAL:', width: 7,
            styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
        PosColumn(text: 'MT ${r.total.toStringAsFixed(2)}',
            width: 5, styles: const PosStyles(bold: true, align: PosAlign.right,
                height: PosTextSize.size2, width: PosTextSize.size2)),
      ]);
      bytes += gen.hr(ch: '=');

      // ── Pagamentos ──────────────────────────────────────────────────────────
      for (final pag in r.pagamentos) {
        bytes += gen.row([
          PosColumn(text: '${_metodoLabel(pag.metodo)}:', width: 7),
          PosColumn(text: 'MT ${pag.valor.toStringAsFixed(2)}',
              width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
        if (pag.referencia != null)
          bytes += gen.text('  Ref: ${pag.referencia}',
              styles: const PosStyles(fontType: PosFontType.fontB));
      }
      if (r.troco > 0.001)
        bytes += gen.row([
          PosColumn(text: 'Troco:', width: 7),
          PosColumn(text: 'MT ${r.troco.toStringAsFixed(2)}',
              width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);

      bytes += gen.hr();
      bytes += gen.text('Obrigado pela sua compra!',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += gen.feed(3);
      bytes += gen.cut();

      return PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  Future<bool> imprimirTestePage() async {
    try {
      final profile = await CapabilityProfile.load();
      final gen = Generator(PaperSize.mm80, profile);
      final bytes = <int>[];
      bytes += gen.text('SGC AGRICOLA', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += gen.text('Página de Teste', styles: const PosStyles(align: PosAlign.center));
      bytes += gen.hr();
      bytes += gen.text('Impressora configurada com sucesso!', styles: const PosStyles(align: PosAlign.center));
      bytes += gen.feed(3);
      bytes += gen.cut();
      return PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  String _metodoLabel(String m) => switch (m) {
    'dinheiro'      => 'Dinheiro',
    'mpesa'         => 'M-Pesa',
    'emola'         => 'e-Mola',
    'transferencia' => 'Transferência',
    'credito'       => 'Crédito',
    'pos'           => 'POS',
    _               => m,
  };
}

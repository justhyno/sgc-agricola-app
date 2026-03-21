import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;

  DatabaseHelper._();

  Future<Database> get db async => _db ??= await _initDb();

  Future<void> init() async => _db = await _initDb();

  Future<Database> _initDb() async {
    final dir  = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'sgc_agricola.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE produtos (
        id INTEGER PRIMARY KEY, nome_comercial TEXT NOT NULL,
        sku TEXT, codigo_barras TEXT, categoria TEXT,
        unidade_medida TEXT NOT NULL, preco_venda REAL NOT NULL,
        taxa_iva REAL DEFAULT 0, tem_validade INTEGER DEFAULT 0,
        controla_stock INTEGER DEFAULT 1, updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE lotes (
        id INTEGER PRIMARY KEY, produto_id INTEGER NOT NULL,
        numero_lote TEXT, quantidade_actual REAL NOT NULL,
        preco_custo_unitario REAL DEFAULT 0, data_validade TEXT,
        estado TEXT DEFAULT 'valido', updated_at TEXT NOT NULL,
        FOREIGN KEY (produto_id) REFERENCES produtos(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY, nome TEXT NOT NULL,
        nif TEXT, telefone TEXT, updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE taxas_iva (
        id INTEGER PRIMARY KEY, nome TEXT NOT NULL, percentagem REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE vendas_pendentes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_uuid TEXT NOT NULL, device_sale_id INTEGER NOT NULL,
        dados TEXT NOT NULL, criada_em TEXT NOT NULL,
        sincronizada INTEGER DEFAULT 0, erro_sinc TEXT,
        UNIQUE(device_uuid, device_sale_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_meta (chave TEXT PRIMARY KEY, valor TEXT NOT NULL)
    ''');
    // Índices para pesquisa rápida no PDV
    await db.execute('CREATE INDEX idx_produtos_barras ON produtos(codigo_barras)');
    await db.execute('CREATE INDEX idx_lotes_produto ON lotes(produto_id)');
  }

  // ─── Produtos ─────────────────────────────────────────────────────────────

  Future<void> upsertProdutos(List<Map<String, dynamic>> lista) async {
    final d = await db;
    final batch = d.batch();
    for (final p in lista) {
      batch.insert('produtos', {
        'id': p['id'], 'nome_comercial': p['nome_comercial'],
        'sku': p['sku'], 'codigo_barras': p['codigo_barras'],
        'categoria': p['categoria'], 'unidade_medida': p['unidade_medida'],
        'preco_venda': p['preco_venda'], 'taxa_iva': p['taxa_iva'] ?? 0,
        'tem_validade': p['tem_validade'] == true ? 1 : 0,
        'controla_stock': p['controla_stock'] == true ? 1 : 0,
        'updated_at': p['updated_at'] ?? DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Lotes do produto
      if (p['lotes'] != null) {
        for (final l in (p['lotes'] as List)) {
          batch.insert('lotes', {
            'id': l['id'], 'produto_id': p['id'],
            'numero_lote': l['numero_lote'],
            'quantidade_actual': l['quantidade_actual'],
            'preco_custo_unitario': l['preco_custo_unitario'] ?? 0,
            'data_validade': l['data_validade'],
            'estado': l['estado'] ?? 'valido',
            'updated_at': l['updated_at'] ?? DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> pesquisarProdutos(String termo) async {
    final d = await db;
    return d.rawQuery('''
      SELECT p.*, GROUP_CONCAT(l.id || '|' || l.numero_lote || '|' ||
        l.quantidade_actual || '|' || l.preco_custo_unitario || '|' ||
        COALESCE(l.data_validade,'') || '|' || l.estado, ';;') AS lotes_raw
      FROM produtos p
      LEFT JOIN lotes l ON l.produto_id = p.id AND l.estado NOT IN ('esgotado','retirado','vencido') AND l.quantidade_actual > 0
      WHERE p.controla_stock = 1
        AND (p.nome_comercial LIKE ? OR p.sku LIKE ? OR p.codigo_barras = ?)
      GROUP BY p.id
      ORDER BY p.nome_comercial
      LIMIT 20
    ''', ['%$termo%', '%$termo%', termo]);
  }

  Future<Map<String, dynamic>?> produtoPorBarras(String barras) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT p.*, GROUP_CONCAT(l.id || '|' || l.numero_lote || '|' ||
        l.quantidade_actual || '|' || l.preco_custo_unitario || '|' ||
        COALESCE(l.data_validade,'') || '|' || l.estado, ';;') AS lotes_raw
      FROM produtos p
      LEFT JOIN lotes l ON l.produto_id = p.id AND l.estado NOT IN ('esgotado','retirado','vencido') AND l.quantidade_actual > 0
      WHERE p.codigo_barras = ?
      GROUP BY p.id LIMIT 1
    ''', [barras]);
    return rows.isEmpty ? null : rows.first;
  }

  // ─── Clientes ─────────────────────────────────────────────────────────────

  Future<void> upsertClientes(List<Map<String, dynamic>> lista) async {
    final d = await db;
    final batch = d.batch();
    for (final c in lista) {
      batch.insert('clientes', {
        'id': c['id'], 'nome': c['nome'],
        'nif': c['nif'], 'telefone': c['telefone'],
        'updated_at': c['updated_at'] ?? DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> pesquisarClientes(String termo) async {
    final d = await db;
    return d.query('clientes',
      where: 'nome LIKE ? OR nif LIKE ? OR telefone LIKE ?',
      whereArgs: ['%$termo%', '%$termo%', '%$termo%'],
      orderBy: 'nome', limit: 20);
  }

  // ─── Taxas IVA ────────────────────────────────────────────────────────────

  Future<void> upsertTaxasIva(List<Map<String, dynamic>> lista) async {
    final d = await db;
    final batch = d.batch();
    for (final t in lista) {
      batch.insert('taxas_iva', {
        'id': t['id'], 'nome': t['nome'], 'percentagem': t['percentagem'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ─── Vendas pendentes ─────────────────────────────────────────────────────

  Future<int> inserirVendaPendente(String deviceUuid, int deviceSaleId, String dadosJson) async {
    final d = await db;
    return d.insert('vendas_pendentes', {
      'device_uuid': deviceUuid, 'device_sale_id': deviceSaleId,
      'dados': dadosJson, 'criada_em': DateTime.now().toIso8601String(),
      'sincronizada': 0,
    });
  }

  Future<List<Map<String, dynamic>>> vendasNaoSincronizadas() async {
    final d = await db;
    return d.query('vendas_pendentes',
      where: 'sincronizada = 0',
      orderBy: 'criada_em ASC');
  }

  Future<void> marcarVendaSincronizada(int id) async {
    final d = await db;
    await d.update('vendas_pendentes', {'sincronizada': 1},
      where: 'id = ?', whereArgs: [id]);
  }

  Future<void> marcarVendaErro(int id, String erro) async {
    final d = await db;
    await d.update('vendas_pendentes', {'erro_sinc': erro},
      where: 'id = ?', whereArgs: [id]);
  }

  // ─── Sync meta ────────────────────────────────────────────────────────────

  Future<String?> getSyncMeta(String chave) async {
    final d = await db;
    final rows = await d.query('sync_meta', where: 'chave = ?', whereArgs: [chave]);
    return rows.isEmpty ? null : rows.first['valor'] as String;
  }

  Future<void> setSyncMeta(String chave, String valor) async {
    final d = await db;
    await d.insert('sync_meta', {'chave': chave, 'valor': valor},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── Stock local (para consulta rápida) ──────────────────────────────────

  Future<List<Map<String, dynamic>>> stockResumido() async {
    final d = await db;
    return d.rawQuery('''
      SELECT p.id, p.nome_comercial, p.categoria, p.unidade_medida,
        p.preco_venda, p.stock_minimo,
        COALESCE(SUM(CASE WHEN l.estado NOT IN ('esgotado','retirado','vencido')
          THEN l.quantidade_actual ELSE 0 END), 0) AS stock_total
      FROM produtos p
      LEFT JOIN lotes l ON l.produto_id = p.id
      WHERE p.controla_stock = 1
      GROUP BY p.id
      ORDER BY p.nome_comercial
    ''');
  }
}

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../db/database.dart';
import 'auth_provider.dart';

enum SyncStatus { idle, syncing, error, ok }

class SyncState {
  final SyncStatus status;
  final String? lastSyncAt;
  final int pendentes;
  final String? error;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncAt,
    this.pendentes = 0,
    this.error,
  });

  SyncState copyWith({SyncStatus? status, String? lastSyncAt, int? pendentes, String? error}) =>
      SyncState(
        status:      status      ?? this.status,
        lastSyncAt:  lastSyncAt  ?? this.lastSyncAt,
        pendentes:   pendentes   ?? this.pendentes,
        error:       error,
      );

  bool get isOnline => status != SyncStatus.error;
}

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  final _db = DatabaseHelper.instance;

  SyncNotifier(this._ref) : super(const SyncState()) {
    _init();
  }

  Future<void> _init() async {
    final ultima = await _db.getSyncMeta('ultima_sync');
    final pendentes = await _db.vendasNaoSincronizadas();
    state = state.copyWith(
      lastSyncAt: ultima,
      pendentes: pendentes.length,
      status: SyncStatus.idle,
    );
  }

  /// Sincronização completa (primeira vez ou reset)
  Future<void> syncCompleto() async {
    final auth = _ref.read(authProvider);
    if (!auth.isLoggedIn || auth.lojaId == null) return;

    state = state.copyWith(status: SyncStatus.syncing);
    try {
      final data = await ApiClient.instance.syncCompleto();
      await _aplicarSync(data);
      final agora = DateTime.now().toIso8601String();
      await _db.setSyncMeta('ultima_sync', agora);
      state = state.copyWith(status: SyncStatus.ok, lastSyncAt: agora);
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, error: e.toString());
    }
  }

  /// Sincronização delta (apenas alterações)
  Future<void> syncDelta() async {
    final ultima = await _db.getSyncMeta('ultima_sync');
    if (ultima == null) return syncCompleto();

    state = state.copyWith(status: SyncStatus.syncing);
    try {
      final data = await ApiClient.instance.syncDelta(ultima);
      await _aplicarSync(data);
      final agora = DateTime.now().toIso8601String();
      await _db.setSyncMeta('ultima_sync', agora);
      state = state.copyWith(status: SyncStatus.ok, lastSyncAt: agora);
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, error: e.toString());
    }

    // Depois do delta, tentar enviar vendas pendentes
    await _enviarPendentes();
  }

  Future<void> _aplicarSync(Map<String, dynamic> data) async {
    if (data['produtos'] != null) {
      await _db.upsertProdutos(List<Map<String, dynamic>>.from(data['produtos']));
    }
    if (data['clientes'] != null) {
      await _db.upsertClientes(List<Map<String, dynamic>>.from(data['clientes']));
    }
    if (data['taxas_iva'] != null) {
      await _db.upsertTaxasIva(List<Map<String, dynamic>>.from(data['taxas_iva']));
    }
  }

  /// Enviar vendas pendentes para o servidor
  Future<void> _enviarPendentes() async {
    final pendentes = await _db.vendasNaoSincronizadas();
    if (pendentes.isEmpty) {
      state = state.copyWith(pendentes: 0);
      return;
    }

    final payload = pendentes.map((v) {
      final dados = jsonDecode(v['dados'] as String) as Map<String, dynamic>;
      return dados;
    }).toList();

    try {
      final result = await ApiClient.instance.enviarBatchVendas(payload);
      final resultados = result['resultados'] as List;

      for (int i = 0; i < pendentes.length; i++) {
        final res = resultados[i] as Map<String, dynamic>;
        if (res['sucesso'] == true) {
          await _db.marcarVendaSincronizada(pendentes[i]['id'] as int);
        } else {
          final erro = (res['dados'] as Map?)?.containsKey('error') == true
              ? res['dados']['error'] as String
              : 'Erro desconhecido';
          await _db.marcarVendaErro(pendentes[i]['id'] as int, erro);
        }
      }

      final restantes = await _db.vendasNaoSincronizadas();
      state = state.copyWith(pendentes: restantes.length);
    } catch (_) {
      // Sem rede — mantém pendentes para próxima tentativa
      state = state.copyWith(pendentes: pendentes.length);
    }
  }

  Future<void> tentarSincronizar() async {
    await syncDelta();
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>(
  (ref) => SyncNotifier(ref),
);

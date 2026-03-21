import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? error;
  final String? userName;
  final String? userEmail;
  final int? lojaId;
  final String? lojaNome;
  final Map<String, bool> permissoes;
  final List<Map<String, dynamic>> lojas;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.error,
    this.userName,
    this.userEmail,
    this.lojaId,
    this.lojaNome,
    this.permissoes = const {},
    this.lojas = const [],
  });

  AuthState copyWith({
    bool? isLoggedIn, bool? isLoading, String? error,
    String? userName, String? userEmail,
    int? lojaId, String? lojaNome,
    Map<String, bool>? permissoes, List<Map<String, dynamic>>? lojas,
  }) => AuthState(
    isLoggedIn:  isLoggedIn  ?? this.isLoggedIn,
    isLoading:   isLoading   ?? this.isLoading,
    error:       error,
    userName:    userName    ?? this.userName,
    userEmail:   userEmail   ?? this.userEmail,
    lojaId:      lojaId      ?? this.lojaId,
    lojaNome:    lojaNome    ?? this.lojaNome,
    permissoes:  permissoes  ?? this.permissoes,
    lojas:       lojas       ?? this.lojas,
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _storage = const FlutterSecureStorage();

  AuthNotifier() : super(const AuthState()) {
    _restaurarSessao();
  }

  Future<void> _restaurarSessao() async {
    final token  = await _storage.read(key: 'auth_token');
    final user   = await _storage.read(key: 'user_json');
    final lojaId = await _storage.read(key: 'loja_id');
    final lojaNm = await _storage.read(key: 'loja_nome');

    if (token == null || user == null) return;

    final u = jsonDecode(user) as Map<String, dynamic>;
    state = state.copyWith(
      isLoggedIn: true,
      userName:   u['name'],
      userEmail:  u['email'],
      lojaId:     lojaId != null ? int.tryParse(lojaId) : null,
      lojaNome:   lojaNm,
      permissoes: Map<String, bool>.from(u['permissoes'] ?? {}),
      lojas:      List<Map<String, dynamic>>.from(u['lojas'] ?? []),
    );
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await ApiClient.instance.login(email, password, 'sgc-mobile');
      final token = data['token'] as String;
      final user  = data['user']  as Map<String, dynamic>;
      final lojas = List<Map<String, dynamic>>.from(data['lojas'] ?? []);

      await _storage.write(key: 'auth_token', value: token);
      await _storage.write(key: 'user_json',  value: jsonEncode({...user, 'lojas': lojas}));

      state = state.copyWith(
        isLoggedIn: true, isLoading: false,
        userName:  user['name'],
        userEmail: user['email'],
        permissoes: Map<String, bool>.from(user['permissoes'] ?? {}),
        lojas: lojas,
      );
      return true;
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<void> selecionarLoja(int id, String nome) async {
    await ApiClient.instance.selecionarLoja(id);
    await _storage.write(key: 'loja_id',   value: id.toString());
    await _storage.write(key: 'loja_nome', value: nome);
    state = state.copyWith(lojaId: id, lojaNome: nome);
  }

  Future<void> logout() async {
    await ApiClient.instance.logout();
    await _storage.deleteAll();
    state = const AuthState();
  }

  String _parseError(Object e) {
    if (e is Exception) return e.toString().replaceAll('Exception: ', '');
    return 'Erro desconhecido';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);

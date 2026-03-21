import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../shared/theme.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._();
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token  = await _storage.read(key: 'auth_token');
        final lojaId = await _storage.read(key: 'loja_id');
        if (token  != null) options.headers['Authorization'] = 'Bearer $token';
        if (lojaId != null) options.headers['X-Loja-ID'] = lojaId;
        return handler.next(options);
      },
      onError: (err, handler) {
        // 401 → sessão inválida, token será limpo pela camada de auth
        return handler.next(err);
      },
    ));
  }

  Dio get dio => _dio;

  // ─── Auth ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password, String deviceName) async {
    final r = await _dio.post('/auth/login', data: {
      'email': email, 'password': password, 'device_name': deviceName,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> me() async {
    final r = await _dio.get('/auth/me');
    return r.data as Map<String, dynamic>;
  }

  Future<void> selecionarLoja(int lojaId) async {
    await _dio.post('/auth/selecionar-loja', data: {'loja_id': lojaId});
  }

  // ─── Sync ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> syncCompleto() async {
    final r = await _dio.get('/sync/completo');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> syncDelta(String desde) async {
    final r = await _dio.get('/sync/delta', queryParameters: {'desde': desde});
    return r.data as Map<String, dynamic>;
  }

  // ─── Vendas ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> criarVenda(Map<String, dynamic> dados) async {
    final r = await _dio.post('/vendas', data: dados);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> enviarBatchVendas(List<Map<String, dynamic>> vendas) async {
    final r = await _dio.post('/vendas/batch', data: {'vendas': vendas});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listarVendas({int pagina = 1}) async {
    final r = await _dio.get('/vendas', queryParameters: {'page': pagina});
    return r.data as Map<String, dynamic>;
  }

  // ─── Alertas / Stock ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> alertas() async {
    final r = await _dio.get('/alertas');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> stock() async {
    final r = await _dio.get('/stock');
    return r.data as Map<String, dynamic>;
  }
}

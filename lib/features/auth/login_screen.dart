import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _verSenha   = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
      _emailCtrl.text.trim(), _passCtrl.text.trim(),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(authProvider).error ?? 'Erro de autenticação'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    return Scaffold(
      backgroundColor: kVerde,
      body: SafeArea(
        child: Column(children: [
          // Header
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 48, 24, 40),
            child: Column(children: [
              Icon(Icons.agriculture, color: Colors.white, size: 56),
              SizedBox(height: 12),
              Text('SGC Agrícola', style: TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800,
              )),
              SizedBox(height: 4),
              Text('Gestão Comercial', style: TextStyle(
                color: Colors.white70, fontSize: 14,
              )),
            ]),
          ),
          // Form card
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Entrar na conta', style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: kVerdeClaro,
                    )),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'E-mail inválido' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passCtrl,
                      obscureText: !_verSenha,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_verSenha ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _verSenha = !_verSenha),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton(
                      onPressed: isLoading ? null : _login,
                      child: isLoading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Entrar'),
                    ),

                    const Spacer(),
                    const Center(
                      child: Text('SGC Agrícola © 2026',
                        style: TextStyle(fontSize: 11, color: kCinza)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

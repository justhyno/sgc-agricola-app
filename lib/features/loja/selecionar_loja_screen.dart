import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/sync_provider.dart';
import '../../shared/theme.dart';

class SelecionarLojaScreen extends ConsumerWidget {
  const SelecionarLojaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: kVerde,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: Column(children: [
              const Icon(Icons.store_outlined, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text('Olá, ${auth.userName?.split(' ').first ?? ''}!',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Seleccione a loja para continuar',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('Lojas disponíveis', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: kVerdeClaro,
                    )),
                  ),
                  Expanded(
                    child: auth.lojas.isEmpty
                        ? const Center(child: Text('Sem lojas atribuídas.\nContacte o administrador.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: kCinza)))
                        : ListView.separated(
                            itemCount: auth.lojas.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final loja = auth.lojas[i];
                              return _LojaCard(
                                id:   loja['id'] as int,
                                nome: loja['nome'] as String,
                              );
                            },
                          ),
                  ),
                  TextButton.icon(
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Terminar sessão'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _LojaCard extends ConsumerStatefulWidget {
  final int id;
  final String nome;
  const _LojaCard({required this.id, required this.nome});

  @override
  ConsumerState<_LojaCard> createState() => _LojaCardState();
}

class _LojaCardState extends ConsumerState<_LojaCard> {
  bool _loading = false;

  Future<void> _selecionar() async {
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).selecionarLoja(widget.id, widget.nome);
      // Disparar sync completo após selecionar loja
      ref.read(syncProvider.notifier).syncCompleto();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _loading ? null : _selecionar,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kVerdeLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.store, color: kVerde, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(widget.nome, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: kVerdeClaro,
            ))),
            if (_loading)
              const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.arrow_forward_ios, size: 16, color: kCinza),
          ]),
        ),
      ),
    );
  }
}

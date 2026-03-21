import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/sync_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/loja/selecionar_loja_screen.dart';
import 'features/pdv/pdv_screen.dart';
import 'features/stock/stock_screen.dart';
import 'features/alertas/alertas_screen.dart';
import 'features/historico/historico_screen.dart';
import 'features/impressora/impressora_screen.dart';
import 'shared/theme.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  return GoRouter(
    refreshListenable: _AuthListenable(ref),
    redirect: (_, state) {
      if (!auth.isLoggedIn)    return '/login';
      if (auth.lojaId == null) return '/loja';
      return null;
    },
    routes: [
      GoRoute(path: '/login',      builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/loja',       builder: (_, __) => const SelecionarLojaScreen()),
      GoRoute(path: '/impressora', builder: (_, __) => const ImpressoraScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => _MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/',          builder: (_, __) => const PdvScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/stock',     builder: (_, __) => const StockScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/alertas',   builder: (_, __) => const AlertasScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/historico', builder: (_, __) => const HistoricoScreen())]),
        ],
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

class _MainShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const _MainShell({required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    return Scaffold(
      body: Column(children: [
        if (sync.pendentes > 0)
          Container(
            color: const Color(0xFFFFF7ED),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              const Icon(Icons.cloud_upload_outlined, size: 14, color: Color(0xFF92400E)),
              const SizedBox(width: 6),
              Text('${sync.pendentes} venda(s) por sincronizar',
                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
              const Spacer(),
              GestureDetector(
                onTap: () => ref.read(syncProvider.notifier).tentarSincronizar(),
                child: const Text('Sincronizar', style: TextStyle(
                  fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                )),
              ),
            ]),
          ),
        Expanded(child: shell),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFf0fdf4),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'PDV'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), label: 'Alertas'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
        ],
      ),
    );
  }
}

class SgcApp extends ConsumerWidget {
  const SgcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'SGC Agrícola',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../providers/admin_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/admin_service.dart';
import '../../services/product_service.dart';
import '../admin/admin_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../movements/movements_screen.dart';
import '../products/product_list_screen.dart';
import '../profile/profile_screen.dart';

/// The signed-in area.
///
/// It owns the per-session providers and a nested [Navigator], so every page
/// pushed from inside (product form, detail, QR, user detail, ...) is a
/// descendant of those providers. Signing out removes the shell, which
/// disposes every provider and so drops all of the previous user's state.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});

  final AppUser user;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final ProductProvider _products;
  late final DashboardProvider _dashboard;
  AdminProvider? _admin;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _products = ProductProvider(
      userId: user.id,
      service: context.read<ProductService>(),
    )..load();
    _dashboard = DashboardProvider(
      userId: user.id,
      stats: context.read<StatsRepository>(),
      products: context.read<ProductRepository>(),
      productProvider: _products,
    )..load();
    if (user.isAdmin) {
      _admin = AdminProvider(
        adminId: user.id,
        service: context.read<AdminService>(),
      )..load();
    }
  }

  @override
  void dispose() {
    _dashboard.dispose();
    _products.dispose();
    _admin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProductProvider>.value(value: _products),
        ChangeNotifierProvider<DashboardProvider>.value(value: _dashboard),
        if (_admin != null)
          ChangeNotifierProvider<AdminProvider>.value(value: _admin!),
      ],
      // Lets the system back button pop pages of the nested navigator first.
      child: NavigatorPopHandler(
        onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
        child: Navigator(
          key: _navigatorKey,
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute<void>(
              builder: (_) => _ShellPage(isAdmin: widget.user.isAdmin),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom navigation + the tab pages. Keeps its own selected index.
class _ShellPage extends StatefulWidget {
  const _ShellPage({required this.isAdmin});

  final bool isAdmin;

  @override
  State<_ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<_ShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(onSeeAllProducts: () => setState(() => _index = 1)),
      const ProductListScreen(),
      const MovementsScreen(),
      const ProfileScreen(),
      if (widget.isAdmin) const AdminScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              label: 'Accueil',
            ),
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Produits',
            ),
            const NavigationDestination(
              icon: Icon(Icons.swap_vert),
              label: 'Mouvements',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Profil',
            ),
            if (widget.isAdmin)
              const NavigationDestination(
                icon: Icon(Icons.admin_panel_settings_outlined),
                label: 'Admin',
              ),
          ],
        ),
      ),
    );
  }
}

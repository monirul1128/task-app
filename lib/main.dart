import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_auth.dart';
import 'firebase_options.dart';
import 'oms_demo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BechaKenaHubApp());
}

const brand = Color(0xFF625FEA);
const brandDark = Color(0xFF5146E5);
const ink = Color(0xFF192335);
const muted = Color(0xFF68778B);
const canvas = Color(0xFFF2F5FA);
const line = Color(0xFFE1E6EE);
const green = Color(0xFF18AD83);
const orange = Color(0xFFE59B13);
const red = Color(0xFFE45359);
const blue = Color(0xFF4387ED);

String _tableHeader(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');

int _tableColumn(List<String> headers, List<String> candidates) =>
    headers.indexWhere(candidates.contains);

String _tableValue(List<String> row, int index) =>
    index >= 0 && index < row.length ? row[index].trim() : '';

Future<void> _saveExcelTemplate(
  BuildContext context, {
  required String fileName,
  required List<int> bytes,
}) async {
  try {
    final savedFile = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      dialogTitle: 'Save Excel template',
    );
    if (!context.mounted || savedFile == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Template saved: $fileName')));
  } on PlatformException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not save the Excel template: ${error.message ?? error.code}',
        ),
      ),
    );
  } on UnsupportedError catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not save the Excel template: ${error.message ?? error.toString()}',
        ),
      ),
    );
  } on StateError catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.message)));
  }
}

class BechaKenaHubApp extends StatelessWidget {
  const BechaKenaHubApp({this.adminAuth, super.key});

  final AdminAuthService? adminAuth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BKH Business Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: brand),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: muted),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: brand, width: 1.5),
          ),
        ),
      ),
      home: HubShell(adminAuth: adminAuth),
    );
  }
}

class _NavItem {
  const _NavItem(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const resellerNav = <_NavItem>[
  _NavItem('home', 'Home', Icons.home_rounded),
  _NavItem('orders', 'Orders', Icons.inventory_2_rounded),
  _NavItem('wallet', 'Wallet', Icons.account_balance_wallet_rounded),
  _NavItem('withdraw', 'Withdraw', Icons.payments_rounded),
  _NavItem('catalog', 'Catalog', Icons.storefront_rounded),
];

const adminNav = <_NavItem>[
  _NavItem('adminHome', 'Home', Icons.space_dashboard_rounded),
  _NavItem('customers', 'Customer', Icons.people_alt_rounded),
  _NavItem('products', 'Products', Icons.inventory_2_rounded),
  _NavItem('batch', 'Batch', Icons.layers_rounded),
  _NavItem('settings', 'Settings', Icons.settings_rounded),
];

const adminMenu = <_NavItem>[
  _NavItem('adminHome', 'Dashboard', Icons.space_dashboard_rounded),
  _NavItem('customers', 'Customer Management', Icons.people_alt_rounded),
  _NavItem('products', 'Product Management', Icons.inventory_2_rounded),
  _NavItem('resellers', 'Reseller Management', Icons.storefront_rounded),
  _NavItem('batch', 'Batch Management', Icons.layers_rounded),
  _NavItem('adminOrders', 'Order Management', Icons.receipt_long_rounded),
  _NavItem('withdrawals', 'Withdrawal & Disbursement', Icons.payments_rounded),
  _NavItem('adminWallet', 'Wallet', Icons.account_balance_wallet_rounded),
  _NavItem('adminNotifications', 'Notifications', Icons.notifications_rounded),
  _NavItem('settings', 'Settings', Icons.settings_rounded),
];

class HubShell extends StatefulWidget {
  const HubShell({this.adminAuth, super.key});

  final AdminAuthService? adminAuth;

  @override
  State<HubShell> createState() => _HubShellState();
}

class _HubShellState extends State<HubShell> {
  late final AdminAuthService _adminAuth =
      widget.adminAuth ?? FirebaseAdminAuthService(FirebaseAuth.instance);
  String? _role;
  String _page = 'register'; // Changed from 'roles' to 'register'
  String _previousPage = 'orders';
  String? _selectedOrderId;

  Future<void> _enter(String role) async {
    if (role == 'admin') {
      var hasAdminAccess = false;
      try {
        hasAdminAccess = await _adminAuth.hasAdminAccess;
      } on FirebaseAuthException catch (error) {
        _message(error.message ?? error.code);
      }
      if (!mounted) return;
      setState(() {
        _role = 'admin';
        _page = hasAdminAccess ? 'adminHome' : 'adminLogin';
      });
      return;
    }
    setState(() {
      _role = 'reseller';
      _page = 'home';
    });
  }

  void _go(String page) {
    Navigator.of(context).maybePop();
    setState(() {
      if (page.startsWith('orderDetails:')) {
        _previousPage = _page;
        _selectedOrderId = page.substring('orderDetails:'.length);
        _page = 'orderDetails';
      } else {
        _page = page;
      }
    });
  }

  Future<void> _switchRole() async {
    Navigator.of(context).maybePop();
    try {
      if (_role == 'admin') await _adminAuth.signOut();
    } on FirebaseAuthException catch (error) {
      _message(error.message ?? error.code);
      return;
    }
    if (!mounted) return;
    setState(() {
      _role = null;
      _page = 'register'; // Changed from 'roles' to 'register'
    });
  }

  Future<void> _signInAdmin(String email, String password) async {
    await _adminAuth.signIn(email, password);
    if (!mounted) return;
    setState(() => _page = 'adminHome');
  }

  Future<void> _signOutAdmin() async {
    try {
      await _adminAuth.signOut();
    } on FirebaseAuthException catch (error) {
      _message(error.message ?? error.code);
      return;
    }
    if (!mounted) return;
    setState(() {
      _role = null;
      _page = 'register'; // Changed from 'roles' to 'register'
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null) {
      return _page == 'about'
          ? AboutUsPage(
              onBack: () => setState(() => _page = 'register'),
            )
          : _page == 'adminLogin'
              ? AdminLoginPage(
                  onSignIn: _signInAdmin,
                  onMessage: _message,
                  onBack: () => setState(() => _page = 'register'),
                )
              : AuthPage(
                  register: true,
                  onMessage: _message,
                  onOpen: (page) {
                    if (page == 'adminLogin') {
                      setState(() => _page = 'adminLogin');
                    } else {
                      _go(page);
                    }
                  },
                );
    }

    final isReseller = _role == 'reseller';
    final nav = isReseller ? resellerNav : adminNav;
    final title = _titleFor(_page);
    final isStandalone = const {
      'login',
      'register',
      'adminLogin',
      'about',
    }.contains(_page);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        leading: isStandalone || _page == 'orderDetails'
            ? IconButton(
                tooltip: 'Back',
                onPressed: _page == 'adminLogin'
                    ? () => setState(() {
                        _role = null;
                        _page = 'register';
                      })
                    : () => _go(
                        _page == 'orderDetails'
                            ? _previousPage
                            : (isReseller ? 'home' : 'adminHome'),
                      ),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : Builder(
                builder: (context) => IconButton(
                  tooltip: 'Open navigation',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ),
        actions: [
          if (!isStandalone && _page != 'orderDetails') ...[
            IconButton(
              tooltip: 'Notifications',
              onPressed: () =>
                  _go(isReseller ? 'notifications' : 'adminNotifications'),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            IconButton(
              tooltip: 'My profile',
              onPressed: () => _go('profile'),
              icon: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE9EAFE),
                child: Icon(Icons.person_rounded, size: 19, color: brand),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      drawer: isStandalone || _page == 'orderDetails'
          ? null
          : HubDrawer(
              role: _role!,
              page: _page,
              onSelect: _go,
              onSwitch: _switchRole,
            ),
      body: _buildPage(),
      bottomNavigationBar: isStandalone || _page == 'orderDetails'
          ? null
          : NavigationBar(
              selectedIndex: _navIndex(nav, _page),
              onDestinationSelected: (index) => _go(nav[index].id),
              destinations: nav
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.icon, color: brand),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  int _navIndex(List<_NavItem> items, String page) {
    final index = items.indexWhere((item) => item.id == page);
    return index < 0 ? 0 : index;
  }

  String _titleFor(String page) {
    const titles = <String, String>{
      'home': 'Dashboard',
      'orders': 'Order Management',
      'wallet': 'Wallet',
      'withdraw': 'Withdraw Management',
      'catalog': 'Product Catalog',
      'orderDetails': 'Reseller Order Details',
      'notifications': 'Notifications',
      'profile': 'Reseller Profile',
      'login': 'Welcome Back',
      'register': 'Become a Reseller',
      'adminLogin': 'Administrator Sign In',
      'adminHome': 'Dashboard',
      'customers': 'Customer Management',
      'products': 'Product Management',
      'resellers': 'Reseller Management',
      'batch': 'Batch Management',
      'adminOrders': 'Order Management',
      'withdrawals': 'Withdrawal & Disbursement',
      'adminWallet': 'Wallet',
      'adminNotifications': 'Notifications',
      'settings': 'System Settings',
      'about': 'About Us',
    };
    return titles[page] ?? 'BKH Business Manager';
  }

  Widget _buildPage() {
    switch (_page) {
      case 'home':
        return ResellerHome(onOpen: _go);
      case 'orders':
        return ResellerOrders(onOpen: _go, onMessage: _message);
      case 'wallet':
        return const ResellerWallet();
      case 'withdraw':
        return WithdrawPage(onMessage: _message);
      case 'catalog':
        return const ResellerCatalog();
      case 'orderDetails':
        return OrderDetails(orderId: _selectedOrderId, onMessage: _message);
      case 'notifications':
        return NotificationsPage(onMessage: _message);
      case 'profile':
        return ProfilePage(onOpen: _go);
      case 'login':
        return AuthPage(register: false, onMessage: _message, onOpen: _go);
      case 'adminLogin':
        return AdminLoginPage(onSignIn: _signInAdmin, onMessage: _message);
      case 'register':
        return AuthPage(register: true, onMessage: _message, onOpen: _go);
      case 'adminHome':
        return AdminHome(onOpen: _go);
      case 'customers':
        return const AdminCustomers();
      case 'products':
        return const AdminProducts();
      case 'resellers':
        return const AdminResellers();
      case 'batch':
        return AdminBatch(onMessage: _message);
      case 'adminOrders':
        return AdminOrders(onMessage: _message);
      case 'withdrawals':
        return AdminWithdrawals(onMessage: _message);
      case 'adminWallet':
        return const AdminWallet();
      case 'adminNotifications':
        return NotificationsPage(onMessage: _message, admin: true);
      case 'settings':
        return AdminSettings(auth: _adminAuth, onSignOut: _signOutAdmin);
      case 'about':
        return const AboutUsPage();
      default:
        return RolePicker(
          onSelect: _enter,
          onAboutUs: () => _go('about'),
        );
    }
  }
}

class RolePicker extends StatelessWidget {
  const RolePicker({
    required this.onSelect,
    required this.onAboutUs,
    super.key,
  });
  final ValueChanged<String> onSelect;
  final VoidCallback onAboutUs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 38, 24, 28),
          children: [
            const SizedBox(height: 24),
            Container(
              height: 82,
              width: 82,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [brand, brandDark]),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: brand.withValues(alpha: .25),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'BKH Business Manager',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose your workspace to get started',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 16),
            ),
            const SizedBox(height: 34),
            RoleCard(
              icon: Icons.storefront_rounded,
              title: 'Reseller',
              description: 'Browse products, manage customer orders and track your earnings.',
              onTap: () => onSelect('reseller'),
            ),
            const SizedBox(height: 16),
            RoleCard(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Administrator',
              description: 'Manage customers, products, resellers, batches and payments.',
              onTap: () => onSelect('admin'),
              dark: true,
            ),
            const SizedBox(height: 28),
            const Text(
              'Sample information',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12),
            ),
            TextButton.icon(
              onPressed: onAboutUs,
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text('About Us'),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({this.onBack, super.key});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: onBack == null
          ? null
          : AppBar(
              leading: IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: const Text('About Us'),
            ),
      body: PageBody(
        children: const [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.storefront_rounded, color: brand, size: 34),
                SizedBox(height: 14),
                Text(
                  'M/S Riyad Medicine Corner',
                  style: TextStyle(
                    color: ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Business information as listed on the trade license.',
                  style: TextStyle(color: muted, height: 1.5),
                ),
                SizedBox(height: 16),
                Divider(height: 1, color: line),
                KeyValueRow(
                  'Trade License Number',
                  'TRAD/BCC/22794/2025',
                ),
                KeyValueRow(
                  'Business Address',
                  'Sadar Road, Barishal (Ward No: 19)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  const RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.dark = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? brand : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(21),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: .17)
                      : const Color(0xFFE9EAFE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: dark ? Colors.white : brand, size: 29),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: dark ? Colors.white : ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        color: dark ? Colors.white70 : muted,
                        height: 1.35,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: dark ? Colors.white : brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HubDrawer extends StatelessWidget {
  const HubDrawer({
    required this.role,
    required this.page,
    required this.onSelect,
    required this.onSwitch,
    super.key,
  });

  final String role;
  final String page;
  final ValueChanged<String> onSelect;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final isReseller = role == 'reseller';
    final items = isReseller
        ? <_NavItem>[
            ...resellerNav,
            const _NavItem(
              'notifications',
              'Notifications',
              Icons.notifications_rounded,
            ),
            const _NavItem('profile', 'My Profile', Icons.person_rounded),
            const _NavItem('login', 'Sign in', Icons.login_rounded),
            const _NavItem(
              'register',
              'Create account',
              Icons.person_add_alt_1_rounded,
            ),
            const _NavItem('about', 'About Us', Icons.info_outline_rounded),
          ]
        : adminMenu;
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [brand, brandDark]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shopping_bag_rounded,
                    color: Colors.white,
                    size: 35,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'BKH Business Manager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    isReseller
                        ? 'Reseller workspace'
                        : 'Administrator workspace',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  for (final item in items)
                    Material(
                      color: Colors.white,
                      child: ListTile(
                        selected: page == item.id,
                        selectedColor: brand,
                        selectedTileColor: const Color(0xFFF0F0FF),
                        leading: Icon(item.icon),
                        title: Text(
                          item.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () => onSelect(item.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageBody extends StatelessWidget {
  const PageBody({required this.children, this.padding, super.key});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 20, 20, 26),
      children: children,
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({required this.child, this.padding, super.key});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: .025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.icon, super.key});
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 13),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: brand, size: 23),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = brand,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 51,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 19),
        label: Text(label),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label.toLowerCase()) {
      'pending' || 'pending payment' || 'unpaid' => orange,
      'processing' => blue,
      'cancelled' || 'inactive' => red,
      'paid' || 'completed' || 'approved' || 'active' || 'delivered' => green,
      _ => brand,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    this.color = brand,
    this.icon,
    super.key,
  });
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, color: color.withValues(alpha: .7), size: 19),
              ],
            ),
          if (icon == null)
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 13),
            ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({
    required this.items,
    this.childAspectRatio = 1.3,
    super.key,
  });
  final List<MetricCard> items;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
      children: items,
    );
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {this.valueColor, super.key});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PriceStrip extends StatelessWidget {
  const PriceStrip({
    required this.wholesale,
    required this.retail,
    required this.profit,
    super.key,
  });
  final String wholesale;
  final String retail;
  final String profit;

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('Wholesale', wholesale, blue),
      ('Retail', retail, ink),
      ('Profit', profit, green),
    ];
    return Row(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FB),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: line),
              ),
              child: Column(
                children: [
                  Text(
                    entries[i].$1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    entries[i].$2,
                    style: TextStyle(
                      color: entries[i].$3,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class FilterChips extends StatelessWidget {
  const FilterChips({
    required this.options,
    required this.selected,
    required this.onSelect,
    super.key,
  });
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final active = option == selected;
          return ChoiceChip(
            label: Text(option),
            selected: active,
            onSelected: (_) => onSelect(option),
            backgroundColor: Colors.white,
            selectedColor: brand,
            labelStyle: TextStyle(
              color: active ? Colors.white : muted,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(color: active ? brand : line),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class ResellerHome extends StatelessWidget {
  const ResellerHome({required this.onOpen, super.key});
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    int orderCount(DemoOrderStatus status) =>
        demoOms.orders.where((order) => order.status == status).length;
    final simulated = demoOms.orders.where(
      (order) => order.paymentStatus == DemoPaymentStatus.simulated,
    );
    int withdrawalCount(DemoWithdrawalStatus status) =>
        demoOms.withdrawals.where((request) => request.status == status).length;
    final recentOrders = demoOms.orders.reversed.take(2).toList();
    final recentWithdrawals = demoOms.withdrawals
        .where((request) => request.reseller == demoOms.resellers.first)
        .toList()
        .reversed
        .take(2)
        .toList();
    return PageBody(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6764F3), Color(0xFF5146E5)],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: brand.withValues(alpha: .2),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WELCOME BACK',
                style: TextStyle(color: Colors.white70, letterSpacing: 1.1),
              ),
              SizedBox(height: 13),
              Text(
                'Hello, Reseller!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Manage your orders and business activities easily.',
                style: TextStyle(color: Colors.white, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionTitle('Order Overview', icon: Icons.assignment_rounded),
        MetricGrid(
          items: [
            MetricCard(label: 'Total Order', value: '${demoOms.orders.length}'),
            MetricCard(
              label: 'Pending',
              value: '${orderCount(DemoOrderStatus.pending)}',
              color: orange,
            ),
            MetricCard(
              label: 'Processing',
              value: '${orderCount(DemoOrderStatus.processing)}',
              color: blue,
            ),
            MetricCard(
              label: 'Delivered',
              value: '${orderCount(DemoOrderStatus.delivered)}',
              color: green,
            ),
            MetricCard(
              label: 'Cancelled',
              value: '${orderCount(DemoOrderStatus.cancelled)}',
              color: red,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle(
          'Payment Overview',
          icon: Icons.account_balance_wallet_rounded,
        ),
        MetricGrid(
          items: [
            MetricCard(
              label: 'Total Payment',
              value: '${demoOms.orders.length}',
              color: brand,
            ),
            MetricCard(
              label: 'Paid',
              value: '${simulated.length}',
              color: green,
            ),
            MetricCard(
              label: 'Unpaid',
              value: '${demoOms.orders.length - simulated.length}',
              color: orange,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Withdrawal Overview', icon: Icons.payments_rounded),
        MetricGrid(
          items: [
            MetricCard(
              label: 'Total Withdraw',
              value: '${demoOms.withdrawals.length}',
            ),
            MetricCard(
              label: 'Pending',
              value: '${withdrawalCount(DemoWithdrawalStatus.pending)}',
              color: orange,
            ),
            MetricCard(
              label: 'Processing',
              value: '${withdrawalCount(DemoWithdrawalStatus.processing)}',
              color: blue,
            ),
            MetricCard(
              label: 'Approved',
              value: '${withdrawalCount(DemoWithdrawalStatus.approved)}',
              color: green,
            ),
            MetricCard(
              label: 'Cancelled',
              value: '${withdrawalCount(DemoWithdrawalStatus.cancelled)}',
              color: red,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Recent Order', icon: Icons.inventory_2_rounded),
        if (recentOrders.isEmpty)
          const Panel(child: Text('No orders yet.'))
        else
          for (final order in recentOrders)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecentActivityCard(
                title: '#${order.id}',
                detail: order.product.title,
                status: _orderStatusLabel(order.status),
                onTap: () => onOpen('orderDetails:${order.id}'),
              ),
            ),
        const SizedBox(height: 8),
        const SectionTitle('Recent Payment', icon: Icons.payment_rounded),
        if (simulated.isEmpty)
          const Panel(child: Text('No payments yet.'))
        else
          for (final order in simulated.toList().reversed.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecentActivityCard(
                title: '#${order.id}',
                detail: '${order.product.title} • ৳${order.wholesalePrice}',
                status: 'Paid',
                onTap: () => onOpen('orderDetails:${order.id}'),
              ),
            ),
        const SizedBox(height: 8),
        const SectionTitle('Recent Withdraw', icon: Icons.money_rounded),
        if (recentWithdrawals.isEmpty)
          const Panel(child: Text('No withdrawal requests yet.'))
        else
          for (final request in recentWithdrawals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecentActivityCard(
                title: request.id,
                detail: '${request.method} • ৳${request.amount}',
                status: _withdrawalStatusLabel(request.status),
                onTap: () => onOpen('withdraw'),
              ),
            ),
        const SizedBox(height: 8),
        const SectionTitle('Quick Action', icon: Icons.bolt_rounded),
        Row(
          children: [
            Expanded(
              child: _QuickLink(
                icon: Icons.inventory_2_rounded,
                label: 'My Orders',
                onTap: () => onOpen('orders'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickLink(
                icon: Icons.storefront_rounded,
                label: 'Catalog',
                onTap: () => onOpen('catalog'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickLink(
                icon: Icons.payments_rounded,
                label: 'Withdraw',
                onTap: () => onOpen('withdraw'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _orderStatusLabel(DemoOrderStatus status) => switch (status) {
  DemoOrderStatus.pending => 'Pending',
  DemoOrderStatus.processing => 'Processing',
  DemoOrderStatus.delivered => 'Delivered',
  DemoOrderStatus.cancelled => 'Cancelled',
};

String _withdrawalStatusLabel(DemoWithdrawalStatus status) => switch (status) {
  DemoWithdrawalStatus.pending => 'Pending',
  DemoWithdrawalStatus.processing => 'Processing',
  DemoWithdrawalStatus.approved => 'Approved',
  DemoWithdrawalStatus.cancelled => 'Cancelled',
};

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.title,
    required this.detail,
    required this.status,
    this.onTap,
  });

  final String title;
  final String detail;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusPill(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(detail, style: const TextStyle(color: muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 5),
          child: Column(
            children: [
              Icon(icon, color: brand, size: 24),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderInfoRow extends StatelessWidget {
  const _OrderInfoRow(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: const TextStyle(
                color: muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResellerOrders extends StatefulWidget {
  const ResellerOrders({
    required this.onOpen,
    required this.onMessage,
    super.key,
  });
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onMessage;

  @override
  State<ResellerOrders> createState() => _ResellerOrdersState();
}

class _ResellerOrdersState extends State<ResellerOrders> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final orders = demoOms.orders.where((order) {
      final status = switch (order.status) {
        DemoOrderStatus.pending => 'Pending',
        DemoOrderStatus.processing => 'Processing',
        DemoOrderStatus.delivered => 'Delivered',
        DemoOrderStatus.cancelled => 'Cancelled',
      };
      return filter == 'All' || status == filter;
    }).toList();

    return PageBody(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FilterChips(
            options: const [
              'All',
              'Pending',
              'Processing',
              'Delivered',
              'Cancelled',
            ],
            selected: filter,
            onSelect: (value) => setState(() => filter = value),
          ),
        ),
        const SizedBox(height: 14),
        for (final order in orders)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Panel(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_rounded,
                        color: brand,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '#${order.id}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      StatusPill(_orderStatusLabel(order.status)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _OrderInfoRow('Order ID', '#${order.id}'),
                  _OrderInfoRow(
                    'Order Status',
                    _orderStatusLabel(order.status),
                  ),
                  _OrderInfoRow(
                    'Payment Status',
                    order.paymentStatus == DemoPaymentStatus.simulated
                        ? 'Paid'
                        : 'Unpaid',
                    valueColor:
                        order.paymentStatus == DemoPaymentStatus.simulated
                        ? green
                        : orange,
                  ),
                  _OrderInfoRow(
                    'Wholesale Price',
                    '৳${order.wholesalePrice}',
                    valueColor: blue,
                  ),
                  _OrderInfoRow(
                    'Retail Price',
                    '৳${order.retailPrice}',
                    valueColor: ink,
                  ),
                  _OrderInfoRow(
                    'Profit',
                    '৳${order.profit}',
                    valueColor: green,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: blue,
                            side: const BorderSide(color: blue),
                          ),
                          onPressed: () =>
                              widget.onOpen('orderDetails:${order.id}'),
                          child: const Text('View Details'),
                        ),
                      ),
                      if (order.status == DemoOrderStatus.pending) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: green,
                            ),
                            onPressed: () {
                              try {
                                demoOms.confirmPayment(order);
                                setState(() {});
                                widget.onMessage(
                                  'Payment confirmed successfully.',
                                );
                              } on StateError catch (error) {
                                widget.onMessage(error.message);
                              }
                            },
                            child: const Text('Pay & Confirm'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: red,
                              side: const BorderSide(color: red),
                            ),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Cancel Order'),
                                  content: const Text('Do you want to cancel?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('No'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: red),
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Yes'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                try {
                                  demoOms.transferOrder(order);
                                  setState(() {});
                                  widget.onMessage(
                                    'Order cancelled successfully.',
                                  );
                                } on StateError catch (error) {
                                  widget.onMessage(error.message);
                                }
                              }
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ResellerWallet extends StatelessWidget {
  const ResellerWallet({super.key});

  @override
  Widget build(BuildContext context) {
    final reseller = demoOms.resellers.first;
    final entries = demoOms.walletEntries
        .where((entry) => entry.reseller == reseller)
        .toList()
        .reversed
        .toList();
    final balance = reseller.capital + reseller.profit;
    return PageBody(
      children: [
        MetricGrid(
          childAspectRatio: 1.25,
          items: [
            MetricCard(
              label: 'Capital',
              value: '৳${reseller.capital}',
              color: blue,
              icon: Icons.savings_rounded,
            ),
            MetricCard(
              label: 'Profit',
              value: '৳${reseller.profit}',
              color: green,
              icon: Icons.trending_up_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [brand, brandDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(23),
            boxShadow: [
              BoxShadow(
                color: brand.withValues(alpha: .18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total Balance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white.withValues(alpha: .8),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '৳$balance',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Available to withdraw',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '৳${demoOms.availableBalanceFor(reseller)}',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Transaction History', icon: Icons.history_rounded),
        if (entries.isEmpty)
          const Panel(child: Text('No settlement credits yet.'))
        else
          Panel(
            child: Column(
              children: [
                for (var index = 0; index < entries.length; index++) ...[
                  if (index > 0) const Divider(color: line),
                  TransactionTile(
                    title:
                        'Batch settlement • Capital ৳${entries[index].capital} + Profit ৳${entries[index].profit}',
                    id: entries[index].reference,
                    amount:
                        '+৳${entries[index].capital + entries[index].profit}',
                    date: 'Order ${entries[index].orderId}',
                    status: 'Completed',
                    positive: true,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.title,
    required this.id,
    required this.amount,
    required this.date,
    required this.status,
    this.positive = false,
    super.key,
  });
  final String title;
  final String id;
  final String amount;
  final String date;
  final String status;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: positive ? green : red,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  color: positive ? green : red,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text('Transaction ID  •  $id', style: const TextStyle(color: muted)),
          const SizedBox(height: 5),
          Text(date, style: const TextStyle(color: ink)),
          const SizedBox(height: 8),
          StatusPill(status),
        ],
      ),
    );
  }
}

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({required this.onMessage, super.key});
  final ValueChanged<String> onMessage;

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  final amount = TextEditingController();
  final account = TextEditingController();
  String? method;
  String filter = 'All';

  @override
  void dispose() {
    amount.dispose();
    account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reseller = demoOms.resellers.first;
    final available = demoOms.availableBalanceFor(reseller);
    final requests = demoOms.withdrawals
        .where((request) => request.reseller == reseller)
        .where(
          (request) =>
              filter == 'All' ||
              _withdrawalStatusLabel(request.status) == filter,
        )
        .toList()
        .reversed
        .toList();
    return PageBody(
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                'Withdrawal Request',
                icon: Icons.request_quote_rounded,
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1FF),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: brand.withValues(alpha: .18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '৳$available',
                      style: const TextStyle(
                        color: brand,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              const FieldLabel('Withdrawal Amount'),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter withdrawal amount',
                ),
              ),
              const SizedBox(height: 15),
              const FieldLabel('Payment Method'),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(
                  hintText: 'Select payment method',
                ),
                items: const [
                  DropdownMenuItem(value: 'bKash', child: Text('bKash')),
                  DropdownMenuItem(value: 'Nagad', child: Text('Nagad')),
                  DropdownMenuItem(
                    value: 'Bank transfer',
                    child: Text('Bank transfer'),
                  ),
                ],
                onChanged: (value) => setState(() => method = value),
              ),
              const SizedBox(height: 15),
              const FieldLabel('Account Number'),
              TextField(
                controller: account,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'Enter account number',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Submit Withdrawal Request',
                  icon: Icons.send_rounded,
                  onPressed: () {
                    final requestedAmount = int.tryParse(amount.text.trim());
                    if (requestedAmount == null ||
                        account.text.trim().isEmpty ||
                        method == null) {
                      widget.onMessage(
                        'Complete the amount, payment method and account number.',
                      );
                      return;
                    }
                    try {
                      demoOms.requestWithdrawal(
                        reseller: reseller,
                        amount: requestedAmount,
                        method: method!,
                        account: account.text.trim(),
                      );
                      setState(() {});
                      widget.onMessage('Withdrawal request recorded.');
                      amount.clear();
                      account.clear();
                    } on StateError catch (error) {
                      widget.onMessage(error.message);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle(
          'Withdrawal Request List',
          icon: Icons.history_rounded,
        ),
        FilterChips(
          options: const [
            'All',
            'Pending',
            'Processing',
            'Approved',
            'Cancelled',
          ],
          selected: filter,
          onSelect: (value) => setState(() => filter = value),
        ),
        const SizedBox(height: 12),
        if (requests.isEmpty)
          Panel(
            child: Text(
              filter == 'All'
                  ? 'No withdrawal requests yet.'
                  : 'No withdrawal requests match this filter.',
            ),
          )
        else
          for (final request in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.id,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '-৳${request.amount}',
                          style: const TextStyle(
                            color: red,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: line),
                    KeyValueRow('Method', request.method),
                    const Divider(height: 1, color: line),
                    KeyValueRow(
                      'Account Number',
                      _maskedAccount(request.account),
                    ),
                    const Divider(height: 1, color: line),
                    KeyValueRow(
                      'Status',
                      _withdrawalStatusLabel(request.status),
                      valueColor: switch (request.status) {
                        DemoWithdrawalStatus.pending => orange,
                        DemoWithdrawalStatus.processing => blue,
                        DemoWithdrawalStatus.approved => green,
                        DemoWithdrawalStatus.cancelled => red,
                      },
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

String _maskedAccount(String account) {
  final visibleDigits = account.length < 4 ? account.length : 4;
  return '${List.filled(account.length - visibleDigits, '*').join()}'
      '${account.substring(account.length - visibleDigits)}';
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label,
        style: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class ResellerCatalog extends StatefulWidget {
  const ResellerCatalog({super.key});

  @override
  State<ResellerCatalog> createState() => _ResellerCatalogState();
}

class _ResellerCatalogState extends State<ResellerCatalog> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = demoOms.products
        .where(
          (product) =>
              product.title.toLowerCase().contains(query.toLowerCase()) ||
              product.category.toLowerCase().contains(query.toLowerCase()) ||
              product.description.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return PageBody(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        TextField(
          onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(
            hintText: 'Search items...',
            prefixIcon: Icon(Icons.search_rounded, color: muted),
          ),
        ),
        const SizedBox(height: 17),
        if (filtered.isEmpty)
          const Panel(
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, color: muted, size: 34),
                SizedBox(height: 8),
                Text(
                  'No products found.',
                  style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        for (final product in filtered) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF0FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    product.category,
                    style: const TextStyle(
                      color: brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  product.title,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  product.description,
                  style: const TextStyle(color: muted, height: 1.5),
                ),
                const SizedBox(height: 14),
                PriceStrip(
                  wholesale: '৳${product.wholesalePrice}',
                  retail:
                      '৳${product.retailPrice(demoOms.settings.profitRate)}',
                  profit:
                      '৳${product.retailPrice(demoOms.settings.profitRate) - product.wholesalePrice}',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'View Details',
                    icon: Icons.visibility_rounded,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Product Details'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.category,
                              style: const TextStyle(
                                color: brand,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.description,
                              style: const TextStyle(color: muted, height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            PriceStrip(
                              wholesale: '৳${product.wholesalePrice}',
                              retail:
                                  '৳${product.retailPrice(demoOms.settings.profitRate)}',
                              profit:
                                  '৳${product.retailPrice(demoOms.settings.profitRate) - product.wholesalePrice}',
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class OrderDetails extends StatelessWidget {
  const OrderDetails({
    required this.orderId,
    required this.onMessage,
    super.key,
  });
  final String? orderId;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final order = demoOms.orderById(orderId);
    if (order == null) {
      return const PageBody(
        children: [Panel(child: Text('No order is available.'))],
      );
    }
    return Column(
      children: [
        Expanded(
          child: PageBody(
            children: [
              Container(
                padding: const EdgeInsets.all(21),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [brand, brandDark]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: brand.withValues(alpha: .19),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RESELLER ORDER ID',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '#${order.id}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Spacer(),
                        StatusPill(_orderStatusLabel(order.status)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      'Customer Details',
                      icon: Icons.person_rounded,
                    ),
                    KeyValueRow('Name', order.customer.name),
                    const Divider(height: 1, color: line),
                    KeyValueRow('Mobile Number', order.customer.mobile),
                    const Divider(height: 1, color: line),
                    KeyValueRow('Address', order.customer.address),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      'Product Details',
                      icon: Icons.inventory_2_rounded,
                    ),
                    KeyValueRow('Category', order.product.category),
                    const Divider(height: 1, color: line),
                    KeyValueRow('Title', order.product.title),
                    const Divider(height: 1, color: line),
                    KeyValueRow('Description', order.product.description),
                    const Divider(height: 1, color: line),
                    KeyValueRow('Wholesale Price', '৳${order.wholesalePrice}'),
                    const Divider(height: 1, color: line),
                    KeyValueRow('Retail Price', '৳${order.retailPrice}'),
                    KeyValueRow(
                      'Profit',
                      '৳${order.profit}',
                      valueColor: green,
                    ),
                    const Divider(height: 1, color: line),
                    KeyValueRow(
                      'Payment status',
                      order.paymentStatus == DemoPaymentStatus.simulated
                          ? 'Paid'
                          : 'Unpaid',
                      valueColor:
                          order.paymentStatus == DemoPaymentStatus.simulated
                          ? green
                          : orange,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: red,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: order.status == DemoOrderStatus.pending
                        ? () {
                            try {
                              demoOms.transferOrder(order);
                              onMessage(
                                'Order transferred to ${order.reseller.name}; transfer ${order.transferNumber}.',
                              );
                            } on StateError catch (error) {
                              onMessage(error.message);
                            }
                          }
                        : null,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: 'Pay & Confirm',
                    icon: Icons.check_rounded,
                    onPressed: order.status == DemoOrderStatus.pending
                        ? () {
                            try {
                              demoOms.confirmPayment(order);
                              onMessage('Payment confirmed successfully.');
                            } on StateError catch (error) {
                              onMessage(error.message);
                            }
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    required this.onMessage,
    this.admin = false,
    super.key,
  });
  final ValueChanged<String> onMessage;
  final bool admin;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String filter = 'All';
  final read = <int>{2, 3, 4};

  @override
  Widget build(BuildContext context) {
    final entries = demoOms.auditLog
        .map(
          (message) => (
            widget.admin ? 'Admin activity' : 'Activity',
            message,
            'This session',
            Icons.notifications_active_rounded,
          ),
        )
        .toList();
    return PageBody(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: FilterChips(
                options: const ['All', 'Unread', 'Read'],
                selected: filter,
                onSelect: (value) => setState(() => filter = value),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(
                  () => read.addAll(List.generate(entries.length, (i) => i)),
                );
                widget.onMessage('All notifications marked as read.');
              },
              child: const Text('Mark all read'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < entries.length; i++)
          if (filter == 'All' ||
              (filter == 'Unread' && !read.contains(i)) ||
              (filter == 'Read' && read.contains(i)))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => read.add(i)),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: line),
                      color: read.contains(i)
                          ? Colors.white
                          : const Color(0xFFF9F8FF),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EAFE),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(entries[i].$4, color: brand),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entries[i].$1,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    entries[i].$3,
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entries[i].$2,
                                style: const TextStyle(
                                  color: muted,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!read.contains(i)) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.circle, color: brand, size: 11),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.onOpen, super.key});
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final reseller = demoOms.resellers.first;
    final accountStatus = reseller.active ? 'Active' : 'Inactive';
    return PageBody(
      children: [
        Panel(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 112,
                height: 112,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [brand, brandDark]),
                ),
                child: Text(
                  reseller.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 45,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Text(
                reseller.name,
                style: const TextStyle(
                  color: ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Reseller ID: RSL-10001',
                style: TextStyle(color: muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              StatusPill(accountStatus),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Information',
                style: TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10),
              KeyValueRow('Full Name', reseller.name),
              Divider(height: 1, color: line),
              KeyValueRow('Mobile Number', reseller.mobile),
              Divider(height: 1, color: line),
              KeyValueRow('Email Address', reseller.email),
              Divider(height: 1, color: line),
              KeyValueRow(
                'Account Status',
                accountStatus,
                valueColor: reseller.active ? green : red,
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.settings_rounded, color: brand),
                title: const Text('Settings'),
                subtitle: const Text('Manage your account settings'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onOpen('login'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: brand),
                title: const Text('Share Platform'),
                subtitle: const Text('Share this application with others'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({
    required this.onSignIn,
    required this.onMessage,
    this.onBack,
    super.key,
  });

  final Future<void> Function(String email, String password) onSignIn;
  final ValueChanged<String> onMessage;
  final VoidCallback? onBack;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscurePassword = true;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      widget.onMessage('Enter your administrator email and password.');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.onSignIn(email.text, password.text);
    } on FirebaseAuthException catch (error) {
      widget.onMessage(error.message ?? error.code);
    } on StateError catch (error) {
      widget.onMessage(error.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.onBack != null
          ? AppBar(
              leading: IconButton(
                tooltip: 'Back',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: const Text('Administrator Sign In'),
            )
          : null,
      body: PageBody(
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.admin_panel_settings_rounded, size: 58, color: brand),
          const SizedBox(height: 12),
          const Text(
            'Administrator Sign In',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('EMAIL ADDRESS'),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    hintText: 'Enter administrator email',
                  ),
                ),
                const SizedBox(height: 14),
                const FieldLabel('PASSWORD'),
                TextField(
                  controller: password,
                  obscureText: obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => obscurePassword = !obscurePassword),
                      icon: Icon(
                        obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: busy ? 'Signing in...' : 'Sign in',
                    icon: Icons.login_rounded,
                    onPressed: busy ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.register,
    required this.onMessage,
    required this.onOpen,
    super.key,
  });
  final bool register;
  final ValueChanged<String> onMessage;
  final ValueChanged<String> onOpen;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool obscure = true;
  bool agree = false;

  @override
  Widget build(BuildContext context) {
    final register = widget.register;
    return Scaffold(
      appBar: !register
          ? AppBar(
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () => widget.onOpen('register'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: const Text('Welcome Back'),
            )
          : null,
      body: PageBody(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const SizedBox(height: 8),
          Container(
            width: 82,
            height: 82,
            margin: const EdgeInsets.symmetric(horizontal: 115),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [brand, brandDark]),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              register ? Icons.person_add_alt_1 : Icons.login_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            register ? 'Become a Reseller' : 'Welcome Back',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            register
                ? 'Join our platform and start your business today'
                : 'Login to your reseller account',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 15),
          ),
          const SizedBox(height: 22),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  register ? 'Reseller Registration' : 'Reseller Login',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                if (register) ...[
                  const FieldLabel('FULL NAME'),
                  const TextField(
                    decoration: InputDecoration(hintText: 'Enter your full name'),
                  ),
                  const SizedBox(height: 14),
                ],
                const FieldLabel('MOBILE NUMBER'),
                const TextField(
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(hintText: 'Enter mobile number'),
                ),
                if (register) ...[
                  const SizedBox(height: 14),
                  const FieldLabel('EMAIL ADDRESS (Optional)'),
                  const TextField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter your email address',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const FieldLabel('PASSWORD'),
                TextField(
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: register ? 'Create a password' : 'Enter password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                if (register) ...[
                  const SizedBox(height: 14),
                  const FieldLabel('CONFIRM PASSWORD'),
                  TextField(
                    obscureText: obscure,
                    decoration: const InputDecoration(
                      hintText: 'Confirm your password',
                    ),
                  ),
                  CheckboxListTile(
                    value: agree,
                    onChanged: (value) => setState(() => agree = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I agree to the Terms & Conditions and Privacy Policy.',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ),
                ] else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => widget.onMessage(
                        'Contact support to reset your password.',
                      ),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: register ? 'Create Reseller Account' : 'Login',
                    icon: register ? Icons.person_add_alt_1 : Icons.login_rounded,
                    onPressed: () {
                      if (register && !agree) {
                        widget.onMessage(
                          'Please agree to the terms to continue.',
                        );
                      } else {
                        widget.onMessage(
                          register
                              ? 'Registration form is ready to connect.'
                              : 'Login form is ready to connect.',
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        widget.onOpen(register ? 'login' : 'register'),
                    child: Text(
                      register
                          ? 'Already have an account? Login'
                          : "Don't have an account? Create Reseller Account",
                    ),
                  ),
                ),
                if (register)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => widget.onOpen('adminLogin'),
                      icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                      label: const Text('Admin Login'),
                      style: TextButton.styleFrom(
                        foregroundColor: brand,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminHome extends StatelessWidget {
  const AdminHome({required this.onOpen, super.key});
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    int orderCount(DemoOrderStatus status) =>
        demoOms.orders.where((order) => order.status == status).length;
    int withdrawalCount(DemoWithdrawalStatus status) =>
        demoOms.withdrawals.where((request) => request.status == status).length;
    return PageBody(
      children: [
        Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [brand, brandDark]),
            borderRadius: BorderRadius.circular(23),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to BKH Business Manager 👋',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Manage your complete Order Management System from one place.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Platform Overview', icon: Icons.analytics_rounded),
        MetricGrid(
          items: [
            MetricCard(
              label: 'Customers',
              value: '${demoOms.customers.length}',
            ),
            MetricCard(
              label: 'Products',
              value: '${demoOms.products.length}',
              color: blue,
            ),
            MetricCard(
              label: 'Active resellers',
              value: '${demoOms.activeResellers.length}',
              color: green,
            ),
            MetricCard(
              label: 'Total Batch',
              value: '${demoOms.batches.length}',
              color: orange,
            ),
            MetricCard(
              label: 'Total Orders',
              value: '${demoOms.orders.length}',
            ),
            MetricCard(
              label: 'Pending',
              value: '${orderCount(DemoOrderStatus.pending)}',
              color: orange,
            ),
            MetricCard(
              label: 'Processing',
              value: '${orderCount(DemoOrderStatus.processing)}',
              color: blue,
            ),
            MetricCard(
              label: 'Delivered',
              value: '${orderCount(DemoOrderStatus.delivered)}',
              color: green,
            ),
            MetricCard(
              label: 'Cancelled',
              value: '${orderCount(DemoOrderStatus.cancelled)}',
              color: red,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Withdrawal Overview', icon: Icons.payments_rounded),
        MetricGrid(
          items: [
            MetricCard(
              label: 'Total Withdraw',
              value: '${demoOms.withdrawals.length}',
            ),
            MetricCard(
              label: 'Pending',
              value: '${withdrawalCount(DemoWithdrawalStatus.pending)}',
              color: orange,
            ),
            MetricCard(
              label: 'Processing',
              value: '${withdrawalCount(DemoWithdrawalStatus.processing)}',
              color: blue,
            ),
            MetricCard(
              label: 'Approved',
              value: '${withdrawalCount(DemoWithdrawalStatus.approved)}',
              color: green,
            ),
            MetricCard(
              label: 'Cancelled',
              value: '${withdrawalCount(DemoWithdrawalStatus.cancelled)}',
              color: red,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Recent Payment', icon: Icons.payment_rounded),
        Panel(
          child: demoOms.orders
                  .where((order) =>
                      order.paymentStatus == DemoPaymentStatus.simulated)
                  .isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No payments yet.'),
                )
              : Column(
                  children: demoOms.orders
                      .where((order) =>
                          order.paymentStatus == DemoPaymentStatus.simulated)
                      .toList()
                      .reversed
                      .take(3)
                      .map((order) {
                    return KeyValueRow(
                      '#${order.id} • ${order.reseller.name}',
                      '৳${order.wholesalePrice} • Paid',
                      valueColor: green,
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Recent Withdraw', icon: Icons.money_rounded),
        Panel(
          child: demoOms.withdrawals.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No withdrawal requests yet.'),
                )
              : Column(
                  children: demoOms.withdrawals.reversed.take(3).map((request) {
                    return KeyValueRow(
                      '${request.id} • ${request.reseller.name}',
                      '৳${request.amount} • ${request.method}',
                      valueColor: request.status ==
                              DemoWithdrawalStatus.approved
                          ? green
                          : orange,
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Quick Actions', icon: Icons.bolt_rounded),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            ActionChip(
              avatar: const Icon(Icons.person_add_alt_1, color: brand),
              label: const Text('Add Customer'),
              onPressed: () => onOpen('customers'),
            ),
            ActionChip(
              avatar: const Icon(Icons.add_box_rounded, color: brand),
              label: const Text('Add Product'),
              onPressed: () => onOpen('products'),
            ),
            ActionChip(
              avatar: const Icon(Icons.account_balance_rounded, color: brand),
              label: const Text('Withdrawal & Disbursement'),
              onPressed: () => onOpen('withdrawals'),
            ),
          ],
        ),
      ],
    );
  }
}

class AdminCustomers extends StatefulWidget {
  const AdminCustomers({super.key});

  @override
  State<AdminCustomers> createState() => _AdminCustomersState();
}

class _AdminCustomersState extends State<AdminCustomers> {
  String query = '';
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  void _addCustomer() {
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and mobile number are required.')),
      );
      return;
    }
    if (demoOms.customers.any(
      (customer) => customer.mobile == phone.text.trim(),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That mobile number already exists.')),
      );
      return;
    }
    setState(
      () => demoOms.customers.add(
        DemoCustomer(
          name.text.trim(),
          phone.text.trim(),
          address.text.trim().isEmpty ? '—' : address.text.trim(),
        ),
      ),
    );
    name.clear();
    phone.clear();
    address.clear();
  }

  Future<void> _editCustomer(DemoCustomer customer) async {
    final editName = TextEditingController(text: customer.name);
    final editPhone = TextEditingController(text: customer.mobile);
    final editAddress = TextEditingController(text: customer.address);
    try {
      final updated = await showDialog<DemoCustomer>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit customer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editName,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editPhone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editAddress,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (editName.text.trim().isEmpty ||
                    editPhone.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  DemoCustomer(
                    editName.text.trim(),
                    editPhone.text.trim(),
                    editAddress.text.trim(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (!mounted || updated == null) return;
      if (demoOms.customers.any(
        (item) => item != customer && item.mobile == updated.mobile,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That mobile number already exists.')),
        );
        return;
      }
      final index = demoOms.customers.indexOf(customer);
      if (index >= 0) {
        setState(() => demoOms.customers[index] = updated);
      }
    } finally {
      editName.dispose();
      editPhone.dispose();
      editAddress.dispose();
    }
  }

  Future<void> _importCustomers() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select customer Excel file',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (!mounted || files.isEmpty) return;
      final file = files.first;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final rows = parseExcelRows(bytes);
      final header = rows.first.map(_tableHeader).toList();
      final nameIndex = _tableColumn(header, const ['name', 'customer_name']);
      final mobileIndex = _tableColumn(header, const [
        'mobile',
        'mobile_number',
        'phone',
      ]);
      final addressIndex = _tableColumn(header, const ['address']);
      if (nameIndex < 0 || mobileIndex < 0) {
        throw const FormatException(
          'The Excel header row must include name and mobile_number columns.',
        );
      }
      var imported = 0;
      var skipped = 0;
      final mobileNumbers = demoOms.customers
          .map((customer) => customer.mobile)
          .toSet();
      final newCustomers = <DemoCustomer>[];
      for (final columns in rows.skip(1)) {
        final rowName = _tableValue(columns, nameIndex);
        final mobile = _tableValue(columns, mobileIndex);
        if (rowName.isEmpty || mobile.isEmpty || !mobileNumbers.add(mobile)) {
          skipped++;
          continue;
        }
        newCustomers.add(
          DemoCustomer(
            rowName,
            mobile,
            _tableValue(columns, addressIndex).isEmpty
                ? '—'
                : _tableValue(columns, addressIndex),
          ),
        );
        imported++;
      }
      if (newCustomers.isNotEmpty) {
        setState(() => demoOms.customers.addAll(newCustomers));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported $imported customer(s) from ${file.name}; skipped $skipped invalid or duplicate row(s).',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer Excel import failed: ${error.message}'),
          ),
        );
      }
    } on UnsupportedError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Customer Excel import failed: ${error.message ?? error.toString()}',
            ),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Customer Excel import failed: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = demoOms.customers
        .where(
          (customer) => [
            customer.name,
            customer.mobile,
            customer.address,
          ].any((value) => value.toLowerCase().contains(query.toLowerCase())),
        )
        .toList();
    return PageBody(
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Add Customer', icon: Icons.person_add_alt_1),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Customer name',
                ),
              ),
              const SizedBox(height: 11),
              TextField(
                controller: phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: '01XXXXXXXXX',
                ),
              ),
              const SizedBox(height: 11),
              TextField(
                controller: address,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Customer address',
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Add Customer',
                icon: Icons.add_rounded,
                onPressed: _addCustomer,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _importCustomers,
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text(
                        'Upload Excel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveExcelTemplate(
                        context,
                        fileName: 'customer_template.xlsx',
                        bytes: createCustomerExcelTemplate(),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text(
                        'Get Template',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'Excel: name, mobile_number, address (optional). Keep mobile numbers as text.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        const SectionTitle('Customer List'),
        TextField(
          onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search customer...',
          ),
        ),
        const SizedBox(height: 12),
        for (final customer in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit customer',
                        onPressed: () => _editCustomer(customer),
                        icon: const Icon(Icons.edit_rounded, color: brand),
                      ),
                      IconButton(
                        tooltip: 'Delete customer',
                        onPressed: () {
                          setState(() => demoOms.customers.remove(customer));
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  KeyValueRow('Mobile Number', customer.mobile),
                  const Divider(height: 1, color: line),
                  KeyValueRow('Address', customer.address),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class AdminProducts extends StatefulWidget {
  const AdminProducts({super.key});

  @override
  State<AdminProducts> createState() => _AdminProductsState();
}

class _AdminProductsState extends State<AdminProducts> {
  final category = TextEditingController();
  final title = TextEditingController();
  final description = TextEditingController();
  final wholesaleController = TextEditingController();
  String? wholesale;
  String query = '';

  @override
  void dispose() {
    category.dispose();
    title.dispose();
    description.dispose();
    wholesaleController.dispose();
    super.dispose();
  }

  Future<void> _importProducts() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select product Excel file',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (!mounted || files.isEmpty) return;
      final file = files.first;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final rows = parseExcelRows(bytes);
      final headers = rows.first.map(_tableHeader).toList();
      final categoryIndex = _tableColumn(headers, const ['category']);
      final titleIndex = _tableColumn(headers, const [
        'title',
        'product_title',
      ]);
      final descriptionIndex = _tableColumn(headers, const [
        'description',
        'details',
      ]);
      final wholesaleIndex = _tableColumn(headers, const [
        'wholesale_price',
        'wholesale',
        'price',
      ]);
      if (categoryIndex < 0 || titleIndex < 0 || wholesaleIndex < 0) {
        throw const FormatException(
          'The Excel header row must include category, title, and wholesale_price columns.',
        );
      }
      final knownTitles = demoOms.products
          .map((product) => product.title.toLowerCase())
          .toSet();
      final imported = <DemoProduct>[];
      var skipped = 0;
      for (final row in rows.skip(1)) {
        final productCategory = _tableValue(row, categoryIndex);
        final productTitle = _tableValue(row, titleIndex);
        final rawPrice = _tableValue(row, wholesaleIndex);
        final wholesalePrice = int.tryParse(
          rawPrice.replaceAll(RegExp(r'^[৳$]\s*'), '').replaceAll(',', ''),
        );
        if (productCategory.isEmpty ||
            productTitle.isEmpty ||
            wholesalePrice == null ||
            wholesalePrice <= 0 ||
            wholesalePrice % 50 != 0 ||
            !knownTitles.add(productTitle.toLowerCase())) {
          skipped++;
          continue;
        }
        imported.add(
          DemoProduct(
            title: productTitle,
            category: productCategory,
            description: _tableValue(row, descriptionIndex),
            wholesalePrice: wholesalePrice,
          ),
        );
      }
      if (imported.isNotEmpty) {
        setState(() => demoOms.products.addAll(imported));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${imported.length} product(s) from ${file.name}; skipped $skipped invalid or duplicate row(s). Retail prices use the current ${demoOms.settings.profitRate}% rate.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product Excel import failed: ${error.message}'),
          ),
        );
      }
    } on UnsupportedError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product Excel import failed: ${error.message ?? error.toString()}',
            ),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product Excel import failed: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _editProduct(DemoProduct product) async {
    final updated = await showDialog<DemoProduct>(
      context: context,
      builder: (dialogContext) => _EditProductDialog(
        product: product,
        onSave: (updated) {
          final duplicateTitle = demoOms.products.any(
            (item) =>
                !identical(item, product) &&
                item.title.toLowerCase() == updated.title.toLowerCase(),
          );
          if (duplicateTitle) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('A product with that title already exists.'),
              ),
            );
            return;
          }
          Navigator.of(dialogContext).pop(updated);
        },
      ),
    );
    if (!mounted || updated == null) return;
    final index = demoOms.products.indexOf(product);
    if (index < 0) return;
    setState(() => demoOms.products[index] = updated);
    demoOms.auditLog.insert(0, 'Product "${updated.title}" updated.');
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Product updated.')));
  }

  Future<void> _deleteProduct(DemoProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'Delete "${product.title}" from the product catalog? Existing orders will keep their saved product details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => demoOms.products.remove(product));
    demoOms.auditLog.insert(0, 'Product "${product.title}" deleted.');
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Product deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = demoOms.products
        .where(
          (product) =>
              product.title.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final wholesalePrice = int.tryParse(wholesale ?? '');
    final retail = wholesalePrice == null
        ? null
        : (wholesalePrice * (1 + demoOms.settings.profitRate / 100)).round();
    return PageBody(
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Add Product', icon: Icons.add_box_rounded),
              TextField(
                controller: category,
                decoration: const InputDecoration(
                  labelText: 'Product Category',
                  hintText: 'Enter a category',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
              ),
              const SizedBox(height: 11),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Product title',
                ),
              ),
              const SizedBox(height: 11),
              TextField(
                controller: wholesaleController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Wholesale Price',
                  hintText: 'Enter an amount in ৳50 multiples',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
                onChanged: (value) => setState(() => wholesale = value),
              ),
              const SizedBox(height: 11),
              TextField(
                controller: description,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Product description',
                ),
              ),
              const SizedBox(height: 11),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'System Profit Rate',
                ),
                child: Text('${demoOms.settings.profitRate}%'),
              ),
              const SizedBox(height: 11),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Retail Price'),
                child: Text(retail == null ? 'Auto calculated' : '৳$retail'),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Add Product',
                icon: Icons.add_rounded,
                onPressed: () {
                  if (category.text.trim().isEmpty ||
                      title.text.trim().isEmpty ||
                      wholesalePrice == null ||
                      wholesalePrice <= 0 ||
                      wholesalePrice % 50 != 0 ||
                      retail == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter a category, title, and a valid wholesale price in ৳50 multiples.',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(
                    () => demoOms.products.add(
                      DemoProduct(
                        title: title.text.trim(),
                        category: category.text.trim(),
                        description: description.text.trim(),
                        wholesalePrice: wholesalePrice,
                      ),
                    ),
                  );
                  title.clear();
                  category.clear();
                  description.clear();
                  wholesaleController.clear();
                  wholesale = null;
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _importProducts,
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text(
                        'Upload Excel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveExcelTemplate(
                        context,
                        fileName: 'product_template.xlsx',
                        bytes: createProductExcelTemplate(),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text(
                        'Get Template',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'Excel: category, title, description (optional), wholesale_price. Price must be a ৳50 multiple.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        const SectionTitle('Product List'),
        TextField(
          onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search product...',
          ),
        ),
        const SizedBox(height: 12),
        for (final product in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${product.category} • ${product.description}',
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 10),
                  KeyValueRow('Wholesale Price', '৳${product.wholesalePrice}'),
                  const Divider(height: 1, color: line),
                  KeyValueRow(
                    'Retail Price',
                    '৳${product.retailPrice(demoOms.settings.profitRate)}',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _editProduct(product),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: red,
                          side: BorderSide(color: red.withValues(alpha: .5)),
                        ),
                        onPressed: () => _deleteProduct(product),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog({required this.product, required this.onSave});

  final DemoProduct product;
  final ValueChanged<DemoProduct> onSave;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  late final TextEditingController categoryController;
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController priceController;

  @override
  void initState() {
    super.initState();
    categoryController = TextEditingController(text: widget.product.category);
    titleController = TextEditingController(text: widget.product.title);
    descriptionController = TextEditingController(
      text: widget.product.description,
    );
    priceController = TextEditingController(
      text: '${widget.product.wholesalePrice}',
    );
  }

  @override
  void dispose() {
    categoryController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void _save() {
    final title = titleController.text.trim();
    final category = categoryController.text.trim();
    final wholesalePrice = int.tryParse(priceController.text.trim());
    if (category.isEmpty ||
        title.isEmpty ||
        wholesalePrice == null ||
        wholesalePrice <= 0 ||
        wholesalePrice % 50 != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a category, title, and a valid wholesale price in ৳50 multiples.',
          ),
        ),
      );
      return;
    }
    widget.onSave(
      DemoProduct(
        title: title,
        category: category,
        description: descriptionController.text.trim(),
        wholesalePrice: wholesalePrice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Product'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'Product Category',
                hintText: 'Enter a category',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Wholesale Price',
                helperText: 'Must be a positive multiple of ৳50.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save Changes')),
      ],
    );
  }
}

class AdminResellers extends StatefulWidget {
  const AdminResellers({super.key});

  @override
  State<AdminResellers> createState() => _AdminResellersState();
}

class _AdminResellersState extends State<AdminResellers> {
  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        const SectionTitle(
          'Reseller Management',
          icon: Icons.storefront_rounded,
        ),
        for (final reseller in demoOms.resellers) ...[
          Builder(
            builder: (context) {
              final resellerOrders = demoOms.orders
                  .where((order) => order.reseller == reseller)
                  .toList();
              int countOrders(DemoOrderStatus status) => resellerOrders
                  .where((order) => order.status == status)
                  .length;
              final resellerWithdrawals = demoOms.withdrawals.where(
                (request) => request.reseller == reseller,
              );
              final withdrawn = resellerWithdrawals
                  .where(
                    (request) =>
                        request.status != DemoWithdrawalStatus.cancelled,
                  )
                  .fold<int>(0, (total, request) => total + request.amount);
              return ResellerAdminCard(
                name: reseller.name,
                mobile: reseller.mobile,
                email: reseller.email,
                pendingOrders: countOrders(DemoOrderStatus.pending),
                processingOrders: countOrders(DemoOrderStatus.processing),
                deliveredOrders: countOrders(DemoOrderStatus.delivered),
                cancelledOrders: countOrders(DemoOrderStatus.cancelled),
                capital: reseller.capital,
                profit: reseller.profit,
                currentBalance: demoOms.availableBalanceFor(reseller),
                withdrawn: withdrawn,
                status: reseller.active ? 'Active' : 'Inactive',
                active: reseller.active,
                onActiveChanged: (value) => setState(() {
                  reseller.active = value;
                  demoOms.auditLog.insert(
                    0,
                    '${reseller.name} ${value ? 'activated' : 'deactivated'}',
                  );
                }),
                onDelete: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Reseller'),
                      content: Text(
                        'Are you sure you want to delete ${reseller.name}? This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: red),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    setState(() {
                      demoOms.resellers.remove(reseller);
                      demoOms.auditLog.insert(
                        0,
                        'Reseller ${reseller.name} deleted.',
                      );
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${reseller.name} deleted successfully.'),
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class ResellerAdminCard extends StatelessWidget {
  const ResellerAdminCard({
    required this.name,
    required this.mobile,
    required this.email,
    required this.pendingOrders,
    required this.processingOrders,
    required this.deliveredOrders,
    required this.cancelledOrders,
    required this.capital,
    required this.profit,
    required this.currentBalance,
    required this.withdrawn,
    required this.status,
    this.active = true,
    this.onActiveChanged,
    this.onDelete,
    super.key,
  });
  final String name;
  final String mobile;
  final String email;
  final int pendingOrders;
  final int processingOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final int capital;
  final int profit;
  final int currentBalance;
  final int withdrawn;
  final String status;
  final bool active;
  final ValueChanged<bool>? onActiveChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              StatusPill(status),
            ],
          ),
          const SizedBox(height: 8),
          KeyValueRow('Mobile', mobile),
          const Divider(height: 1, color: line),
          KeyValueRow('Email', email),
          const Divider(height: 1, color: line),
          const SizedBox(height: 8),
          const SectionTitle('Orders', icon: Icons.inventory_2_rounded),
          KeyValueRow('Pending', '$pendingOrders', valueColor: orange),
          const Divider(height: 1, color: line),
          KeyValueRow('Processing', '$processingOrders', valueColor: blue),
          const Divider(height: 1, color: line),
          KeyValueRow('Delivered', '$deliveredOrders', valueColor: green),
          const Divider(height: 1, color: line),
          KeyValueRow('Cancelled', '$cancelledOrders', valueColor: red),
          const SizedBox(height: 8),
          const SectionTitle(
            'Wallet',
            icon: Icons.account_balance_wallet_rounded,
          ),
          KeyValueRow('Capital', '৳$capital', valueColor: blue),
          const Divider(height: 1, color: line),
          KeyValueRow('Profit', '৳$profit', valueColor: green),
          const Divider(height: 1, color: line),
          KeyValueRow('Current Balance', '৳$currentBalance'),
          const Divider(height: 1, color: line),
          KeyValueRow('Withdraw', '৳$withdrawn', valueColor: red),
          if (onActiveChanged != null)
            Material(
              color: Colors.white,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(active ? 'Reseller active' : 'Reseller inactive'),
                value: active,
                activeThumbColor: brand,
                onChanged: onActiveChanged,
              ),
            ),
          if (onDelete != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: red,
                  side: const BorderSide(color: red),
                ),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_rounded),
                label: const Text('Delete Reseller'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminOrders extends StatefulWidget {
  const AdminOrders({required this.onMessage, super.key});
  final ValueChanged<String> onMessage;

  @override
  State<AdminOrders> createState() => _AdminOrdersState();
}

class _AdminOrdersState extends State<AdminOrders> {
  String query = '';
  String filter = 'All';
  String batchFilter = demoOms.currentBatchId;

  String _label(DemoOrderStatus status) => switch (status) {
    DemoOrderStatus.pending => 'Pending',
    DemoOrderStatus.processing => 'Processing',
    DemoOrderStatus.delivered => 'Delivered',
    DemoOrderStatus.cancelled => 'Cancelled',
  };

  void _showOrderDetails(BuildContext context, DemoOrder order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order Details - ${order.id}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Customer Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              KeyValueRow('Name', order.customer.name),
              const Divider(height: 1, color: line),
              KeyValueRow('Mobile Number', order.customer.mobile),
              const Divider(height: 1, color: line),
              KeyValueRow('Address', order.customer.address),
              const SizedBox(height: 16),
              const Text(
                'Product Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              KeyValueRow('Title', order.product.title),
              const Divider(height: 1, color: line),
              KeyValueRow('Description', order.product.description),
              const Divider(height: 1, color: line),
              KeyValueRow('Wholesale Price', '৳${order.wholesalePrice}'),
              const Divider(height: 1, color: line),
              KeyValueRow('Retail Price', '৳${order.retailPrice}'),
              const SizedBox(height: 16),
              const Text(
                'Reseller Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              KeyValueRow('Name', order.reseller.name),
              const Divider(height: 1, color: line),
              KeyValueRow('Mobile Number', order.reseller.mobile),
              const Divider(height: 1, color: line),
              KeyValueRow('Email Address', order.reseller.email),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, DemoOrder order) {
    DemoCustomer? selectedCustomer = order.customer;
    DemoProduct? selectedProduct = order.product;
    DemoReseller? selectedReseller = order.reseller;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Order - ${order.id}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<DemoCustomer>(
                  initialValue: selectedCustomer,
                  decoration: const InputDecoration(
                    labelText: 'Select Customer',
                    border: OutlineInputBorder(),
                  ),
                  items: demoOms.customers
                      .map((customer) => DropdownMenuItem(
                            value: customer,
                            child: Text(customer.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedCustomer = value);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Product', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<DemoProduct>(
                  initialValue: selectedProduct,
                  decoration: const InputDecoration(
                    labelText: 'Select Product',
                    border: OutlineInputBorder(),
                  ),
                  items: demoOms.products
                      .map((product) => DropdownMenuItem(
                            value: product,
                            child: Text(product.title),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedProduct = value);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Reseller', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<DemoReseller>(
                  initialValue: selectedReseller,
                  decoration: const InputDecoration(
                    labelText: 'Select Reseller',
                    border: OutlineInputBorder(),
                  ),
                  items: demoOms.resellers
                      .map((reseller) => DropdownMenuItem(
                            value: reseller,
                            child: Text(reseller.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedReseller = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedCustomer != null &&
                    selectedProduct != null &&
                    selectedReseller != null) {
                  final index = demoOms.orders.indexOf(order);
                  if (index >= 0) {
                    final profitRate = demoOms.settings.profitRate;
                    final calculatedRetailPrice = 
                        (selectedProduct!.wholesalePrice * (100 + profitRate) / 100).round();
                    final updatedOrder = DemoOrder(
                      id: order.id,
                      batchId: order.batchId,
                      customer: selectedCustomer!,
                      product: selectedProduct!,
                      reseller: selectedReseller!,
                      wholesalePrice: selectedProduct!.wholesalePrice,
                      retailPrice: calculatedRetailPrice,
                    )
                      ..status = order.status
                      ..paymentStatus = order.paymentStatus
                      ..transferNumber = order.transferNumber;
                    demoOms.orders[index] = updatedOrder;
                    setState(() {});
                    Navigator.of(dialogContext).pop();
                    widget.onMessage('Order updated successfully.');
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancelOrder(BuildContext context, DemoOrder order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Do you want to cancel order ${order.id}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: red),
            onPressed: () {
              try {
                final index = demoOms.orders.indexOf(order);
                if (index >= 0) {
                  final cancelledOrder = demoOms.orders[index];
                  
                  // If order was paid, refund only capital to reseller wallet
                  if (cancelledOrder.paymentStatus == DemoPaymentStatus.simulated) {
                    cancelledOrder.reseller.capital += cancelledOrder.wholesalePrice;
                  }
                  
                  demoOms.orders[index].status = DemoOrderStatus.cancelled;
                  setState(() {});
                  Navigator.of(context).pop();
                  widget.onMessage('Order ${order.id} cancelled successfully.');
                }
              } on StateError catch (error) {
                widget.onMessage(error.message);
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBatch = demoOms.batches.where(
      (batch) => batch.id == batchFilter,
    );
    final batch = selectedBatch.isEmpty ? null : selectedBatch.first;
    final orders = demoOms.orders.where((order) {
      final matchesStatus = filter == 'All' || _label(order.status) == filter;
      final matchesBatch =
          batchFilter == 'All Batches' || order.batchId == batchFilter;
      final searchText = [
        order.id,
        order.batchId,
        order.customer.name,
        order.product.title,
        order.reseller.name,
      ].join(' ').toLowerCase();
      return matchesStatus &&
          matchesBatch &&
          searchText.contains(query.toLowerCase());
    }).toList();
    return PageBody(
      children: [
        DropdownButtonFormField<String>(
          initialValue: batchFilter,
          decoration: const InputDecoration(labelText: 'Batch'),
          items: [
            const DropdownMenuItem(
              value: 'All Batches',
              child: Text('All Batches'),
            ),
            for (final item in demoOms.batches.reversed)
              DropdownMenuItem(value: item.id, child: Text(item.id)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => batchFilter = value);
          },
        ),
        if (batch != null) ...[
          const SizedBox(height: 12),
          Panel(
            child: Column(
              children: [
                KeyValueRow('Batch target', '৳${batch.target}'),
                const Divider(height: 1, color: line),
                KeyValueRow(
                  'Batch payment',
                  '৳${demoOms.paidTotalFor(batch.id)} / ৳${batch.target}',
                ),
                const Divider(height: 1, color: line),
                KeyValueRow(
                  'Settlement',
                  demoOms.settledBatchIds.contains(batch.id)
                      ? 'Settled'
                      : 'Pending',
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => query = value.trim()),
          decoration: const InputDecoration(
            hintText: 'Search order, customer, product, reseller...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        FilterChips(
          options: const [
            'All',
            'Pending',
            'Processing',
            'Delivered',
            'Cancelled',
          ],
          selected: filter,
          onSelect: (value) => setState(() => filter = value),
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          const Panel(child: Text('No orders match this filter.')),
        for (final order in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${order.id} • ${order.batchId}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      StatusPill(_label(order.status)),
                    ],
                  ),
                  const Divider(height: 18, color: line),
                  KeyValueRow('Customer', order.customer.name),
                  const Divider(height: 1, color: line),
                  KeyValueRow('Product', order.product.title),
                  const Divider(height: 1, color: line),
                  KeyValueRow('Wholesale', '৳${order.wholesalePrice}'),
                  const Divider(height: 1, color: line),
                  KeyValueRow('Retail', '৳${order.retailPrice}'),
                  const Divider(height: 1, color: line),
                  KeyValueRow('Assignment', order.reseller.name),
                  const Divider(height: 1, color: line),
                  KeyValueRow(
                    'Payment status',
                    order.paymentStatus == DemoPaymentStatus.simulated
                        ? 'DEMO • Not verified'
                        : 'Unpaid',
                    valueColor: orange,
                  ),
                  const Divider(height: 1, color: line),
                  KeyValueRow('Transfer number', '${order.transferNumber}'),
                  const Divider(height: 1, color: line),
                  KeyValueRow(
                    'Settlement',
                    demoOms.settledBatchIds.contains(order.batchId)
                        ? 'Settled • Credited'
                        : 'Pending',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: blue,
                            side: const BorderSide(color: blue),
                          ),
                          onPressed: () => _showOrderDetails(context, order),
                          child: const Text('View Details'),
                        ),
                      ),
                      if (order.status == DemoOrderStatus.pending) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: orange,
                              side: const BorderSide(color: orange),
                            ),
                            onPressed: () => _showEditDialog(context, order),
                            child: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: red,
                              side: const BorderSide(color: red),
                            ),
                            onPressed: () => _confirmCancelOrder(context, order),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class AdminBatch extends StatefulWidget {
  const AdminBatch({required this.onMessage, super.key});
  final ValueChanged<String> onMessage;

  @override
  State<AdminBatch> createState() => _AdminBatchState();
}

class _AdminBatchState extends State<AdminBatch> {
  @override
  void initState() {
    super.initState();
    // Auto-settle batch if system is ON and batch is ready to settle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (demoOms.settings.systemEnabled && demoOms.canSettleCurrentBatch) {
        try {
          demoOms.settleCurrentBatch();
          widget.onMessage('Batch ${demoOms.batches.last.id} automatically settled.');
          if (mounted) setState(() {});
        } catch (e) {
          // Ignore errors
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = demoOms.currentBatchTarget == 0
        ? 0.0
        : demoOms.batchPaidTotal / demoOms.currentBatchTarget;
    final nextTarget = DemoOmsStore.calculateNextBatchTarget(
      demoOms.currentBatchTarget,
      demoOms.settings.growthRate,
    );
    return PageBody(
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Batch ${demoOms.currentBatchId}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StatusPill(
                    demoOms.canSettleCurrentBatch
                        ? 'Target reached'
                        : 'Processing',
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                'Paid: ৳${demoOms.batchPaidTotal} / ৳${demoOms.currentBatchTarget}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(10),
                color: green,
                backgroundColor: canvas,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            children: [
              KeyValueRow('Growth rate', '${demoOms.settings.growthRate}%'),
              const Divider(height: 1, color: line),
              KeyValueRow('Next batch target', '৳$nextTarget'),
              const Divider(height: 1, color: line),
              KeyValueRow('Cycle', '${demoOms.settings.cycleHours} Hours'),
              const Divider(height: 1, color: line),
              KeyValueRow(
                'Transfer period',
                '${demoOms.settings.transferHours} Hours',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Batch Calculations & Division'),
        for (final batch in demoOms.batches.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          batch.id,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      StatusPill(
                        demoOms.settledBatchIds.contains(batch.id)
                            ? 'Settled'
                            : 'Active',
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: line),
                  KeyValueRow(
                    'Target calculation',
                    batch.previousTarget == null
                        ? 'Initial target'
                        : '৳${batch.previousTarget} × ${100 + batch.growthRate!}% → ৳${batch.target}',
                  ),
                  const Divider(height: 1, color: line),
                  KeyValueRow(
                    'Division (৳50 units)',
                    batch.division.map((amount) => '৳$amount').join(' + '),
                  ),
                  const Divider(height: 1, color: line),
                  KeyValueRow(
                    'Paid',
                    '৳${demoOms.paidTotalFor(batch.id)} / ৳${batch.target}',
                  ),
                  if (batch.division.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Target must equal consecutive ৳50 multiples, such as ৳50 + ৳100 + ৳150 + ৳200.',
                        style: TextStyle(color: red),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Settle full batch & create next',
          icon: Icons.task_alt_rounded,
          color: demoOms.canSettleCurrentBatch ? green : muted,
          onPressed: demoOms.canSettleCurrentBatch
              ? () {
                  try {
                    demoOms.settleCurrentBatch();
                    setState(() {});
                    widget.onMessage('Batch settled and wallet credited.');
                  } on StateError catch (error) {
                    widget.onMessage(error.message);
                  }
                }
              : () => widget.onMessage(
                  'Partial settlement is disabled. Confirm the full batch target first.',
                ),
        ),
      ],
    );
  }
}

class AdminWithdrawals extends StatefulWidget {
  const AdminWithdrawals({required this.onMessage, super.key});
  final ValueChanged<String> onMessage;

  @override
  State<AdminWithdrawals> createState() => _AdminWithdrawalsState();
}

class _AdminWithdrawalsState extends State<AdminWithdrawals> {
  String filter = 'All';

  String _escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';

  Future<void> _copyProcessingCsv() async {
    final processing = demoOms.withdrawals.where(
      (request) => request.status == DemoWithdrawalStatus.processing,
    );
    final rows = <String>['reference,amount,method,account,reseller'];
    for (final request in processing) {
      rows.add(
        [
          request.id,
          request.amount.toString(),
          request.method,
          request.account,
          request.reseller.name,
        ].map(_escapeCsv).join(','),
      );
    }
    try {
      await Clipboard.setData(ClipboardData(text: rows.join('\n')));
      if (!mounted) return;
      widget.onMessage(
        'Processing-request CSV copied to clipboard. No payments were sent.',
      );
    } on PlatformException catch (error) {
      if (mounted) {
        widget.onMessage(
          'Could not copy the CSV: ${error.message ?? error.code}',
        );
      }
    }
  }

  Future<void> _pasteResults() async {
    final input = TextEditingController();
    try {
      final content = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Upload disbursement result'),
          content: SizedBox(
            width: 460,
            child: TextField(
              controller: input,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'reference,status\\nWD-5001,approved',
                helperText: 'Paste result CSV rows: withdrawal reference, approved or cancelled',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input.text),
              child: const Text('Validate & record result'),
            ),
          ],
        ),
      );
      if (!mounted || content == null) return;
      final parsed = <(DemoWithdrawal, bool)>[];
      final seen = <String>{};
      final issues = <String>[];
      for (final line in content.split(RegExp(r'\r?\n'))) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.toLowerCase().startsWith('reference,')) {
          continue;
        }
        final columns = trimmed
            .split(',')
            .map((value) => value.trim())
            .toList();
        if (columns.length != 2 || !seen.add(columns[0])) {
          issues.add('Malformed or duplicate row: $trimmed');
          continue;
        }
        DemoWithdrawal? request;
        for (final candidate in demoOms.withdrawals) {
          if (candidate.id == columns[0]) {
            request = candidate;
            break;
          }
        }
        if (request == null ||
            request.status != DemoWithdrawalStatus.processing) {
          issues.add('Unknown or non-processing request: ${columns[0]}');
          continue;
        }
        final status = columns[1].toLowerCase();
        if (status != 'approved' && status != 'cancelled') {
          issues.add('Unsupported result for ${columns[0]}: ${columns[1]}');
          continue;
        }
        parsed.add((request, status == 'approved'));
      }
      if (issues.isNotEmpty || parsed.isEmpty) {
        widget.onMessage(
          issues.isEmpty
              ? 'No valid result rows were provided.'
              : issues.take(2).join(' • '),
        );
        return;
      }
      for (final result in parsed) {
        demoOms.applyDemoDisbursementResult(result.$1, approved: result.$2);
      }
      setState(() {});
      widget.onMessage(
        'Recorded ${parsed.length} result(s). Provider transactions were not verified.',
      );
    } finally {
      input.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = demoOms.withdrawals.where((request) {
      final status = switch (request.status) {
        DemoWithdrawalStatus.pending => 'Pending',
        DemoWithdrawalStatus.processing => 'Processing',
        DemoWithdrawalStatus.approved => 'Approved',
        DemoWithdrawalStatus.cancelled => 'Cancelled',
      };
      return filter == 'All' || status == filter;
    }).toList();
    return PageBody(
      children: [
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Move Pending to Processing',
            icon: Icons.forward_rounded,
            color: orange,
            onPressed: () {
              final pending = demoOms.withdrawals
                  .where((item) => item.status == DemoWithdrawalStatus.pending)
                  .length;
              demoOms.movePendingWithdrawalsToProcessing();
              setState(() {});
              widget.onMessage(
                pending == 0
                    ? 'There are no pending requests.'
                    : '$pending request(s) moved to processing.',
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        FilterChips(
          options: const [
            'All',
            'Pending',
            'Processing',
            'Approved',
            'Cancelled',
          ],
          selected: filter,
          onSelect: (value) => setState(() => filter = value),
        ),
        const SizedBox(height: 13),
        if (filtered.isEmpty)
          const Panel(child: Text('No withdrawal requests match this filter.')),
        for (final request in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.id,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      StatusPill(request.status.name),
                    ],
                  ),
                  KeyValueRow('Reseller', request.reseller.name),
                  const Divider(height: 1, color: line),
                  KeyValueRow('Amount', '৳${request.amount}'),
                  const Divider(height: 1, color: line),
                  KeyValueRow('Method', request.method),
                  const Divider(height: 1, color: line),
                  KeyValueRow('Account', request.account),
                  if (request.transactionReference != null)
                    KeyValueRow(
                      'Transaction reference',
                      request.transactionReference!,
                    ),
                  const SizedBox(height: 9),
                  OutlinedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(request.id),
                        content: Text(
                          'DEMO ONLY • ${request.reseller.name} • ৳${request.amount} via ${request.method}. No payment provider was contacted.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                          if (request.status == DemoWithdrawalStatus.pending)
                            FilledButton(
                              onPressed: () {
                                demoOms.moveWithdrawalToProcessing(request);
                                Navigator.pop(context);
                                setState(() {});
                                widget.onMessage(
                                  '${request.id} moved to processing.',
                                );
                              },
                              child: const Text('Move to Processing'),
                            ),
                          if (request.status ==
                              DemoWithdrawalStatus.processing) ...[
                            TextButton(
                              onPressed: () {
                                demoOms.applyDemoDisbursementResult(
                                  request,
                                  approved: false,
                                );
                                Navigator.pop(context);
                                setState(() {});
                                widget.onMessage(
                                  'Cancellation result recorded.',
                                );
                              },
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () {
                                demoOms.applyDemoDisbursementResult(
                                  request,
                                  approved: true,
                                );
                                Navigator.pop(context);
                                setState(() {});
                                widget.onMessage(
                                  'Approval recorded successfully.',
                                );
                              },
                              child: const Text('Approve'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    child: Text(
                      request.status == DemoWithdrawalStatus.processing
                          ? 'Record demo result'
                          : 'View request',
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),
        const SectionTitle('Disbursement', icon: Icons.account_balance_rounded),
        Panel(
          child: Column(
            children: [
              _AdminActionRow(
                icon: Icons.download_rounded,
                title: 'Copy processing CSV',
                detail: 'Copy processing requests as CSV data',
                onTap: _copyProcessingCsv,
              ),
              const Divider(height: 1, color: line),
              _AdminActionRow(
                icon: Icons.account_balance_rounded,
                title: 'External Disbursement',
                detail: 'Requires a verified payment-provider integration',
                onTap: () => widget.onMessage(
                  'No payment provider is connected; disbursement cannot be made.',
                ),
              ),
              const Divider(height: 1, color: line),
              _AdminActionRow(
                icon: Icons.upload_file_rounded,
                title: 'Paste result CSV',
                detail: 'Validate and record processing results',
                onTap: _pasteResults,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            children: [
              KeyValueRow(
                'Processing',
                '${demoOms.withdrawals.where((item) => item.status == DemoWithdrawalStatus.processing).length}',
                valueColor: blue,
              ),
              const Divider(height: 1, color: line),
              KeyValueRow(
                'Approved',
                '${demoOms.withdrawals.where((item) => item.status == DemoWithdrawalStatus.approved).length}',
                valueColor: green,
              ),
              const Divider(height: 1, color: line),
              KeyValueRow(
                'Cancelled',
                '${demoOms.withdrawals.where((item) => item.status == DemoWithdrawalStatus.cancelled).length}',
                valueColor: red,
              ),
              const Divider(height: 1, color: line),
              const KeyValueRow(
                'Duplicate protected',
                'Yes',
                valueColor: green,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminActionRow extends StatelessWidget {
  const _AdminActionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: brand),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(detail),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class AdminWallet extends StatelessWidget {
  const AdminWallet({super.key});

  @override
  Widget build(BuildContext context) {
    final withdrawn = demoOms.withdrawals
        .where((request) => request.status == DemoWithdrawalStatus.approved)
        .fold(0, (total, request) => total + request.amount);
    final payment = demoOms.resellerCapital + demoOms.resellerProfit;
    return PageBody(
      children: [
        MetricCard(
          label: 'Payment',
          value: '৳$payment',
          color: blue,
          icon: Icons.south_rounded,
        ),
        const SizedBox(height: 12),
        MetricCard(
          label: 'Withdraw',
          value: '৳$withdrawn',
          color: red,
          icon: Icons.north_rounded,
        ),
        const SizedBox(height: 12),
        MetricCard(
          label: 'Current Balance',
          value: '৳${demoOms.totalWalletBalance}',
          color: brand,
          icon: Icons.account_balance_wallet_rounded,
        ),
        SizedBox(height: 20),
        SectionTitle('Transaction History', icon: Icons.history_rounded),
        if (demoOms.walletEntries.isEmpty && demoOms.withdrawals.isEmpty)
          const Panel(child: Text('No wallet transactions yet.'))
        else
          Panel(
            child: Column(
              children: [
                for (final entry in demoOms.walletEntries.reversed) ...[
                  KeyValueRow(
                    '${entry.reference} • ${entry.orderId} • ${entry.reseller.name}',
                    '+৳${entry.capital + entry.profit} (৳${entry.capital} + ৳${entry.profit})',
                    valueColor: green,
                  ),
                  const Divider(height: 1, color: line),
                ],
                for (final request in demoOms.withdrawals.where(
                  (request) => request.status == DemoWithdrawalStatus.approved,
                ))
                  KeyValueRow(
                    '${request.id} • ${request.reseller.name}',
                    '-৳${request.amount}',
                    valueColor: red,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class AdminSettings extends StatefulWidget {
  const AdminSettings({required this.auth, required this.onSignOut, super.key});

  final AdminAuthService auth;
  final VoidCallback onSignOut;

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  late final TextEditingController target = TextEditingController(
    text: '${demoOms.settings.initialBatchTarget}',
  );
  late final TextEditingController cycle = TextEditingController(
    text: '${demoOms.settings.cycleHours}',
  );
  late final TextEditingController transfer = TextEditingController(
    text: '${demoOms.settings.transferHours}',
  );
  late bool enabled = demoOms.settings.systemEnabled;
  late String profit = '${demoOms.settings.profitRate}%';
  late String growth = '${demoOms.settings.growthRate}%';

  void _showAccountError(Object error) {
    final message = switch (error) {
      FirebaseAuthException(:final message, :final code) => message ?? code,
      StateError(:final message) => message,
      _ => error.toString(),
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeAdminEmail() async {
    var currentPassword = '';
    var newEmail = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change admin email'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (value) => (value?.isEmpty ?? true)
                    ? 'Enter your current password.'
                    : null,
                onSaved: (value) => currentPassword = value ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'New email'),
                validator: (value) => (value?.trim().contains('@') ?? false)
                    ? null
                    : 'Enter a valid email address.',
                onSaved: (value) => newEmail = value?.trim() ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              Navigator.pop(context, true);
            },
            child: const Text('Send verification'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.auth.sendEmailChangeVerification(
        currentPassword: currentPassword,
        newEmail: newEmail,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email verification sent to $newEmail. The address changes after verification.',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showAccountError(error);
    } on StateError catch (error) {
      if (mounted) _showAccountError(error);
    }
  }

  Future<void> _changeAdminPassword() async {
    var currentPassword = '';
    var newPassword = '';
    var newPasswordInput = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change admin password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (value) => (value?.isEmpty ?? true)
                    ? 'Enter your current password.'
                    : null,
                onSaved: (value) => currentPassword = value ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) => (value?.length ?? 0) >= 6
                    ? null
                    : 'Password must be at least 6 characters.',
                onChanged: (value) => newPasswordInput = value,
                onSaved: (value) => newPassword = value ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (value) => value == newPasswordInput
                    ? null
                    : 'Passwords do not match.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              Navigator.pop(context, true);
            },
            child: const Text('Update password'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin password updated.')),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showAccountError(error);
    } on StateError catch (error) {
      if (mounted) _showAccountError(error);
    }
  }

  @override
  void dispose() {
    target.dispose();
    cycle.dispose();
    transfer.dispose();
    super.dispose();
  }

  Future<void> _confirmSystemReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset system data?'),
        content: const Text(
          'This clears all data currently held in this app and restores the initial customers, products, resellers, batches, wallet transactions, and settings. Server data is not connected or affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset System'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    demoOms.resetSystem();
    target.text = '${demoOms.settings.initialBatchTarget}';
    cycle.text = '${demoOms.settings.cycleHours}';
    transfer.text = '${demoOms.settings.transferHours}';
    setState(() {
      enabled = demoOms.settings.systemEnabled;
      profit = '${demoOms.settings.profitRate}%';
      growth = '${demoOms.settings.growthRate}%';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('System data and settings were reset.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextTarget = DemoOmsStore.calculateNextBatchTarget(
      demoOms.currentBatchTarget,
      int.parse(growth.replaceAll('%', '')),
    );
    return PageBody(
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                'Admin Account',
                icon: Icons.admin_panel_settings_rounded,
              ),
              KeyValueRow(
                'Email address',
                widget.auth.currentEmail ?? 'Not signed in',
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _changeAdminEmail,
                  icon: const Icon(Icons.alternate_email_rounded),
                  label: const Text('Change Email Address'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _changeAdminPassword,
                  icon: const Icon(Icons.lock_reset_rounded),
                  label: const Text('Change Password'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                'System Settings',
                icon: Icons.settings_rounded,
              ),
              Material(
                color: Colors.white,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('System Status'),
                  subtitle: Text(enabled ? 'System is ON' : 'System is OFF'),
                  value: enabled,
                  activeThumbColor: brand,
                  onChanged: (value) => setState(() => enabled = value),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: profit,
                decoration: const InputDecoration(labelText: 'Profit Rate'),
                items: const [
                  DropdownMenuItem(value: '20%', child: Text('20%')),
                  DropdownMenuItem(value: '30%', child: Text('30%')),
                  DropdownMenuItem(value: '40%', child: Text('40%')),
                ],
                onChanged: (value) => setState(() => profit = value ?? '30%'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: target,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Initial Batch Target Amount',
                  hintText: '500',
                  helperText: 'Target must match a progressive ৳50 division (e.g. ৳500 = ৳50 + ৳100 + ৳150 + ৳200).',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: growth,
                decoration: const InputDecoration(
                  labelText: 'Batch Growth Rate',
                ),
                items: const [
                  DropdownMenuItem(value: '30%', child: Text('30%')),
                  DropdownMenuItem(value: '40%', child: Text('40%')),
                  DropdownMenuItem(value: '50%', child: Text('50%')),
                ],
                onChanged: (value) => setState(() => growth = value ?? '50%'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cycle,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Batch Cycle Period (Hours)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: transfer,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Transfer Period (Hours)',
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Save Settings',
                icon: Icons.save_rounded,
                onPressed: () {
                  final targetAmount = int.tryParse(target.text.trim());
                  final cycleHours = int.tryParse(cycle.text.trim());
                  final transferHours = int.tryParse(transfer.text.trim());
                  if (targetAmount == null ||
                      targetAmount <= 0 ||
                      DemoOmsStore.divideTarget(targetAmount).isEmpty ||
                      cycleHours == null ||
                      cycleHours <= 0 ||
                      transferHours == null ||
                      transferHours <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter a valid progressive ৳50 batch target (for example ৳500), and positive whole-number hours.',
                        ),
                      ),
                    );
                    return;
                  }
                  try {
                    if (demoOms.currentBatchId == 'B-001' &&
                        demoOms.batchPaidTotal == 0 &&
                        targetAmount != demoOms.currentBatchTarget) {
                      demoOms.reconfigureInitialBatch(targetAmount);
                    } else {
                      demoOms.settings.initialBatchTarget = targetAmount;
                    }
                    demoOms.updateProfitRate(
                      int.parse(profit.replaceAll('%', '')),
                    );
                  } on StateError catch (error) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                    return;
                  }
                  demoOms.settings
                    ..systemEnabled = enabled
                    ..growthRate = int.parse(growth.replaceAll('%', ''))
                    ..cycleHours = cycleHours
                    ..transferHours = transferHours;
                  demoOms.auditLog.insert(
                    0,
                    'Settings saved: system ${enabled ? 'on' : 'off'}, profit ${demoOms.settings.profitRate}%, growth ${demoOms.settings.growthRate}%.',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Settings saved. Existing batch target is unchanged; product retail prices use the updated profit rate.',
                      ),
                    ),
                  );
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmSystemReset,
                  icon: const Icon(Icons.restart_alt_rounded, color: red),
                  label: const Text(
                    'Reset System',
                    style: TextStyle(color: red),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionTitle('Current Batch Rules'),
        Panel(
          child: Column(
            children: [
              KeyValueRow('Growth Options', '30 / 40 / 50%'),
              const Divider(height: 1, color: line),
              const KeyValueRow('Division Unit', '৳50'),
              const Divider(height: 1, color: line),
              KeyValueRow('Cycle', '${demoOms.settings.cycleHours} Hours'),
              const Divider(height: 1, color: line),
              KeyValueRow('Transfer', '${demoOms.settings.transferHours} Hours'),
              const Divider(height: 1, color: line),
              KeyValueRow(
                'Next target estimate',
                '৳$nextTarget',
                valueColor: brand,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

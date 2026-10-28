import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bechakena_hub/admin_auth.dart';
import 'package:bechakena_hub/main.dart';
import 'package:bechakena_hub/oms_demo.dart';

class FakeAdminAuthService implements AdminAuthService {
  @override
  String? currentEmail = 'admin@bkh.example';
  bool authorized = true;
  String? changedEmail;
  String? changedPassword;

  @override
  Future<bool> get hasAdminAccess async => authorized;

  @override
  Future<void> signIn(String email, String password) async {
    if (email == 'admin@bkh.example' && password == 'password123') {
      authorized = true;
      currentEmail = email;
      return;
    }
    throw StateError('Invalid administrator credentials.');
  }

  @override
  Future<void> signOut() async {
    authorized = false;
    currentEmail = null;
  }

  @override
  Future<void> sendEmailChangeVerification({
    required String currentPassword,
    required String newEmail,
  }) async {
    changedEmail = newEmail;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changedPassword = newPassword;
  }
}

void main() {
  testWidgets('role picker opens the reseller workspace', (tester) async {
    await tester.pumpWidget(const BechaKenaHubApp());

    expect(find.text('BKH Business Manager'), findsOneWidget);
    expect(find.text('Reseller'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);

    await tester.tap(find.text('Reseller'));
    await tester.pumpAndSettle();

    expect(find.text('Order Overview'), findsOneWidget);
    expect(find.text('Hello, Reseller!'), findsOneWidget);
    expect(find.textContaining('DEMO DATA'), findsNothing);

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Sample orders from all reseller accounts'),
      findsNothing,
    );

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('DEMO WALLET'), findsNothing);
  });

  testWidgets('About Us shows the licensed business information', (
    tester,
  ) async {
    await tester.pumpWidget(const BechaKenaHubApp());

    await tester.tap(find.text('About Us'));
    await tester.pumpAndSettle();
    expect(find.text('M/S Riyad Medicine Corner'), findsOneWidget);
    expect(find.text('TRAD/BCC/22794/2025'), findsOneWidget);
    expect(find.text('Sadar Road, Barishal (Ward No: 19)'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reseller'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    final drawerList = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    );
    await tester.drag(drawerList, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Us'));
    await tester.pumpAndSettle();

    expect(find.text('M/S Riyad Medicine Corner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reseller catalog opens details for the selected product', (
    tester,
  ) async {
    await tester.pumpWidget(const BechaKenaHubApp());
    await tester.tap(find.text('Reseller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Details').first);
    await tester.pumpAndSettle();

    expect(find.text('Product Details'), findsOneWidget);
    expect(find.text('Type-C Fast Charging Cable'), findsWidgets);
    expect(find.text('Order Details'), findsNothing);
  });

  testWidgets('reseller order View Details opens the selected order page', (
    tester,
  ) async {
    await tester.pumpWidget(const BechaKenaHubApp());
    await tester.tap(find.text('Reseller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    final viewDetails = find.text('View Details').first;
    await tester.ensureVisible(viewDetails);
    await tester.tap(viewDetails);
    await tester.pumpAndSettle();

    expect(find.text('Reseller Order Details'), findsOneWidget);
    expect(find.text('Customer Details'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Order Management'), findsOneWidget);
    expect(find.text('View Details'), findsWidgets);
  });

  testWidgets('reseller wallet shows one fitted total balance summary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BechaKenaHubApp());
    await tester.tap(find.text('Reseller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Capital'), findsOneWidget);
    expect(find.text('Profit'), findsOneWidget);
    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Available to withdraw'), findsOneWidget);
    expect(find.text('Total wallet balance'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administrator workspace requires Firebase account sign-in', (
    tester,
  ) async {
    final auth = FakeAdminAuthService()..authorized = false;
    await tester.pumpWidget(BechaKenaHubApp(adminAuth: auth));
    await tester.tap(find.text('Administrator'));
    await tester.pumpAndSettle();

    expect(find.text('Administrator Sign In'), findsNWidgets(2));
    expect(find.text('Platform Overview'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'admin@bkh.example');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Platform Overview'), findsOneWidget);
  });

  testWidgets('admin navigation opens management sections', (tester) async {
    await tester.pumpWidget(BechaKenaHubApp(adminAuth: FakeAdminAuthService()));

    await tester.tap(find.text('Administrator'));
    await tester.pumpAndSettle();
    expect(find.text('Platform Overview'), findsOneWidget);
    expect(find.textContaining('DEMO DATA'), findsNothing);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    final drawerList = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    );
    await tester.drag(drawerList, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdrawal & Disbursement'));
    await tester.pumpAndSettle();

    expect(find.text('Withdrawal & Disbursement'), findsOneWidget);
    expect(find.text('Move Pending to Processing'), findsOneWidget);
    expect(find.text('Copy processing CSV'), findsOneWidget);
    expect(find.text('Disbursement'), findsOneWidget);
    expect(
      find.text('No withdrawal requests match this filter.'),
      findsOneWidget,
    );
  });

  testWidgets('admin products accepts free-form categories and Excel import', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BechaKenaHubApp(adminAuth: FakeAdminAuthService()));
    await tester.tap(find.text('Administrator'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Product Management'));
    await tester.pumpAndSettle();

    expect(find.text('Add Product'), findsWidgets);
    expect(find.text('Upload Excel'), findsOneWidget);
    expect(find.text('Get Template'), findsOneWidget);
    expect(find.textContaining('Excel: category, title'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Upload Excel'),
        matching: find.byType(Panel),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Select product CSV'), findsNothing);

    final categoryField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Product Category',
    );
    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Title',
    );
    expect(categoryField, findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(titleField, findsOneWidget);
    expect(
      tester.getTopLeft(categoryField).dy,
      lessThan(tester.getTopLeft(titleField).dy),
    );

    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    final editCategory = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Product Category',
      ),
    );
    final editTitle = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Title',
      ),
    );
    await tester.enterText(editCategory, 'Specialty');
    await tester.enterText(editTitle, 'Edited demo cable');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Edited demo cable'), findsOneWidget);
    expect(find.textContaining('Specialty'), findsOneWidget);

    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    expect(find.text('Delete product?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edited demo cable'), findsNothing);
  });

  testWidgets('admin customers exposes Excel bulk upload', (tester) async {
    await tester.pumpWidget(BechaKenaHubApp(adminAuth: FakeAdminAuthService()));
    await tester.tap(find.text('Administrator'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer Management'));
    await tester.pumpAndSettle();

    expect(find.text('Add Customer'), findsWidgets);
    expect(find.text('Upload Excel'), findsOneWidget);
    expect(find.text('Get Template'), findsOneWidget);
    expect(find.textContaining('Excel: name, mobile_number'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Upload Excel'),
        matching: find.byType(Panel),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Select customer CSV'), findsNothing);
  });

  testWidgets('admin reseller management shows order and wallet breakdowns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BechaKenaHubApp(adminAuth: FakeAdminAuthService()));
    await tester.tap(find.text('Administrator'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    final drawerScrollable = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    );
    await tester.drag(drawerScrollable, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reseller Management'));
    await tester.pumpAndSettle();

    expect(find.text('Rahim Store'), findsOneWidget);
    expect(find.text('Orders'), findsNWidgets(3));
    expect(find.text('Pending'), findsNWidgets(3));
    expect(find.text('Processing'), findsNWidgets(3));
    expect(find.text('Delivered'), findsNWidgets(3));
    expect(find.text('Cancelled'), findsNWidgets(3));
    expect(find.text('Wallet'), findsNWidgets(3));
    expect(find.text('Capital'), findsNWidgets(3));
    expect(find.text('Profit'), findsNWidgets(3));
    expect(find.text('Current Balance'), findsNWidgets(3));
    expect(find.text('Withdraw'), findsNWidgets(3));
  });

  testWidgets('batch page shows calculations while orders show assignments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    demoOms.resetSystem();
    await tester.pumpWidget(BechaKenaHubApp(adminAuth: FakeAdminAuthService()));
    await tester.tap(find.text('Administrator'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batch Management'));
    await tester.pumpAndSettle();
    expect(find.text('Batch Calculations & Division'), findsOneWidget);
    expect(find.text('৳50 + ৳100 + ৳150 + ৳200'), findsOneWidget);
    expect(find.text('Assignment'), findsNothing);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order Management').last);
    await tester.pumpAndSettle();
    expect(find.text('Batch'), findsNWidgets(2));
    expect(find.text('Assignment'), findsNWidgets(4));
    expect(find.text('Transfer number'), findsNWidgets(4));
    expect(find.text('Settlement'), findsNWidgets(5));
  });

  testWidgets('admin wallet summaries and reset confirmation are available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    demoOms.resetSystem();
    demoOms.products.removeAt(0);
    final auth = FakeAdminAuthService();
    await tester.pumpWidget(BechaKenaHubApp(adminAuth: auth));
    await tester.tap(find.text('Administrator'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);
    expect(find.text('Current Balance'), findsOneWidget);
    expect(find.text('Transaction History'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Admin Account'), findsOneWidget);
    expect(find.text('admin@bkh.example'), findsOneWidget);
    expect(find.text('Change Email Address'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);

    await tester.tap(find.text('Change Email Address'));
    await tester.pumpAndSettle();
    final emailDialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(emailDialogFields.first, 'currentPass');
    await tester.enterText(emailDialogFields.last, 'new-admin@bkh.example');
    await tester.tap(find.text('Send verification'));
    await tester.pumpAndSettle();
    expect(auth.changedEmail, 'new-admin@bkh.example');
    expect(
      find.textContaining('The address changes after verification'),
      findsOneWidget,
    );

    await tester.tap(find.text('Change Password'));
    await tester.pumpAndSettle();
    final passwordDialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(passwordDialogFields.at(0), 'currentPass');
    await tester.enterText(passwordDialogFields.at(1), 'newPassword123');
    await tester.enterText(passwordDialogFields.at(2), 'newPassword123');
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(auth.changedPassword, 'newPassword123');
    expect(find.byType(AlertDialog), findsNothing);

    expect(find.text('Reset System'), findsOneWidget);
    await tester.tap(find.text('Reset System'));
    await tester.pumpAndSettle();
    expect(find.text('Reset system data?'), findsOneWidget);
    expect(find.textContaining('Server data is not connected'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Reset System'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      demoOms.products.any(
        (product) => product.title == 'Type-C Fast Charging Cable',
      ),
      isTrue,
    );
  });
}

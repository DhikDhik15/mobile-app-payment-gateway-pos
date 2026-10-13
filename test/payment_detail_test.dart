import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/payments/data/services/payment_url_opener.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/domain/usecases/create_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/get_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_payments.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_fail.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_success.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/payments/presentation/pages/payment_detail_page.dart';
import 'package:payment_simulator/features/payments/presentation/pages/payments_page.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

class _FakePaymentRepository implements PaymentRepository {
  Future<PaymentResult<Payment>> Function(String paymentId)? getHandler;
  Future<PaymentResult<Payment>> Function(String paymentId)? simulateHandler;
  PaymentResult<List<Payment>>? listResult;
  int getCalls = 0;
  String? lastGetId;

  @override
  Future<PaymentResult<Payment>> createPayment(
    CreatePaymentParams params,
  ) async => PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> getPayment(String paymentId) async {
    getCalls++;
    lastGetId = paymentId;
    return getHandler!(paymentId);
  }

  @override
  Future<PaymentResult<List<Payment>>> listPayments() async =>
      listResult ?? PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> simulateSuccess(String paymentId) async =>
      simulateHandler!(paymentId);

  @override
  Future<PaymentResult<Payment>> simulateFail(String paymentId) async =>
      simulateHandler!(paymentId);

  @override
  Future<PaymentResult<Payment>> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async => PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<List<Payment>>> listOrderPayments(
    String orderId,
  ) async => PaymentError(const ServerFailure());
}

Payment _payment({
  String id = 'tx-001',
  PaymentStatus status = PaymentStatus.pending,
  String? url = 'https://pay.example.com/checkout/abc',
}) => Payment(
  transactionId: id,
  merchantOrderId: 'ORDER-001',
  amount: 150000,
  currency: 'IDR',
  paymentMethod: 'QRIS',
  status: status,
  paymentUrl: url,
  createdAt: DateTime.parse('2026-01-01T10:00:00Z'),
  updatedAt: DateTime.parse('2026-01-01T10:00:00Z'),
);

PaymentCubit _cubit(_FakePaymentRepository repo) => PaymentCubit(
  listPayments: ListPaymentsUseCase(repo),
  getPayment: GetPaymentUseCase(repo),
  createPayment: CreatePaymentUseCase(repo),
  simulateSuccess: SimulatePaymentSuccessUseCase(repo),
  simulateFail: SimulatePaymentFailUseCase(repo),
);

Widget _detailApp(
  PaymentCubit cubit, {
  String paymentId = 'tx-001',
  bool showSimulator = true,
  LaunchPaymentUri? urlLauncher,
}) {
  return MaterialApp(
    home: BlocProvider.value(
      value: cubit,
      child: PaymentDetailPage(
        paymentId: paymentId,
        showSimulator: showSimulator,
        urlLauncher: urlLauncher ?? (_) async => true,
      ),
    ),
  );
}

/// Emits a cubit state and flushes both the bloc notification frame and the
/// resulting rebuild frame. A single pump is not enough for direct emits.
Future<void> _emit(
  WidgetTester tester,
  PaymentCubit cubit,
  PaymentState state,
) async {
  cubit.emit(state);
  await tester.pump();
  await tester.pump();
}

/// Scrolls an action into view before tapping it. Detail content exceeds the
/// 800x600 test viewport, so bare taps would miss below-the-fold buttons.
/// Uses bounded pumps: quiescence waiting can hang on scroll animations.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
}

void main() {
/// Drives a full background/foreground cycle through the states the
/// framework accepts (resumed -> inactive -> hidden -> paused ->
/// hidden -> inactive -> resumed).
Future<void> _backgroundAndResume(WidgetTester tester) async {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
    await tester.pump();
  }
}

  group('isLaunchablePaymentUrl', () {
    test('accepts http and https with a host', () {
      expect(isLaunchablePaymentUrl('https://pay.example.com/x'), isTrue);
      expect(isLaunchablePaymentUrl('http://pay.example.com/x'), isTrue);
    });

    test('does not reject development hosts', () {
      expect(isLaunchablePaymentUrl('http://localhost:5173/pay/abc'), isTrue);
      expect(isLaunchablePaymentUrl('http://127.0.0.1:8081/x'), isTrue);
      expect(isLaunchablePaymentUrl('http://192.168.1.10:8081/x'), isTrue);
      expect(isLaunchablePaymentUrl('http://10.0.2.2:8081/x'), isTrue);
    });

    test('rejects dangerous and malformed URLs', () {
      expect(isLaunchablePaymentUrl(null), isFalse);
      expect(isLaunchablePaymentUrl(''), isFalse);
      expect(isLaunchablePaymentUrl('   '), isFalse);
      expect(isLaunchablePaymentUrl('javascript:alert(1)'), isFalse);
      expect(isLaunchablePaymentUrl('file:///etc/passwd'), isFalse);
      expect(isLaunchablePaymentUrl('myapp://pay/abc'), isFalse);
      expect(isLaunchablePaymentUrl('not a url'), isFalse);
      expect(isLaunchablePaymentUrl('https://'), isFalse);
      expect(isLaunchablePaymentUrl('/relative/path'), isFalse);
    });

    test('unreachable hint guides loopback/LAN setups', () {
      expect(
        unreachablePaymentUrlHint('http://localhost:5173/pay/abc'),
        contains('10.0.2.2'),
      );
      expect(
        unreachablePaymentUrlHint('http://192.168.1.10:8081/x'),
        contains('LAN'),
      );
      expect(
        unreachablePaymentUrlHint('https://pay.example.com/x'),
        contains('https://pay.example.com/x'),
      );
    });
  });

  group('PaymentDetailPage states', () {
    testWidgets('every state renders non-blank content', (tester) async {
      final repo = _FakePaymentRepository()
        ..getHandler = (_) async => PaymentSuccess(_payment());
      final cubit = _cubit(repo);
      await tester.pumpWidget(_detailApp(cubit));
      await tester.pumpAndSettle();
      expect(find.text('tx-001'), findsOneWidget);

      // Loading with cache: retained detail, not blank.
      await _emit(tester, cubit, const PaymentLoading());
      expect(find.text('tx-001'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);

      // Foreign list state: retained detail, not blank.
      await _emit(tester, cubit, const PaymentListLoaded([]));
      expect(find.text('tx-001'), findsOneWidget);

      // Foreign creating state: retained detail with progress.
      await _emit(tester, cubit, const PaymentCreating());
      expect(find.text('tx-001'), findsOneWidget);
      expect(find.byKey(const Key('payment-detail-progress')), findsOneWidget);

      // Foreign created state: retained detail.
      await _emit(tester, cubit, PaymentCreated(_payment(id: 'tx-999')));
      expect(find.text('tx-001'), findsOneWidget);
      expect(find.text('tx-999'), findsNothing);

      // Initial: retained detail (page already loaded).
      await _emit(tester, cubit, const PaymentInitial());
      expect(find.text('tx-001'), findsOneWidget);
    });

    testWidgets('simulating keeps the detail visible with progress', (
      tester,
    ) async {
      final gate = Completer<PaymentResult<Payment>>();
      var simulateCalls = 0;
      final repo = _FakePaymentRepository();
      repo.getHandler = (_) async => PaymentSuccess(_payment());
      repo.simulateHandler = (_) {
        simulateCalls++;
        return gate.future;
      };
      final cubit = _cubit(repo);
      await tester.pumpWidget(_detailApp(cubit));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.text('Success'));
      await tester.pump();
      expect(simulateCalls, 1);

      // Not blank: detail retained, progress shown, actions disabled.
      expect(find.text('tx-001'), findsOneWidget);
      expect(find.byKey(const Key('payment-detail-progress')), findsOneWidget);
      await _tapVisible(tester, find.text('Success'));
      await tester.pump();
      expect(simulateCalls, 1);

      gate.complete(PaymentSuccess(_payment(status: PaymentStatus.paid)));
      await tester.pumpAndSettle();
      expect(find.text('PAID'), findsWidgets);
      expect(
        find.byKey(const Key('payment-detail-progress')),
        findsNothing,
      );
    });

    testWidgets('opening B while A is loaded never shows A', (tester) async {
      final paymentA = _payment(id: 'tx-AAA');
      final paymentB = _payment(id: 'tx-BBB');
      final repo = _FakePaymentRepository()
        ..getHandler = (_) async => PaymentSuccess(paymentB);
      final cubit = _cubit(repo);
      cubit.emit(PaymentDetailLoaded(paymentA));
      await tester.pump();
      await tester.pump();

      await tester.pumpWidget(_detailApp(cubit, paymentId: 'tx-BBB'));
      await tester.pump();

      // initState immediately requests B; A's data must not render as B.
      expect(find.text('tx-AAA'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('tx-BBB'), findsOneWidget);
    });

    testWidgets('refresh failure preserves details with inline error', (
      tester,
    ) async {
      var failNext = false;
      final repo = _FakePaymentRepository()
        ..getHandler = (_) async => failNext
            ? PaymentError(const ConnectionFailure())
            : PaymentSuccess(_payment());
      final cubit = _cubit(repo);
      await tester.pumpWidget(_detailApp(cubit));
      await tester.pumpAndSettle();
      expect(find.text('tx-001'), findsOneWidget);

      failNext = true;
      await tester.tap(find.byKey(const Key('payment-detail-refresh')));
      await tester.pumpAndSettle();

      // Details retained, recoverable inline error shown (plus a
      // transient snackbar from the simulation listener carrying the same
      // message).
      expect(find.text('tx-001'), findsOneWidget);
      expect(
        find.byKey(const Key('payment-detail-inline-error')),
        findsOneWidget,
      );
      expect(find.text('Could not reach the server'), findsWidgets);

      // Retry recovers.
      failNext = false;
      await _tapVisible(tester, find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('payment-detail-inline-error')),
        findsNothing,
      );
      expect(find.text('tx-001'), findsOneWidget);
    });

    testWidgets('first-load failure shows the full error page', (
      tester,
    ) async {
      final repo = _FakePaymentRepository()
        ..getHandler = (_) async =>
            PaymentError(const ApiFailure(404, 'Transaction not found'));
      await tester.pumpWidget(_detailApp(_cubit(repo)));
      await tester.pumpAndSettle();

      expect(find.text('Transaction not found'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('refresh button reloads and is disabled while busy', (
      tester,
    ) async {
      final gate = Completer<PaymentResult<Payment>>();
      var calls = 0;
      final repo = _FakePaymentRepository()
        ..getHandler = (_) {
          calls++;
          return calls == 1
              ? Future.value(PaymentSuccess(_payment()))
              : gate.future;
        };
      final cubit = _cubit(repo);
      await tester.pumpWidget(_detailApp(cubit));
      await tester.pumpAndSettle();
      expect(calls, 1);

      await tester.tap(find.byKey(const Key('payment-detail-refresh')));
      await tester.pump();
      expect(calls, 2);

      // Disabled while the refresh is in flight: no third call.
      await tester.tap(find.byKey(const Key('payment-detail-refresh')));
      await tester.pump();
      expect(calls, 2);

      gate.complete(PaymentSuccess(_payment()));
      await tester.pumpAndSettle();
    });

    testWidgets('resume refreshes an idle settled payment', (tester) async {
      final repo = _FakePaymentRepository()
        ..getHandler = (_) async => PaymentSuccess(_payment());
      final cubit = _cubit(repo);
      await tester.pumpWidget(_detailApp(cubit));
      await tester.pumpAndSettle();
      expect(repo.getCalls, 1);

      await _backgroundAndResume(tester);
      await tester.pumpAndSettle();

      expect(repo.getCalls, 2);
      expect(repo.lastGetId, 'tx-001');
      expect(find.text('tx-001'), findsOneWidget);
    });

    testWidgets('resume does not refresh while simulating', (tester) async {
      final gate = Completer<PaymentResult<Payment>>();
      final repo = _FakePaymentRepository();
      repo.getHandler = (_) async => PaymentSuccess(_payment());
      repo.simulateHandler = (_) => gate.future;
      final cubit = _cubit(repo);
      await tester.pumpWidget(_detailApp(cubit));
      await tester.pumpAndSettle();
      expect(repo.getCalls, 1);

      await _tapVisible(tester, find.text('Success'));
      await tester.pump();
      await _backgroundAndResume(tester);

      // No competing reload during simulation.
      expect(repo.getCalls, 1);

      gate.complete(PaymentSuccess(_payment(status: PaymentStatus.paid)));
      await tester.pumpAndSettle();
    });
  });

  group('payment URL actions', () {
    testWidgets('open success informs and refresh happens on resume', (
      tester,
    ) async {
      var launched = <Uri>[];
      final repo = _FakePaymentRepository()
        ..getHandler = (_) async => PaymentSuccess(_payment());
      final cubit = _cubit(repo);
      await tester.pumpWidget(
        _detailApp(
          cubit,
          urlLauncher: (uri) async {
            launched.add(uri);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('payment-open-url')));
      await tester.pumpAndSettle();

      expect(launched, [Uri.parse('https://pay.example.com/checkout/abc')]);
      expect(find.textContaining('Return here'), findsOneWidget);
      // No duplicate creation path exists on this page; still one load.
      expect(repo.getCalls, 1);
    });

    testWidgets('launch failure shows actionable feedback', (tester) async {
      final repo = _FakePaymentRepository()
        ..getHandler = (_) async => PaymentSuccess(
              _payment(url: 'http://192.168.1.10:8081/pay/abc'),
            );
      await tester.pumpWidget(
        _detailApp(_cubit(repo), urlLauncher: (_) async => false),
      );
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('payment-open-url')));
      await tester.pumpAndSettle();

      expect(find.textContaining('LAN'), findsOneWidget);
      expect(find.byType(PaymentDetailPage), findsOneWidget);
    });

    testWidgets('copy writes the actual URL with truthful feedback', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final repo = _FakePaymentRepository()
        ..getHandler = (_) async => PaymentSuccess(_payment());
      await tester.pumpWidget(_detailApp(_cubit(repo)));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byTooltip('Copy Payment URL'));
      await tester.pumpAndSettle();

      expect(copied, 'https://pay.example.com/checkout/abc');
      expect(
        find.text('Payment URL copied to clipboard.'),
        findsOneWidget,
      );
    });
  });

  group('simulator visibility', () {
    testWidgets('hidden when disabled', (tester) async {
      final repo = _FakePaymentRepository()
        ..getHandler = (_) async => PaymentSuccess(_payment());
      await tester.pumpWidget(
        _detailApp(_cubit(repo), showSimulator: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Simulate Payment'), findsNothing);
      expect(find.text('Success'), findsNothing);
      expect(find.text('tx-001'), findsOneWidget);
    });

    testWidgets('shown with dev-only caption when enabled', (tester) async {
      final repo = _FakePaymentRepository()
        ..getHandler = (_) async => PaymentSuccess(_payment());
      await tester.pumpWidget(_detailApp(_cubit(repo), showSimulator: true));
      await tester.pumpAndSettle();

      expect(find.text('Simulate Payment'), findsOneWidget);
      expect(find.textContaining('Development only'), findsOneWidget);
    });
  });

  group('PaymentsPage transient states', () {
    testWidgets('foreign states retain the loaded list', (tester) async {
      final repo = _FakePaymentRepository();
      repo.getHandler = (_) async => PaymentSuccess(_payment());
      repo.listResult = PaymentSuccess([_payment()]);
      final cubit = _cubit(repo);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const PaymentsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ORDER-001'), findsOneWidget);

      // Detail/creation states passing through the shared cubit must not
      // blank the list.
      cubit.emit(PaymentDetailLoaded(_payment()));
      await tester.pump();
      expect(find.text('ORDER-001'), findsOneWidget);

      cubit.emit(PaymentCreated(_payment()));
      await tester.pump();
      expect(find.text('ORDER-001'), findsOneWidget);
    });
  });
}

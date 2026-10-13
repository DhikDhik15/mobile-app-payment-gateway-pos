import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/domain/usecases/create_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/get_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_payments.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_fail.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_success.dart';

/// Cubit that manages payment state for the Payments feature.
///
/// Handles three operations:
///  * [loadPayments]    — fetches the paginated payment list;
///  * [loadPayment]     — fetches a single payment by ID;
///  * [createPayment]   — initiates a new payment.
///
/// States follow the same sealed-hierarchy convention as [AuthCubit].
class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit({
    required this._listPayments,
    required this._getPayment,
    required this._createPayment,
    required this._simulateSuccess,
    required this._simulateFail,
  })  : super(const PaymentInitial());

  final ListPaymentsUseCase _listPayments;
  final GetPaymentUseCase _getPayment;
  final CreatePaymentUseCase _createPayment;
  final SimulatePaymentSuccessUseCase _simulateSuccess;
  final SimulatePaymentFailUseCase _simulateFail;

  /// Loads the paginated payment list.
  Future<void> loadPayments() async {
    emit(const PaymentLoading());
    final result = await _listPayments(const NoParams());
    switch (result) {
      case PaymentSuccess(value: final payments):
        emit(PaymentListLoaded(payments));
      case PaymentError(failure: final failure):
        emit(PaymentFailure(failure.message, failure: failure));
    }
  }

  /// Loads a single payment by its transaction UUID.
  Future<void> loadPayment(String paymentId) async {
    emit(const PaymentLoading());
    final result = await _getPayment(GetPaymentParams(paymentId: paymentId));
    switch (result) {
      case PaymentSuccess(value: final payment):
        emit(PaymentDetailLoaded(payment));
      case PaymentError(failure: final failure):
        emit(PaymentFailure(failure.message, failure: failure));
    }
  }

  /// Creates a new payment and emits the created payment on success.
  Future<void> createPayment(CreatePaymentParams params) async {
    emit(const PaymentCreating());
    final result = await _createPayment(params);
    switch (result) {
      case PaymentSuccess(value: final payment):
        emit(PaymentCreated(payment));
      case PaymentError(failure: final failure):
        emit(PaymentFailure(failure.message, failure: failure));
    }
  }

  /// Simulates a successful payment outcome.
  Future<void> simulateSuccess(String paymentId) async {
    emit(const PaymentSimulating());
    final result = await _simulateSuccess(SimulatePaymentParams(paymentId: paymentId));
    switch (result) {
      case PaymentSuccess(value: final payment):
        emit(PaymentSimulated(payment));
      case PaymentError(failure: final failure):
        emit(PaymentFailure(failure.message, failure: failure));
    }
  }

  /// Simulates a failed payment outcome.
  Future<void> simulateFail(String paymentId) async {
    emit(const PaymentSimulating());
    final result = await _simulateFail(SimulatePaymentParams(paymentId: paymentId));
    switch (result) {
      case PaymentSuccess(value: final payment):
        emit(PaymentSimulated(payment));
      case PaymentError(failure: final failure):
        emit(PaymentFailure(failure.message, failure: failure));
    }
  }

  /// Creates a payment scoped to an existing order.
  ///
  /// This uses the order-scoped payment initiation endpoint which derives
  /// amount/currency/merchant/merchant_order_id from the order server-side.
  /// [idempotencyKey] must be stable per payment attempt (e.g.
  /// `order:{orderId}:qris:v1`, with `:retry:{n}` suffixes for retries after
  /// observed failures) to prevent duplicate creations on retries. The
  /// backend replays the stored result per key, so a fresh attempt key is
  /// required to start a new attempt after a FAILED/CANCELLED/EXPIRED one;
  /// the order-level active/paid guards still forbid duplicates.
  ///
  /// Unexpected exceptions (e.g. unparseable payloads that escape the typed
  /// data-layer path) are converted to [PaymentFailure] so callers never
  /// hang in [PaymentCreating]: the checkout page clears its loading state
  /// on every emitted failure.
  Future<void> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    emit(const PaymentCreating());
    try {
      final result = await _repository.createOrderPayment(
        orderId: orderId,
        paymentMethod: paymentMethod,
        idempotencyKey: idempotencyKey,
      );
      switch (result) {
        case PaymentSuccess(value: final payment):
          emit(PaymentCreated(payment));
        case PaymentError(failure: final failure):
          emit(PaymentFailure(failure.message, failure: failure));
      }
    } catch (_) {
      const failure = UnexpectedFailure();
      emit(PaymentFailure(failure.message, failure: failure));
    }
  }

  PaymentRepository get _repository => _createPayment.repository;

  /// Exposes the shared repository so pages can build read-only use cases
  /// (such as order-payment history recovery) without duplicating clients.
  PaymentRepository get paymentRepository => _createPayment.repository;
}

/// Sealed payment state hierarchy.
sealed class PaymentState {
  const PaymentState();
}

/// Initial state — no operation has been attempted yet.
final class PaymentInitial extends PaymentState {
  const PaymentInitial();
}

/// A list or detail request is in flight.
final class PaymentLoading extends PaymentState {
  const PaymentLoading();
}

/// The payment list has been loaded successfully.
final class PaymentListLoaded extends PaymentState {
  const PaymentListLoaded(this.payments);

  final List<Payment> payments;
}

/// A single payment has been loaded successfully.
final class PaymentDetailLoaded extends PaymentState {
  const PaymentDetailLoaded(this.payment);

  final Payment payment;
}

/// A payment creation request is in flight.
final class PaymentCreating extends PaymentState {
  const PaymentCreating();
}

/// A payment was created successfully.
final class PaymentCreated extends PaymentState {
  const PaymentCreated(this.payment);

  final Payment payment;
}

/// A payment simulation request is in flight.
final class PaymentSimulating extends PaymentState {
  const PaymentSimulating();
}

/// A payment was simulated successfully.
final class PaymentSimulated extends PaymentState {
  const PaymentSimulated(this.payment);

  final Payment payment;
}

/// The last operation failed with a user-safe message.
final class PaymentFailure extends PaymentState {
  const PaymentFailure(this.message, {this.failure});

  final String message;

  /// Typed failure context for classification-driven recovery. Null for
  /// states produced before typed context existed; treat as unknown.
  final Failure? failure;
}

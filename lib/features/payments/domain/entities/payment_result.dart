import 'package:payment_simulator/core/error/failure.dart';

/// Result of a payment use case.
///
/// A sealed type so the presentation layer can exhaustively handle success
/// and failure without catching exceptions. The failure variant carries a
/// domain [Failure] whose [Failure.message] is always user-safe (never a
/// raw exception or stack trace).
sealed class PaymentResult<T> {
  const PaymentResult();
}

/// The use case succeeded.
final class PaymentSuccess<T> extends PaymentResult<T> {
  const PaymentSuccess(this.value);

  final T value;
}

/// The use case failed with a user-safe, domain-level failure.
final class PaymentError<T> extends PaymentResult<T> {
  const PaymentError(this.failure);

  final Failure failure;
}

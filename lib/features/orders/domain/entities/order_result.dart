import 'package:payment_simulator/core/error/failure.dart';

sealed class OrderResult<T> {
  const OrderResult();
}

final class OrderSuccess<T> extends OrderResult<T> {
  const OrderSuccess(this.value);

  final T value;
}

final class OrderError<T> extends OrderResult<T> {
  const OrderError(this.failure);

  final Failure failure;
}

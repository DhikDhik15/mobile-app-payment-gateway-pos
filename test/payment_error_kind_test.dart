import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_error_kind.dart';

void main() {
  group('classifyOrderPaymentError', () {
    test('definitive provider failure by code and status', () {
      expect(
        classifyOrderPaymentError(
          const ApiFailure(502, 'provider failed', 'PAYMENT_PROVIDER_ERROR'),
        ),
        PaymentErrorKind.definitiveFailure,
      );
      // Status fallback when the backend omits the code.
      expect(
        classifyOrderPaymentError(const ApiFailure(502, 'bad gateway')),
        PaymentErrorKind.definitiveFailure,
      );
    });

    test('ambiguous timeout by code, status, and client timeout', () {
      expect(
        classifyOrderPaymentError(
          const ApiFailure(504, 'timed out', 'PAYMENT_PROVIDER_TIMEOUT'),
        ),
        PaymentErrorKind.ambiguousTimeout,
      );
      expect(
        classifyOrderPaymentError(const ApiFailure(504, 'timed out')),
        PaymentErrorKind.ambiguousTimeout,
      );
      expect(
        classifyOrderPaymentError(const TimeoutFailure()),
        PaymentErrorKind.ambiguousTimeout,
      );
    });

    test('order conflict by code and status, never by message', () {
      expect(
        classifyOrderPaymentError(
          const ApiFailure(409, 'anything', 'INVALID_TRANSACTION_STATE'),
        ),
        PaymentErrorKind.orderConflict,
      );
      expect(
        classifyOrderPaymentError(const ApiFailure(409, 'conflict')),
        PaymentErrorKind.orderConflict,
      );
    });

    test('idempotency states stay distinct from conflicts', () {
      expect(
        classifyOrderPaymentError(
          const ApiFailure(409, 'x', 'IDEMPOTENCY_KEY_REUSED'),
        ),
        PaymentErrorKind.idempotencyReused,
      );
      expect(
        classifyOrderPaymentError(
          const ApiFailure(409, 'x', 'IDEMPOTENCY_REQUEST_IN_PROGRESS'),
        ),
        PaymentErrorKind.idempotencyProcessing,
      );
    });

    test('transport failures with unknown outcome', () {
      expect(
        classifyOrderPaymentError(const ConnectionFailure()),
        PaymentErrorKind.unknownOutcome,
      );
    });

    test('validation, auth, and not-found', () {
      expect(
        classifyOrderPaymentError(
          const ApiFailure(400, 'x', 'VALIDATION_ERROR'),
        ),
        PaymentErrorKind.validation,
      );
      expect(
        classifyOrderPaymentError(const ApiFailure(422, 'x')),
        PaymentErrorKind.validation,
      );
      expect(
        classifyOrderPaymentError(const ApiFailure(401, 'x')),
        PaymentErrorKind.auth,
      );
      expect(
        classifyOrderPaymentError(
          const ApiFailure(404, 'x', 'RESOURCE_NOT_FOUND'),
        ),
        PaymentErrorKind.notFound,
      );
    });

    test('unrecognized failures never advance retry state', () {
      expect(
        classifyOrderPaymentError(const ApiFailure(500, 'boom')),
        PaymentErrorKind.unknown,
      );
      expect(
        classifyOrderPaymentError(const ServerFailure()),
        PaymentErrorKind.unknown,
      );
      expect(
        classifyOrderPaymentError(const InvalidResponseFailure()),
        PaymentErrorKind.unknown,
      );
    });
  });
}

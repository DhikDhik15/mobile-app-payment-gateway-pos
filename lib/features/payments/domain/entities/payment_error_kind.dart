import 'package:payment_simulator/core/error/failure.dart';

/// Classified outcome of an order-payment request, grounded in backend error
/// codes and HTTP semantics — never in human-readable message text.
///
/// Backend reference (`pay-gate-backend`, dashboard order-payment handler):
/// - 502 `PAYMENT_PROVIDER_ERROR` — definitive provider failure; the
///   transaction was recorded as FAILED and a new attempt is permitted.
/// - 504 `PAYMENT_PROVIDER_TIMEOUT` — ambiguous outcome; the transaction may
///   still resolve. Reconcile, do not start a blind new attempt.
/// - 409 `INVALID_TRANSACTION_STATE` — the order already has an active
///   (CREATED/PENDING) or PAID payment. The backend uses one code for both;
///   consult attempt history to tell them apart.
/// - 409 `IDEMPOTENCY_KEY_REUSED` — same key, different logical request.
/// - 409 `IDEMPOTENCY_REQUEST_IN_PROGRESS` — same key still processing.
/// - 400/422 validation codes — request rejected before any payment work.
/// - 401/403 — authentication/authorization.
/// - 404 `RESOURCE_NOT_FOUND` — missing or foreign order.
enum PaymentErrorKind {
  /// Definitive terminal failure; a new logical attempt is permitted.
  definitiveFailure,

  /// Order already has an active or paid payment; recover history instead.
  orderConflict,

  /// Same key bound to a different logical request.
  idempotencyReused,

  /// Same key still processing; the outcome is unknown.
  idempotencyProcessing,

  /// Ambiguous provider outcome; reconcile the existing attempt.
  ambiguousTimeout,

  /// Transport failure with unknown server-side outcome.
  unknownOutcome,

  /// Request rejected before any payment work; safe to fix and resend.
  validation,

  /// Authentication or authorization failure.
  auth,

  /// Missing or foreign order.
  notFound,

  /// Anything else; do not advance retry state on this.
  unknown,
}

/// Classifies a domain [failure] from an order-payment request.
///
/// Prefers the stable backend error [code] when present and falls back to
/// HTTP status codes. Message text is never inspected.
PaymentErrorKind classifyOrderPaymentError(Failure failure) {
  if (failure is TimeoutFailure) return PaymentErrorKind.ambiguousTimeout;
  if (failure is ConnectionFailure) return PaymentErrorKind.unknownOutcome;
  if (failure is ApiFailure) {
    switch (failure.code) {
      case 'PAYMENT_PROVIDER_ERROR':
        return PaymentErrorKind.definitiveFailure;
      case 'PAYMENT_PROVIDER_TIMEOUT':
        return PaymentErrorKind.ambiguousTimeout;
      case 'INVALID_TRANSACTION_STATE':
        return PaymentErrorKind.orderConflict;
      case 'IDEMPOTENCY_KEY_REUSED':
        return PaymentErrorKind.idempotencyReused;
      case 'IDEMPOTENCY_REQUEST_IN_PROGRESS':
        return PaymentErrorKind.idempotencyProcessing;
      case 'VALIDATION_ERROR':
      case 'INVALID_REQUEST':
      case 'INVALID_AMOUNT':
      case 'INVALID_CURRENCY':
      case 'INVALID_PAYMENT_METHOD':
        return PaymentErrorKind.validation;
      case 'RESOURCE_NOT_FOUND':
      case 'TRANSACTION_NOT_FOUND':
        return PaymentErrorKind.notFound;
      case 'UNAUTHORIZED':
      case 'INVALID_API_KEY':
      case 'FORBIDDEN':
      case 'MERCHANT_INACTIVE':
        return PaymentErrorKind.auth;
      case null:
        break;
      default:
        break;
    }
    if (failure.statusCode == 502) return PaymentErrorKind.definitiveFailure;
    if (failure.statusCode == 504) return PaymentErrorKind.ambiguousTimeout;
    if (failure.statusCode == 409) return PaymentErrorKind.orderConflict;
    if (failure.statusCode == 400 || failure.statusCode == 422) {
      return PaymentErrorKind.validation;
    }
    if (failure.statusCode == 401 || failure.statusCode == 403) {
      return PaymentErrorKind.auth;
    }
    if (failure.statusCode == 404) return PaymentErrorKind.notFound;
  }
  return PaymentErrorKind.unknown;
}

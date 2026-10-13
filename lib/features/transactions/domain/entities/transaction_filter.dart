/// Filter criteria for the merchant's transaction history.
///
/// Every field maps to a query parameter actually supported by the backend
/// dashboard payments list endpoint (`page`, `limit`, `status`,
/// `payment_method`, `search`, `created_from`, `created_to`). Absent or
/// blank values are omitted from the request.
class TransactionFilter {
  const TransactionFilter({
    this.page = 1,
    this.limit = 20,
    this.status,
    this.paymentMethod,
    this.search,
    this.from,
    this.to,
  });

  /// Default page size, following the backend convention.
  static const int defaultLimit = 20;

  final int page;
  final int limit;

  /// Exact backend status value (`CREATED`, `PENDING`, `PAID`, `FAILED`,
  /// `EXPIRED`, `CANCELLED`), or null for all statuses.
  final String? status;

  /// Exact backend payment method (`QRIS`), or null for all methods.
  final String? paymentMethod;

  /// Free-text query using backend search semantics: exact transaction UUID,
  /// or case-insensitive partial match on `merchant_order_id` or provider
  /// transaction ID. Null or blank means no search.
  final String? search;

  /// Inclusive lower bound; sent as an RFC3339 UTC timestamp.
  final DateTime? from;

  /// Exclusive upper bound; sent as an RFC3339 UTC timestamp. The backend
  /// treats the range as the half-open interval [from, to).
  final DateTime? to;

  /// True when no filter criteria are set (plain first-page listing).
  bool get isEmpty =>
      status == null &&
      paymentMethod == null &&
      (search == null || search!.trim().isEmpty) &&
      from == null &&
      to == null;

  TransactionFilter copyWith({
    int? page,
    int? limit,
    String? Function()? status,
    String? Function()? paymentMethod,
    String? Function()? search,
    DateTime? Function()? from,
    DateTime? Function()? to,
  }) {
    return TransactionFilter(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      status: status != null ? status() : this.status,
      paymentMethod:
          paymentMethod != null ? paymentMethod() : this.paymentMethod,
      search: search != null ? search() : this.search,
      from: from != null ? from() : this.from,
      to: to != null ? to() : this.to,
    );
  }
}

/// Endpoint constants for the GO-SAAS backend.
///
/// Every constant here is taken directly from the backend's published OpenAPI
/// (swagger) specification — no endpoints are invented. Paths containing
/// `{...}` are path-parameter templates to be filled by the caller.
class ApiEndpoints {
  const ApiEndpoints._();

  // ── Health ────────────────────────────────────────────────────────────────
  static const String health = '/health';
  static const String healthReady = '/health/ready';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String login = '/api/v1/auth/login';
  static const String logout = '/api/v1/auth/logout';
  static const String me = '/api/v1/auth/me';
  static const String refresh = '/api/v1/auth/refresh';

  // ── Payments ──────────────────────────────────────────────────────────────
  static const String payments = '/api/v1/payments';
  static const String paymentById = '/api/v1/payments/{id}';
  static const String paymentCancel = '/api/v1/payments/{id}/cancel';
  static const String paymentRefunds = '/api/v1/payments/{id}/refunds';

  // ── Payment simulator ─────────────────────────────────────────────────────
  static const String simulatorPayments = '/api/v1/simulator/payments';
  static const String simulatorPaymentById =
      '/api/v1/simulator/payments/{payment_id}';
  static const String simulatorPaymentSuccess =
      '/api/v1/simulator/payments/{payment_id}/success';
  static const String simulatorPaymentFail =
      '/api/v1/simulator/payments/{payment_id}/fail';

  // ── Dashboard ─────────────────────────────────────────────────────────────
  static const String dashboardPayments = '/api/v1/dashboard/payments';
  static const String dashboardPaymentById =
      '/api/v1/dashboard/payments/{payment_id}';
  static const String dashboardOrders = '/api/v1/dashboard/orders';
  static const String dashboardOrderById =
      '/api/v1/dashboard/orders/{order_id}';
  static const String dashboardOverview = '/api/v1/dashboard/overview';
  static const String dashboardCategories = '/api/v1/dashboard/categories';
  static const String dashboardCategoryById =
      '/api/v1/dashboard/categories/{category_id}';
  static const String dashboardProducts = '/api/v1/dashboard/products';
  static const String dashboardProductById =
      '/api/v1/dashboard/products/{product_id}';
  static const String dashboardPaymentSimulateSuccess =
      '/api/v1/dashboard/payments/{payment_id}/simulate/success';
  static const String dashboardPaymentSimulateFail =
      '/api/v1/dashboard/payments/{payment_id}/simulate/fail';
  static const String dashboardOrderPayments =
      '/api/v1/dashboard/orders/{order_id}/payments';
}

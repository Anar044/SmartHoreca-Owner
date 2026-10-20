/// Lightweight, non-authoritative plausibility checks for displayed OLAP
/// financial metrics. They never modify figures returned by the server.
/// A warning is not proof of an accounting error.
class OwnerFinanceValidation {
  const OwnerFinanceValidation._();

  static bool grossProfitMatchesRevenue(Map metrics) {
    final revenue = metrics['revenue'];
    final grossProfit = metrics['grossProfit'];
    if (revenue is! num || grossProfit is! num) return false;
    if (!revenue.isFinite || !grossProfit.isFinite || revenue <= 0) {
      return false;
    }
    return (revenue - grossProfit).abs() < 0.005;
  }
}

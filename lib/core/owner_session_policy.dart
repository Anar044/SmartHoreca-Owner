/// Supabase Flutter can restore an expired access token from local iOS storage
/// before its background token refresh has finished. The refresh token remains
/// persisted and should be used instead of asking for the password again.
bool ownerSessionNeedsRenewal({
  required bool isExpired,
  required int? expiresAt,
  required int nowSeconds,
  int safetyWindowSeconds = 90,
}) {
  if (isExpired) return true;
  if (expiresAt == null) return false;
  return expiresAt <= nowSeconds + safetyWindowSeconds;
}

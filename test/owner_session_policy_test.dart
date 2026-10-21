import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_session_policy.dart';

void main() {
  test('fresh tokens remain valid without unnecessary refresh', () {
    expect(ownerSessionNeedsRenewal(
        isExpired:false,expiresAt:4600,nowSeconds:3600),false);
  });
  test('iOS cold start renews expired persisted tokens', () {
    expect(ownerSessionNeedsRenewal(
        isExpired:true,expiresAt:3500,nowSeconds:3600),true);
  });
  test('tokens close to expiry renew before dashboard and AI requests', () {
    expect(ownerSessionNeedsRenewal(
        isExpired:false,expiresAt:3660,nowSeconds:3600),true);
  });
  test('unknown expiry preserves current session unless SDK flags expiry', () {
    expect(ownerSessionNeedsRenewal(
        isExpired:false,expiresAt:null,nowSeconds:3600),false);
  });
}

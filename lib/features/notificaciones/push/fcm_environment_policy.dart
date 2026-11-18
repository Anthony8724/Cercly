import '../../../config/supabase_options.dart';

/// Promotional push remains disabled in all builds until a separate review.
class FcmEnvironmentPolicy {
  const FcmEnvironmentPolicy({
    required this.staging,
    required this.optIn,
    required this.url,
    this.productionOptIn = false,
  });

  const FcmEnvironmentPolicy.build()
    : staging = const bool.fromEnvironment('CERCLY_STAGING'),
      optIn = const bool.fromEnvironment('CERCLY_FCM_STAGING_ENABLED'),
      productionOptIn = const bool.fromEnvironment(
        'CERCLY_FCM_PRODUCTION_ENABLED',
      ),
      url = SupabaseOptions.url;

  static const stagingUrl = 'https://dlajxviqhkdcqnmczhvr.supabase.co';

  static const productionUrl = 'https://aimubazregckmjchnszf.supabase.co';

  final bool staging;
  final bool optIn;
  final bool productionOptIn;
  final String url;

  bool get enabled => false;
}

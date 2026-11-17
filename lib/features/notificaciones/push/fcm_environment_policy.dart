import '../../../config/supabase_options.dart';

/// Push is opt-in only for the explicitly configured Staging project.
class FcmEnvironmentPolicy {
  const FcmEnvironmentPolicy({
    required this.staging,
    required this.optIn,
    required this.url,
  });

  const FcmEnvironmentPolicy.build()
    : staging = const bool.fromEnvironment('CERCLY_STAGING'),
      optIn = const bool.fromEnvironment('CERCLY_FCM_STAGING_ENABLED'),
      url = SupabaseOptions.url;

  final bool staging;
  final bool optIn;
  final String url;

  bool get enabled =>
      staging && optIn && url == 'https://dlajxviqhkdcqnmczhvr.supabase.co';
}

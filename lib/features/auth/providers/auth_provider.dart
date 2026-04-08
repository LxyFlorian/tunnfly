import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/crypto/key_manager.dart';
import '../models/profile_model.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final keyManagerProvider = Provider<KeyManager>((ref) => KeyManager());

/// Watches the Supabase auth state and returns the current user.
final authStateProvider = StreamProvider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => event.session?.user);
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// Provides the current user's profile from Supabase.
final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final response = await client.from(SupabaseConstants.profilesTable).select().eq('id', user.id).maybeSingle();

  if (response == null) return null;
  return ProfileModel.fromJson(response);
});

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  SupabaseClient get _client => ref.read(supabaseClientProvider);
  KeyManager get _keyManager => ref.read(keyManagerProvider);

  Future<void> signUp({required String email, required String password, required String username}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 1. Generate E2E key pair — private key stays local, never sent to server
      final publicKeyBase64 = await _keyManager.generateAndStoreKeyPair();

      // 2. Sign up — pass username + public key as metadata so the DB trigger
      //    (handle_new_user, SECURITY DEFINER) can create the profile row.
      //    This works whether email confirmation is enabled or not.
      final response = await _client.auth.signUp(email: email, password: password, data: {'username': username, 'public_key': publicKeyBase64});

      if (response.user == null) throw Exception("L'inscription a échoué");
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signInWithPassword(email: email, password: password);

      // Load or generate key pair for this device
      String publicKey;
      if (await _keyManager.hasKeyPair()) {
        publicKey = (await _keyManager.getPublicKey())!;
      } else {
        publicKey = await _keyManager.generateAndStoreKeyPair();
      }

      // Upsert profile: creates it if missing (e.g. signed up before trigger),
      // or updates the public key for a new device. Uses SECURITY DEFINER
      // so it works even if the profiles row doesn't exist yet.
      await _client.rpc('upsert_my_profile', params: {'p_public_key': publicKey});
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _keyManager.deleteKeyPair();
      await _client.auth.signOut();
    });
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

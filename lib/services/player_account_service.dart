import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../screens/domino_player_profile.dart';
import 'player_points_service.dart';

enum PlayerAccountProvider { apple, google, email }

class PlayerAccountResult {
  const PlayerAccountResult({required this.profile, required this.recovered});

  final DominoPlayerProfile profile;
  final bool recovered;
}

class PlayerAccountService {
  PlayerAccountService._();

  static final instance = PlayerAccountService._();
  static const collection = 'kapi_player_accounts';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _googleInitialized = false;

  User? get user => _auth.currentUser;
  bool get isProtected => user != null && !user!.isAnonymous;
  String? get accountEmail => user?.email;
  bool get requiresEmailVerification {
    final current = user;
    if (current == null || current.isAnonymous) return false;
    final usesPassword = current.providerData.any(
      (item) => item.providerId == 'password',
    );
    return usesPassword && !current.emailVerified;
  }

  bool get canPurchaseCoins => isProtected && !requiresEmailVerification;

  String? get providerLabel {
    final providers = user?.providerData.map((item) => item.providerId).toSet();
    if (providers?.contains('apple.com') ?? false) return 'Apple';
    if (providers?.contains('google.com') ?? false) return 'Google';
    if (providers?.contains('password') ?? false) return 'Email';
    return null;
  }

  bool providerAvailable(PlayerAccountProvider provider) {
    if (kIsWeb) return provider != PlayerAccountProvider.apple;
    return switch (provider) {
      PlayerAccountProvider.apple =>
        defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS,
      PlayerAccountProvider.google => true,
      PlayerAccountProvider.email => true,
    };
  }

  Future<PlayerAccountResult> protectOrRecover(
    PlayerAccountProvider provider, {
    bool createIfMissing = true,
  }) async {
    final credential = switch (provider) {
      PlayerAccountProvider.apple => await _appleCredential(),
      PlayerAccountProvider.google => await _googleCredential(),
      PlayerAccountProvider.email =>
        throw UnsupportedError(
          'Use registerWithEmail or signInWithEmail for email accounts.',
        ),
    };
    final signedIn = await _auth.signInWithCredential(credential);
    final signedInUser = signedIn.user;
    if (signedInUser == null) {
      throw StateError('The store did not return a signed-in account.');
    }

    return _completeSignedInUser(
      signedInUser,
      createIfMissing: createIfMissing,
    );
  }

  Future<PlayerAccountResult> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final signedInUser = credential.user;
    if (signedInUser == null) {
      throw StateError('The store did not return a signed-in account.');
    }
    await _sendEmailVerificationIfNeeded(signedInUser);
    return _completeSignedInUser(signedInUser, createIfMissing: true);
  }

  Future<PlayerAccountResult> signInWithEmail({
    required String email,
    required String password,
    bool createIfMissing = false,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final signedInUser = credential.user;
    if (signedInUser == null) {
      throw StateError('The store did not return a signed-in account.');
    }
    await _sendEmailVerificationIfNeeded(signedInUser);
    return _completeSignedInUser(
      signedInUser,
      createIfMissing: createIfMissing,
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  Future<bool> reloadEmailVerification() async {
    await user?.reload();
    final current = _auth.currentUser;
    if (current != null && !current.isAnonymous) {
      await _db.collection(collection).doc(current.uid).set({
        'accountEmail': current.email,
        'emailVerified': current.emailVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return canPurchaseCoins;
  }

  Future<void> resendEmailVerification() async {
    final current = user;
    if (current == null || current.isAnonymous || current.emailVerified) return;
    await current.sendEmailVerification();
  }

  Future<void> _sendEmailVerificationIfNeeded(User signedInUser) async {
    if (signedInUser.emailVerified) return;
    try {
      await signedInUser.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      // Firebase rate-limits repeated verification emails. A recent email may
      // already be on its way, so this should not prevent the account login.
      if (error.code != 'too-many-requests') rethrow;
    }
  }

  Future<PlayerAccountResult> _completeSignedInUser(
    User signedInUser, {
    required bool createIfMissing,
  }) async {
    final accountRef = _db.collection(collection).doc(signedInUser.uid);
    final existing = await accountRef.get(
      const GetOptions(source: Source.server),
    );
    final recovered = DominoPlayerProfile.fromAccountMap(existing.data());
    if (recovered != null) {
      await recovered.saveLocally();
      await _refreshPublicOwnership(recovered, signedInUser.uid);
      await _syncRankingIdentity(recovered);
      await _updatePrivateAccountMetadata(signedInUser);
      return PlayerAccountResult(profile: recovered, recovered: true);
    }

    if (!createIfMissing) {
      await _auth.signOut();
      throw const PlayerAccountNotFoundException();
    }

    final local = await DominoPlayerProfile.load();
    await accountRef.set({
      ...local.toAccountMap(),
      'ownerUid': signedInUser.uid,
      'providerIds':
          signedInUser.providerData.map((item) => item.providerId).toList(),
      'accountEmail': signedInUser.email,
      'emailVerified': signedInUser.emailVerified,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _refreshPublicOwnership(local, signedInUser.uid);
    await _syncRankingIdentity(local);
    return PlayerAccountResult(profile: local, recovered: false);
  }

  Future<void> syncCurrentProfile() async {
    final currentUser = user;
    if (currentUser == null || currentUser.isAnonymous) return;
    final profile = await DominoPlayerProfile.load();
    await _db.collection(collection).doc(currentUser.uid).set({
      ...profile.toAccountMap(),
      'ownerUid': currentUser.uid,
      'providerIds':
          currentUser.providerData.map((item) => item.providerId).toList(),
      'accountEmail': currentUser.email,
      'emailVerified': currentUser.emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _refreshPublicOwnership(profile, currentUser.uid);
    await _syncRankingIdentity(profile);
  }

  /// Publishes the macOS Pro badge without changing mobile entitlements.
  Future<void> syncMacProStatus(bool active) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    final currentUser = user;
    if (currentUser == null || currentUser.isAnonymous) return;
    final profile = await DominoPlayerProfile.load();
    final changes = <String, Object>{
      'macPro': active,
      'macProUpdatedAt': FieldValue.serverTimestamp(),
    };
    await Future.wait([
      _db
          .collection(collection)
          .doc(currentUser.uid)
          .set(changes, SetOptions(merge: true)),
      _db
          .collection('kapi_lobby_profiles')
          .doc(profile.publicId)
          .set(changes, SetOptions(merge: true)),
      _db
          .collection('kapi_player_points')
          .doc(profile.code)
          .set(changes, SetOptions(merge: true)),
      _db
          .collection('kapi_ranking_seasons')
          .doc(PlayerPointsService.seasonIdFor())
          .collection('players')
          .doc(profile.code)
          .set(changes, SetOptions(merge: true)),
    ]);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialized) await GoogleSignIn.instance.signOut();
  }

  Future<void> _refreshPublicOwnership(
    DominoPlayerProfile profile,
    String uid,
  ) async {
    await _db.collection('kapi_lobby_profiles').doc(profile.publicId).set({
      ...profile.toAccountMap(),
      'ownerUid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _syncRankingIdentity(DominoPlayerProfile profile) async {
    await PlayerPointsService.ensureProfileRegistered(
      code: profile.code,
      publicId: profile.publicId,
      initials: profile.initials,
      displayName: profile.effectiveDisplayName,
      countryCode: profile.countryCode,
    );
  }

  Future<void> _updatePrivateAccountMetadata(User signedInUser) async {
    await _db.collection(collection).doc(signedInUser.uid).set({
      'ownerUid': signedInUser.uid,
      'providerIds':
          signedInUser.providerData.map((item) => item.providerId).toList(),
      'accountEmail': signedInUser.email,
      'emailVerified': signedInUser.emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<AuthCredential> _googleCredential() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final authentication = account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null) {
      throw StateError('Google did not return an identity token.');
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  Future<AuthCredential> _appleCredential() async {
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email],
      nonce: hashedNonce,
    );
    final identityToken = apple.identityToken;
    if (identityToken == null) {
      throw StateError('Apple did not return an identity token.');
    }
    return OAuthProvider(
      'apple.com',
    ).credential(idToken: identityToken, rawNonce: rawNonce);
  }

  String _randomNonce([int length = 32]) {
    const characters =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }
}

class PlayerAccountNotFoundException implements Exception {
  const PlayerAccountNotFoundException();
}

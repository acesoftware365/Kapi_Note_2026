import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../domino_player_profile.dart';

class SimpleLobbyFriend {
  const SimpleLobbyFriend({
    required this.publicId,
    required this.initials,
    required this.countryCode,
    required this.code,
    required this.avatarKey,
    required this.points,
    required this.online,
  });

  final String publicId;
  final String initials;
  final String countryCode;
  final String code;
  final String avatarKey;
  final int points;
  final bool online;
}

class SimpleFriendsScreen extends StatelessWidget {
  const SimpleFriendsScreen({super.key, required this.profile});

  final DominoPlayerProfile profile;

  bool _isSpanish(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'es';

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final myId = profile.publicId.toUpperCase();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D0907),
        foregroundColor: Colors.white,
        title: Text(
          _isSpanish(context) ? 'Mis amigos' : 'My friends',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF55100F), Color(0xFF071524)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              db
                  .collection('kapi_friendships')
                  .where('users', arrayContains: myId)
                  .snapshots(),
          builder: (context, snapshot) {
            final ids = <String>{};
            for (final doc in snapshot.data?.docs ?? const []) {
              final users = List<String>.from(doc.data()['users'] ?? []);
              ids.addAll(users.map((id) => id.toUpperCase()));
            }
            ids.remove(myId);
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (ids.isEmpty) {
              return _empty(context);
            }
            return FutureBuilder<List<SimpleLobbyFriend>>(
              future: _loadFriends(db, ids),
              builder: (context, friendsSnapshot) {
                final friends = friendsSnapshot.data;
                if (friends == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final online =
                    friends.where((friend) => friend.online).toList();
                final offline =
                    friends.where((friend) => !friend.online).toList();
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _section(context, 'Online', online, true),
                    const SizedBox(height: 18),
                    _section(
                      context,
                      _isSpanish(context) ? 'Desconectados' : 'Offline',
                      offline,
                      false,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<SimpleLobbyFriend>> _loadFriends(
    FirebaseFirestore db,
    Set<String> ids,
  ) async {
    final friends = <SimpleLobbyFriend>[];
    for (final id in ids) {
      final profileDoc =
          await db.collection('kapi_lobby_profiles').doc(id).get();
      final data = profileDoc.data() ?? {};
      final code = data['code'] as String? ?? id.split('.').last;
      final pointsDoc =
          await db.collection('kapi_player_points').doc(code).get();
      final rawPoints = pointsDoc.data()?['totalPoints'];
      friends.add(
        SimpleLobbyFriend(
          publicId: id,
          initials: data['initials'] as String? ?? id.split('.').first,
          countryCode: data['countryCode'] as String? ?? '',
          code: code,
          avatarKey: data['avatarKey'] as String? ?? 'person',
          points: rawPoints is num ? rawPoints.toInt() : 0,
          online: data['status'] == 'online',
        ),
      );
    }
    friends.sort((a, b) {
      if (a.online != b.online) return a.online ? -1 : 1;
      return a.initials.compareTo(b.initials);
    });
    return friends;
  }

  Widget _empty(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Text(
        _isSpanish(context)
            ? 'Todavia no tienes amigos. Usa el ID de 6 caracteres para invitar uno.'
            : 'You do not have friends yet. Use the 6-character ID to invite one.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 17),
      ),
    ),
  );

  Widget _section(
    BuildContext context,
    String title,
    List<SimpleLobbyFriend> friends,
    bool enabled,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${friends.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                _isSpanish(context) ? 'Ninguno' : 'None',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          for (final friend in friends) _friendRow(context, friend, enabled),
        ],
      ),
    );
  }

  Widget _friendRow(
    BuildContext context,
    SimpleLobbyFriend friend,
    bool enabled,
  ) {
    final tier = DominoTierVisual.fromScore(friend.points);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: tier.deep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tier.frameColor(), width: 1.5),
          boxShadow: tier.shadows(),
        ),
        alignment: Alignment.center,
        child: Text(
          friend.initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      title: Text(
        '${friend.initials} · ${friend.countryCode == 'US' ? 'USA' : friend.countryCode}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        '${tier.label} · #${friend.code}',
        style: const TextStyle(color: Colors.white60),
      ),
      trailing:
          enabled
              ? IconButton.filled(
                onPressed: () => Navigator.pop(context, friend),
                tooltip: _isSpanish(context) ? 'Invitar' : 'Invite',
                icon: const Icon(Icons.add_rounded),
              )
              : const Icon(Icons.circle, color: Colors.white24, size: 11),
    );
  }
}

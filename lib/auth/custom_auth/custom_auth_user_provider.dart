import 'package:rxdart/rxdart.dart';

import 'custom_auth_manager.dart';

class RdoproAuthUser {
  RdoproAuthUser({required this.loggedIn, this.uid});

  bool loggedIn;
  String? uid;
}

/// Generates a stream of the authenticated user.
BehaviorSubject<RdoproAuthUser> rdoproAuthUserSubject =
    BehaviorSubject.seeded(RdoproAuthUser(loggedIn: false));
Stream<RdoproAuthUser> rdoproAuthUserStream() =>
    rdoproAuthUserSubject.asBroadcastStream().map((user) => currentUser = user);

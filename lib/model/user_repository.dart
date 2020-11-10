import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum Status {Uninitialized, Authenticated, Authenticating, Unauthenticated }

final databaseReference = FirebaseFirestore.instance;

class UserRepository with ChangeNotifier {
  FirebaseAuth _auth;
  User _user;
  Status _status = Status.Uninitialized;
  String _email;
  Set<String> _saved;

  UserRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    _saved = new Set<String>();
    _status = Status.Unauthenticated;
  }

  Status get status => _status;

  User get user => _user;

  String get email => _email;

  Set<String> get saved => _saved;

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _email = email;
      DocumentSnapshot ds = await databaseReference.collection("users").doc(
          _email).get();
      if (!ds.exists) {
        databaseReference.collection("users").doc(_email).set(
            {'wordPairs': new List<String>()});
      }
      updateWithDb();
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future signOut() async {
    _auth.signOut();
    _status = Status.Unauthenticated;
    _email = "";
    _saved.clear();
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<void> _onAuthStateChanged(User firebaseUser) async {
    if (firebaseUser == null) {
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = Status.Authenticated;
    }
    notifyListeners();
  }

  Future addFav(String pair) async {
    _saved.add(pair);
    if (status == Status.Authenticated) {
      await databaseReference.collection("users").doc(_email).get().then((
          snapshot) async {
        var wordPairs = snapshot.data()['wordPairs'];
        wordPairs.add(pair);
        await databaseReference.collection("users").doc(_email).update(
            {'wordPairs': wordPairs.toList()});
      });
    }
    notifyListeners();
  }

  Future removeFav(String pair) async {
    _saved.remove(pair);
    if (status == Status.Authenticated) {
      databaseReference.collection("users").doc(_email).get().then((
          snapshot) async {
        var wordPairs = snapshot.data()['wordPairs'];
        wordPairs.remove(pair);
        await databaseReference.collection("users").doc(_email).update(
            {'wordPairs': wordPairs.toList()});
      });
    }
    notifyListeners();
  }

  Future updateWithDb() async {
    try {
      await databaseReference.collection("users").doc(_email).get().then((
          snapshot) {
        List<String> wordPairs = List.from(snapshot.data()['wordPairs']);
        _saved.addAll(wordPairs.map((e) => e.toString()));
      });
    } catch (e) {}
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

enum Status {Uninitialized, Authenticated, Authenticating, Unauthenticated }

final databaseReference = FirebaseFirestore.instance;
final firebase_storage.FirebaseStorage storage = firebase_storage.FirebaseStorage.instance;

class UserRepository with ChangeNotifier {
  FirebaseAuth _auth;
  User _user;
  Status _status = Status.Uninitialized;
  String _email;
  String imageURL;
  Set<String> _saved;

  UserRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    _saved = new Set<String>();
    _status = Status.Unauthenticated;
  }

  Status get status => _status;

  User get user => _user;

  String get email => _email;

  String get uid => _user.uid;

  Set<String> get saved => _saved;

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _email = email;
      DocumentSnapshot ds = await databaseReference.collection("users").doc(
          _email).get();
      if (!ds.exists) {
        databaseReference.collection("users").doc(_email).set(
            {'wordPairs': new List<String>()});
      }
      updateWithDb();
      try {
        await storage.ref('images').child(user.uid + ".png").getDownloadURL().then((value) => imageURL = value);
      } catch(e) {
        imageURL = null;
      }
      notifyListeners();
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
    imageURL = null;
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

  Future<bool> addNewUser(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      _auth.createUserWithEmailAndPassword(email: email, password: password);
      return await signIn(email, password);
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<String> setProfilePicture(File picture, String name) async {
    return storage.ref('images').child(name).putFile(picture).then((snap) => snap.ref.getDownloadURL());
  }
}


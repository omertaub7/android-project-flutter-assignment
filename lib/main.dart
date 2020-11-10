import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:hello_me/model/user_repository.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _initialization,
        builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
            body: Center(
                child: Text(snapshot.error.toString(),
                    textDirection: TextDirection.ltr)));
      }
      if (snapshot.connectionState == ConnectionState.done) {
        return MyApp();
      }
      return Center(child: CircularProgressIndicator());
        },
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserRepository>(
      create: (_) => UserRepository.instance(),
      child: MaterialApp(
        title: 'Startup Name Generator',
        theme: ThemeData(          // Add the 3 lines from here...
          primaryColor: Colors.red,
        ),
        home: RandomWords(),
      ),
    );
  }
}

class RandomWords extends StatefulWidget {
  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  @override
  final List<WordPair> _suggestions = <WordPair>[];
  final _biggerFont = TextStyle(fontSize: 18.0);
  void _pushSaved() {
    Navigator.of(context).push(
     MaterialPageRoute<void> (
       builder: (BuildContext context) {
         return Consumer<UserRepository> (
           builder: (context, user, _){
             user.updateWithDb();
             final tiles = user.saved.map((String pair) {
               return ListTile(
                 title: Text(
                   pair,
                   style: _biggerFont,
                 ),
                   trailing: Icon(Icons.delete_outline, color: Colors.red),
                   onTap: () async => user.removeFav(pair),
               );});
             final divided = ListTile.divideTiles(
               context: context,
               tiles: tiles,
             ).toList();
             return Scaffold(
                 appBar: AppBar(
                 title: Text('Saved Suggestions'),
             ),
             body: ListView(
             children: divided,
             )
             );}
         );
       }
     )
    );
  }

  void _pushLogin() {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _LoginPage();
        }
    ));
  }

  void _pushLogout() {
    Provider.of<UserRepository>(context, listen: false).signOut();
  }

  Widget build(BuildContext context) {
    UserRepository loginState = Provider.of(context, listen:false);
    return Scaffold(
      appBar: AppBar(
        title: Text('Startup Name Generator'),
        actions: [
          IconButton(icon: Icon(Icons.favorite), onPressed: _pushSaved),
          Consumer<UserRepository>(
            builder: (context, user, _) {
              return IconButton(
                  icon: (loginState.status == Status.Authenticated) ? Icon(Icons.exit_to_app) : Icon(Icons.login),
                  onPressed: () {
                    if (loginState.status == Status.Authenticated) {
                      _pushLogout();
                    } else {
                      _pushLogin();
                    }
                  }
              );
            }
          ),
        ],
      ),
      body: _buildSuggestions(),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        // The itemBuilder callback is called once per suggested
        // word pairing, and places each suggestion into a ListTile
        // row. For even rows, the function adds a ListTile row for
        // the word pairing. For odd rows, the function adds a
        // Divider widget to visually separate the entries. Note that
        // the divider may be difficult to see on smaller devices.
        itemBuilder: (BuildContext _context, int i) {
          // Add a one-pixel-high divider widget before each row
          // in the ListView.
          if (i.isOdd) {
            return Divider();
          }

          // The syntax "i ~/ 2" divides i by 2 and returns an
          // integer result.
          // For example: 1, 2, 3, 4, 5 becomes 0, 1, 1, 2, 2.
          // This calculates the actual number of word pairings
          // in the ListView,minus the divider widgets.
          final int index = i ~/ 2;
          // If you've reached the end of the available word
          // pairings...
          if (index >= _suggestions.length) {
            // ...then generate 10 more and add them to the
            // suggestions list.
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        }
    );
  }

  Widget _buildRow(WordPair pair) {
    return Consumer<UserRepository>(
      builder: (context, user, _) {
        final alreadySaved = user.saved.contains(pair.asPascalCase);
        return ListTile(
          title: Text(
            pair.asPascalCase,
            style: _biggerFont,
          ),
          trailing: Icon(   // NEW from here...
            alreadySaved ? Icons.favorite : Icons.favorite_border,
            color: alreadySaved ? Colors.red : null,
          ),                // ... to here.
          onTap: () {      // NEW lines from here...
              if (alreadySaved) {
                user.removeFav(pair.asPascalCase);
              } else {
                user.addFav(pair.asPascalCase);
              }
          },
        );
      }
    );
  }
}

class _LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  TextStyle style = TextStyle(fontFamily: 'Montserrat', fontSize: 20.0);
  TextEditingController _email;
  TextEditingController _password;
  final _formKey = GlobalKey<FormState>();
  final _key = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: "");
    _password = TextEditingController(text: "");
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserRepository>(context);
    return Scaffold(
      key: _key,
      appBar: AppBar(
        title: Text("Login"),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextFormField(
                  controller: _email,
                  validator: (value) =>
                  (value.isEmpty) ? "Please Enter Email" : null,
                  style: style,
                  decoration: InputDecoration(
                      prefixIcon: Icon(Icons.email),
                      labelText: "Email",
                      border: OutlineInputBorder()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextFormField(
                  controller: _password,
                  validator: (value) =>
                  (value.isEmpty) ? "Please Enter Password" : null,
                  style: style,
                  decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock),
                      labelText: "Password",
                      border: OutlineInputBorder()),
                  obscureText: true,
                ),
              ),
              user.status == Status.Authenticating
                  ? Center(child: CircularProgressIndicator())
                  : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Material(
                  elevation: 5.0,
                  borderRadius: BorderRadius.circular(30.0),
                  color: Colors.red,
                  child: MaterialButton(
                    onPressed: () async {
                      if (_formKey.currentState.validate()) {
                        if (!await user.signIn(
                            _email.text, _password.text))
                        {
                          _key.currentState.showSnackBar(SnackBar(
                            content: Text("There was an error logging into the app"),));
                        } else {
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: Text(
                      "Sign In",
                      style: style.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
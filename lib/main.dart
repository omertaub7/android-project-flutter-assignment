import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:english_words/english_words.dart';
import 'package:hello_me/model/user_repository.dart';
import 'package:provider/provider.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:file_picker/file_picker.dart';


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
  var _controller = SnappingSheetController();
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
                   trailing: IconButton(icon: Icon(Icons.delete_outline), color: Colors.red,
                       onPressed: () async => user.removeFav(pair),),
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
    var _key = GlobalKey<ScaffoldState>();
    return Consumer<UserRepository> (
      builder: (context, user, _) {
        return Scaffold(
          key: _key,
            appBar: AppBar(
            title: Text('Startup Name Generator'), actions: [
            IconButton(icon: Icon(Icons.favorite), onPressed: _pushSaved),
            IconButton( icon: (user.status == Status.Authenticated) ? Icon(Icons.exit_to_app) : Icon(Icons.login),
              onPressed: () {
                if (user.status == Status.Authenticated) {
                  _pushLogout();
                }  else {
                _pushLogin();
                }})
            ],
          ),
          body: (user.status != Status.Authenticated) ? _buildSuggestions() :
          _buildSnappingSheet(_key)
        );
      }
    );
  }

  Widget _buildSnappingSheet(GlobalKey<ScaffoldState> key) {
    var user = Provider.of<UserRepository>(context);
    return SnappingSheet(
        sheetAbove: SnappingSheetContent(
          child: _buildSuggestions(),
        ),
        snappingSheetController: _controller,
        snapPositions: [
          const SnapPosition(
              positionPixel: 0.0,
              snappingCurve: Curves.elasticOut,
              snappingDuration: Duration(milliseconds: 750)
          ),
          const SnapPosition(
              positionFactor: 0.2,
              snappingCurve: Curves.ease,
              snappingDuration: Duration(milliseconds: 500)
          ),
        ],
        grabbing: Container(
          color: Colors.grey,
          child: InkWell(
              child: ListTile(
                title: user.email!=null ? Text("Welcome back, ${user.email}", style: TextStyle(fontFamily: 'Montserrat', fontSize: 14.0)) : Text(""),
                trailing: Icon(Icons.arrow_drop_up_outlined),
              ),
              onTap: () {
                if(_controller.snapPositions.last != _controller.currentSnapPosition) {
                  _controller.snapToPosition(_controller.snapPositions.last);
                }
                else {
                  _controller.snapToPosition(_controller.snapPositions.first);
                }
              }
          ),
        ),
        sheetBelow: SnappingSheetContent(
            heightBehavior: SnappingSheetHeight.fit(),
            child: Container(
              color:Colors.white,
              child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(5),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(10),
                          ),
                          user.imageURL == null ? CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.camera_alt),
                          ) : CircleAvatar(
                            radius: 45,
                            backgroundImage: NetworkImage(user.imageURL),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.all(10),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(user.email != null ? user.email : ""),
                          Padding(
                            padding: EdgeInsets.all(8),
                          ),
                          MaterialButton(
                            child: Text("Change Avatar", style: TextStyle(fontFamily: 'Montserrat', fontSize: 14.0)),
                            color: Colors.green,
                            onPressed: () async {
                              FilePickerResult result = await FilePicker.platform
                                  .pickFiles(type: FileType.image);
                              File file;
                              if (result != null) {
                                file = File(result.files.single.path);
                                setState(() {
                                  user.imageURL = null;
                                });
                                user.imageURL = await user.setProfilePicture(file, user.uid + ".png");
                                setState(() {});
                              } else {
                                key.currentState.showSnackBar(SnackBar(
                                  content: Text("No image selected"),));
                              }
                            } ,
                          )
                        ],

                      )
                    ],
                  )
              ),
            )
        )
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
  TextEditingController _password_confirm;
  final _formKey = GlobalKey<FormState>();
  final _validateKey = GlobalKey<FormState>();
  final _key = GlobalKey<ScaffoldState>();
  bool registered;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: "");
    _password = TextEditingController(text: "");
    registered = false;
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
                child: Text(
                    "Welcome to Startup Name Generator, please log in below",
                  style: style.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
              ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(height: 16.0,),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Material(
                  elevation: 5.0,
                  borderRadius: BorderRadius.circular(30.0),
                  color: Colors.green,
                  child: MaterialButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context, isScrollControlled: true,
                        builder: (context) {
                          return Container(
                            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                            color: Colors.white,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Text('Please confirm your password below'),
                                  Form(
                                    key: _validateKey,
                                    child:Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        TextFormField(
                                          controller: _password_confirm,
                                          validator: (value) => value.isEmpty || value ==_password.text ? null:"Passwords must match!",
                                          style: style,
                                          decoration: InputDecoration(
                                              prefixIcon: Icon(Icons.lock),
                                              labelText: "Password",
                                              border: OutlineInputBorder()),
                                          obscureText: true,
                                        ),
                                        ElevatedButton(
                                            child: const Text('Confirm'),
                                            onPressed: () async
                                            {
                                              if(!_validateKey.currentState.validate()) return;
                                              if (!await user.addNewUser(_email.text, _password.text)) {
                                                _key.currentState.showSnackBar(SnackBar(
                                                  content: Text("A server error has occurred!"),));
                                                return;
                                              }
                                              registered = true;
                                              Navigator.of(context).pop();
                                            }
                                        )
                                      ],
                                    ),
                                  )

                                ],
                              ),
                          );
                        }
                      ).then((value) {
                        if (registered) {
                          Navigator.of(context).pop();
                            }
                    } );
                    },
                    child: Text(
                      "New User? Click to sign up",
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
// main.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Make sure to change the project name in the imports!
import 'package:goodz_test/firebase_options.dart';
import 'package:goodz_test/screens/home_screen.dart';
import 'package:goodz_test/screens/login_screen.dart';

const gqlUrl = "YOUR GRAPHQL URL HERE";
const bool enableWebsockets = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class GraphQLWidgetScreen extends StatelessWidget {
  const GraphQLWidgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final httpLink = HttpLink(gqlUrl);

    final authLink = AuthLink(
      getToken: () async {
        var user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return "";
        }

        var token = await user.getIdTokenResult(true);
        var res = "Bearer ${token.token!}";
        log(res);
        return res;
      },
    );

    var link = authLink.concat(httpLink);

    if (enableWebsockets) {
      final websocketLink = WebSocketLink(gqlUrl.replaceFirst("https", "ws"),
          config: SocketClientConfig(
              autoReconnect: true,
              inactivityTimeout: const Duration(seconds: 30),
              initialPayload: () async {
                return {
                  "headers": {
                    "Authorization": await authLink.getToken(),
                  }
                };
              }));

      link = Link.split(
        (request) => request.isSubscription,
        websocketLink,
        link,
      );
    }

    final client = ValueNotifier<GraphQLClient>(
      GraphQLClient(cache: GraphQLCache(), link: link),
    );

    return GraphQLProvider(
      client: client,
      child: const CacheProvider(
        child: HomeScreen(),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  refreshUser() async {
    FirebaseFunctions functions = FirebaseFunctions.instance;
    HttpsCallable callable = functions.httpsCallable('refreshUserClaims');
    await callable();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, appSnapshot) {
        return MaterialApp(
            home: appSnapshot.connectionState != ConnectionState.done
                ? const CircularProgressIndicator()
                : StreamBuilder(
                    stream: FirebaseAuth.instance.userChanges(),
                    builder: (ctx, userSnapshot) {
                      if (userSnapshot.hasData) {
                        return FutureBuilder(
                            future: refreshUser(),
                            builder: (ctx, snapshot) {
                              return const GraphQLWidgetScreen();
                            });
                      }
                      return const LoginScreen();
                    }));
      },
    );
  }
}

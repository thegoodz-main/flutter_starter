// home_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Homescreen"), actions: [
          IconButton(
              onPressed: () async {
                FirebaseFunctions functions = FirebaseFunctions.instance;
                HttpsCallable callable =
                    functions.httpsCallable('logoutUserClaims');
                await callable();
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout),
              tooltip: "Logout")
        ]),
        body: Subscription(
          options: SubscriptionOptions(document: gql(r'''
subscription listUsers {
  user {
    id
    phone
    role
  }
}''')),
          builder: (QueryResult result,
              {VoidCallback? refetch, FetchMore? fetchMore}) {
            if (result.hasException) {
              return Text(result.exception.toString());
            }

            if (result.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<dynamic> users = result.data!['user'];

            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (BuildContext context, int index) {
                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text("Id: ${users[index]['id']}"),
                      ),
                      ListTile(
                        title: Text("Role: ${users[index]['role']}"),
                      ),
                      ListTile(
                        title: Text("Phone: ${users[index]['phone']}"),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ));
  }
}

import 'package:boxed_app/screens/capsule_detail_screen.dart';
import 'package:boxed_app/screens/create_capsule_screen.dart';
import 'package:boxed_app/screens/login_signup.dart';
import 'package:boxed_app/widgets/buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


class HomeScreen extends StatefulWidget{
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreen();
}

class Capsule {
  final String title;
  final String description;
  final DateTime unlockDate;
  final bool isOpened;

  Capsule({
    required this.title,
    required this.description,
    required this.unlockDate,
    required this.isOpened,
  });
}

final List<Capsule> dummyCapsules = [
  Capsule(
    title: "Time Capsule", description: "A journey through time ", unlockDate: DateTime(2025, 1, 1), isOpened: false),
    Capsule(title: "College days", description: "Memories with friends", unlockDate: DateTime(2024, 9, 15), isOpened: true),

];

class _HomeScreen extends State<HomeScreen>{
  @override 
  Widget build(BuildContext context){
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: (){
        Navigator.push(context, MaterialPageRoute(builder: (context) => CreateCapsuleScreen(),));
      },
      backgroundColor: Colors.white,
      child: Icon(Icons.add, color: Colors.black,)),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 60, 16, 0),
        child: ListView.builder(
          itemCount: dummyCapsules.length,
          itemBuilder: (context, index){
            final capsule = dummyCapsules[index];
            return Container(
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                title: Text(
                  capsule.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4,),
                    Text(
                      capsule.description,
                      style: TextStyle(color: Colors.grey[400]),

                    ),
                    SizedBox(height: 4,),
                    Text(
                      "Unlocks on ${capsule.unlockDate.toLocal().toString().split(' ')[0]}",
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
                trailing: Icon(
                  capsule.isOpened ? Icons.lock_open : Icons.lock,
                  color: capsule.isOpened ? Colors.white : Colors.amber,
                ),
              ),
            );
          }),
      ),
    );
    }
    
    }
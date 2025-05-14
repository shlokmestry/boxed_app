
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginSignup extends StatefulWidget{
  const LoginSignup({super.key});

  @override
  State<LoginSignup> createState() => _LoginSignupState();
}

class _LoginSignupState extends State<LoginSignup>{
  bool isLogin = true;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  @override 
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,

      body: Center(
        child: Padding(padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text('Welcome to Boxed',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white
              ),),
            ),
            
            SizedBox(height: 6,),
            Center(
              child: Text('Your memories, waiting patiently.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                color: Colors.grey[300],
              ),),
            ),
            SizedBox(height: 25,),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Email',
                 enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white)
                )
                  
              ),
            ),
            SizedBox(height: 10,),
             TextField(
              controller: passwordController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Password',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white)
                ),
 
                
              ),

            ),
            SizedBox(height: 20,),
            ElevatedButton(
              onPressed: () async {
  final email = emailController.text.trim();
  final password = passwordController.text.trim();

  try {
    if (isLogin) {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } else {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
},

            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              minimumSize: Size.fromHeight(55), 
              shape: RoundedRectangleBorder(
                
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.white)
                

              ),
              elevation: 0,
            ), child: Text(
              isLogin ? 'Log In' : 'Sign Up',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white
              ),
            )),
            
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(isLogin ? "Don't have an account?" : "Already have an account?",
                style: TextStyle(color: Colors.white),),
                GestureDetector(
                  onTap: (){
                   setState(() {
                     isLogin = !isLogin;
                   });
                  },
                  child: Text(isLogin ? " Sign up" : " Log in",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),),
                )
              ],
            )
           
         
          ],
        ),),

      )
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'Loginscreen.dart';

class SplashScreen extends StatefulWidget
{
   SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
{

  @override
  void initState()
  {
    // TODO: implement initState
    super.initState();

    Timer
      (
        Duration(seconds: 5), () =>
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()))
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold
      (
      body: Center
        (
          child: Lottie.asset
            (
              "assets/Animation - 1727201651342.json"
          )
      ),
    ) ;
  }
}
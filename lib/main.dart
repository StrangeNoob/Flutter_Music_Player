import 'package:flutter/material.dart';
import 'package:musix/theme.dart';
import 'package:musix/my_app.dart';
void main() => runApp(new MyMaterialApp());

class MyMaterialApp extends StatefulWidget {
  @override
  MyMaterialAppState createState() {
    return new MyMaterialAppState();
    
  }
}

class MyMaterialAppState extends State<MyMaterialApp> {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        debugShowCheckedModeBanner: false, 
        theme: lightTheme,
        home: new MyApp(),
        );
  }
}

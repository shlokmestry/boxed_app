import 'package:flutter/material.dart';

class Buttons extends StatelessWidget{
  final String label;
  final VoidCallback onPressed;

  Buttons({
    super.key,
    required this.label,
    required this.onPressed, 
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      minimumSize: Size.fromHeight(55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.white),
      ),
      elevation: 0,
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),);
  }
  
}
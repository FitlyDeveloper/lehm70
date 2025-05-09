import 'package:flutter/material.dart';
import 'NewScreens/ChooseWorkout.dart';

class CodiaPage extends StatefulWidget {
  // ... (existing code)
}

class _CodiaPageState extends State<CodiaPage> {
  // ... (existing code)

  @override
  Widget build(BuildContext context) {
    // ... (existing code)

    return Scaffold(
      // ... (existing code)

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChooseWorkout()),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
} 
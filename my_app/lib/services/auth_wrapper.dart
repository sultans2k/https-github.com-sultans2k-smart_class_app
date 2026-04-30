import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 1. Listen to Firebase Authentication state changes
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        
        // Show a loading spinner while checking the device cache
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        // 2. If the user is NOT logged in, show the Login Screen
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        // 3. If the user IS logged in, fetch their specific data from Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(authSnapshot.data!.uid).get(),
          builder: (context, userSnapshot) {
            
            // Show a loading spinner while talking to the database
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
            }

            // 4. If the database profile exists, extract the data and route them to MainScreen
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>;
              
              String roleString = data['role'] ?? 'student';
              UserRole role = roleString == 'teacher' ? UserRole.teacher : UserRole.student;
              String userName = data.containsKey('name') ? data['name'] : 'مستخدم';

              return MainScreen(role: role, userName: userName);
            }

            // 5. Fallback: If they are logged into Auth but have no database profile, 
            // force a logout and send them back to the login screen.
            FirebaseAuth.instance.signOut();
            return const LoginScreen();
          },
        );
      },
    );
  }
}
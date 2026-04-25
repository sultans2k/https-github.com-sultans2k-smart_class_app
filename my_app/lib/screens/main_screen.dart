import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants.dart';
import 'login_screen.dart';
import 'chat_screen.dart'; 
import 'student_chat_screen.dart'; 
import 'record_screen.dart';
import 'history_screen.dart';

class MainScreen extends StatefulWidget {
  final UserRole role;
  final String userName;
  
  const MainScreen({
    super.key, 
    required this.role, 
    required this.userName,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  // Create the key to access the HistoryScreen's state
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();

  Future<void> _handleLogout() async {
    // 1. Sign out of Firebase
    await FirebaseAuth.instance.signOut();
    
    // 2. Sign out of Google 
    try {
      await GoogleSignIn.instance.signOut(); 
    } catch (e) {
      // Ignore errors if they logged in via Email
    }

    // 3. Route back to the Login Screen
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isStudent = widget.role == UserRole.student;

    // Conditionally load the screens based on the role
    final List<Widget> screens = [
      isStudent
          ? StudentChatScreen(role: widget.role, userName: widget.userName)
          : ChatScreen(role: widget.role),
      if (!isStudent) RecordScreen(role: widget.role),
      
      // Attach the key to your HistoryScreen
      HistoryScreen(key: _historyKey, role: widget.role), 
    ];

    // Conditionally load the navigation items based on the role
    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.smart_toy_outlined),
        activeIcon: Icon(Icons.smart_toy_rounded),
        label: 'المساعد',
      ),
      if (!isStudent)
        const BottomNavigationBarItem(
          icon: Icon(Icons.fiber_manual_record_outlined),
          activeIcon: Icon(Icons.fiber_manual_record_rounded),
          label: 'تسجيل الحصة',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.history_edu_outlined),
        activeIcon: Icon(Icons.history_edu_rounded),
        label: 'السجل',
      ),
    ];

    if (_currentIndex >= screens.length) {
      _currentIndex = screens.length - 1;
    }

    String getAppBarTitle() {
      if (_currentIndex == 0) return 'المساعد الذكي';
      if (!isStudent && _currentIndex == 1) return 'تسجيل الحصة';
      return 'السجل'; 
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          getAppBarTitle(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white), 
        actions: [
          // Only show the refresh button if we are on the History tab
          if ((!isStudent && _currentIndex == 2) || (isStudent && _currentIndex == 1))
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () {
                // Trigger the refresh function inside the child screen
                _historyKey.currentState?.loadSessions(); 
              },
            ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.cardBg,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              accountName: Text(
                widget.userName,
                style: const TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              accountEmail: Text(
                widget.role == UserRole.teacher ? 'حساب معلم' : 'حساب طالب',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  widget.userName.trim().isNotEmpty 
                      ? widget.userName.trim()[0].toUpperCase() 
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_rounded, color: AppColors.textSecondary),
              title: const Text('الصفحة الرئيسية'),
              onTap: () {
                Navigator.pop(context); 
                setState(() => _currentIndex = 0); 
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(color: AppColors.textSecondary, thickness: 0.2),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.recording), 
              title: const Text(
                'تسجيل الخروج', 
                style: TextStyle(
                  color: AppColors.recording, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex, 
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: navItems,
        ),
      ),
    );
  }
}
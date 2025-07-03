import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Screens
import 'screens/caregivers_screens/caregiver_dashboard.dart';
import 'screens/old_adults_screens/old_adult_dashboard.dart';
import 'screens/shared_screens/landing_page.dart';
import 'screens/shared_screens/login.dart';
import 'screens/shared_screens/register.dart';
import 'screens/shared_screens/about_us.dart';
import 'screens/caregivers_screens/manage_patients.dart';
import 'screens/shared_screens/profile_page.dart';
import 'screens/old_adults_screens/manage_caregivers.dart';
import 'screens/old_adults_screens/medication.dart';
import 'screens/caregivers_screens/patient_profile_caregiver.dart';
import 'screens/family_screens/family_dashboard.dart';
import 'screens/old_adults_screens/nutrition.dart';
import 'screens/old_adults_screens/hydration.dart';
import 'screens/family_screens/patient_profile_family.dart';
import 'screens/family_screens/reports.dart';
import 'screens/family_screens/manage_patients_family.dart';
import 'screens/old_adults_screens/tasks.dart';
import 'screens/old_adults_screens/check_in.dart';
import 'screens/admin_screens/admin_dashboard.dart';
import 'screens/admin_screens/users_list.dart';
import 'screens/old_adults_screens/help.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareConnect',
      theme: ThemeData(primarySwatch: Colors.blue),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: [Locale('en'), Locale('pt')],
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/old_adult_dashboard': (context) => const OldAdultDashboard(),
        '/home_screen': (context) => const HomeScreen(),
        '/nutrition': (context) => const NutritionScreen(),
        '/hydration': (context) => const HydrationScreen(),
        '/help': (context) => const HelpScreen(),
        '/family_dashboard': (context) => const FamilyDashboard(),
        '/about_us': (context) => const AboutUsScreen(),
        '/patients': (context) => const PatientListScreen(),
        '/manage_patients': (context) => const PatientListScreen(),
        '/manage_patients_caregiver': (context) => const PatientListScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/manage_caregivers': (context) => const ManageCaregiversScreen(),
        '/medication_screen': (context) => const MedicationScreen(),
        '/patient_profile': (context) => const PatientProfileCaregiver(),
        '/patient_profile_family': (context) => FamilyPatientProfileScreen(),
        '/reports': (context) => ReportsScreen(),
        '/manage_patients_family': (context) => const ManagePatientsFamilyScreen(),
        '/tasks': (context) => const TasksScreen(),
        '/check_in': (context) => const CheckInScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/users_list': (context) => const UsersListScreen(),
        '/landing_page': (context) => LandingPageScreen(),
        '/caregiver_dashboard': (context) => const CaregiverDashboard(),
      },
    );
  }
}

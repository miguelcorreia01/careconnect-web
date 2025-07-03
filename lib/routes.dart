import 'package:flutter/material.dart';
import 'screens/shared_screens/landing_page.dart';
import 'screens/shared_screens/login.dart';
import 'screens/shared_screens/register.dart';
import 'screens/caregivers_screens/manage_patients.dart';
import 'screens/old_adults_screens/manage_caregivers.dart'; 
import 'screens/old_adults_screens/medication.dart'; 
import 'screens/family_screens/manage_patients_family.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const HomeScreen(),
  '/login': (context) => const LoginScreen(),
  '/register': (context) => const RegisterScreen(),
  '/patients': (context) => const PatientListScreen(),
  '/manage_caregivers': (context) => const ManageCaregiversScreen(),
  '/medication': (context) => const MedicationScreen(),
  '/manage_patients_family': (context) => const ManagePatientsFamilyScreen(),
};

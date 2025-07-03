
# CareConnect 

## Table of Contents
- [Setup](#setup)
- [Key Features](#key-features)
- [Technical Stack & Architecture](#technical-stack--architecture)

## Project Description

CareConnect is a cross-platform application developed using Flutter to provide seamless elderly care support across mobile and web devices. The app enables older adults, family members, and professional caregivers to communicate and monitor daily health activities, medication schedules, and wellness metrics in real-time. Critical alerts ensure timely responses to emergencies and missed tasks.

Built with Flutter’s flexible UI toolkit, CareConnect offers a consistent and responsive user experience on Android, iOS, and web platforms, while maintaining a multi-role system tailored for different users.

## Key Features

### Older Adults
- Perform morning and evening check-ins to confirm well-being.
- View and manage daily assigned tasks.
- Track medications and confirm intake.
- Log water consumption and meals for hydration and nutrition tracking.
- Use an SOS button to instantly alert caregivers and family members in emergencies.
- See a list of all connected caregivers and family members.

### Caregivers
- Monitor real-time status of linked patients through a central dashboard.
- Link and manage patients by email.
- Access detailed patient profiles with health data and alerts.
- Add and modify tasks and medications remotely.
- Receive push notifications for missed check-ins, tasks, medications, or SOS events.

### Family Members
- View a dashboard summarizing relatives’ health and activity.
- Get notified about emergencies or missed tasks.
- Access reports with detailed patient information.
- Manage and oversee caregiver relationships.

### Administrators
- Visualize platform activity with user stats by role.
- Search, remove, or promote user accounts.
- Monitor overall user distribution and system usage.

## Technical Stack & Architecture

- **Framework:** Flutter (Dart)
- **Backend & Database:** Firebase
  - Firebase Authentication for secure multi-role login
  - Cloud Firestore for real-time NoSQL database
  - Firebase Storage for user images


## Setup

1. Clone the repository:

    ```bash
    git clone https://github.com/yourusername/yourflutterrepo.git
    cd yourflutterrepo
    ```

2. Create a Firebase project and add a Web app.

3. Add your Firebase web configuration to the `web/index.html` file.

4. Enable Firebase Authentication (Email/Password), Firestore, Storage, and Cloud Messaging in the Firebase Console.

5. Install dependencies:

    ```bash
    flutter pub get
    ```

6. Run the app for web:

    ```bash
    flutter run -d chrome
    ```

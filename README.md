
# CareConnect 

## Table of Contents
- [Project Description](#project-description)
- [Technical Stack](#technical-stack)
- [Key Features](#key-features)
- [Setup](#setup)

## Project Description

CareConnect is a web application developed using Flutter to provide seamless elderly care support. The app enables older adults, family members, and professional caregivers to communicate and monitor daily health activities, medication schedules, and wellness metrics in real-time. Critical alerts ensure timely responses to emergencies and missed tasks.

## Technical Stack

- **Framework:** Flutter (Dart)
- **Backend & Database:** Firebase
  - Firebase Authentication for secure multi-role login
  - Cloud Firestore for real-time NoSQL database
  - Firebase Storage for user images

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


## Setup

1. Clone the repository:

    ```bash
    git clone https://github.com/miguelcorreia01/careconnect-web.git
    cd careconnect-web
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

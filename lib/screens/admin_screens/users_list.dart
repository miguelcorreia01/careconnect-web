import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  int _currentPage = 0;
  final int _rowsPerPage = 10;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _sortColumn = 'name';
  bool _sortAscending = true;

  // Add this field to your state:
  String _selectedRole = 'all';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      _users = snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();
      _filteredUsers = List.from(_users);
      _isLoading = false;
    });
  }

  // Add this method to your state:
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final role = (user['role'] ?? '').toString();
        final matchesSearch = name.contains(query) || email.contains(query);
        final matchesRole = _selectedRole == 'all' || role == _selectedRole;
        // Only include users with a non-empty role
        final hasRole = role.isNotEmpty;
        return matchesSearch && matchesRole && hasRole;
      }).toList();
      _currentPage = 0;
    });
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  Future<void> _toggleAdmin(int globalIndex, bool isAdmin) async {
    final user = _users[globalIndex];
    final newRole = isAdmin ? 'older_adult' : 'admin';
    await FirebaseFirestore.instance.collection('users').doc(user['uid']).update({'role': newRole});
    setState(() {
      _users[globalIndex]['role'] = newRole;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAdmin
              ? 'Admin privileges revoked successfully!'
              : 'User successfully made an admin!',
        ),
        backgroundColor: isAdmin ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _deleteUser(int globalIndex) async {
    // Defensive: get the user from the filtered list, not by index in _users
    if (globalIndex < 0 || globalIndex >= _filteredUsers.length) return;
    final user = _filteredUsers[globalIndex];
    final userUid = user['uid'];
    // Remove from Firestore
    await FirebaseFirestore.instance.collection('users').doc(userUid).delete();
    setState(() {
      // Remove from both lists to keep UI in sync
      _users.removeWhere((u) => u['uid'] == userUid);
      _filteredUsers.removeAt(globalIndex);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User deleted successfully!'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Função para ordenar os utilizadores
  List<Map<String, dynamic>> _sortUsers(List<Map<String, dynamic>> users) {
    List<Map<String, dynamic>> sorted = List.from(users);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'name':
          cmp = (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase());
          break;
        case 'email':
          cmp = (a['email'] ?? '').toString().toLowerCase().compareTo((b['email'] ?? '').toString().toLowerCase());
          break;
        case 'role':
          cmp = (a['role'] ?? '').toString().toLowerCase().compareTo((b['role'] ?? '').toString().toLowerCase());
          break;
        case 'last_login':
          DateTime? ad, bd;
          var av = a['last_login'], bv = b['last_login'];
          if (av is Timestamp) ad = av.toDate();
          else if (av is DateTime) ad = av;
          else if (av != null) ad = DateTime.tryParse(av.toString());
          if (bv is Timestamp) bd = bv.toDate();
          else if (bv is DateTime) bd = bv;
          else if (bv != null) bd = DateTime.tryParse(bv.toString());
          cmp = (ad ?? DateTime(1970)).compareTo(bd ?? DateTime(1970));
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  Future<void> _exportUsersToCSV() async {
    // Cabeçalhos
    List<List<String>> rows = [
      ['Name', 'Email', 'Role', 'Last Login']
    ];
    // Dados
    for (final user in _sortUsers(_filteredUsers)) {
      String lastLoginStr = '-';
      final lastLogin = user['last_login'];
      if (lastLogin != null) {
        DateTime dt;
        if (lastLogin is Timestamp) {
          dt = lastLogin.toDate();
        } else if (lastLogin is DateTime) {
          dt = lastLogin;
        } else {
          dt = DateTime.tryParse(lastLogin.toString()) ?? DateTime(1970);
        }
        lastLoginStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      rows.add([
        user['name'] ?? '',
        user['email'] ?? '',
        user['role'] ?? '',
        lastLoginStr,
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);

    // Partilha o CSV (ou podes guardar num ficheiro)
    await Share.share(csvData, subject: 'Exported Users');
  }

  Future<void> _exportUsersToPDF() async {
    final pdf = pw.Document();
    // Filter out users with empty role before sorting and exporting
    final users = _sortUsers(_filteredUsers.where((u) => (u['role'] ?? '').toString().isNotEmpty).toList());

    // Estatísticas
    int admins = users.where((u) => (u['role'] ?? '').toString() == 'admin').length;
    int caregivers = users.where((u) => (u['role'] ?? '').toString() == 'caregiver').length;
    int family = users.where((u) => (u['role'] ?? '').toString() == 'family').length;
    int olderAdults = users.where((u) => (u['role'] ?? '').toString() == 'older_adult').length;
    int others = users.where((u) =>
      !['admin', 'caregiver', 'family', 'older_adult'].contains((u['role'] ?? '').toString())
    ).length;

    // Pie chart data (render as a simple table, since PieChart/BarChart is not available in pdf/widgets)
    final pieLabels = <String>[];
    final pieValues = <num>[];
    if (admins > 0) {
      pieLabels.add('Admins');
      pieValues.add(admins);
    }
    if (caregivers > 0) {
      pieLabels.add('Caregivers');
      pieValues.add(caregivers);
    }
    if (family > 0) {
      pieLabels.add('Family');
      pieValues.add(family);
    }
    if (olderAdults > 0) {
      pieLabels.add('Older Adults');
      pieValues.add(olderAdults);
    }
    if (others > 0) {
      pieLabels.add('Others');
      pieValues.add(others);
    }

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'CareConnect Users Statistics',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 16),
              ],
            ),
          ),
          pw.Text('User Distribution', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (pieValues.isNotEmpty)
            pw.Table.fromTextArray(
              headers: ['Role', 'Count'],
              data: List.generate(pieLabels.length, (i) => [pieLabels[i], pieValues[i].toString()]),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
            ),
          pw.SizedBox(height: 18),
          pw.Text('Users Table', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Name', 'Email', 'Role', 'Last Login'],
            data: users
                .where((user) =>
                  (user['role'] ?? '').toString().isNotEmpty &&
                  (user['name'] ?? '').toString().isNotEmpty &&
                  (user['email'] ?? '').toString().isNotEmpty
                )
                .map((user) {
                  String lastLoginStr = '-';
                  final lastLogin = user['last_login'];
                  if (lastLogin != null) {
                    DateTime dt;
                    if (lastLogin is Timestamp) {
                      dt = lastLogin.toDate();
                    } else if (lastLogin is DateTime) {
                      dt = lastLogin;
                    } else {
                      dt = DateTime.tryParse(lastLogin.toString()) ?? DateTime(1970);
                    }
                    lastLoginStr =
                        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
                        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                  }
                  return [
                    user['name'] ?? '',
                    user['email'] ?? '',
                    user['role'] ?? '',
                    lastLoginStr,
                  ];
                }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'users_report.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalPages = (_filteredUsers.length / _rowsPerPage).ceil();
    final List<Map<String, dynamic>> paginatedUsers = _filteredUsers.skip(_currentPage * _rowsPerPage).take(_rowsPerPage).toList();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFD9D9D9),
        title: Row(
          children: [
            const Text(
              'Care',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const Text(
              'Connect',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/admin_dashboard');
              },
              child: const Text('Dashboard', style: TextStyle(color: Colors.black)),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () {},
              child: const Text('Users List', style: TextStyle(color: Colors.blue)),
            ),
            const Spacer(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.black),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () {
              Navigator.pushNamed(context, '/home_screen');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Users List',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                // Remove the Create Admin button from here
              ],
            ),
            const SizedBox(height: 16),
            // Search bar full width with filter button and create admin at the end
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter by role',
                  initialValue: _selectedRole,
                  onSelected: (role) {
                    setState(() {
                      _selectedRole = role;
                      _applyFilters();
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'all',
                      child: Row(
                        children: const [
                          Icon(Icons.list, color: Colors.grey, size: 20),
                          SizedBox(width: 8),
                          Text('All Roles'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'admin',
                      child: Row(
                        children: const [
                          Icon(Icons.admin_panel_settings, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Admin'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'caregiver',
                      child: Row(
                        children: const [
                          Icon(Icons.health_and_safety, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('Caregiver'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'family',
                      child: Row(
                        children: const [
                          Icon(Icons.family_restroom, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('Older Adult'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'older_adult',
                      child: Row(
                        children: const [
                          Icon(Icons.elderly, color: Colors.brown, size: 20),
                          SizedBox(width: 8),
                          Text('Family Member'),
                        ],
                      ),
                    ),
                  ],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 22),
                    label: const Text('Create Admin', style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      _showCreateAdminDialog(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Remove o botão Export CSV
                // Adiciona só o botão Export PDF
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 22),
                    label: const Text('Export PDF', style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _filteredUsers.isEmpty ? null : _exportUsersToPDF,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final users = snapshot.data!.docs;
                  List<Map<String, dynamic>> allUsers = users.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['uid'] = doc.id;
                    return data;
                  }).where((user) => (user['role'] ?? '').toString().isNotEmpty).toList();
                  // Always apply both filters (search and role) here!
                  final query = _searchController.text.toLowerCase();
                  final selectedRole = _selectedRole;
                  List<Map<String, dynamic>> filtered = allUsers.where((user) {
                    final name = (user['name'] ?? '').toString().toLowerCase();
                    final email = (user['email'] ?? '').toString().toLowerCase();
                    final role = (user['role'] ?? '').toString();
                    final matchesSearch = name.contains(query) || email.contains(query);
                    final matchesRole = selectedRole == 'all' || role == selectedRole;
                    return matchesSearch && matchesRole;
                  }).toList();

                  // Ordena os utilizadores
                  final sortedUsers = _sortUsers(filtered);
                  final int totalPages = (sortedUsers.length / _rowsPerPage).ceil();
                  final List<Map<String, dynamic>> paginatedUsers = sortedUsers.skip(_currentPage * _rowsPerPage).take(_rowsPerPage).toList();

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width,
                          child: DataTable(
                            sortColumnIndex: _getSortColumnIndex(),
                            sortAscending: _sortAscending,
                            columns: [
                              DataColumn(
                                label: _buildSortableColumnLabel('Name', 'name'),
                                onSort: (columnIndex, ascending) {
                                  setState(() {
                                    _sortColumn = 'name';
                                    _sortAscending = ascending;
                                  });
                                },
                              ),
                              DataColumn(
                                label: _buildSortableColumnLabel('Email', 'email'),
                                onSort: (columnIndex, ascending) {
                                  setState(() {
                                    _sortColumn = 'email';
                                    _sortAscending = ascending;
                                  });
                                },
                              ),
                              DataColumn(
                                label: _buildSortableColumnLabel('Role', 'role'),
                                onSort: (columnIndex, ascending) {
                                  setState(() {
                                    _sortColumn = 'role';
                                    _sortAscending = ascending;
                                  });
                                },
                              ),
                              DataColumn(
                                label: _buildSortableColumnLabel('Last Login', 'last_login'),
                                onSort: (columnIndex, ascending) {
                                  setState(() {
                                    _sortColumn = 'last_login';
                                    _sortAscending = ascending;
                                  });
                                },
                              ),
                              const DataColumn(
                                label: SizedBox.shrink(), // No label for the action column
                              ),
                            ],
                            rows: paginatedUsers.asMap().entries.map((entry) {
                              final index = entry.key;
                              final user = entry.value;
                              final role = (user['role'] ?? '').toString();
                              String displayRole;
                              Icon roleIcon;
                              if (role == 'admin') {
                                displayRole = 'Admin';
                                roleIcon = const Icon(Icons.admin_panel_settings, color: Colors.red, size: 20);
                              } else if (role == 'family') {
                                displayRole = 'Family Member';
                                roleIcon = const Icon(Icons.family_restroom, color: Colors.green, size: 20);
                              } else if (role == 'caregiver') {
                                displayRole = 'Caregiver';
                                roleIcon = const Icon(Icons.health_and_safety, color: Colors.blue, size: 20);
                              } else if (role == 'older_adult') {
                                displayRole = 'Old Adult';
                                roleIcon = const Icon(Icons.elderly, color: Colors.brown, size: 20);
                              } else if (role.isEmpty) {
                                displayRole = 'No Role';
                                roleIcon = const Icon(Icons.help_outline, color: Colors.grey, size: 20);
                              } else {
                                displayRole = 'Unknown Role';
                                roleIcon = const Icon(Icons.help_outline, color: Colors.grey, size: 20);
                              }

                              // Formatar o last_login
                              String lastLoginStr = '-';
                              final lastLogin = user['last_login'];
                              if (lastLogin != null) {
                                DateTime dt;
                                if (lastLogin is Timestamp) {
                                  dt = lastLogin.toDate();
                                } else if (lastLogin is DateTime) {
                                  dt = lastLogin;
                                } else {
                                  dt = DateTime.tryParse(lastLogin.toString()) ?? DateTime(1970);
                                }
                                lastLoginStr =
                                    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
                                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                              }

                              final isCurrentUser = currentUser != null && user['uid'] == currentUser.uid;

                              return DataRow(cells: [
                                DataCell(Text(user['name'] ?? '')),
                                DataCell(Text(user['email'] ?? '')),
                                DataCell(Row(
                                  children: [
                                    roleIcon,
                                    const SizedBox(width: 6),
                                    Text(displayRole),
                                  ],
                                )),
                                DataCell(Text(lastLoginStr)),
                                DataCell(
                                  // Show a disabled button for the current user
                                  isCurrentUser
                                      ? ElevatedButton.icon(
                                          onPressed: null,
                                          icon: const Icon(Icons.person, color: Colors.white),
                                          label: const Text(
                                            'Currently logged in',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey,
                                            disabledBackgroundColor: Colors.grey,
                                            disabledForegroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                        )
                                      : ElevatedButton(
                                          onPressed: () {
                                            // Find the correct index in _filteredUsers for deletion
                                            final filteredIndex = _filteredUsers.indexWhere((u) => u['uid'] == user['uid']);
                                            if (filteredIndex != -1) {
                                              _showConfirmationDialog(
                                                context,
                                                'Delete User',
                                                'Are you sure you want to delete this user? This action cannot be undone.',
                                                () async {
                                                  await _deleteUser(filteredIndex);
                                                  Navigator.of(context).pop();
                                                },
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          child: const Text(
                                            'Delete Account',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _currentPage > 0
                                  ? () {
                                      setState(() {
                                        _currentPage--;
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_back),
                            ),
                            Text('Page ${_currentPage + 1} of $totalPages'),
                            IconButton(
                              onPressed: _currentPage < totalPages - 1
                                  ? () {
                                      setState(() {
                                        _currentPage++;
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_forward),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog(
      BuildContext context, String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            children: [
              const Icon(Icons.warning, size: 48, color: Colors.orange),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.cancel, color: Colors.black54),
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.grey.shade300,
              ),
              label: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateAdminDialog(BuildContext context) {
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();
    final _nameController = TextEditingController();
    final _formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(28),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Create Admin',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fill in the details below to create a new admin account.',
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Enter name';
                            if (!RegExp(r"^[A-Za-zÀ-ÿ\s'-]+$").hasMatch(val)) {
                              return 'Name must not contain numbers or symbols';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Enter email';
                            if (!RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$").hasMatch(val)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !showPassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPassword ? Icons.visibility : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  showPassword = !showPassword;
                                });
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Enter password';
                            if (val.length < 6) return 'Min 6 characters';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, color: Colors.black54),
                        label: const Text('Cancel', style: TextStyle(color: Colors.black)),
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'Create',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                setState(() => isLoading = true);
                                try {
                                  final cred = await FirebaseFirestore.instance
                                      .runTransaction((transaction) async {
                                    final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                      email: _emailController.text.trim(),
                                      password: _passwordController.text.trim(),
                                    );
                                    await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
                                      'name': _nameController.text.trim(),
                                      'email': _emailController.text.trim(),
                                      'role': 'admin',
                                      'uid': userCred.user!.uid,
                                      'created_at': FieldValue.serverTimestamp(),
                                    });
                                    return userCred;
                                  });
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Admin created successfully!'), backgroundColor: Colors.green),
                                    );
                                    _fetchUsers();
                                  }
                                } on FirebaseAuthException catch (e) {
                                  setState(() => isLoading = false);
                                  String errorMsg;
                                  if (e.code == 'email-already-in-use') {
                                    errorMsg = 'This email is already in use by another account. '
                                        'If you have deleted this user from the list, note that the email may still exist in Firebase Authentication. '
                                        'You must remove it from the Firebase Authentication console before reusing this email.';
                                  } else if (e.code == 'invalid-email') {
                                    errorMsg = 'The email address is not valid.';
                                  } else if (e.code == 'weak-password') {
                                    errorMsg = 'The password is too weak.';
                                  } else {
                                    errorMsg = e.message ?? 'An unknown error occurred.';
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
                                  );
                                } catch (e) {
                                  setState(() => isLoading = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Unexpected error. If you are trying to reuse an email, make sure it is also deleted from Firebase Authentication (not just from the users list).'
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ));
      },
    );
  }

  // Helper para mostrar o label da coluna (sem ícone customizado)
  Widget _buildSortableColumnLabel(String label, String column) {
    return InkWell(
      onTap: () {
        setState(() {
          if (_sortColumn == column) {
            _sortAscending = !_sortAscending;
          } else {
            _sortColumn = column;
            _sortAscending = true;
          }
        });
      },
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  // Helper para DataTable sortColumnIndex
  int? _getSortColumnIndex() {
    switch (_sortColumn) {
      case 'name':
        return 0;
      case 'email':
        return 1;
      case 'role':
        return 2;
      case 'last_login':
        return 3;
      default:
        return null;
    }
  }
}

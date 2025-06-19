import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';
import '../widgets/message_composer_modal.dart';
import '../screens/admin_message_log_screen.dart';

class WorkerManagementScreen extends StatefulWidget {
  const WorkerManagementScreen({super.key});

  @override
  State<WorkerManagementScreen> createState() => _WorkerManagementScreenState();
}

class _WorkerManagementScreenState extends State<WorkerManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Management'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchTerm = value.toLowerCase();
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search workers...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // Workers List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'worker')
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No workers found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final workers =
                        snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name =
                              (data['name'] ?? '').toString().toLowerCase();
                          final email =
                              (data['email'] ?? '').toString().toLowerCase();
                          return name.contains(_searchTerm) ||
                              email.contains(_searchTerm);
                        }).toList();

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: workers.length,
                      itemBuilder: (context, index) {
                        final workerDoc = workers[index];
                        final workerData =
                            workerDoc.data() as Map<String, dynamic>;

                        return _buildWorkerCard(workerDoc.id, workerData);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(String workerId, Map<String, dynamic> workerData) {
    final name = workerData['name'] ?? 'Unknown';
    final email = workerData['email'] ?? 'No email';
    final isActive = workerData['isActive'] ?? true;
    final lastSeen = workerData['lastSeen'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isActive ? AppTheme.primaryGreen : Colors.grey,
          child: Text(
            name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(email),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (lastSeen != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Last seen: ${_formatLastSeen(lastSeen)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected:
              (value) => _handleWorkerAction(value, workerId, workerData),
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'message',
                  child: Row(
                    children: [
                      Icon(Icons.message, size: 20),
                      SizedBox(width: 8),
                      Text('Send Message'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'viewMessages',
                  child: Row(
                    children: [
                      Icon(Icons.message_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('View Message Log'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'resetPassword',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset, size: 20),
                      SizedBox(width: 8),
                      Text('Reset Password'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: isActive ? 'deactivate' : 'activate',
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.block : Icons.check_circle,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(isActive ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit Worker'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Delete Worker',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
        ),
      ),
    );
  }

  String _formatLastSeen(Timestamp timestamp) {
    final now = DateTime.now();
    final lastSeen = timestamp.toDate();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _handleWorkerAction(
    String action,
    String workerId,
    Map<String, dynamic> workerData,
  ) {
    switch (action) {
      case 'message':
        _showSingleMessageDialog(workerId, workerData['name']);
        break;
      case 'viewMessages':
        _viewWorkerMessages(workerId, workerData['name']);
        break;
      case 'resetPassword':
        _resetWorkerPassword(workerId, workerData['email']);
        break;
      case 'activate':
      case 'deactivate':
        _toggleWorkerStatus(workerId, action == 'activate');
        break;
      case 'edit':
        _editWorker(workerId, workerData);
        break;
      case 'delete':
        _deleteWorker(workerId, workerData['name']);
        break;
    }
  }

  void _showSingleMessageDialog(String workerId, String workerName) {
    showDialog(
      context: context,
      builder:
          (context) => MessageComposerModal(
            preselectedWorkerId: workerId,
            preselectedWorkerName: workerName,
          ),
    );
  }

  void _viewWorkerMessages(String workerId, String workerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                AdminMessageLogScreen(userId: workerId, userName: workerName),
      ),
    );
  }

  Future<void> _resetWorkerPassword(String workerId, String email) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Password'),
            content: Text('Send password reset email to $email?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: email,
                    );
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Password reset email sent!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Send Reset Email'),
              ),
            ],
          ),
    );
  }

  Future<void> _toggleWorkerStatus(String workerId, bool activate) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(workerId).update(
        {'isActive': activate},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Worker ${activate ? 'activated' : 'deactivated'} successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating worker status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editWorker(String workerId, Map<String, dynamic> workerData) {
    // Navigate to edit worker screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit worker functionality coming soon!')),
    );
  }

  Future<void> _deleteWorker(String workerId, String workerName) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Worker'),
            content: Text(
              'Are you sure you want to delete $workerName? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(workerId)
                        .delete();

                    if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Worker deleted successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Error deleting worker: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

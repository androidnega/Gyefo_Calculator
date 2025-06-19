import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/message_service.dart';
import '../utils/app_theme.dart';

class MessageComposerModal extends StatefulWidget {
  final String? preselectedWorkerId;
  final String? preselectedWorkerName;

  const MessageComposerModal({
    super.key,
    this.preselectedWorkerId,
    this.preselectedWorkerName,
  });

  @override
  State<MessageComposerModal> createState() => _MessageComposerModalState();
}

class _MessageComposerModalState extends State<MessageComposerModal> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _selectedWorkerIds = [];
  final List<String> _selectedWorkerNames = [];
  bool _isLoading = false;
  bool _isBulkMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedWorkerId != null) {
      _selectedWorkerIds.add(widget.preselectedWorkerId!);
      _selectedWorkerNames.add(widget.preselectedWorkerName ?? 'Worker');
    } else {
      _isBulkMode = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.message, color: AppTheme.primaryGreen, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isBulkMode ? 'Send Bulk Message' : 'Send Message',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Worker Selection (for bulk mode)
            if (_isBulkMode) ...[
              const Text(
                'Select Workers:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
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

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No workers found'));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final worker = snapshot.data!.docs[index];
                        final workerId = worker.id;
                        final workerName = worker['fullName'] ?? 'Unknown';
                        final isSelected = _selectedWorkerIds.contains(
                          workerId,
                        );

                        return CheckboxListTile(
                          title: Text(workerName),
                          subtitle: Text(worker['email'] ?? ''),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedWorkerIds.add(workerId);
                                _selectedWorkerNames.add(workerName);
                              } else {
                                _selectedWorkerIds.remove(workerId);
                                _selectedWorkerNames.remove(workerName);
                              }
                            });
                          },
                          activeColor: AppTheme.primaryGreen,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              // Selected worker display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'To: ${_selectedWorkerNames.first}',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Message Input
            const Text(
              'Message:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(_isBulkMode ? 'Send to All' : 'Send Message'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a message');
      return;
    }

    if (_selectedWorkerIds.isEmpty) {
      _showErrorSnackBar('Please select at least one worker');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final senderName = currentUser?.displayName ?? 'Manager';

      if (_isBulkMode) {
        await MessageService.sendBulkMessage(
          receiverIds: _selectedWorkerIds,
          message: _messageController.text.trim(),
          senderName: senderName,
        );
      } else {
        await MessageService.sendMessage(
          receiverId: _selectedWorkerIds.first,
          message: _messageController.text.trim(),
          senderName: senderName,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('Message sent successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.primaryGreen),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

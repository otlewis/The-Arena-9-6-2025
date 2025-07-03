import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../widgets/user_avatar.dart';

class DebaterInviteChoiceModal extends StatefulWidget {
  final String currentUserId;
  final String debaterRole; // 'affirmative' or 'negative'
  final List<UserProfile> networkUsers;
  final Function(Map<String, String?>) onInviteSelectionComplete;
  final VoidCallback onSkip;
  final String? challengerId;
  final String? challengedId;

  const DebaterInviteChoiceModal({
    super.key,
    required this.currentUserId,
    required this.debaterRole,
    required this.networkUsers,
    required this.onInviteSelectionComplete,
    required this.onSkip,
    this.challengerId,
    this.challengedId,
  });

  @override
  State<DebaterInviteChoiceModal> createState() => _DebaterInviteChoiceModalState();
}

class _DebaterInviteChoiceModalState extends State<DebaterInviteChoiceModal> {
  // Track selected users for each role (only moderator now)
  Map<String, String?> selectedInvites = {
    'moderator': null,
  };

  // Track current selection mode
  String? currentSelectingRole;

  // Filter out debaters from network users
  List<UserProfile> get filteredNetworkUsers {
    return widget.networkUsers.where((user) {
      // Exclude both debaters from being selectable as officials
      return user.id != widget.challengerId && user.id != widget.challengedId;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxModalHeight = screenHeight * 0.85; // 85% of screen height
    
    return Material(
      color: Colors.black.withOpacity(0.7),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: maxModalHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                Flexible(
                  child: currentSelectingRole == null 
                      ? _buildRoleSelectionView()
                      : _buildUserSelectionView(),
                ),
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.gavel,
              color: widget.debaterRole == 'affirmative' 
                  ? const Color(0xFF22C55E) 
                  : const Color(0xFFEF4444),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Choose Your Debate Officials',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.debaterRole == 'affirmative' 
                      ? const Color(0xFF22C55E) 
                      : const Color(0xFFEF4444),
                ),
              ),
            ),
            IconButton(
              onPressed: () => widget.onSkip(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.debaterRole.toUpperCase()} Side - Select from your network',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        if (widget.networkUsers.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No network connections found. Random qualified users will be invited.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRoleSelectionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Select which roles you\'d like to fill from your network:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: GridView.count(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _buildRoleCard('moderator', 'Moderator', Icons.account_balance),
              // Judges will be selected by the moderator
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      'Judges will be\nselected by moderator',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard(String roleId, String roleName, IconData icon) {
    final isSelected = selectedInvites[roleId] != null;
    final selectedUser = isSelected 
        ? widget.networkUsers.firstWhere(
            (user) => user.id == selectedInvites[roleId],
            orElse: () => UserProfile(
              id: '',
              name: 'Unknown',
              email: '',
              avatar: null,
              coinBalance: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          )
        : null;

    return GestureDetector(
      onTap: widget.networkUsers.isNotEmpty 
          ? () => setState(() => currentSelectingRole = roleId)
          : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6B46C1).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF6B46C1) : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF6B46C1) : Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    roleName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF6B46C1) : Colors.grey[700],
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (isSelected && selectedUser != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  UserAvatar(
                    avatarUrl: selectedUser.avatar,
                    initials: selectedUser.name.isNotEmpty ? selectedUser.name[0].toUpperCase() : '?',
                    radius: 8,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      selectedUser.name,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserSelectionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => currentSelectingRole = null),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Select ${_getRoleDisplayName(currentSelectingRole!)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: filteredNetworkUsers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No users in your network available for selection as officials.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredNetworkUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredNetworkUsers[index];
                    final isSelected = selectedInvites[currentSelectingRole] == user.id;
                    final existingRole = selectedInvites.entries
                        .where((entry) => entry.value == user.id && entry.key != currentSelectingRole)
                        .map((entry) => entry.key)
                        .firstOrNull;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: UserAvatar(
                          avatarUrl: user.avatar,
                          initials: user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          radius: 20,
                        ),
                        title: Text(
                          user.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getUserRolePreferences(user),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (existingRole != null)
                              Text(
                                'Already selected as ${_getRoleDisplayName(existingRole)}',
                                style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFF6B46C1))
                            : const Icon(Icons.circle_outlined, color: Colors.grey),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              // Deselect the current user
                              selectedInvites[currentSelectingRole!] = null;
                            } else {
                              // Check if this user is already selected for another role
                              final existingRole = selectedInvites.entries
                                  .where((entry) => entry.value == user.id)
                                  .map((entry) => entry.key)
                                  .firstOrNull;
                              
                              if (existingRole != null) {
                                // Remove from existing role and assign to current role
                                selectedInvites[existingRole] = null;
                              }
                              
                              selectedInvites[currentSelectingRole!] = user.id;
                            }
                            currentSelectingRole = null;
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final hasSelections = selectedInvites.values.any((id) => id != null);
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => widget.onSkip(),
              child: const Text(
                'Skip Personal Invites',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: hasSelections || filteredNetworkUsers.isEmpty
                  ? () => widget.onInviteSelectionComplete(selectedInvites)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B46C1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                hasSelections ? 'Send Invites' : 'Continue with Random',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDisplayName(String roleId) {
    switch (roleId) {
      case 'moderator':
        return 'Moderator';
      default:
        return 'Official';
    }
  }

  String _getUserRolePreferences(UserProfile user) {
    final canMod = user.isAvailableAsModerator;
    final canJudge = user.isAvailableAsJudge;
    
    if (canMod && canJudge) {
      return 'Available for moderator and judge roles';
    } else if (canMod) {
      return 'Available for moderator role';
    } else if (canJudge) {
      return 'Available for judge role';
    } else {
      return 'General network connection';
    }
  }
}
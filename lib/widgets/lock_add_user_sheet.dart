import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/database/user_helper.dart';
import 'package:ntry_mobile/widgets/lock_form_widgets.dart';

class LockAddUserSheet extends StatefulWidget {
  final String lockId;
  final String org;
  final VoidCallback onUserAdded;

  const LockAddUserSheet({
    super.key,
    required this.lockId,
    required this.org,
    required this.onUserAdded,
  });

  @override
  State<LockAddUserSheet> createState() => _LockAddUserSheetState();
}

class _LockAddUserSheetState extends State<LockAddUserSheet> {
  final _searchController = TextEditingController();
  late Future<List<_Candidate>> _candidatesFuture;
  String _query = '';
  String? _assigningUid;

  @override
  void initState() {
    super.initState();
    _candidatesFuture = _loadCandidates();
    _searchController.addListener(
      () => setState(
          () => _query = _searchController.text.toLowerCase().trim()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_Candidate>> _loadCandidates() async {
    final snap = await UserHelper().getUsersByOrg(
      widget.org,
      approvalStatus: 'approved',
      role: 'resident',
    );

    return snap.docs
        .map((doc) {
          final data = doc.data();
          return _Candidate(
            uid: doc.id,
            firstName: data['first_name'] as String? ?? '',
            lastName: data['last_name'] as String? ?? '',
            email: data['email'] as String? ?? '',
            currentLockId: data['lock_id'] as String?,
          );
        })
        .where((u) => u.currentLockId != widget.lockId)
        .toList();
  }

  List<_Candidate> _filtered(List<_Candidate> all) {
    if (_query.isEmpty) return all;
    return all
        .where((u) =>
            u.email.toLowerCase().contains(_query) ||
            u.firstName.toLowerCase().contains(_query) ||
            u.lastName.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _assign(_Candidate user) async {
    setState(() => _assigningUid = user.uid);
    try {
      await UserHelper().assignLock(user.uid, widget.lockId);
      widget.onUserAdded();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _assigningUid = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header + search ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add User',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Search by email, first name, or last name.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Results ──────────────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: FutureBuilder<List<_Candidate>>(
              future: _candidatesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final results = _filtered(snap.data ?? []);

                if (results.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No eligible users found.'
                            : 'No users match "$_query".',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final user = results[index];
                    final isAssigning = _assigningUid == user.uid;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            colors.primaryContainer.withAlpha(60),
                        child: Text(
                          lockInitials(user.firstName, user.lastName),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        '${user.firstName} ${user.lastName}'.trim(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.email,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          if (user.currentLockId != null)
                            Text(
                              'Currently assigned to another lock',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: colors.error.withAlpha(180),
                              ),
                            ),
                        ],
                      ),
                      trailing: isAssigning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : Icon(Icons.add_circle_outline,
                              color: colors.primary, size: 22),
                      onTap: isAssigning ? null : () => _assign(user),
                    );
                  },
                );
              },
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Internal Model ────────────────────────────────────────────────────────────

class _Candidate {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String? currentLockId;

  const _Candidate({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.currentLockId,
  });
}

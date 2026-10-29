import 'package:flutter/material.dart';

import '../../models/platform_policy.dart';

class PolicyReviewScreen extends StatefulWidget {
  final List<PlatformPolicy> policies;
  final Future<List<PlatformPolicy>> Function(List<PlatformPolicy> policies)
  onAccept;
  final Future<void> Function() onDecline;
  final VoidCallback onAccepted;

  const PolicyReviewScreen({
    super.key,
    required this.policies,
    required this.onAccept,
    required this.onDecline,
    required this.onAccepted,
  });

  @override
  State<PolicyReviewScreen> createState() => _PolicyReviewScreenState();
}

class _PolicyReviewScreenState extends State<PolicyReviewScreen> {
  late List<PlatformPolicy> _policies;
  final Set<int> _acknowledgedPolicyIds = <int>{};
  bool _submitting = false;
  bool _signingOut = false;

  bool get _allAcknowledged =>
      _policies.isNotEmpty &&
      _policies.every(
        (PlatformPolicy policy) => _acknowledgedPolicyIds.contains(policy.id),
      );

  @override
  void initState() {
    super.initState();
    _policies = List<PlatformPolicy>.of(widget.policies);
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFFB42318) : null,
        ),
      );
  }

  Future<void> _accept() async {
    if (!_allAcknowledged || _submitting || _signingOut) return;

    setState(() => _submitting = true);
    try {
      final List<PlatformPolicy> pending = await widget.onAccept(_policies);
      if (!mounted) return;

      if (pending.isEmpty) {
        widget.onAccepted();
        return;
      }

      setState(() {
        _policies = pending;
        _acknowledgedPolicyIds.clear();
      });
      _showMessage(
        'A policy changed while you were reviewing it. Please review the current version.',
        error: true,
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _decline() async {
    if (_signingOut || _submitting) return;
    setState(() => _signingOut = true);
    try {
      await widget.onDecline();
    } catch (error) {
      if (mounted) {
        setState(() => _signingOut = false);
        _showMessage(error.toString().replaceFirst('Exception: ', ''), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Policy updates'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.policy_outlined,
                            color: colors.primary,
                            size: 28,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Please review the updated policies',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Review and acknowledge each current policy to continue to your account.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final PlatformPolicy policy in _policies) ...[
                      _PolicyDocumentCard(
                        policy: policy,
                        acknowledged: _acknowledgedPolicyIds.contains(policy.id),
                        enabled: !_submitting && !_signingOut,
                        onAcknowledged: (bool value) {
                          setState(() {
                            if (value) {
                              _acknowledgedPolicyIds.add(policy.id);
                            } else {
                              _acknowledgedPolicyIds.remove(policy.id);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: _allAcknowledged && !_submitting && !_signingOut
                            ? _accept
                            : null,
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Accept and continue'),
                      ),
                      TextButton(
                        onPressed: _submitting || _signingOut ? null : _decline,
                        child: _signingOut
                            ? const Text('Signing out…')
                            : const Text('Decline and sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyDocumentCard extends StatelessWidget {
  final PlatformPolicy policy;
  final bool acknowledged;
  final bool enabled;
  final ValueChanged<bool> onAcknowledged;

  const _PolicyDocumentCard({
    required this.policy,
    required this.acknowledged,
    required this.enabled,
    required this.onAcknowledged,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<String> metadata = <String>[
      if (policy.version.trim().isNotEmpty) 'Version ${policy.version}',
      if (policy.effectiveDate?.trim().isNotEmpty == true)
        'Effective ${policy.effectiveDate}',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            policy.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              metadata.join('  •  '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SelectableText(
            policy.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: acknowledged,
            onChanged: enabled
                ? (bool? value) => onAcknowledged(value ?? false)
                : null,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('I have read and agree to this policy.'),
          ),
        ],
      ),
    );
  }
}

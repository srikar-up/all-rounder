import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/vault_rate_limiter.dart';
import '../services/vault_repository.dart';
import 'vault_home_screen.dart';
import 'vault_setup_screen.dart';
import 'vault_unlock_screen.dart';

class VaultGateScreen extends StatefulWidget {
  final VaultRepository repository;

  const VaultGateScreen({
    super.key,
    required this.repository,
  });

  @override
  State<VaultGateScreen> createState() => _VaultGateScreenState();
}

class _VaultGateScreenState extends State<VaultGateScreen> {
  final VaultRateLimiter _rateLimiter = VaultRateLimiter();

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.exists) {
      return VaultSetupScreen(
        repository: widget.repository,
        onSetupComplete: () => setState(() {}),
      );
    }

    if (!widget.repository.isUnlocked) {
      return VaultUnlockScreen(
        repository: widget.repository,
        rateLimiter: _rateLimiter,
        onUnlocked: () => setState(() {}),
      );
    }

    return VaultHomeScreen(
      repository: widget.repository,
      onLocked: () => setState(() {}),
    );
  }
}

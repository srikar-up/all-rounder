import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/vault_repository.dart';
import 'recovery_key_screen.dart';

class VaultSetupScreen extends StatefulWidget {
  final VaultRepository repository;
  final VoidCallback onSetupComplete;

  const VaultSetupScreen({
    super.key,
    required this.repository,
    required this.onSetupComplete,
  });

  @override
  State<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends State<VaultSetupScreen> {
  final TextEditingController _passphraseController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassphrase = true;
  bool _obscureConfirm = true;
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _getStrengthHint(String pass) {
    if (pass.isEmpty) return 'Enter at least 10 characters';
    if (pass.length < 10) return 'Too short (minimum 10 characters required)';
    if (pass.length < 14) return 'Moderate (14+ characters recommended)';
    final hasUpper = pass.contains(RegExp(r'[A-Z]'));
    final hasLower = pass.contains(RegExp(r'[a-z]'));
    final hasNumber = pass.contains(RegExp(r'[0-9]'));
    final hasSpecial = pass.contains(RegExp(r'[^A-Za-z0-9]'));
    if (hasUpper && hasLower && hasNumber && hasSpecial) {
      return 'Very Strong passphrase';
    }
    return 'Strong passphrase';
  }

  Color _getStrengthColor(String pass) {
    if (pass.length < 10) return AppColors.bentoCoral;
    if (pass.length < 14) return AppColors.bentoMarigold;
    return AppColors.bentoEmerald;
  }

  Future<void> _submit() async {
    final pass = _passphraseController.text;
    final confirm = _confirmController.text;

    if (pass.length < 10) {
      setState(() => _errorMessage = 'Passphrase must be at least 10 characters');
      return;
    }

    if (pass != confirm) {
      setState(() => _errorMessage = 'Passphrases do not match');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final recoveryCode = await widget.repository.create(pass);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecoveryKeyScreen(
            recoveryCode: recoveryCode,
            onConfirmed: () {
              Navigator.pop(context);
              widget.onSetupComplete();
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pass = _passphraseController.text;
    final strengthHint = _getStrengthHint(pass);
    final strengthColor = _getStrengthColor(pass);

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        title: Text(
          'Create Secure Vault',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252834) : const Color(0xFFFFE6E2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: AppColors.bentoCoral, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Zero-Knowledge Vault: Your files are encrypted with XChaCha20-Poly1305 and Argon2id. Lost credentials cannot be recovered by anyone.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passphraseController,
              obscureText: _obscurePassphrase,
              decoration: InputDecoration(
                labelText: 'Master Passphrase',
                filled: true,
                fillColor: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassphrase ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscurePassphrase = !_obscurePassphrase),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: strengthColor),
                const SizedBox(width: 6),
                Text(
                  strengthHint,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: strengthColor),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Passphrase',
                filled: true,
                fillColor: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.bentoCoral, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.iris,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isCreating ? null : _submit,
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Continue to Recovery Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

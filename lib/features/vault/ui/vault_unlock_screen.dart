import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/vault_rate_limiter.dart';
import '../services/vault_repository.dart';

class VaultUnlockScreen extends StatefulWidget {
  final VaultRepository repository;
  final VaultRateLimiter rateLimiter;
  final VoidCallback onUnlocked;
  final Future<bool> Function()? onBiometricPrompt;

  const VaultUnlockScreen({
    super.key,
    required this.repository,
    required this.rateLimiter,
    required this.onUnlocked,
    this.onBiometricPrompt,
  });

  @override
  State<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends State<VaultUnlockScreen> {
  final TextEditingController _inputController = TextEditingController();
  bool _useRecoveryMode = false;
  bool _obscureText = true;
  bool _isUnlocking = false;
  String? _errorMessage;
  int _lockoutSeconds = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _checkLockout();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final remaining = await widget.rateLimiter.remainingLockoutSeconds();
    if (remaining > 0) {
      setState(() => _lockoutSeconds = remaining);
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSeconds <= 1) {
        timer.cancel();
        setState(() => _lockoutSeconds = 0);
      } else {
        setState(() => _lockoutSeconds--);
      }
    });
  }

  Future<void> _attemptUnlock() async {
    if (_lockoutSeconds > 0) return;

    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isUnlocking = true;
      _errorMessage = null;
    });

    try {
      if (_useRecoveryMode) {
        await widget.repository.unlockWithRecoveryCode(text);
      } else {
        await widget.repository.unlockWithPassphrase(text);
      }

      await widget.rateLimiter.recordSuccess();
      if (!mounted) return;
      widget.onUnlocked();
    } catch (e) {
      final lockout = await widget.rateLimiter.recordFailure();
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isUnlocking = false;
          _lockoutSeconds = lockout;
        });
        if (lockout > 0) {
          _startCountdown();
        }
      }
    }
  }

  Future<void> _attemptBiometric() async {
    if (widget.onBiometricPrompt == null || _lockoutSeconds > 0) return;
    try {
      final success = await widget.onBiometricPrompt!();
      if (success && mounted) {
        await widget.rateLimiter.recordSuccess();
        widget.onUnlocked();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLockedOut = _lockoutSeconds > 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        title: Text(
          'Encrypted Vault',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252834) : const Color(0xFFFFF4DC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, color: AppColors.bentoMarigold, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  _useRecoveryMode ? 'Enter Recovery Key' : 'Unlock Your Vault',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _useRecoveryMode
                      ? 'Type the 32-byte recovery code you saved during setup'
                      : 'Protected with on-device XChaCha20-Poly1305 encryption',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                  ),
                ),
                const SizedBox(height: 28),
                if (isLockedOut)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bentoCoral.withAlpha(30),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, color: AppColors.bentoCoral, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Rate limit active: Try again in $_lockoutSeconds s',
                          style: const TextStyle(color: AppColors.bentoCoral, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _inputController,
                  obscureText: _useRecoveryMode ? false : _obscureText,
                  enabled: !isLockedOut && !_isUnlocking,
                  decoration: InputDecoration(
                    labelText: _useRecoveryMode ? 'Recovery Key (ABCD-EFGH-...)' : 'Master Passphrase',
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _useRecoveryMode
                        ? null
                        : IconButton(
                            icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                            onPressed: () => setState(() => _obscureText = !_obscureText),
                          ),
                  ),
                  onSubmitted: (_) => _attemptUnlock(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.bentoCoral, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.iris,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: isLockedOut || _isUnlocking ? null : _attemptUnlock,
                    child: _isUnlocking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Unlock Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.onBiometricPrompt != null && !isLockedOut)
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.fingerprint_rounded, color: AppColors.iris),
                    tooltip: 'Unlock with biometrics',
                    onPressed: _attemptBiometric,
                  ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _useRecoveryMode = !_useRecoveryMode;
                      _errorMessage = null;
                      _inputController.clear();
                    });
                  },
                  child: Text(
                    _useRecoveryMode ? '← Use master passphrase instead' : 'Forgot passphrase? Use recovery key',
                    style: TextStyle(
                      color: isDark ? AppColors.irisLight : AppColors.iris,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

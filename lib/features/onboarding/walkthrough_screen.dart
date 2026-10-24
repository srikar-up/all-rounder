import 'package:flutter/material.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../vault/services/vault_crypto_service.dart';

class WalkthroughScreen extends StatefulWidget {
  final VoidCallback onFinishOnboarding;

  const WalkthroughScreen({
    super.key,
    required this.onFinishOnboarding,
  });

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1: User Name
  final TextEditingController _nameController = TextEditingController(text: 'Anna Lane');

  // Step 2: Selected Bento Spaces
  final Set<String> _selectedSpaces = {
    'Lectures',
    'Media & Scans',
    'HTML Zines',
    'Fitness Log',
  };

  // Step 3: Vault Security Primer & Interactive Link Demo
  bool _biometricEnabled = true;
  bool _recoveryKeyConfirmed = false;
  late final String _recoveryKey;
  bool _hasLinkedDemo = false;

  @override
  void initState() {
    super.initState();
    _recoveryKey = VaultCryptoService.generateRecoveryKey();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 2) {
      _pageController.animateToPage(
        _currentStep + 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeWalkthrough();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.animateToPage(
        _currentStep - 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _completeWalkthrough() async {
    final prefs = AppPreferencesService.instance;
    await prefs.setUserName(_nameController.text.trim().isEmpty ? 'Anna Lane' : _nameController.text.trim());
    await prefs.setSelectedBentoSpaces(_selectedSpaces.toList());
    await prefs.setBiometricEnabled(_biometricEnabled);
    await prefs.setHasCompletedOnboarding(true);
    widget.onFinishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Indicator Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Step Indicator Dots
                  Row(
                    children: List.generate(3, (index) {
                      final isActive = index == _currentStep;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.iris
                              : (isDark ? const Color(0xFF2C2F3D) : const Color(0xFFD8D5CE)),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),

                  // Skip to App Button
                  GestureDetector(
                    onTap: _completeWalkthrough,
                    child: Text(
                      'Skip to App →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Walkthrough Content (PageView)
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Controlled via buttons for tactile feel
                onPageChanged: (page) => setState(() => _currentStep = page),
                children: [
                  _buildStep1Positioning(context, isDark),
                  _buildStep2PersonalizeSpaces(context, isDark),
                  _buildStep3SecurityAndMagicLink(context, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 1: POSITIONING & CORE PROMISE
  // =========================================================================
  Widget _buildStep1Positioning(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bento Hero Card (Lavender #B19CFF)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.bentoLavender,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.bentoLavender.withAlpha(70),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(160),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '🔒 100% On-Device · Zero Cloud',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkPrimaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your private\nsecond brain.',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: AppColors.inkPrimaryLight,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Notes, timetable, fitness, and files—linked together on your device. Zero cloud, zero trackers, zero accounts.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C2448),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
                // Decorative 3D badge in corner matching Prototype
                Positioned(
                  right: -12,
                  bottom: -12,
                  child: Transform.rotate(
                    angle: 0.18,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: AppColors.bentoMarigold,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withAlpha(90), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Transform.rotate(
                        angle: -0.18,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.bentoCoral,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text('🔗', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Two Value Pillar Cards
          _buildPillarTile(
            icon: Icons.code_rounded,
            iconBg: const Color(0xFFEAE6FD),
            iconColor: AppColors.iris,
            title: 'Markdown + HTML Document System',
            subtitle: 'Write fast .md notes or rich magazine-style .html sheets with custom offline CSS.',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildPillarTile(
            icon: Icons.folder_special_rounded,
            iconBg: const Color(0xFFFFE6E2),
            iconColor: AppColors.bentoCoral,
            title: 'Dedicated Media Folders & Standalone Photos',
            subtitle: 'Store lab diagrams, whiteboard photos and PDFs without needing a Markdown wrapper.',
            isDark: isDark,
          ),
          const SizedBox(height: 18),

          // Name Input field
          Text(
            'What should we call your space?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'e.g. Alex Lane',
              prefixIcon: const Icon(Icons.person_rounded, color: AppColors.iris, size: 20),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : const Color(0xFFE4E1DA),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : const Color(0xFFE4E1DA),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.iris, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Step 1 CTA
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF141416),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              elevation: 4,
            ),
            onPressed: _nextPage,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Choose Your Bento Folders',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 2: PERSONALIZE BENTO SPACES
  // =========================================================================
  Widget _buildStep2PersonalizeSpaces(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 2 of 3 · Personalize',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Pick your Bento spaces',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select which spaces you want visible on your home hub. You can always change this later.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
            ),
          ),
          const SizedBox(height: 18),

          // 2x2 Bento Chips Grid
          Row(
            children: [
              Expanded(
                child: _buildBentoSpaceChip(
                  title: 'Lectures',
                  subtitle: '.md, .html & slide photos',
                  icon: Icons.school_rounded,
                  color: AppColors.iris,
                  textColor: Colors.white,
                  isSelected: _selectedSpaces.contains('Lectures'),
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _selectedSpaces.contains('Lectures')
                          ? _selectedSpaces.remove('Lectures')
                          : _selectedSpaces.add('Lectures');
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBentoSpaceChip(
                  title: 'Media & Scans',
                  subtitle: 'Images, diagrams & PDFs',
                  icon: Icons.photo_library_rounded,
                  color: AppColors.bentoCoral,
                  textColor: Colors.white,
                  isSelected: _selectedSpaces.contains('Media & Scans'),
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _selectedSpaces.contains('Media & Scans')
                          ? _selectedSpaces.remove('Media & Scans')
                          : _selectedSpaces.add('Media & Scans');
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBentoSpaceChip(
                  title: 'HTML Zines',
                  subtitle: 'Custom HTML/CSS pages',
                  icon: Icons.code_rounded,
                  color: AppColors.bentoMarigold,
                  textColor: AppColors.inkPrimaryLight,
                  isSelected: _selectedSpaces.contains('HTML Zines'),
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _selectedSpaces.contains('HTML Zines')
                          ? _selectedSpaces.remove('HTML Zines')
                          : _selectedSpaces.add('HTML Zines');
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBentoSpaceChip(
                  title: 'Fitness Log',
                  subtitle: 'Steps & workout quota',
                  icon: Icons.directions_run_rounded,
                  color: AppColors.bentoEmerald,
                  textColor: Colors.white,
                  isSelected: _selectedSpaces.contains('Fitness Log'),
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _selectedSpaces.contains('Fitness Log')
                          ? _selectedSpaces.remove('Fitness Log')
                          : _selectedSpaces.add('Fitness Log');
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Actions Row (Back + Next)
          Row(
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(80, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: _prevPage,
                child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.iris,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    elevation: 4,
                  ),
                  onPressed: _nextPage,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Security & Magic Link',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.auto_awesome_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoSpaceChip({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color textColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 146,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withAlpha(isSelected ? 255 : 80),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.black.withAlpha(20),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withAlpha(80),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(isSelected ? 60 : 30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: isSelected ? textColor : textColor.withAlpha(150), size: 18),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.black26,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 14, color: color)
                          : null,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? textColor : textColor.withAlpha(180),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? textColor.withAlpha(200) : textColor.withAlpha(120),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Subtle side notch matching Target Image 2 & Prototype (.bento-notch)
          Positioned(
            right: -6,
            top: 56,
            child: Container(
              width: 12,
              height: 24,
              decoration: BoxDecoration(
                color: isDark ? AppColors.canvasDark : AppColors.canvasLight,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 3: VAULT QUICK SETUP & INTERACTIVE LINK GRAPH DEMO
  // =========================================================================
  Widget _buildStep3SecurityAndMagicLink(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Step 3 of 3 · The Superpower',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.iris,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bentoEmeraldSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '256-bit AES Vault',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.bentoEmerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Link Notes & Arm Your Vault',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Experience the magic link connecting a study pack to an alarm, and secure your master recovery key.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),

          // 1. INTERACTIVE LINK DEMO (Prototype lines 357-407)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bentoMarigold,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(160),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '🌐 HTML + 📝 MD · Lectures',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '+ 2 Images',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Physics: Wave Mechanics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.inkPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Includes interactive HTML formula card & whiteboard photo.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF4A3805), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Connector button with graph stems matching Prototype
          Center(
            child: Column(
              children: [
                Container(width: 2, height: 12, color: AppColors.iris.withAlpha(80)),
                GestureDetector(
                  onTap: () {
                    setState(() => _hasLinkedDemo = true);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _hasLinkedDemo ? AppColors.bentoEmerald : AppColors.iris,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: (_hasLinkedDemo ? AppColors.bentoEmerald : AppColors.iris).withAlpha(80),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasLinkedDemo ? Icons.check_circle_rounded : Icons.link_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _hasLinkedDemo ? 'Linked to 08:30 Alarm ✓' : 'Tap to Link to 08:30 Alarm',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 2, height: 12, color: AppColors.iris.withAlpha(80)),
              ],
            ),
          ),

          // Alarm Target Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _hasLinkedDemo ? AppColors.iris : (isDark ? AppColors.borderDark : AppColors.borderLight),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAE6FD),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.alarm_rounded, color: AppColors.iris, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '08:30 AM',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const Text(
                        'Prep for Physics Lecture',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      if (_hasLinkedDemo) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAE6FD),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '🔗 Physics: Wave Mechanics',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.iris,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 38,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.iris,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_hasLinkedDemo) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F9E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bentoEmerald.withAlpha(60)),
              ),
              child: const Text(
                '🎉 Connected! When your 08:30 alarm rings, your note & image folder open in one tap.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A7F37),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // 2. MASTER RECOVERY KEY DISPLAY
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1D26) : const Color(0xFFF1EFEA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF2C2F3D) : const Color(0xFFE4E1DA),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.vpn_key_rounded, size: 16, color: AppColors.iris),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Your 12-Word Recovery Key',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.bentoMarigold.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'SHOWN ONCE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF8C5D00)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _recoveryKey,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: _recoveryKeyConfirmed,
                      activeColor: AppColors.iris,
                      onChanged: (val) => setState(() => _recoveryKeyConfirmed = val ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'I have safely written down my 12-word master recovery key.',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Biometric Toggle Row
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded, color: AppColors.bentoEmerald, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Biometric Authentication', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text('Auto-lock vault when app is backgrounded', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _biometricEnabled = !_biometricEnabled),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    height: 28,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: _biometricEnabled ? AppColors.iris : (isDark ? const Color(0xFF2C2F3D) : const Color(0xFFD4D0C7)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _biometricEnabled ? AppColors.iris : (isDark ? Colors.white24 : const Color(0xFFBEB9AE)),
                        width: 1.2,
                      ),
                    ),
                    alignment: _biometricEnabled ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 23,
                      height: 23,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(55),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 1,
                            offset: const Offset(0, 0.5),
                          ),
                        ],
                      ),
                      child: _biometricEnabled
                          ? const Center(
                              child: Icon(Icons.check, size: 13, color: AppColors.iris),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // CTA: Enter All-Rounder
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _recoveryKeyConfirmed ? AppColors.iris : const Color(0xFF141416),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              elevation: 4,
            ),
            onPressed: _completeWalkthrough,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Enter All-Rounder',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

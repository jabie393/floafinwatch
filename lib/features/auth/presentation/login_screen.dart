import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    await ref.read(authNotifierProvider.notifier).login(
          _emailController.text,
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Liquid Glass Mesh
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF050B14), Color(0xFF0F1E33), Color(0xFF070F1E)]
                      : const [Color(0xFFE2F0FE), Color(0xFFF0F7FF), Color(0xFFE6EEF8)],
                ),
              ),
            ),
          ),

          // Subtle ambient glow orbs
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.15 : 0.25),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.12 : 0.2),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = constraints.maxHeight;
                final isCompact = maxHeight < 680;
                final isUltraCompact = maxHeight < 560;

                final double logoSize = isUltraCompact ? 48.0 : (isCompact ? 60.0 : 76.0);
                final double logoIconSize = isUltraCompact ? 28.0 : (isCompact ? 36.0 : 46.0);
                final double appTitleSize = isUltraCompact ? 18.0 : (isCompact ? 20.0 : 24.0);
                final double vSpacing = isUltraCompact ? 8.0 : (isCompact ? 14.0 : 20.0);

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(height: vSpacing * 0.5),

                                // App Icon Glass Squircle
                                Center(
                                  child: Container(
                                    width: logoSize,
                                    height: logoSize,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.65),
                                      borderRadius: BorderRadius.circular(isUltraCompact ? 16 : 24),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.8),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        'assets/images/app_logo.png',
                                        width: logoIconSize,
                                        height: logoIconSize,
                                        errorBuilder: (_, _, _) => Icon(
                                          Icons.account_balance_wallet_rounded,
                                          color: const Color(0xFF0284C7),
                                          size: logoIconSize * 0.9,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: vSpacing * 0.7),

                                // App Title RichText
                                Center(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: appTitleSize,
                                        fontWeight: FontWeight.bold,
                                        color: theme.textTheme.titleLarge?.color ??
                                            (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: 'F ',
                                          style: TextStyle(
                                            color: Color(0xFF0284C7),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        TextSpan(text: 'Loafinwatch'),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Subtitle
                                Text(
                                  'Sistem Monitoring Finansial LOA CIB',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isUltraCompact ? 12 : 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                SizedBox(height: vSpacing),

                                // Liquid Glass Card Container
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(26),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                    child: Container(
                                      padding: EdgeInsets.all(isUltraCompact ? 18 : 24),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.65),
                                        borderRadius: BorderRadius.circular(26),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.80),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                                            blurRadius: 24,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Form(
                                        key: _formKey,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Card Header badge & title
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0284C7)
                                                        .withValues(alpha: isDark ? 0.20 : 0.12),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(
                                                    Icons.login_rounded,
                                                    color: Color(0xFF0284C7),
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Masuk ke Akun',
                                                        style: TextStyle(
                                                          fontSize: 17,
                                                          fontWeight: FontWeight.w700,
                                                          color: isDark
                                                              ? Colors.white
                                                              : const Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Gunakan akun LOA Cahaya Ilmu Bangsa Anda',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isDark
                                                              ? const Color(0xFF94A3B8)
                                                              : const Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 20),

                                            // Error Banner
                                            if (authState.errorMessage != null) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 14, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444)
                                                      .withValues(alpha: isDark ? 0.15 : 0.10),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.error_outline_rounded,
                                                        color: Color(0xFFEF4444), size: 20),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        authState.errorMessage!,
                                                        style: const TextStyle(
                                                          color: Color(0xFFEF4444),
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                            ],

                                            // Email Input
                                            TextFormField(
                                              controller: _emailController,
                                              keyboardType: TextInputType.emailAddress,
                                              textInputAction: TextInputAction.next,
                                              style: TextStyle(
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                fontSize: 14.5,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: 'Email',
                                                labelStyle: TextStyle(
                                                  color: isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF64748B),
                                                ),
                                                hintText: 'nama@domain.com',
                                                hintStyle: TextStyle(
                                                  color: isDark
                                                      ? const Color(0xFF64748B)
                                                      : const Color(0xFF94A3B8),
                                                ),
                                                prefixIcon: Icon(
                                                  Icons.mail_outline_rounded,
                                                  size: 20,
                                                  color: isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF64748B),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white
                                                    .withValues(alpha: isDark ? 0.06 : 0.55),
                                                contentPadding: const EdgeInsets.symmetric(
                                                    horizontal: 16, vertical: 14),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  borderSide: BorderSide(
                                                    color: Colors.white
                                                        .withValues(alpha: isDark ? 0.12 : 0.70),
                                                    width: 1,
                                                  ),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  borderSide: const BorderSide(
                                                      color: Color(0xFF0284C7), width: 1.5),
                                                ),
                                                errorBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  borderSide: const BorderSide(
                                                      color: Color(0xFFEF4444), width: 1.2),
                                                ),
                                                focusedErrorBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  borderSide: const BorderSide(
                                                      color: Color(0xFFEF4444), width: 1.5),
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null || value.trim().isEmpty) {
                                                  return 'Email wajib diisi';
                                                }
                                                if (!value.contains('@') || !value.contains('.')) {
                                                  return 'Format email tidak valid';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 16),

                                            // Password Input
                                            TextFormField(
                                              controller: _passwordController,
                                              obscureText: _obscurePassword,
                                              textInputAction: TextInputAction.done,
                                              onFieldSubmitted: (_) => _handleLogin(),
                                              style: TextStyle(
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                fontSize: 14.5,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: 'Kata Sandi',
                                                labelStyle: TextStyle(
                                                  color: isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF64748B),
                                                ),
                                                prefixIcon: Icon(
                                                  Icons.lock_outline_rounded,
                                                  size: 20,
                                                  color: isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF64748B),
                                                ),
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _obscurePassword
                                                        ? Icons.visibility_outlined
                                                        : Icons.visibility_off_outlined,
                                                    size: 20,
                                                    color: isDark
                                                        ? const Color(0xFF94A3B8)
                                                        : const Color(0xFF64748B),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _obscurePassword = !_obscurePassword;
                                                    });
                                                  },
                                                ),
                                                filled: true,
                                                fillColor: Colors.white
                                                    .withValues(alpha: isDark ? 0.06 : 0.55),
                                                contentPadding: const EdgeInsets.symmetric(
                                                    horizontal: 16, vertical: 14),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  borderSide: BorderSide(
                                                    color: Colors.white
                                                        .withValues(alpha: isDark ? 0.12 : 0.70),
                                                    width: 1,
                                                  ),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  borderSide: const BorderSide(
                                                      color: Color(0xFF0284C7), width: 1.5),
                                                ),
                                                errorBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  borderSide: const BorderSide(
                                                      color: Color(0xFFEF4444), width: 1.2),
                                                ),
                                                focusedErrorBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  borderSide: const BorderSide(
                                                      color: Color(0xFFEF4444), width: 1.5),
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Kata sandi wajib diisi';
                                                }
                                                if (value.length < 6) {
                                                  return 'Kata sandi minimal 6 karakter';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 24),

                                            // Submit Button
                                            SizedBox(
                                              height: 50,
                                              child: ElevatedButton(
                                                onPressed: authState.isLoading ? null : _handleLogin,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF0284C7),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                ),
                                                child: authState.isLoading
                                                    ? const SizedBox(
                                                        width: 22,
                                                        height: 22,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Text(
                                                        'Masuk',
                                                        style: TextStyle(
                                                          fontSize: 15.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: vSpacing),

                                // Footer Security text
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.verified_user_outlined,
                                      size: 15,
                                      color: isDark
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Sesi login tersimpan secara aman pada perangkat.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: vSpacing * 0.5),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

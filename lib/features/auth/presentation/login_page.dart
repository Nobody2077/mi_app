import 'package:flutter/material.dart';

import '../../../app/app_assets.dart';
import '../../../app/ruta_facil_app.dart';
import '../../../core/constants/app_constants.dart';
import '../../home/presentation/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController(text: AppConstants.demoUser);
  final _passwordController = TextEditingController(
    text: AppConstants.demoPassword,
  );

  bool _obscurePassword = true;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;

    final isValidUser =
        _userController.text.trim() == AppConstants.demoUser &&
        _passwordController.text == AppConstants.demoPassword;

    if (!isValidUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario o contraseña incorrectos')),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(userName: _userController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = AppSettingsScope.maybeOf(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (settings != null)
              Positioned(
                right: 12,
                top: 8,
                child: IconButton(
                  tooltip: settings.isDarkMode ? 'Tema naranja' : 'Tema oscuro',
                  onPressed: () {
                    settings.setThemeMode(
                      settings.isDarkMode ? ThemeMode.light : ThemeMode.dark,
                    );
                  },
                  icon: Icon(
                    settings.isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
              ),
            Positioned(
              right: -64,
              top: 20,
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(AppAssets.mascot, width: 220),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(AppAssets.logo, height: 130),
                        const SizedBox(height: 18),
                        Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Transporte publico colaborativo',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rutas, tarifas y cambios reales de El Alto.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 28),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _userController,
                                  decoration: const InputDecoration(
                                    labelText: 'Usuario',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Ingresa tu usuario';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Contraseña',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Mostrar contraseña'
                                          : 'Ocultar contraseña',
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Ingresa tu contraseña';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed: _login,
                                  icon: const Icon(Icons.login),
                                  label: const Text('Ingresar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Demo: usuario admin, contraseña 1234',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

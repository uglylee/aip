import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final handleCtrl = TextEditingController();
  bool loading = false;
  String error = '';

  void doAuth() async {
    setState(() { loading = true; error = ''; });
    try {
      final result = isLogin
          ? await ApiService.login(emailCtrl.text, passwordCtrl.text)
          : await ApiService.register(usernameCtrl.text, handleCtrl.text, emailCtrl.text, passwordCtrl.text);
      if (result != null && result.containsKey('token')) {
        await ApiService.saveToken(result['token']);
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        setState(() { error = '认证失败，请检查输入'; loading = false; });
      }
    } catch (e) {
      setState(() { error = '网络错误: $e'; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text('X', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(isLogin ? '登录到 X' : '注册 X 账号', style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 32),
              if (!isLogin) ...[
                TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: '用户名', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: handleCtrl, decoration: const InputDecoration(labelText: '@用户名', border: OutlineInputBorder())),
                const SizedBox(height: 12),
              ],
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: '邮箱', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              if (error.isNotEmpty) ...[
                Text(error, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : doAuth,
                  child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isLogin ? '登录' : '注册'),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(isLogin ? '没有账号？注册' : '已有账号？登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

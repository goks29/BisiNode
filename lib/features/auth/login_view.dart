  import 'dart:async';
  import 'package:flutter/material.dart';
  import 'package:logbook_app_001/features/auth/login_controller.dart';
  import 'package:logbook_app_001/features/logbook/log_view.dart';

  class LoginView extends StatefulWidget {
    const LoginView({super.key});

    @override
    State<LoginView>createState()=> _LoginViewState();
  }

  class _LoginViewState extends State<LoginView> {
    final LoginController _controller = LoginController();
    final TextEditingController _userController = TextEditingController();
    final TextEditingController _passController = TextEditingController();

    bool _show = true;
    int _failedAttempts = 0;
    bool _isLocked = false;

    void _handleLogin() {
      String user = _userController.text;
      String pass = _passController.text;

      if (user.isEmpty || pass.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Username dan password tidak boleh kosong!"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }

      bool isSuccess = _controller.login(user, pass);

      if (isSuccess) {
        setState(() {
          _failedAttempts = 0;
        });

        String assignedRole = _controller.getRole(user);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:(context)=> LogView(username:user, role:assignedRole),
          ),
        );
      } else {
        setState(() {
          _failedAttempts++;
        });

        if(_failedAttempts >= 3) {
          setState(() {
            _isLocked = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Salah 3x! Tunggu 10 detik."),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 10),
            ),
          );

          Timer(const Duration(seconds:10), () {
            setState(() {
              _isLocked = false;
              _failedAttempts = 0;
            });
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Login Gagal! Sisa percobaan: ${3 - _failedAttempts}"),
              duration: Duration(seconds: 1)
            ),
          );
        }
      } 
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar:AppBar(title:const Text("Login Gatekeeper")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
              children: [
                TextField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText:"Username"),
                ),
                TextField(
                  controller: _passController,
                  obscureText: _show,
                  decoration: InputDecoration(
                    labelText:"Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _show ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _show = !_show;
                        });
                      },
                    )
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: 500,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLocked ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLocked ? Colors.grey : Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isLocked ? "Tunggu 10 Detik" : "Masuk")
                  )
                )
              ],
          ),
        ),
      );
    }
  }
class LoginController {
  final Map<String, Map<String,String>> _account = {
    'admin': {'password': '123', 'role': 'Ketua'},
    'king': {'password': '123', 'role': 'Asisten'},
    'ayam': {'password': '123', 'role': 'Anggota'},
  };

  bool login(String username, String password) {
    if (_account.containsKey(username)) {
      String correctPassword = _account[username]!['password']!;

      if (correctPassword == password) {
        return true;
      }
    } 
    return false;
  }

  String getRole(String username) {
    return _account[username]?['role'] ?? 'Anggota';
  }
}
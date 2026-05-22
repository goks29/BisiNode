import 'package:flutter_dotenv/flutter_dotenv.dart';

class AccessControlService {
  static List<String> get availableRoles => 
      dotenv.env['APP_ROLES']?.split(',') ?? ['Anggota']; 
  
  static const String actionCreate = 'create';
  static const String actionRead = 'read';
  static const String actionUpdate = 'update';
  static const String actionDelete = 'delete';  

  static final Map<String, List<String>> _rolePermission = {
    'Ketua' : [actionCreate, actionRead, actionUpdate, actionDelete],
    'Anggota' : [actionCreate, actionRead],
    'Asisten' : [actionRead, actionUpdate], 
  };

  static bool canPerform(String role, String action, {bool isOwner = false}) {
    final permissions = _rolePermission[role] ?? [];
    bool hasBasicPermission = permissions.contains(action);

    if (role == 'Anggota' && (action == actionUpdate || action == actionDelete)) {
      return isOwner;
    }
    return hasBasicPermission;
  }

}
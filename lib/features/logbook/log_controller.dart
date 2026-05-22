import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';

class LogController {
  final String username;
  final String role;
  
  late final dynamic currentUser;

  final ValueNotifier<List<LogModel>> logsNotifier = ValueNotifier([]);
  final ValueNotifier<List<LogModel>> filteredLogs = ValueNotifier([]);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<bool> isOffline = ValueNotifier(false);
  bool isOff = false;

  LogController(this.username, this.role) {
    currentUser = (id: username, role:role, teamId: 'team_polban_01');
  }

  Future<void> initDatabase() async {
    isLoading.value = true; 
    try {
      await LogHelper.writeLog("CONTROLLER: Memulai inisialisasi...", source: "log_controller.dart");

      await MongoService().connect(username).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception("Koneksi Cloud Timeout. Periksa sinyal/IP Whitelist."),
      );

      isOffline.value = false;
      await loadFromDisk(); 
      await LogHelper.writeLog("CONTROLLER: Data berhasil dimuat.", source: "log_controller.dart");
    } catch (e) {
      isOffline.value = true;
      await LogHelper.writeLog("CONTROLLER: Error - $e", level: 1);
      await loadFromDisk();
    } finally {
      isLoading.value = false; 
    }
  }


  Future<void> addLog(String title, String desc, String category, bool public) async {
    final newLog = LogModel(
      id: ObjectId().oid, 
      title: title,
      description: desc,
      date: DateTime.now(),
      category: category,
      authorId: currentUser.id,   
      teamId: currentUser.teamId,  
      isSynced: false,
      isPublic: public,
    );

    final box = Hive.box<LogModel>('offline_logs');
    await box.put(newLog.id.toString(), newLog);

    logsNotifier.value = [...logsNotifier.value, newLog];
    filteredLogs.value = logsNotifier.value;
    
    try {
      await MongoService().insertLog(newLog);
      newLog.isSynced = true;
      await box.put(newLog.id.toString(), newLog);

      logsNotifier.value = List.from(logsNotifier.value);
      filteredLogs.value = List.from(logsNotifier.value);

    } catch (e) {
      LogHelper.writeLog("Gagal tambah log: $e", level: 1);
    }
  }

  Future<void> updateLog(int index, String title, String desc, String category, bool public) async {
    final logToUpdate = filteredLogs.value[index];
    
    final updatedLog = LogModel(
      id: logToUpdate.id, 
      title: title,
      description: desc,
      date: DateTime.now(), 
      category: category,
      authorId: logToUpdate.authorId, 
      teamId: logToUpdate.teamId,     
      isPublic: public,
    );

    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final realIndex = logsNotifier.value.indexOf(logToUpdate);
      
    if (realIndex != -1) {
      currentLogs[realIndex] = updatedLog;
      logsNotifier.value = currentLogs;
      filteredLogs.value = currentLogs;
    }

    try{
      final box = Hive.box<LogModel>('offline_logs');
      await box.put(updatedLog.id.toString(), updatedLog);
    } catch (e) {
      LogHelper.writeLog("HIVE ERROR: Gagal update lokal - $e", level: 1);
    }

    try {
      await MongoService().updateLog(updatedLog);
    } catch (e) {
      LogHelper.writeLog("Gagal update log: $e", level: 1);
    }
  }


  Future<void> removeLog(int index) async {
    final logToRemove = filteredLogs.value[index];
    
    try {
      bool canDelete = (logToRemove.authorId == currentUser.id);

      if (!canDelete) {
        await LogHelper.writeLog("SECURITY: Unauthorized delete attempt by ${currentUser.id}", level: 1);
        return;
      } 

      if (logToRemove.id != null) {
        await MongoService().deleteLog(logToRemove.id!);

        final box = Hive.box<LogModel>('offline_logs');
        await box.delete(logToRemove.id.toString());

        final currentLogs = List<LogModel>.from(logsNotifier.value);
        currentLogs.removeWhere((item) => item.id == logToRemove.id);

        
        logsNotifier.value = currentLogs;
        filteredLogs.value = List.from(currentLogs);
      }
    } catch (e) {
      LogHelper.writeLog("Gagal hapus log: $e", level: 1);
    }
  }


  Future<void> loadFromDisk() async {
    final box = Hive.box<LogModel>('offline_logs');
    
    try {
      //Ambil data terbaru dari Cloud (MongoDB)
      final cloudData = await MongoService().getLogs();
      final localData = box.values.toList();
      
      for (var localLog in localData) {
        bool existInCloud = cloudData.any((cloudLog) => cloudLog.id == localLog.id);
        if (!existInCloud) {
          await LogHelper.writeLog("Mendorong data offline ke Cloud: ${localLog.title}");
          try {
            await MongoService().insertLog(localLog);
            localLog.isSynced = true;
            cloudData.add(localLog);
          } catch (e) {
            LogHelper.writeLog("Gagal push data offline: $e");
            cloudData.add(localLog);
          }
        }
      }

      await box.clear();
      for (var log in cloudData) {
        await box.put(log.id.toString(), log);
      }

      final visibleLogs = cloudData.where((log) {
        return log.authorId == currentUser.id || log.isPublic == true;
      }).toList();
      
      logsNotifier.value = visibleLogs;
    } catch (e) {
      //Jika gagal/offline, ambil data dari Hive saja
      await LogHelper.writeLog("Offline Mode: Mengambil data dari local storage.");
      final localVisibileLogs = box.values.where((log) {
        return log.authorId == currentUser.id || log.isPublic == true;
      }).toList();

      logsNotifier.value = localVisibileLogs;
    } finally {
      filteredLogs.value = logsNotifier.value;
    }
  }


  void searchLog(String query) {
    if (query.isEmpty) {
      filteredLogs.value = logsNotifier.value;
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredLogs.value = logsNotifier.value.where((log) => log.title.toLowerCase().contains(lowerCaseQuery) || 
                           log.description.toLowerCase().contains(query.toLowerCase())).toList();
    }
  }

  void setUpNetworkListener() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      if (isOff) return;
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        isOffline.value = false;
        await _syncOfflineLogs();
      } else {
        isOffline.value = true;
      }
    });
  }

  Future<void> _syncOfflineLogs() async {
    final box = Hive.box<LogModel>('offline_logs');
    final offlineLogs = box.values.where((log) => log.isSynced == false).toList();

    if (offlineLogs.isEmpty) return;

    LogHelper.writeLog("Koneksi terdeteksi. Memulai auto-sync ${offlineLogs.length} catatan...");

    for (var log in offlineLogs) {
      try {
        await MongoService().insertLog(log);
        log.isSynced = true;
        await box.put(log.id.toString(), log);
      } catch (e) {
        LogHelper.writeLog("Gagal auto-sync catatan ${log.title}: $e");
      }
    }

    await loadFromDisk();
  }
}
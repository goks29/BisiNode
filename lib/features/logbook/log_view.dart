import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:logbook_app_001/features/logbook/log_controller.dart';
import 'package:logbook_app_001/features/auth/login_view.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/features/logbook/log_editor_page.dart';
// Import Baru
import 'package:logbook_app_001/features/vision/camera_viewport.dart';


class LogView extends StatefulWidget {
  final String username;
  final String role;

  const LogView({super.key, required this.username, required this.role});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final LogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LogController(widget.username, widget.role);
    _controller.setUpNetworkListener();
    Future.microtask(
      () => _controller.initDatabase().catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white),
                  Expanded(
                    child: Text("Offline Mode: Tidak dapat tersambung ke database"),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Mechanical':
        return Colors.red.shade100;
      case 'Software':
        return Colors.blue.shade100;
      case 'Electronic':
      default:
        return Colors.green.shade100;
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Konfirmasi Logout"),
          content: const Text(
            "Apakah Anda yakin? Data yang belum disimpan mungkin akan hilang.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () {
                _controller.isOff = true;
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginView()),
                  (route) => false,
                );
              },
              child: const Text(
                "Ya, Keluar",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Logbook: ${widget.username}"),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout),
          // --- TOMBOL VISION BARU (Module 6) ---
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CameraViewport()),
              );
            },
            tooltip: 'Smart Patrol Vision',
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _controller.isLoading,
        builder: (context, loading, child) {
          if (loading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Menghubungkan data ke databse"),
                ],
              ),
            );
          }
          //search bar
          return Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _controller.isOffline,
                builder: (context, isOffline, child) {
                  if (!isOffline) return const SizedBox.shrink();

                  return Container(
                    width: double.infinity,
                    color: Colors.orange.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_off, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Mode Offline Aktif. Perubahan disimpan di perangkat dan akan disinkronkan otomatis saat online.",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } 
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: (value) => _controller.searchLog(value),
                  decoration: InputDecoration(
                    labelText: "Cari Catatan...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15.0),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15.0),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              //list log kosong
              Expanded(
                child: ValueListenableBuilder<List<LogModel>>(
                  valueListenable: _controller.filteredLogs,
                  builder: (context, currentLogs, child) {
                    if (currentLogs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/empty.json',
                              width: 250, 
                              height: 250,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.inbox_outlined,
                                  size: 100,
                                  color: Colors.grey,
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32.0),
                              child: Text(
                               "Belum ada aktivitas hari ini?\nMulai catat kemajuan proyek Anda!",
                               textAlign: TextAlign.center,
                               style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                               ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LogEditorPage(
                                      controller: _controller,
                                      currentUser: _controller.currentUser,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit_document),
                              label: const Text("Buat Catatan Pertama"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    //refresh
                    return RefreshIndicator(
                      color: Colors.blue,
                      backgroundColor: Colors.white,
                      onRefresh: () async {
                        await _controller.loadFromDisk();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Data berhasil diperbaharui"),
                              duration: Duration(seconds:1),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },

                      //list log ada
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: currentLogs.length,
                        itemBuilder: (context, index) {
                          final log = currentLogs[index];

                          bool isOwner = (log.authorId == _controller.currentUser.id);

                          return Dismissible(
                            key: Key(log.id?.toString() ?? log.date.toString()),
                            direction: isOwner ? DismissDirection.endToStart : DismissDirection.none,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (direction) => _controller.removeLog(index),
                            child: Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: _getCategoryColor(log.category),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300, width: 0.5), // Garis pinggir tipis
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16), 
                                
                                leading: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      log.isSynced ? Icons.cloud_done : Icons.cloud_off,
                                      color: log.isSynced ? Colors.green.shade600 : Colors.orange.shade600,
                                      size: 28,
                                    ),
                                  ],
                                ),
                                
                                // judul
                                title: Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
                                  child: Text(
                                    log.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                
                                // Deskripsi, Author, Tanggal
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                    
                                    Row(
                                      children: [
                                        Icon(Icons.person, size: 16, color: Colors.blueGrey.shade700),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            log.authorId,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blueGrey.shade800,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white60,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            log.category,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${DateFormat.yMMMMEEEEd('id').format(log.date)} • ${DateFormat('HH:mm').format(log.date)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          log.isPublic ? Icons.public : Icons.lock,
                                          size: 16,
                                          color: log.isPublic ? Colors.blue.shade600 : Colors.grey.shade600,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                // edit dan hapus
                                trailing: isOwner 
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            constraints: const BoxConstraints(), 
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => LogEditorPage(
                                                    log: log,
                                                    index: index,
                                                    controller: _controller,
                                                    currentUser: _controller.currentUser,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            onPressed: () => _controller.removeLog(index),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : null, 
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      //add button
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogEditorPage(
                controller: _controller,
                currentUser: _controller.currentUser,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

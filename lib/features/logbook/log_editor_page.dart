import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/features/logbook/log_controller.dart';


class LogEditorPage extends StatefulWidget {
  final LogModel? log;
  final int? index;
  final LogController controller;
  final dynamic currentUser;


  const LogEditorPage({
    super.key,
    this.log,
    this.index,
    required this.controller,
    required this.currentUser,
  });


  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}


class _LogEditorPageState extends State<LogEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  String _selectedCategory = 'Software';
  bool _isPublic = false;


  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.log?.title ?? '');
    _descController = TextEditingController(text: widget.log?.description ?? '',);
    _selectedCategory = widget.log?.category ?? 'Software';
    _isPublic = widget.log?.isPublic ?? false;


    _descController.addListener(() {
      setState(() {});
    });
  }


  void _save() async {
  if (_titleController.text.isEmpty || _descController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Judul dan deskripsi tidak boleh kosong")),
    );
    return;
  }

  if (widget.log == null) {
    await widget.controller.addLog(
      _titleController.text,
      _descController.text,
      _selectedCategory, 
      _isPublic,
    );
  } else {
    await widget.controller.updateLog(
      widget.index!,
      _titleController.text,
      _descController.text,
      _selectedCategory,
      _isPublic,
    );
  }
  Navigator.pop(context);
}


  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.log == null ? "Catatan Baru" : "Edit Catatan"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Editor"),
              Tab(text: "Pratinjau"),
            ],
          ),
          actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: "Judul"),
                  ),
                  const SizedBox(height: 15),
       
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: "Kategori",
                      border: OutlineInputBorder(),
                    ),
                    items: ['Mechanical', 'Electronic', 'Software'].map((String category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                  ),
                  
                  SwitchListTile(
                    title: const Text("Publikasikan?"),
                    subtitle: const Text("Bisa dilihat anggota Tim"),
                    value: _isPublic,
                    onChanged: (value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  
                  Expanded(
                    child: TextField(
                      controller: _descController,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: "Tulis laporan dengan format Markdown...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Markdown(
              data: _descController.text,
              selectable: true,
            ),
          ],
        ),
      ),
    );
  }
}

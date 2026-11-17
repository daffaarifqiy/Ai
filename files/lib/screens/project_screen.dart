import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/app_services.dart';
import '../services/settings_service.dart';
import '../services/github_service.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  List<String> _projects = [];
  String? _selectedProject;
  List<File> _files = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projs = await ProjectService.getAllProjects();
    setState(() => _projects = projs);
  }

  Future<void> _loadFiles(String project) async {
    final files = await ProjectService.getFilesInProject(project);
    setState(() {
      _selectedProject = project;
      _files = files;
    });
  }

  Future<void> _createNewProject() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Project Baru', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nama Folder Project', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Buat'),
          )
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await ProjectService.createProject(name);
      _loadProjects();
    }
  }

  Future<void> _addFile() async {
    if (_selectedProject == null) return;
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      for (var file in result.files) {
        if (file.path != null) {
          await ProjectService.addFileToProject(_selectedProject!, File(file.path!));
        }
      }
      _loadFiles(_selectedProject!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File ditambahkan')));
    }
  }

  Future<void> _uploadToGithub() async {
    if (_selectedProject == null || _files.isEmpty) return;
    
    final token = await SettingsService.getGithubToken();
    final repoUrl = await SettingsService.getGithubRepo();

    if (token.isEmpty || repoUrl.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            title: const Text('GitHub Belum Diatur', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Silakan atur GitHub Token dan URL Repo di menu Pengaturan terlebih dahulu.\n\n'
              'PENTING: Pastikan Repo GitHub kamu bersifat PUBLIK agar file bisa diunggah.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);
    
    try {
      for (var file in _files) {
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        final ghPath = 'projects/$_selectedProject/${file.uri.pathSegments.last}';
        
        await GitHubService.uploadBase64File(
          token: token,
          repoUrl: repoUrl,
          path: ghPath,
          base64Content: base64String,
          message: 'Upload file ${file.uri.pathSegments.last}',
        );
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil transfer ke GitHub')));
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            title: const Text('Gagal Upload', style: TextStyle(color: Colors.redAccent)),
            content: Text('$e', style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedProject == null ? 'Project Explorer' : _selectedProject!),
        leading: _selectedProject != null 
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedProject = null))
            : null,
        actions: [
          if (_selectedProject != null)
            IconButton(
              tooltip: 'Transfer ke GitHub',
              icon: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload),
              onPressed: _isUploading ? null : _uploadToGithub,
            ),
        ],
      ),
      body: _selectedProject == null ? _buildProjectList() : _buildFileList(),
      floatingActionButton: _selectedProject != null
          ? FloatingActionButton(
              onPressed: _addFile,
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              onPressed: _createNewProject,
              child: const Icon(Icons.create_new_folder),
            ),
    );
  }

  Widget _buildProjectList() {
    if (_projects.isEmpty) return const Center(child: Text('Belum ada project. Buat baru!'));
    return ListView.builder(
      itemCount: _projects.length,
      itemBuilder: (ctx, i) {
        return ListTile(
          leading: const Icon(Icons.folder, color: Colors.deepPurpleAccent),
          title: Text(_projects[i]),
          onTap: () => _loadFiles(_projects[i]),
        );
      },
    );
  }

  Widget _buildFileList() {
    if (_files.isEmpty) return const Center(child: Text('Folder kosong. Tambah file dengan tombol +'));
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (ctx, i) {
        final file = _files[i];
        final fileName = file.uri.pathSegments.last;
        final isImage = fileName.endsWith('.png') || fileName.endsWith('.jpg') || fileName.endsWith('.jpeg');
        
        return ListTile(
          leading: isImage 
              ? Image.file(file, width: 40, height: 40, fit: BoxFit.cover)
              : const Icon(Icons.insert_drive_file),
          title: Text(fileName),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () async {
              await ProjectService.deleteFile(_selectedProject!, file);
              _loadFiles(_selectedProject!);
            },
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/role.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});
  @override State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<Role> roles = Role.defaults();
  String currentRoleId = 'default';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    currentRoleId = prefs.getString('current_role_id') ?? 'default';
    final str = prefs.getString('roles');
    if (str != null) {
      try {
        final list = (jsonDecode(str) as List).map((e) => Role(id: e['id'], name: e['name'], systemPrompt: e['systemPrompt'] ?? '', deletable: e['deletable'] ?? true)).toList();
        final defaults_ = Role.defaults();
        final merged = <Role>[...defaults_];
        for (final l in list) {
          if (!defaults_.any((d) => d.id == l.id)) merged.add(l);
        }
        roles = merged;
      } catch (_) {}
    }
    setState(() {});
  }

  void _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_role_id', currentRoleId);
    final currentRole = roles.firstWhere((r) => r.id == currentRoleId, orElse: () => roles.first);
    await prefs.setString('current_role_prompt', currentRole.systemPrompt);
    await prefs.setString('roles', jsonEncode(roles.map((r) => {'id': r.id, 'name': r.name, 'systemPrompt': r.systemPrompt, 'deletable': r.deletable}).toList()));
  }

  void _showAddDialog({Role? edit}) {
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    final promptCtrl = TextEditingController(text: edit?.systemPrompt ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(edit != null ? '编辑角色' : '新建角色'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '角色名称')),
            const SizedBox(height: 8),
            TextField(controller: promptCtrl, decoration: const InputDecoration(labelText: '系统提示词'), maxLines: 5),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () {
            if (nameCtrl.text.isNotEmpty) {
              if (edit != null) {
                roles = roles.map((r) => r.id == edit.id ? Role(id: r.id, name: nameCtrl.text, systemPrompt: promptCtrl.text, deletable: r.deletable) : r).toList();
              } else {
                roles = [...roles, Role(id: 'role_${DateTime.now().millisecondsSinceEpoch}', name: nameCtrl.text, systemPrompt: promptCtrl.text)];
              }
              _save();
              Navigator.pop(ctx);
              setState(() {});
            }
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('角色管理'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddDialog())],
      ),
      body: ListView.separated(
        itemCount: roles.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final role = roles[i];
          final isSelected = role.id == currentRoleId;
          return ListTile(
            leading: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? const Color(0xFF1DA1F2) : Colors.grey),
            title: Text(role.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text(role.systemPrompt.isEmpty ? '无系统提示词' : role.systemPrompt, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: role.deletable ? IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () {
              setState(() { roles = roles.where((r) => r.id != role.id).toList(); });
              if (currentRoleId == role.id) { currentRoleId = 'default'; }
              _save();
            }) : null,
            onTap: () {
              setState(() { currentRoleId = role.id; });
              _save();
            },
          );
        },
      ),
    );
  }
}

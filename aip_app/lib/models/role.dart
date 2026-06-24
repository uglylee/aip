class Role {
  final String id, name, systemPrompt;
  final bool deletable;
  Role({required this.id, required this.name, this.systemPrompt = '', this.deletable = true});

  static List<Role> defaults() => [
    Role(id: 'default', name: '默认', deletable: false),
    Role(id: 'translator', name: '翻译助手', systemPrompt: '你是翻译器。规则：1.检测用户输入的语言，如果是中文就翻译成英文，如果是英文就翻译成中文，如果是中英混合就翻译成纯英文；2.只输出翻译结果，不要解释、不要问候、不要任何多余内容；3.保持原文语气和含义。', deletable: false),
  ];
}

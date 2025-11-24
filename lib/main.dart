import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart'; // Para Hash de senha
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatação de data
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart'; // Máscara CPF
import 'package:path/path.dart' as path; // IMPORT CORRIGIDO (aliased)
import 'package:provider/provider.dart'; // Gerencia Estado
import 'package:sqflite/sqflite.dart'; // Banco de Dados

void main() {
  // Garante que os bindings do Flutter estejam inicializados antes do DB
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Injeção de Dependências (ViewModels)
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => AnalyzerViewModel()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Analisador Completo MVVM',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const TelaLogin(),
          '/cadastro': (context) => const TelaCadastro(),
          '/principal': (context) => const TelaPrincipal(),
          '/resultados': (context) => const TelaResultados(),
        },
      ),
    );
  }
}

// ============================================================================
// CAMADA 1: MODEL (Entidade de Dados)
// ============================================================================

class Usuario {
  final int? id;
  final String nome;
  final String cpf;
  final String dataNascimento;
  final String email;
  final String senhaHash;

  Usuario({
    this.id,
    required this.nome,
    required this.cpf,
    required this.dataNascimento,
    required this.email,
    required this.senhaHash,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'cpf': cpf,
      'dataNascimento': dataNascimento,
      'email': email,
      'senhaHash': senhaHash,
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'],
      nome: map['nome'],
      cpf: map['cpf'],
      dataNascimento: map['dataNascimento'],
      email: map['email'],
      senhaHash: map['senhaHash'],
    );
  }
}

// ============================================================================
// CAMADA 2: SERVICE (Banco de Dados e Lógica de Negócio Pura)
// ============================================================================

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    
    // CORREÇÃO DO CAMINHO DO ARQUIVO
    final dbLocation = path.join(dbPath, 'analisador_app.db');

    return await openDatabase(
      dbLocation,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE usuarios(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT,
            cpf TEXT,
            dataNascimento TEXT,
            email TEXT,
            senhaHash TEXT
          )
        ''');
      },
    );
  }

  // Criar Hash SHA-256 da senha
  String generateMd5(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  // Salvar Usuário
  Future<int> registrarUsuario(Usuario usuario) async {
    final db = await database;
    return await db.insert('usuarios', usuario.toMap());
  }

  // Buscar Usuário (Login)
  Future<Usuario?> login(String email, String senha) async {
    final db = await database;
    final senhaHash = generateMd5(senha);

    final List<Map<String, dynamic>> maps = await db.query(
      'usuarios',
      where: 'email = ? AND senhaHash = ?',
      whereArgs: [email, senhaHash],
    );

    if (maps.isNotEmpty) {
      return Usuario.fromMap(maps.first);
    }
    return null;
  }
}

// ============================================================================
// CAMADA 3: VIEWMODELS (Gerenciamento de Estado e Validações)
// ============================================================================

// ViewModel de Autenticação
class AuthViewModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  
  Usuario? _usuarioLogado;
  Usuario? get usuarioLogado => _usuarioLogado;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // --- Estado do Cadastro (Validações de Senha) ---
  bool hasUpper = false;
  bool hasLower = false;
  bool hasDigit = false;
  bool hasSpecial = false;
  bool passwordsMatch = false;
  
  void updatePasswordStrength(String password, String confirmPassword) {
    hasUpper = password.contains(RegExp(r'[A-Z]'));
    hasLower = password.contains(RegExp(r'[a-z]'));
    hasDigit = password.contains(RegExp(r'[0-9]'));
    hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    passwordsMatch = password == confirmPassword && password.isNotEmpty;
    notifyListeners();
  }

  bool get isFormValid => hasUpper && hasLower && hasDigit && hasSpecial && passwordsMatch;

  // Ação de Registro
  Future<bool> cadastrar(String nome, String cpf, String dataNasc, String email, String senha) async {
    _isLoading = true;
    notifyListeners();

    try {
      final novoUsuario = Usuario(
        nome: nome,
        cpf: cpf,
        dataNascimento: dataNasc,
        email: email,
        senhaHash: _dbService.generateMd5(senha),
      );
      await _dbService.registrarUsuario(novoUsuario);
      return true;
    } catch (e) {
      debugPrint("Erro no cadastro: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Ação de Login
  Future<bool> login(String email, String senha) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _dbService.login(email, senha);
      if (user != null) {
        _usuarioLogado = user;
        return true;
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _usuarioLogado = null;
    notifyListeners();
  }
}

// ViewModel do Analisador (Lógica da Unidade 1/2)
class AnalyzerViewModel extends ChangeNotifier {
  Map<String, dynamic>? _resultados;
  Map<String, dynamic>? get resultados => _resultados;

  void analisarTexto(String texto) {
    final charCount = texto.length;
    final charCountNoSpaces = texto.replaceAll(" ", "").length;
    final words = texto.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final wordCount = words.length;
    final sentenceCount = texto.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).length;
    final readingTime = wordCount / 250;

    // Lógica Top Words
    const stopwords = ["a", "o", "que", "de", "para", "com", "sem", "mas", "e", "ou", "em", "por", "da", "do", "um", "uma"];
    final cleanWords = texto.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !stopwords.contains(w))
        .toList();
    
    final Map<String, int> freq = {};
    for (var w in cleanWords) {
      freq[w] = (freq[w] ?? 0) + 1;
    }
    final topWords = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    _resultados = {
      'textoOriginal': texto,
      'charCount': charCount,
      'charCountNoSpaces': charCountNoSpaces,
      'wordCount': wordCount,
      'sentenceCount': sentenceCount,
      'readingTime': readingTime,
      'topWords': topWords.take(10).toList(),
    };
    notifyListeners();
  }
}

// ============================================================================
// CAMADA 4: VIEWS (Telas)
// ============================================================================

// --- TELA 2: LOGIN ---
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.analytics, size: 80, color: Colors.indigo),
                  const SizedBox(height: 16),
                  const Text(
                    "Analisador de Texto",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "E-mail",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || !value.contains('@')) {
                        return 'Insira um e-mail válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senhaController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: "Senha",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
                      ),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Insira a senha' : null,
                  ),
                  const SizedBox(height: 24),
                  authVM.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              bool success = await authVM.login(
                                _emailController.text,
                                _senhaController.text,
                              );
                              
                              // Verificação de montagem do widget antes de navegar
                              if (!mounted) return;

                              if (success) {
                                Navigator.pushReplacementNamed(context, '/principal');
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("E-mail ou senha inválidos")),
                                );
                              }
                            }
                          },
                          child: const Text("Entrar", style: TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/cadastro'),
                    child: const Text("Ainda não tem conta? Cadastre-se"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- TELA 1: CADASTRO ---
class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _cpfController = TextEditingController();
  final _dataNascController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmaSenhaController = TextEditingController();
  
  bool _obscureText = true;

  // Máscara de CPF
  final maskFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##', 
    filter: { "#": RegExp(r'[0-9]') },
    type: MaskAutoCompletionType.lazy
  );

  void _checkPassword() {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    authVM.updatePasswordStrength(_senhaController.text, _confirmaSenhaController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro de Usuário")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Nome Completo
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: "Nome Completo", border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Obrigatório';
                  if (value.trim().split(' ').length < 2) return 'Digite nome e sobrenome';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // CPF
              TextFormField(
                controller: _cpfController,
                inputFormatters: [maskFormatter],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "CPF", border: OutlineInputBorder(), hintText: "000.000.000-00"),
                validator: (value) => (value == null || value.length < 14) ? 'CPF inválido' : null,
              ),
              const SizedBox(height: 16),

              // Data de Nascimento (DatePicker)
              TextFormField(
                controller: _dataNascController,
                readOnly: true,
                decoration: const InputDecoration(labelText: "Data de Nascimento", border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dataNascController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
                    });
                  }
                },
                validator: (value) => (value == null || value.isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "E-mail", border: OutlineInputBorder()),
                validator: (value) => (value != null && value.contains('@')) ? null : 'E-mail inválido',
              ),
              const SizedBox(height: 16),

              // Senha
              TextFormField(
                controller: _senhaController,
                obscureText: _obscureText,
                onChanged: (_) => _checkPassword(),
                decoration: InputDecoration(
                  labelText: "Senha",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirmar Senha
              TextFormField(
                controller: _confirmaSenhaController,
                obscureText: _obscureText,
                onChanged: (_) => _checkPassword(),
                decoration: const InputDecoration(labelText: "Confirmar Senha", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              // Validador Visual (Requisito Avançado)
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      _buildCriteriaRow("Pelo menos 1 maiúscula", authVM.hasUpper),
                      _buildCriteriaRow("Pelo menos 1 minúscula", authVM.hasLower),
                      _buildCriteriaRow("Pelo menos 1 número", authVM.hasDigit),
                      _buildCriteriaRow("Pelo menos 1 caractere especial", authVM.hasSpecial),
                      _buildCriteriaRow("Senhas iguais", authVM.passwordsMatch),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  // Botão habilita/desabilita baseado no estado
                  onPressed: authVM.isFormValid && !authVM.isLoading
                      ? () async {
                          if (_formKey.currentState!.validate()) {
                            final sucesso = await authVM.cadastrar(
                              _nomeController.text,
                              _cpfController.text,
                              _dataNascController.text,
                              _emailController.text,
                              _senhaController.text,
                            );
                            
                            // Verificação de segurança
                            if (!mounted) return;

                            if (sucesso) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuário cadastrado! Faça login.")));
                              Navigator.pop(context);
                            }
                          }
                        }
                      : null, // Null desabilita o botão
                  child: authVM.isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Cadastrar", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCriteriaRow(String text, bool isMet) {
    return Row(
      children: [
        Icon(isMet ? Icons.check_circle : Icons.cancel, color: isMet ? Colors.green : Colors.grey, size: 20),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: isMet ? Colors.green : Colors.grey, decoration: isMet ? TextDecoration.none : TextDecoration.lineThrough)),
      ],
    );
  }
}

// --- TELA 3: PRINCIPAL (Input) ---
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final analyzerVM = Provider.of<AnalyzerViewModel>(context, listen: false);
    final usuario = authVM.usuarioLogado;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analisador de Texto"),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              authVM.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Bem-vindo, ${usuario?.nome ?? 'Visitante'}!",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 20),
            const Text("Digite seu texto para análise:"),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: "Cole seu texto aqui...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                if (_textController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Digite algo!")));
                  return;
                }
                // Processa os dados no ViewModel
                analyzerVM.analisarTexto(_textController.text);
                // Navega para a tela de resultados
                Navigator.pushNamed(context, '/resultados');
              },
              child: const Text("Analisar Texto", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TELA 4: RESULTADOS (Output) ---
class TelaResultados extends StatelessWidget {
  const TelaResultados({super.key});

  @override
  Widget build(BuildContext context) {
    final results = Provider.of<AnalyzerViewModel>(context).resultados;

    if (results == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text("Nenhum resultado encontrado.")));
    }

    final List<MapEntry<String, int>> topWords = results['topWords'];

    return Scaffold(
      appBar: AppBar(title: const Text("Resultados")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildResultCard("Estatísticas Gerais", [
              _buildResultRow(Icons.text_fields, "Caracteres (c/ espaços):", results['charCount'].toString()),
              _buildResultRow(Icons.text_fields, "Caracteres (s/ espaços):", results['charCountNoSpaces'].toString()),
              _buildResultRow(Icons.sort_by_alpha, "Palavras:", results['wordCount'].toString()),
              _buildResultRow(Icons.format_quote, "Sentenças:", results['sentenceCount'].toString()),
              _buildResultRow(Icons.timer, "Tempo de leitura:", "${(results['readingTime'] as double).toStringAsFixed(2)} min"),
            ]),
            const SizedBox(height: 16),
            _buildResultCard("Top 10 palavras mais frequentes", [
              if (topWords.isEmpty)
                const Text("Nenhuma palavra frequente encontrada.")
              else
                ...topWords.map((e) => Text("• ${e.key} → ${e.value}", style: const TextStyle(fontSize: 16))),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Voltar e Analisar Novo Texto"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
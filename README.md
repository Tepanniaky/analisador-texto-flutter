 Analisador de Texto (MVVM + SQLite)

Aplicativo desenvolvido em Flutter para a disciplina de Desenvolvimento Mobile.
O app inclui um sistema completo de autenticação (Login/Cadastro) com persistência local e uma ferramenta de análise estatística de textos.

O foco principal foi a implementação da arquitetura MVVM e do SQLite nativo.

 Funcionalidades

 Autenticação Segura

Cadastro com validação avançada

Senha forte (maiúscula, minúscula, número e especial)

Login com consulta ao banco de dados local

Hash de senha usando SHA-256

 Persistência de Dados

Banco local usando sqflite

Armazenamento seguro e offline

 Analisador de Texto

Contagem de caracteres (com e sem espaços)

Contagem de palavras e sentenças

Estimativa de tempo de leitura

Top 10 palavras mais frequentes

Com filtro de stopwords

 UX/UI

Feedback visual da força da senha

Máscara automática de CPF

Seletor de data nativo (DatePicker)

 Tecnologias e Pacotes

Flutter & Dart

Arquitetura: MVVM (Model-View-ViewModel)

Gerência de Estado: provider

Banco de Dados: sqflite + path

Segurança: crypto (hashing SHA-256)

Utilitários: intl, mask_text_input_formatter

📸 Screenshots



Login

Cadastro

Tela de Análise

Tela de Resultados

(Insira seus prints aqui)

 Como Rodar o Projeto
Pré-requisitos

Flutter SDK instalado

Emulador ou dispositivo Android configurado

1. Clonar Repositório
git clone https://github.com/SEU_USUARIO/analisador-texto.git

2. Instalar Dependências
cd analisador-texto
flutter pub get

3. Executar
flutter run


O banco analisador_app.db é criado automaticamente na primeira execução.

 Estrutura de Pastas (MVVM)
lib/
 ├─ models/        # Entidades (ex: Usuario)
 ├─ viewmodels/    # Regras de negócio e gerência de estado
 ├─ views/         # Telas (Login, Cadastro, Principal, Resultados)
 ├─ services/      # Interações com SQLite (DatabaseService)

 Autor

Desenvolvido por Jose Raimundo.

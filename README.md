# Refeicao Diaria

Aplicativo Flutter para Android com cadastro e listagem local de refeicoes.
Cada registro possui data, descricao obrigatoria e foto opcional da galeria.
A listagem mostra primeiro as datas mais recentes; empates mostram o ultimo
registro cadastrado primeiro.

## Estrutura

```text
lib/
	models/refeicao.dart
	data/
		repositories/refeicao_repository.dart
		services/hive_service.dart
		services/notification_service.dart
	ui/
		views/home_page.dart
		viewmodels/home_viewmodel.dart
	main.dart
```

O modelo converte os dados para mapas. O HiveService abre a caixa `refeicoes`.
O repositorio salva os registros no Hive e copia fotos para o diretorio privado
do aplicativo, persistindo caminhos relativos. O HomeViewModel usa ChangeNotifier
e recebe dependencias injetadas; a tela nao acessa o Hive diretamente.

O seletor de galeria nao precisa de permissoes amplas de armazenamento.
Fotos recuperadas apos o Android encerrar a atividade ficam no rascunho de
uma nova refeicao, sem criar registros automaticamente. Cancelar o formulario
descarta o rascunho. Falhas ao salvar preservam os campos para nova tentativa.

## Executar no Android

Instale um Flutter compativel com a restricao Dart do pubspec e configure
o Android SDK, Java 17 e um aparelho ou emulador Android.

```sh
flutter pub get
flutter devices
flutter run -d <id-do-dispositivo>
```

## Verificacao

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Os testes usam Hive em diretorios temporarios e dependencias falsas para
selecionar fotos sem chamar plugins nativos nos testes de widget.
No aparelho, confira o cadastro com e sem foto, cancelamento da galeria,
reabertura do aplicativo, teclado e selecao de data.

## Transferir registros entre celulares

Na tela inicial, **Configuracoes** abre a tela **Mais**. Em **Relatorio para
o medico**, escolha PDF (com os filtros existentes) ou arquivo de registros.
Tambem existem atalhos **Exportar registros** e **Importar registros**.

A exportacao cria um arquivo `registros.meualmoco.json` (formato versionado 1)
com todas as refeicoes, datas, porcoes, respostas, observacoes e fotos originais
em base64, sem caminhos privados do celular e sem os filtros do PDF.
O limite de arquivo e 100 MB. Fotos ausentes ou ilegíveis interrompem a
exportacao em vez de gerar uma copia incompleta.

Envie/salve o arquivo e, no outro celular, use **Importar registros**.
Apos validar o arquivo, o app pede confirmacao e mescla os registros sem
apagar os atuais. Copias identicas (incluindo conteudo da foto) sao ignoradas,
mesmo ao importar o mesmo arquivo novamente. Registros alterados sao mantidos
separadamente, sem sobrescrever respostas existentes. Configuracoes de
lembretes nao sao transferidas. PDF nao pode ser importado.

O arquivo contem dados de saude e fotos, **sem criptografia ou senha**.
Compartilhe apenas com pessoas de confianca. O arquivo compartilhado fica no
cache temporario do Android; salve uma copia fora do app para guarda-lo.
Os dados locais sobrevivem ao fechamento do app, mas limpar os dados ou
desinstalar pode remove-los. Uma interrupcao abrupta durante a importacao
nao tem garantia de transacao atomica entre Hive e arquivos.

// lib/data/datasources/local/database_helper.dart

import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// Imports dos modelos (mantidos)
import 'package:geovigilancia/models/campanha_model.dart';
import 'package:geovigilancia/models/atividade_model.dart';
import 'package:geovigilancia/models/bairro_model.dart';
import 'package:geovigilancia/models/setor_model.dart';
import 'package:geovigilancia/models/vistoria_model.dart';
import 'package:geovigilancia/models/foco_model.dart';
import 'package:geovigilancia/models/tipo_criadouro_model.dart';

// MELHORIA 1: Centralização de nomes de tabelas e colunas para evitar erros de digitação.
class _DBConstants {
  static const dbName = 'geovigilancia.db';

  // Nomes das Tabelas
  static const tblCampanhas = 'campanhas';
  static const tblAtividades = 'atividades';
  static const tblBairros = 'bairros';
  static const tblSetores = 'setores';
  static const tblVistorias = 'vistorias';
  static const tblFocos = 'focos';
  static const tblTiposCriadouro = 'tipos_criadouro';

  // Colunas Comuns
  static const colId = 'id';
  static const colNome = 'nome';
  static const colDataCriacao = 'dataCriacao';
  
  // Colunas de Campanhas
  static const colCampanhaOrgao = 'orgao';
  static const colCampanhaResponsavel = 'responsavel';

  // Colunas de Atividades
  static const colAtividadeCampanhaId = 'campanhaId';
  static const colAtividadeTipo = 'tipo';
  static const colAtividadeDescricao = 'descricao';
  
  // Colunas de Bairros
  static const colBairroAtividadeId = 'atividadeId';
  static const colBairroMunicipio = 'municipio';
  static const colBairroEstado = 'estado';

  // Colunas de Setores
  static const colSetorBairroId = 'bairroId';
  static const colSetorBairroAtividadeId = 'bairroAtividadeId';
  static const colSetorAreaHa = 'areaHa';

  // Colunas de Vistorias
  static const colVistoriaSetorId = 'setorId';
  static const colVistoriaIdImovel = 'identificadorImovel';
  static const colVistoriaTipoImovel = 'tipoImovel';
  static const colVistoriaStatus = 'statusVisita';
  static const colVistoriaResultado = 'resultado';
  static const colVistoriaObs = 'observacao';
  static const colVistoriaLat = 'latitude';
  static const colVistoriaLon = 'longitude';
  static const colVistoriaDataColeta = 'dataColeta';
  static const colVistoriaAgenteId = 'agenteId';
  static const colVistoriaExportada = 'exportada';
  static const colVistoriaPhotoPaths = 'photoPaths';
  static const colVistoriaIdBairro = 'idBairro';
  static const colVistoriaNomeBairro = 'nomeBairro';
  static const colVistoriaNomeSetor = 'nomeSetor';
  static const colVistoriaIsSynced = 'isSynced';

  // Colunas de Focos
  static const colFocoVistoriaId = 'vistoriaId';
  static const colFocoTipoCriadouro = 'tipoCriadouro';
  static const colFocoLarvas = 'larvasEncontradas';
  static const colFocoTratamento = 'tratamentoRealizado';
  static const colFocoFotoUrl = 'fotoUrl';
}

/// Classe singleton para gerenciar o banco de dados local (SQLite).
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  /// Ponto de acesso global para a instância do [DatabaseHelper].
  factory DatabaseHelper() => _instance;
  
  /// Atalho para a instância do [DatabaseHelper].
  static DatabaseHelper get instance => _instance;

  /// Retorna a instância do banco de dados, inicializando-a se necessário.
  Future<Database> get database async => _database ??= await _initDatabase();

  /// Inicializa o banco de dados, definindo o caminho e as rotinas de criação.
  Future<Database> _initDatabase() async {
    final dbPath = join(await getDatabasesPath(), _DBConstants.dbName);
    return await openDatabase(
      dbPath,
      version: 1,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  /// Habilita o suporte a chaves estrangeiras.
  Future<void> _onConfigure(Database db) async => await db.execute('PRAGMA foreign_keys = ON');

  /// Cria todas as tabelas do banco de dados na primeira execução.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE ${_DBConstants.tblCampanhas} (
        ${_DBConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${_DBConstants.colNome} TEXT NOT NULL,
        ${_DBConstants.colCampanhaOrgao} TEXT NOT NULL,
        ${_DBConstants.colCampanhaResponsavel} TEXT NOT NULL,
        ${_DBConstants.colDataCriacao} TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE ${_DBConstants.tblAtividades} (
        ${_DBConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${_DBConstants.colAtividadeCampanhaId} INTEGER NOT NULL,
        ${_DBConstants.colAtividadeTipo} TEXT NOT NULL,
        ${_DBConstants.colAtividadeDescricao} TEXT NOT NULL,
        ${_DBConstants.colDataCriacao} TEXT NOT NULL,
        FOREIGN KEY (${_DBConstants.colAtividadeCampanhaId}) REFERENCES ${_DBConstants.tblCampanhas} (${_DBConstants.colId}) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE ${_DBConstants.tblBairros} (
        ${_DBConstants.colId} TEXT NOT NULL,
        ${_DBConstants.colBairroAtividadeId} INTEGER NOT NULL,
        ${_DBConstants.colNome} TEXT NOT NULL,
        ${_DBConstants.colBairroMunicipio} TEXT NOT NULL,
        ${_DBConstants.colBairroEstado} TEXT NOT NULL,
        PRIMARY KEY (${_DBConstants.colId}, ${_DBConstants.colBairroAtividadeId}),
        FOREIGN KEY (${_DBConstants.colBairroAtividadeId}) REFERENCES ${_DBConstants.tblAtividades} (${_DBConstants.colId}) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE ${_DBConstants.tblSetores} (
        ${_DBConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${_DBConstants.colSetorBairroId} TEXT NOT NULL,
        ${_DBConstants.colSetorBairroAtividadeId} INTEGER NOT NULL,
        ${_DBConstants.colNome} TEXT NOT NULL,
        ${_DBConstants.colSetorAreaHa} REAL,
        FOREIGN KEY (${_DBConstants.colSetorBairroId}, ${_DBConstants.colSetorBairroAtividadeId}) REFERENCES ${_DBConstants.tblBairros} (${_DBConstants.colId}, ${_DBConstants.colBairroAtividadeId}) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE ${_DBConstants.tblVistorias} (
        ${_DBConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${_DBConstants.colVistoriaSetorId} INTEGER,
        ${_DBConstants.colVistoriaIdImovel} TEXT,
        ${_DBConstants.colVistoriaTipoImovel} TEXT NOT NULL,
        ${_DBConstants.colVistoriaStatus} TEXT NOT NULL,
        ${_DBConstants.colVistoriaResultado} TEXT,
        ${_DBConstants.colVistoriaObs} TEXT,
        ${_DBConstants.colVistoriaLat} REAL,
        ${_DBConstants.colVistoriaLon} REAL,
        ${_DBConstants.colVistoriaDataColeta} TEXT NOT NULL,
        ${_DBConstants.colVistoriaAgenteId} TEXT,
        ${_DBConstants.colVistoriaExportada} INTEGER DEFAULT 0 NOT NULL,
        ${_DBConstants.colVistoriaPhotoPaths} TEXT,
        ${_DBConstants.colVistoriaIdBairro} TEXT, 
        ${_DBConstants.colVistoriaNomeBairro} TEXT,
        ${_DBConstants.colVistoriaNomeSetor} TEXT,
        ${_DBConstants.colVistoriaIsSynced} INTEGER DEFAULT 0 NOT NULL,
        FOREIGN KEY (${_DBConstants.colVistoriaSetorId}) REFERENCES ${_DBConstants.tblSetores} (${_DBConstants.colId}) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE ${_DBConstants.tblFocos} (
        ${_DBConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${_DBConstants.colFocoVistoriaId} INTEGER NOT NULL,
        ${_DBConstants.colFocoTipoCriadouro} TEXT NOT NULL,
        ${_DBConstants.colFocoLarvas} INTEGER NOT NULL,
        ${_DBConstants.colFocoTratamento} TEXT,
        ${_DBConstants.colFocoFotoUrl} TEXT,
        FOREIGN KEY (${_DBConstants.colFocoVistoriaId}) REFERENCES ${_DBConstants.tblVistorias} (${_DBConstants.colId}) ON DELETE CASCADE
      )
    ''');
    batch.execute('CREATE INDEX idx_focos_vistoriaId ON ${_DBConstants.tblFocos}(${_DBConstants.colFocoVistoriaId})');
    
    batch.execute('''
      CREATE TABLE ${_DBConstants.tblTiposCriadouro} (
        ${_DBConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${_DBConstants.colNome} TEXT NOT NULL UNIQUE
      )
    ''');

    // Insere os tipos de criadouro padrão na criação do banco
    const padroes = ['Pneu', 'Vaso de Planta', 'Caixa d\'água', 'Lixo Acumulado', 'Calha', 'Garrafa PET', 'Outro'];
    for (final nome in padroes) {
      batch.insert(_DBConstants.tblTiposCriadouro, {'nome': nome}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);
  }

  // --- MÉTODOS CRUD: Campanha ---
  
  /// Insere uma nova campanha e retorna seu ID.
  Future<int> insertCampanha(Campanha c) async => (await database).insert(_DBConstants.tblCampanhas, c.toMap());

  /// Retorna uma lista com todas as campanhas.
  Future<List<Campanha>> getTodasCampanhas() async {
    final db = await database;
    final maps = await db.query(_DBConstants.tblCampanhas, orderBy: '${_DBConstants.colDataCriacao} DESC');
    return List.generate(maps.length, (i) => Campanha.fromMap(maps[i]));
  }
  
  /// Deleta uma campanha e todas as suas atividades, bairros, setores e vistorias associadas (via ON DELETE CASCADE).
  Future<void> deleteCampanha(int id) async => (await database).delete(_DBConstants.tblCampanhas, where: '${_DBConstants.colId} = ?', whereArgs: [id]);
  
  // --- MÉTODOS CRUD: Atividade ---

  /// Insere uma nova atividade e retorna seu ID.
  Future<int> insertAtividade(Atividade a) async => (await database).insert(_DBConstants.tblAtividades, a.toMap());

  /// Retorna uma lista de atividades associadas a uma campanha específica.
  Future<List<Atividade>> getAtividadesDaCampanha(int campanhaId) async {
    final db = await database;
    final maps = await db.query(
      _DBConstants.tblAtividades,
      where: '${_DBConstants.colAtividadeCampanhaId} = ?',
      whereArgs: [campanhaId],
      orderBy: '${_DBConstants.colDataCriacao} DESC',
    );
    return List.generate(maps.length, (i) => Atividade.fromMap(maps[i]));
  }

  /// Deleta uma atividade e seus dados associados.
  Future<void> deleteAtividade(int id) async => (await database).delete(_DBConstants.tblAtividades, where: '${_DBConstants.colId} = ?', whereArgs: [id]);

  // --- MÉTODOS CRUD: Bairro ---

  /// Insere um novo bairro. Lança uma exceção se a chave primária composta (id, atividadeId) já existir.
  Future<void> insertBairro(Bairro b) async => (await database).insert(_DBConstants.tblBairros, b.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);

  /// Retorna uma lista de bairros associados a uma atividade específica.
  Future<List<Bairro>> getBairrosDaAtividade(int atividadeId) async {
    final db = await database;
    final maps = await db.query(
      _DBConstants.tblBairros,
      where: '${_DBConstants.colBairroAtividadeId} = ?',
      whereArgs: [atividadeId],
      orderBy: _DBConstants.colNome,
    );
    return List.generate(maps.length, (i) => Bairro.fromMap(maps[i]));
  }

  /// Deleta um bairro específico de uma atividade.
  Future<void> deleteBairro(String id, int atividadeId) async {
    final db = await database;
    await db.delete(
      _DBConstants.tblBairros,
      where: '${_DBConstants.colId} = ? AND ${_DBConstants.colBairroAtividadeId} = ?',
      whereArgs: [id, atividadeId],
    );
  }

  /// Atualiza os dados de um bairro.
  Future<int> updateBairro(Bairro bairro) async {
    final db = await database;
    return db.update(
      _DBConstants.tblBairros,
      bairro.toMap(),
      where: '${_DBConstants.colId} = ? AND ${_DBConstants.colBairroAtividadeId} = ?',
      whereArgs: [bairro.id, bairro.atividadeId],
    );
  }
  
  // --- MÉTODOS CRUD: Setor ---
  
  /// Insere um novo setor e retorna seu ID.
  Future<int> insertSetor(Setor s) async => (await database).insert(_DBConstants.tblSetores, s.toMap());
  
  /// Retorna uma lista de setores associados a um bairro específico dentro de uma atividade.
  Future<List<Setor>> getSetoresDoBairro(String bairroId, int bairroAtividadeId) async {
    final db = await database;
    final maps = await db.query(
      _DBConstants.tblSetores,
      where: '${_DBConstants.colSetorBairroId} = ? AND ${_DBConstants.colSetorBairroAtividadeId} = ?',
      whereArgs: [bairroId, bairroAtividadeId],
      orderBy: _DBConstants.colNome,
    );
    return List.generate(maps.length, (i) => Setor.fromMap(maps[i]));
  }
  
  /// Deleta um setor.
  Future<void> deleteSetor(int id) async => (await database).delete(_DBConstants.tblSetores, where: '${_DBConstants.colId} = ?', whereArgs: [id]);
  
  // --- MÉTODOS CRUD: Vistoria e Foco ---

  /// Salva uma vistoria completa e seus focos associados de forma transacional.
  Future<Vistoria> saveFullVistoria(Vistoria v, List<Foco> focos) async {
  final db = await database;
  
  // A variável que será retornada no final.
  late Vistoria vistoriaSalva;

  await db.transaction((txn) async {
    // <<< CORREÇÃO APLICADA AQUI: Variável declarada no escopo correto >>>
    int idDaVistoria;
    
    final vistoriaMap = v.toMap();

    if (v.dbId == null) {
      // INSERIR NOVA VISTORIA
      vistoriaMap.remove('id');
      idDaVistoria = await txn.insert('vistorias', vistoriaMap);
    } else {
      // ATUALIZAR VISTORIA EXISTENTE
      idDaVistoria = v.dbId!;
      await txn.update(
        'vistorias', 
        vistoriaMap,
        where: 'id = ?',
        whereArgs: [idDaVistoria]
      );
    }
    
    // Agora 'idDaVistoria' está acessível aqui.
    vistoriaSalva = v.copyWith(dbId: idDaVistoria);

    // Sincronizar os focos (lógica inalterada)
    await txn.delete('focos', where: 'vistoriaId = ?', whereArgs: [idDaVistoria]);

    if (focos.isNotEmpty) {
      final batch = txn.batch();
      for (final foco in focos) {
        // O toMap do Foco já lida com o id do próprio foco.
        // O copyWith apenas garante que o vistoriaId está correto.
        batch.insert('focos', foco.copyWith(vistoriaId: idDaVistoria).toMap());
      }
      await batch.commit(noResult: true);
    }
    
    vistoriaSalva.focos = focos;
  });

  return vistoriaSalva;
}

  /// Retorna uma vistoria específica pelo seu ID.
  Future<Vistoria?> getVistoriaById(int id) async {
    final db = await database;
    final maps = await db.query(_DBConstants.tblVistorias, where: '${_DBConstants.colId} = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Vistoria.fromMap(maps.first) : null;
  }

  /// Retorna todas as vistorias de um setor específico.
  Future<List<Vistoria>> getVistoriasDoSetor(int setorId) async {
    final db = await database;
    final maps = await db.query(
      _DBConstants.tblVistorias,
      where: '${_DBConstants.colVistoriaSetorId} = ?',
      whereArgs: [setorId],
      orderBy: '${_DBConstants.colVistoriaDataColeta} DESC',
    );
    return List.generate(maps.length, (i) => Vistoria.fromMap(maps[i]));
  }
  
  /// Retorna todos os focos associados a uma vistoria.
  Future<List<Foco>> getFocosDaVistoria(int vistoriaId) async {
    final db = await database;
    final maps = await db.query(
      _DBConstants.tblFocos,
      where: '${_DBConstants.colFocoVistoriaId} = ?',
      whereArgs: [vistoriaId],
    );
    return List.generate(maps.length, (i) => Foco.fromMap(maps[i]));
  }

  /// Deleta uma vistoria e seus focos associados.
  Future<void> deleteVistoria(int id) async => (await database).delete(_DBConstants.tblVistorias, where: '${_DBConstants.colId} = ?', whereArgs: [id]);
  
  // --- MÉTODOS CRUD: Tipo de Criadouro ---

  /// Insere um novo tipo de criadouro. Substitui se já existir.
  Future<int> insertTipoCriadouro(TipoCriadouro tc) async => (await database).insert(_DBConstants.tblTiposCriadouro, tc.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  
  /// Retorna todos os tipos de criadouro cadastrados, em ordem alfabética.
  Future<List<TipoCriadouro>> getTodosTiposCriadouro() async {
    final db = await database;
    final maps = await db.query(_DBConstants.tblTiposCriadouro, orderBy: '${_DBConstants.colNome} ASC');
    return List.generate(maps.length, (i) => TipoCriadouro.fromMap(maps[i]));
  }
  
  /// Deleta um tipo de criadouro.
  Future<void> deleteTipoCriadouro(int id) async => (await database).delete(_DBConstants.tblTiposCriadouro, where: '${_DBConstants.colId} = ?', whereArgs: [id]);
  
  // --- LÓGICA DE IMPORTAÇÃO DE CSV ---

  /// Valida o cabeçalho do arquivo CSV. Lança uma exceção se colunas essenciais faltarem.
  void _validarCabecalhoCsv(List<String> headers) {
    const colunasObrigatorias = ['ID_Bairro', 'Setor', 'Tipo_Imovel', 'Status_Visita'];
    final colunasFaltantes = colunasObrigatorias.whereNot(headers.contains).toList();
    if (colunasFaltantes.isNotEmpty) {
      throw Exception('Arquivo CSV inválido. Faltando colunas essenciais: ${colunasFaltantes.join(', ')}');
    }
  }

  /// Busca um bairro no banco de dados ou o cria se não existir, dentro de uma transação.
  Future<Bairro> _findOrCreateBairro(Transaction txn, Map<String, dynamic> rowData, int atividadeIdAlvo) async {
    final idBairro = rowData['ID_Bairro']?.toString();
    if (idBairro == null || idBairro.isEmpty) throw Exception("Coluna 'ID_Bairro' não pode ser vazia.");

    final maps = await txn.query(_DBConstants.tblBairros, where: '${_DBConstants.colId} = ? AND ${_DBConstants.colBairroAtividadeId} = ?', whereArgs: [idBairro, atividadeIdAlvo]);
    
    if (maps.isNotEmpty) {
      return Bairro.fromMap(maps.first);
    }
    
    final novoBairro = Bairro(
      id: idBairro, 
      atividadeId: atividadeIdAlvo, 
      nome: rowData['Nome_Bairro']?.toString() ?? idBairro, 
      municipio: rowData['Municipio']?.toString() ?? 'N/I', 
      estado: rowData['Estado']?.toString() ?? 'N/I'
    );
    await txn.insert(_DBConstants.tblBairros, novoBairro.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    return novoBairro;
  }

  /// Busca um setor ou o cria se não existir, dentro de uma transação.
  Future<Setor> _findOrCreateSetor(Transaction txn, Map<String, dynamic> rowData, Bairro bairro) async {
    final nomeSetor = rowData['Setor']?.toString();
    if (nomeSetor == null || nomeSetor.isEmpty) throw Exception("Coluna 'Setor' não pode ser vazia.");
    
    final maps = await txn.query(_DBConstants.tblSetores, where: '${_DBConstants.colNome} = ? AND ${_DBConstants.colSetorBairroId} = ? AND ${_DBConstants.colSetorBairroAtividadeId} = ?', whereArgs: [nomeSetor, bairro.id, bairro.atividadeId]);

    if (maps.isNotEmpty) {
        return Setor.fromMap(maps.first);
    }
    
    Setor novoSetor = Setor(bairroId: bairro.id, bairroAtividadeId: bairro.atividadeId, nome: nomeSetor);
    final setorId = await txn.insert(_DBConstants.tblSetores, novoSetor.toMap());
    return novoSetor.copyWith(id: setorId);
  }

  /// Constrói um objeto Vistoria a partir de uma linha do CSV.
  Vistoria _buildVistoriaFromRow(Map<String, dynamic> rowData, Setor setor, Bairro bairro) {
    return Vistoria(
        setorId: setor.id,
        identificadorImovel: rowData['ID_Imovel']?.toString(),
        tipoImovel: rowData['Tipo_Imovel']?.toString() ?? 'N/I',
        status: StatusVisita.values.firstWhere(
          (e) => e.name == (rowData['Status_Visita']?.toString().trim().toLowerCase() ?? ''), 
          orElse: () => StatusVisita.realizada
        ),
        resultado: rowData['Resultado']?.toString(),
        latitude: double.tryParse(rowData['Latitude']?.toString() ?? ''),
        longitude: double.tryParse(rowData['Longitude']?.toString() ?? ''),
        dataColeta: DateTime.tryParse(rowData['Data_Coleta']?.toString() ?? '') ?? DateTime.now(),
        nomeBairro: bairro.nome,
        nomeSetor: setor.nome,
        idBairro: bairro.id,
    );
  }

  /// Importa um conjunto de vistorias e focos de um arquivo CSV para uma atividade específica.
  /// O CSV deve agrupar linhas pelo 'ID_Imovel' para representar uma vistoria com múltiplos focos.
  /// Retorna uma string com o resumo da importação ou uma mensagem de erro.
  Future<String> importarVistoriasDeEquipe(String csvContent, int atividadeIdAlvo) async {
    int vistoriasImportadas = 0;
    int focosImportados = 0;

    final db = await database;

    try {
      final List<List<dynamic>> rows = const CsvToListConverter(fieldDelimiter: ',', eol: '\n').convert(csvContent);
      if (rows.length < 2) return "Erro: O arquivo CSV está vazio ou contém apenas o cabeçalho.";
      
      final headers = rows.first.map((h) => h.toString().trim()).toList();
      _validarCabecalhoCsv(headers);

      // Agrupa as linhas do CSV pelo 'ID_Imovel'. Cada grupo representa uma vistoria única com um ou mais focos.
      final vistoriasAgrupadas = groupBy(rows.sublist(1), (row) {
          final rowMap = Map.fromIterables(headers, row);
          return rowMap['ID_Imovel']?.toString() ?? 'VISTORIA_PADRAO_${DateTime.now().microsecondsSinceEpoch}';
      });

      await db.transaction((txn) async {
        for (final entry in vistoriasAgrupadas.entries) {
            final grupoDeLinhas = entry.value;
            final primeiraLinhaMap = Map.fromIterables(headers, grupoDeLinhas.first);
            
            final bairro = await _findOrCreateBairro(txn, primeiraLinhaMap, atividadeIdAlvo);
            final setor = await _findOrCreateSetor(txn, primeiraLinhaMap, bairro);
            final novaVistoria = _buildVistoriaFromRow(primeiraLinhaMap, setor, bairro);

            final vistoriaDbId = await txn.insert(_DBConstants.tblVistorias, novaVistoria.toMap());
            vistoriasImportadas++;
            
            // Itera sobre todas as linhas do grupo para registrar os focos associados à vistoria.
            for (final linhaFoco in grupoDeLinhas) {
                final focoMap = Map.fromIterables(headers, linhaFoco);
                final tipoCriadouro = focoMap['Tipo_Criadouro']?.toString();
                if (tipoCriadouro != null && tipoCriadouro.isNotEmpty) {
                    await txn.insert(_DBConstants.tblFocos, {
                      _DBConstants.colFocoVistoriaId: vistoriaDbId,
                      _DBConstants.colFocoTipoCriadouro: tipoCriadouro,
                      _DBConstants.colFocoLarvas: focoMap['Larvas_Encontradas']?.toString().toLowerCase() == 'sim' ? 1 : 0,
                      _DBConstants.colFocoTratamento: focoMap['Tratamento']?.toString(),
                    });
                    focosImportados++;
                }
            }
        }
      });

      // Após a transação, busca a contagem atualizada de bairros e setores na atividade.
      final bairrosNaAtividade = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(id) FROM ${_DBConstants.tblBairros} WHERE ${_DBConstants.colBairroAtividadeId} = ?', [atividadeIdAlvo])) ?? 0;
      final setoresNaAtividade = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(id) FROM ${_DBConstants.tblSetores} WHERE ${_DBConstants.colSetorBairroAtividadeId} = ?', [atividadeIdAlvo])) ?? 0;

      return "Importação Concluída!\n\n"
             "Vistorias: $vistoriasImportadas\n"
             "Focos: $focosImportados\n\n"
             "Estruturas na Atividade:\n"
             "- Bairros Totais: $bairrosNaAtividade\n"
             "- Setores Totais: $setoresNaAtividade";
    } catch (e, s) {
      debugPrint("Erro ao importar CSV: $e\nStack Trace: $s");
      return "Erro Crítico: Ocorreu uma falha. Verifique o formato e o conteúdo do CSV.\n\nDetalhe: ${e.toString()}";
    }
  }
}
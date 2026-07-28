import 'package:flutter/material.dart';
import '/backend/schema/structs/index.dart';
import '/backend/api_requests/api_manager.dart';
import '/backend/sqlite/sqlite_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'dart:convert';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    prefs = await SharedPreferences.getInstance();
    _safeInit(() {
      _UserToken = prefs.getString('ff_UserToken') ?? _UserToken;
    });
    _safeInit(() {
      if (prefs.containsKey('ff_UserPermissoes')) {
        try {
          _UserPermissoes =
              jsonDecode(prefs.getString('ff_UserPermissoes') ?? '');
        } catch (e) {
          print("Can't decode persisted json. Error: $e.");
        }
      }
    });
    _safeInit(() {
      _UserID = prefs.getInt('ff_UserID') ?? _UserID;
    });
    _safeInit(() {
      _UserName = prefs.getString('ff_UserName') ?? _UserName;
    });
    _safeInit(() {
      _creatorId = prefs.getInt('ff_creatorId') ?? _creatorId;
    });
    _safeInit(() {
      _activeTenantUserId = prefs.getInt('ff_activeTenantUserId') ?? _activeTenantUserId;
    });
    _safeInit(() {
      _activeEmpresaUserId =
          prefs.getInt('ff_activeEmpresaUserId') ?? _activeEmpresaUserId;
    });
    _safeInit(() {
      _activeEmpresaNome =
          prefs.getString('ff_activeEmpresaNome') ?? _activeEmpresaNome;
    });
    _safeInit(() {
      _userTipo = prefs.getString('ff_userTipo') ?? _userTipo;
    });
    _safeInit(() {
      _userCargo = prefs.getString('ff_userCargo') ?? _userCargo;
    });
    _safeInit(() {
      _UserUuid = prefs.getString('ff_UserUuid') ?? _UserUuid;
    });
    _safeInit(() {
      _creatorUuid = prefs.getString('ff_creatorUuid') ?? _creatorUuid;
    });
    _safeInit(() {
      _membershipType = prefs.getString('ff_membershipType') ?? _membershipType;
    });
    _safeInit(() {
      _obraTravada = prefs.getBool('ff_obraTravada') ?? _obraTravada;
    });
    _safeInit(() {
      if (prefs.containsKey('ff_permissionNames')) {
        try {
          final raw = prefs.getString('ff_permissionNames');
          if (raw != null && raw.isNotEmpty) {
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              _permissionNames = decoded
                  .map((e) => e.toString())
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
          }
        } catch (e) {
          print("Can't decode ff_permissionNames: $e");
        }
      }
    });
    _safeInit(() {
      if (prefs.containsKey('ff_allowedObraIds')) {
        try {
          final raw = prefs.getString('ff_allowedObraIds');
          if (raw != null && raw.isNotEmpty) {
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              _allowedObraIds = decoded
                  .map((e) => int.tryParse(e.toString()) ?? 0)
                  .where((id) => id > 0)
                  .toList();
            }
          }
        } catch (e) {
          print("Can't decode ff_allowedObraIds: $e");
        }
      }
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  int _tenantContextVersion = 0;
  int get tenantContextVersion => _tenantContextVersion;

  /// Dispara recarga de listas locais após login/troca de empresa.
  void notifyTenantContextChanged() {
    _tenantContextVersion++;
    notifyListeners();
  }

  /// Limpa dados de sessão persistidos (token, usuário). Chame no logout.
  void clearAuthSession() {
    UserToken = '';
    UserID = 0;
    UserName = '';
    creatorId = 0;
    activeTenantUserId = 0;
    activeEmpresaUserId = 0;
    activeEmpresaNome = '';
    userTipo = '';
    userCargo = '';
    UserUuid = '';
    creatorUuid = '';
    try {
      prefs.remove('ff_UserPermissoes');
      prefs.remove('ff_userCargo');
      prefs.remove('ff_membershipType');
      prefs.remove('ff_permissionNames');
      prefs.remove('ff_obraTravada');
      prefs.remove('ff_allowedObraIds');
    } catch (_) {}
    _UserPermissoes = null;
    _membershipType = '';
    _permissionNames = [];
    _obraTravada = false;
    _allowedObraIds = [];
    _allowedObraLocalIds = [];
    _allowedObraUuids = [];
    notifyListeners();
  }

  late SharedPreferences prefs;

  String _UserToken = '';
  String get UserToken => _UserToken;
  set UserToken(String value) {
    _UserToken = value;
    prefs.setString('ff_UserToken', value);
  }

  dynamic _UserPermissoes;
  dynamic get UserPermissoes => _UserPermissoes;
  set UserPermissoes(dynamic value) {
    _UserPermissoes = value;
    if (value == null) {
      prefs.remove('ff_UserPermissoes');
    } else {
      prefs.setString('ff_UserPermissoes', jsonEncode(value));
    }
  }

  /// Permissões ligadas ao vínculo ativo (`permission_names` / `permissoes`).
  bool hasPermission(String permissionName) {
    if (permissionName.trim().isEmpty) return false;
    final type = membershipType.isNotEmpty
        ? membershipType
        : userTipo.toLowerCase().trim();
    if (['company', 'admin', 'administrador'].contains(type)) {
      return true;
    }
    if (permissionNames.contains(permissionName)) return true;
    final p = UserPermissoes;
    if (p is! List) return false;
    for (final item in p) {
      if (item is Map && item['name']?.toString() == permissionName) {
        return true;
      }
      if (item is String && item == permissionName) return true;
    }
    return false;
  }

  /// Alinhado a `User::TYPE_*` no Laravel.
  bool get isUserTypeAdmin =>
      userTipo == 'admin' || membershipType == 'admin';
  bool get isUserTypeCompany =>
      userTipo == 'company' || membershipType == 'company';
  bool get isUserTypeAdministrador =>
      membershipType == 'administrador' || userTipo == 'administrador';
  bool get isUserTypeOperador => membershipType == 'operador';
  bool get isUserTypeSupervisor => membershipType == 'supervisor';
  bool get isUserTypeCliente => membershipType == 'cliente';
  bool get hasFullTenantAccess =>
      isUserTypeCompany ||
      isUserTypeAdmin ||
      isUserTypeAdministrador;

  int _UserID = 0;
  int get UserID => _UserID;
  set UserID(int value) {
    _UserID = value;
    prefs.setInt('ff_UserID', value);
  }

  String _UserName = '';
  String get UserName => _UserName;
  set UserName(String value) {
    _UserName = value;
    prefs.setString('ff_UserName', value);
  }

  int _reloadFotos = 0;
  int get reloadFotos => _reloadFotos;
  set reloadFotos(int value) {
    _reloadFotos = value;
  }

  bool _reloadFotosTrigger = false;
  bool get reloadFotosTrigger => _reloadFotosTrigger;
  set reloadFotosTrigger(bool value) {
    _reloadFotosTrigger = value;
  }

  bool _isConnectedToInternet = false;
  bool get isConnectedToInternet => _isConnectedToInternet;
  set isConnectedToInternet(bool value) {
    _isConnectedToInternet = value;
  }

  int _creatorId = 0;
  int get creatorId => _creatorId;
  set creatorId(int value) {
    _creatorId = value;
    prefs.setInt('ff_creatorId', value);
  }

  int _activeTenantUserId = 0;
  int get activeTenantUserId => _activeTenantUserId;
  set activeTenantUserId(int value) {
    _activeTenantUserId = value;
    prefs.setInt('ff_activeTenantUserId', value);
  }

  /// `empresa_users.id` do vínculo ativo (login / troca de empresa).
  int _activeEmpresaUserId = 0;
  int get activeEmpresaUserId => _activeEmpresaUserId;
  set activeEmpresaUserId(int value) {
    _activeEmpresaUserId = value;
    prefs.setInt('ff_activeEmpresaUserId', value);
  }

  String _activeEmpresaNome = '';
  String get activeEmpresaNome => _activeEmpresaNome;
  set activeEmpresaNome(String value) {
    _activeEmpresaNome = value;
    prefs.setString('ff_activeEmpresaNome', value);
  }

  bool _syncSuccess = false;
  bool get syncSuccess => _syncSuccess;
  set syncSuccess(bool value) {
    _syncSuccess = value;
  }

  String _syncMessage = '\" \"';
  String get syncMessage => _syncMessage;
  set syncMessage(String value) {
    _syncMessage = value;
  }

  int _syncUploadedCount = 0;
  int get syncUploadedCount => _syncUploadedCount;
  set syncUploadedCount(int value) {
    _syncUploadedCount = value;
  }

  int _syncDownloadedCount = 0;
  int get syncDownloadedCount => _syncDownloadedCount;
  set syncDownloadedCount(int value) {
    _syncDownloadedCount = value;
  }

  String _lastSyncTime = '\" \"';
  String get lastSyncTime => _lastSyncTime;
  set lastSyncTime(String value) {
    _lastSyncTime = value;
  }

  int _userId = 0;
  int get userId => _userId;
  set userId(int value) {
    _userId = value;
  }

  String _progressoChecklist = '';
  String get progressoChecklist => _progressoChecklist;
  set progressoChecklist(String value) {
    _progressoChecklist = value;
  }

  String _assinaturaUrl = '';
  String get assinaturaUrl => _assinaturaUrl;
  set assinaturaUrl(String value) {
    _assinaturaUrl = value;
  }

  String _checklistAtualJson = '';
  String get checklistAtualJson => _checklistAtualJson;
  set checklistAtualJson(String value) {
    _checklistAtualJson = value;
  }

  String _ultimaAcaoMensagem = '';
  String get ultimaAcaoMensagem => _ultimaAcaoMensagem;
  set ultimaAcaoMensagem(String value) {
    _ultimaAcaoMensagem = value;
  }

  String _ultimoErroAcao = '';
  String get ultimoErroAcao => _ultimoErroAcao;
  set ultimoErroAcao(String value) {
    _ultimoErroAcao = value;
  }

  String _codigoUltimaOrdem = '';
  String get codigoUltimaOrdem => _codigoUltimaOrdem;
  set codigoUltimaOrdem(String value) {
    _codigoUltimaOrdem = value;
  }

  String _dataEmissaoUltimaOrdem = '';
  String get dataEmissaoUltimaOrdem => _dataEmissaoUltimaOrdem;
  set dataEmissaoUltimaOrdem(String value) {
    _dataEmissaoUltimaOrdem = value;
  }

  int _ultimaOrdemAdicionadaId = 0;
  int get ultimaOrdemAdicionadaId => _ultimaOrdemAdicionadaId;
  set ultimaOrdemAdicionadaId(int value) {
    _ultimaOrdemAdicionadaId = value;
  }

  int _ultimosCustosInseridos = 0;
  int get ultimosCustosInseridos => _ultimosCustosInseridos;
  set ultimosCustosInseridos(int value) {
    _ultimosCustosInseridos = value;
  }

  bool _ultimaAcaoSucesso = false;
  bool get ultimaAcaoSucesso => _ultimaAcaoSucesso;
  set ultimaAcaoSucesso(bool value) {
    _ultimaAcaoSucesso = value;
  }

  String _userTipo = '';
  String get userTipo => _userTipo;
  set userTipo(String value) {
    _userTipo = value;
    prefs.setString('ff_userTipo', value);
  }

  String _userCargo = '';
  String get userCargo => _userCargo;
  set userCargo(String value) {
    _userCargo = value;
    prefs.setString('ff_userCargo', value);
  }

  String _membershipType = '';
  String get membershipType => _membershipType;
  set membershipType(String value) {
    _membershipType = value;
    prefs.setString('ff_membershipType', value);
  }

  List<String> _permissionNames = [];
  List<String> get permissionNames => _permissionNames;
  set permissionNames(List<String> value) {
    _permissionNames = value;
    prefs.setString('ff_permissionNames', jsonEncode(value));
  }

  bool _obraTravada = false;
  bool get obraTravada => _obraTravada;
  set obraTravada(bool value) {
    _obraTravada = value;
    prefs.setBool('ff_obraTravada', value);
  }

  List<int> _allowedObraIds = [];
  List<int> get allowedObraIds => _allowedObraIds;
  set allowedObraIds(List<int> value) {
    _allowedObraIds = value;
    prefs.setString('ff_allowedObraIds', jsonEncode(value));
  }

  /// IDs locais (SQLite) correspondentes a [allowedObraIds] do servidor.
  List<int> _allowedObraLocalIds = [];
  List<int> get allowedObraLocalIds => _allowedObraLocalIds;
  set allowedObraLocalIds(List<int> value) {
    _allowedObraLocalIds = value;
  }

  /// UUIDs das obras permitidas (resolvidos via sync_id_mapping).
  List<String> _allowedObraUuids = [];
  List<String> get allowedObraUuids => _allowedObraUuids;
  set allowedObraUuids(List<String> value) {
    _allowedObraUuids = value;
  }

  String _UserUuid = '';
  String get UserUuid => _UserUuid;
  set UserUuid(String value) {
    _UserUuid = value;
    prefs.setString('ff_UserUuid', value);
  }

  String _creatorUuid = '';
  String get creatorUuid => _creatorUuid;
  set creatorUuid(String value) {
    _creatorUuid = value;
    prefs.setString('ff_creatorUuid', value);
  }

  String _ultimaOrdemAdicionadaUuid = '';
  String get ultimaOrdemAdicionadaUuid => _ultimaOrdemAdicionadaUuid;
  set ultimaOrdemAdicionadaUuid(String value) {
    _ultimaOrdemAdicionadaUuid = value;
  }

  bool _carregarPagina = false;
  bool get carregarPagina => _carregarPagina;
  set carregarPagina(bool value) {
    _carregarPagina = value;
  }

  int _gatilhoRebuilderPage = 0;
  int get gatilhoRebuilderPage => _gatilhoRebuilderPage;
  set gatilhoRebuilderPage(int value) {
    _gatilhoRebuilderPage = value;
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}

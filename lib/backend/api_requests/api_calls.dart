import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'api_config.dart';
import 'api_manager.dart';

export 'api_config.dart' show kApiBaseUrl, kApiHost, apiUrl, apiUri;
export 'api_manager.dart' show ApiCallResponse;

class LoginCall {
  static Future<ApiCallResponse> call({
    String? email = '',
    String? password = '',
    String? type = '',
    int? createdBy,
    int? tenantUserId,
  }) async {
    final bodyMap = <String, dynamic>{
      'email': email,
      'password': password,
      'remember_me': false,
    };
    if (tenantUserId != null && tenantUserId > 0) {
      bodyMap['tenant_user_id'] = tenantUserId;
    }
    final ffApiRequestBody = jsonEncode(bodyMap);
    return ApiManager.instance.makeApiCall(
      callName: 'login',
      apiUrl: '$kApiBaseUrl/api/auth/login',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static String? userToken(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.accessToken''',
      ));
  static int? userID(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.userData.id''',
      ));
  static String? userNome(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.userData.nome''',
      ));
  static String? userSobrenome(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.userData.sobrenome''',
      ));
  static String? userDocumento(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.userData.documento''',
      ));
  static String? userRazaoSocial(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.userData.razao_social''',
      ));
  static String? userTelefone(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.userData.telefone''',
      ));
  static String? userWhatsapp(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.userData.whatsapp''',
      ));
  static String? userRua(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.userData.rua''',
      ));
  static String? userNumero(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.userData.numero''',
      ));
  static String? userComplemento(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.userData.complemento''',
      ));
  static String? userCep(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.userData.cep''',
      ));
  static String? userBairro(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.userData.bairro''',
      ));
  static String? userCidade(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.userData.cidade''',
      ));
  static String? userEstado(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.userData.estado''',
      ));
  static String? userEmail(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.userData.email''',
      ));
  static String? userTipo(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.userData.type''',
      ));

  static String? userCargo(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.userData.cargo''',
      ));

  /// Preferência: `user_type` na raiz do login; fallback `userData.type`.
  static String? userTypeRoot(dynamic response) {
    final root = castToType<String>(getJsonField(
      response,
      r'''$.user_type''',
    ));
    if (root != null && root.isNotEmpty) return root;
    return userTipo(response);
  }

  /// Lista `{ id, name, description }` vinda de `permissoes` no login.
  static dynamic permissoes(dynamic response) => getJsonField(
        response,
        r'''$.permissoes''',
        true,
      );

  /// Atalho `permission_names` no login (só strings).
  static List<String>? permissionNames(dynamic response) {
    final raw = getJsonField(response, r'''$.permission_names''', true);
    if (raw is! List) return null;
    return raw.map((e) => e.toString()).toList();
  }

  /// IDs de obras permitidas quando `obra_travada` está ativo.
  static List<int>? allowedObraIds(dynamic response) {
    final raw = getJsonField(response, r'''$.allowed_obra_ids''', true);
    if (raw is! List) return null;
    return raw
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((id) => id > 0)
        .toList();
  }

  /// Regras genéricas CASL (legado); preferir [permissoes].
  static List? userAbilityRules(dynamic response) => getJsonField(
        response,
        r'''$.userAbilityRules''',
        true,
      ) as List?;
  static int? creatorId(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.creatorId''',
      ));
  static String? message(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.message''',
      ));
  static String? status(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.status''',
      ));
  static String? userUuid(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.userData.uuid''',
      ));
  static String? creatorUuid(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.creatorUuid''',
      ));
  static String? expiresAt(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.expires_at''',
      ));
  static int? empresaId(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.empresa_id''',
      ));
  static bool? requiresTenantSelection(dynamic response) =>
      getJsonField(response, r'''$.requires_tenant_selection''');
  static List? memberships(dynamic response) =>
      getJsonField(response, r'''$.memberships''', true) as List?;
  static int? activeTenantUserId(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.active_tenant_user_id''',
      ));

  static int? membershipTenantUserId(dynamic response) {
    final m = membership(response);
    if (m is Map) {
      return castToType<int>(m['tenant_user_id']);
    }
    return null;
  }

  static dynamic membership(dynamic response) =>
      getJsonField(response, r'''$.membership''');

  static int? activeEmpresaUserId(dynamic response) {
    final m = membership(response);
    if (m is Map) {
      return castToType<int>(m['empresa_user_id']);
    }
    return null;
  }

  static String? membershipTenantUuid(dynamic response) {
    final m = membership(response);
    if (m is Map) {
      return castToType<String>(m['tenant_user_uuid']);
    }
    return null;
  }

  static String? empresaNome(dynamic response) {
    final root = castToType<String>(getJsonField(
      response,
      r'''$.empresa_nome''',
    ));
    if (root != null && root.trim().isNotEmpty) {
      return root.trim();
    }
    final m = membership(response);
    if (m is Map) {
      final n = m['empresa_nome']?.toString().trim();
      if (n != null && n.isNotEmpty) return n;
    }
    return null;
  }
}

class AuthMembershipsCall {
  static Future<ApiCallResponse> call({required String token}) async {
    return ApiManager.instance.makeApiCall(
      callName: 'authMemberships',
      apiUrl: '$kApiBaseUrl/api/auth/memberships',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: '',
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static List? membershipsList(dynamic response) =>
      getJsonField(response, r'''$.memberships''', true) as List?;
}

class AuthCheckTokenCall {
  static Future<ApiCallResponse> call({required String token}) async {
    return ApiManager.instance.makeApiCall(
      callName: 'authCheckToken',
      apiUrl: '$kApiBaseUrl/api/check-token',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: '',
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class AuthSwitchTenantCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int tenantUserId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'authSwitchTenant',
      apiUrl: '$kApiBaseUrl/api/auth/switch-tenant',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode({'tenant_user_id': tenantUserId}),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class RefreshTokenCall {
  static Future<ApiCallResponse> call({
    required String token,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'refreshToken',
      apiUrl: '$kApiBaseUrl/api/auth/refresh',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: '{}',
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static String? token(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.accessToken''',
      ));

  static String? expiresAt(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.expires_at''',
      ));
}

class CadastrarObraCall {
  /// `POST /api/obras` — multipart (mesmo `ObrasController@store` do web); `file` opcional.
  static Future<ApiCallResponse> call({
    String? token = '',
    String? nome = '',
    String? grupoUuid = '',
    String? clienteUuid = '',
    String? rua = '',
    String? numero = '',
    String? complemento = '',
    String? bairro = '',
    String? cidade = '',
    String? estado = '',
    String? engenheiro = '',
    String? dataInicio = '',
    String? dataFinal = '',
    String? contrato = '',
    FFUploadedFile? file,
  }) async {
    final params = <String, dynamic>{
      'nome': nome ?? '',
      'grupoUuid': grupoUuid ?? '',
      'clienteUuid': clienteUuid ?? '',
      'rua': rua ?? '',
      'numero': numero ?? '',
      'complemento': complemento ?? '',
      'bairro': bairro ?? '',
      'cidade': cidade ?? '',
      'estado': estado ?? '',
      'engenheiro': engenheiro ?? '',
      'dataInicio': dataInicio ?? '',
      'dataFinal': dataFinal ?? '',
      'contrato': contrato ?? '',
    };
    final f = file;
    if (f != null &&
        f.bytes != null &&
        f.bytes!.isNotEmpty &&
        (f.name ?? '').isNotEmpty) {
      params['file'] = f;
    }
    return ApiManager.instance.makeApiCall(
      callName: 'CadastrarObra',
      apiUrl: '$kApiBaseUrl/api/obras',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${token}',
      },
      params: params,
      bodyType: BodyType.MULTIPART,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static List? dados(dynamic response) => getJsonField(
        response,
        r'''$.dados''',
        true,
      ) as List?;
  static bool? result(dynamic response) => castToType<bool>(getJsonField(
        response,
        r'''$.success''',
      ));
}

class ListarClientesApiCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? itemsPerPage = 1000,
    int? page = 1,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'ListarClientes',
      apiUrl: '$kApiBaseUrl/api/clientes',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
      },
      params: {
        'itemsPerPage': itemsPerPage,
        'page': page,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ListarGrupoObrasApiCall {
  static Future<ApiCallResponse> call({
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'ListarGrupoObras',
      apiUrl: '$kApiBaseUrl/api/grupo-obras',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ObraDetalhesApiCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? obraServidorId,
    String? obraUuid = '',
  }) async {
    final identificador = (obraUuid ?? '').trim().isNotEmpty
        ? obraUuid!.trim()
        : '${obraServidorId ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'ObraDetalhesApi',
      apiUrl: '$kApiBaseUrl/api/obras/api/$identificador',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/obras/listar-situacoes` — lista situações para edição (mesmo fluxo do web).
class ListarSituacoesObrasCall {
  static Future<ApiCallResponse> call({
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'ListarSituacoesObras',
      apiUrl: '$kApiBaseUrl/api/obras/listar-situacoes',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// POST multipart com `_method: PUT` em `/obras/{id}` (Laravel + arquivo opcional), alinhado ao `EditObraDialog.vue`.
class AtualizarObraCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? obraServidorId,
    String? obraUuid = '',
    String? nome = '',
    int? grupoId,
    int? clienteId,
    String? grupoUuid = '',
    String? clienteUuid = '',
    int? situacaoId,
    String? rua = '',
    String? numero = '',
    String? complemento = '',
    String? bairro = '',
    String? cidade = '',
    String? estado = '',
    String? dataInicio = '',
    String? dataFinal = '',
    String? contrato = '',
    FFUploadedFile? file,
  }) async {
    final params = <String, dynamic>{
      '_method': 'PUT',
      'nome': nome ?? '',
      'grupo_id': '${grupoId ?? ''}',
      'cliente_id': '${clienteId ?? ''}',
      'grupo_uuid': grupoUuid ?? '',
      'cliente_uuid': clienteUuid ?? '',
      'situacao_id': '${situacaoId ?? ''}',
      'rua': rua ?? '',
      'numero': numero ?? '',
      'complemento': complemento ?? '',
      'bairro': bairro ?? '',
      'cidade': cidade ?? '',
      'estado': estado ?? '',
      'data_inicio': dataInicio ?? '',
      'data_final': dataFinal ?? '',
      'contrato': contrato ?? '',
    };
    final f = file;
    if (f != null &&
        f.bytes != null &&
        f.bytes!.isNotEmpty &&
        (f.name ?? '').isNotEmpty) {
      params['file'] = f;
    }

    final identificador = (obraUuid ?? '').trim().isNotEmpty
        ? obraUuid!.trim()
        : '${obraServidorId ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'AtualizarObra',
      apiUrl: '$kApiBaseUrl/api/obras/$identificador',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${token}',
      },
      params: params,
      bodyType: BodyType.MULTIPART,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/obras/{obraId}/list-etapas` — mesma origem que o web (`ObraTabTarefas`).
class ListarEtapasObraApiCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? obraServidorId,
    String? obraUuid = '',
  }) async {
    final identificador = (obraUuid ?? '').trim().isNotEmpty
        ? obraUuid!.trim()
        : '${obraServidorId ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'ListarEtapasObra',
      apiUrl: '$kApiBaseUrl/api/obras/$identificador/list-etapas',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/obras/{obraId}/locais` — nomes dos locais da obra (mesmo fluxo do web `AddNewTarefaDrawer.vue`).
class ObraLocaisPorObraCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? obraServidorId,
    String? obraUuid = '',
  }) async {
    final identificador = (obraUuid ?? '').trim().isNotEmpty
        ? obraUuid!.trim()
        : '${obraServidorId ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'ObraLocaisPorObra',
      apiUrl: '$kApiBaseUrl/api/obras/$identificador/locais',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// POST `/obras/{obraId}/add-etapa` — corpo `{ item, nome }` (strings).
class AddObraEtapaCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? obraServidorId,
    String? obraUuid = '',
    required String item,
    required String nome,
  }) async {
    final identificador = (obraUuid ?? '').trim().isNotEmpty
        ? obraUuid!.trim()
        : '${obraServidorId ?? 0}';
    final body = json.encode({
      'item': item,
      'nome': nome,
    });
    return ApiManager.instance.makeApiCall(
      callName: 'AddObraEtapa',
      apiUrl: '$kApiBaseUrl/api/obras/$identificador/add-etapa',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/obras/etapa/get-ultimo-item/{etapaId}/tarefa` — próximo código de item.
class UltimoItemTarefaObraCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? etapaServidorId,
    String? etapaUuid = '',
  }) async {
    final identificador = (etapaUuid ?? '').trim().isNotEmpty
        ? etapaUuid!.trim()
        : '${etapaServidorId ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'UltimoItemTarefaObra',
      apiUrl:
          '$kApiBaseUrl/api/obras/etapa/get-ultimo-item/$identificador/tarefa',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/obras/etapa/get-ultimo-item/{etapaId}/{tipo}` — próximo item (web usa `insumo` na composição).
class UltimoItemEtapaPorTipoCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? etapaServidorId,
    String? etapaUuid = '',
    required String tipo,
  }) async {
    final identificador = (etapaUuid ?? '').trim().isNotEmpty
        ? etapaUuid!.trim()
        : '${etapaServidorId ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'UltimoItemEtapaPorTipo',
      apiUrl:
          '$kApiBaseUrl/api/obras/etapa/get-ultimo-item/$identificador/$tipo',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/obras/etapas/{etapaId}/tarefas-pai` — tarefas raiz (`tipo` = tarefa) da etapa.
class GetTarefasPaiEtapaCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? etapaServidorId,
    String? etapaUuid = '',
  }) async {
    final identificador = (etapaUuid ?? '').trim().isNotEmpty
        ? etapaUuid!.trim()
        : '${etapaServidorId ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'GetTarefasPaiEtapa',
      apiUrl:
          '$kApiBaseUrl/api/obras/etapas/$identificador/tarefas-pai',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/obras/etapa/get-ultimo-item-composicao/{tarefaPaiId}` — próximo item sob a tarefa pai.
class UltimoItemComposicaoCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? tarefaPaiServidorId,
    String? tarefaPaiUuid = '',
  }) async {
    final identificador = (tarefaPaiUuid ?? '').trim().isNotEmpty
        ? tarefaPaiUuid!.trim()
        : '${tarefaPaiServidorId ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'UltimoItemComposicao',
      apiUrl:
          '$kApiBaseUrl/api/obras/etapa/get-ultimo-item-composicao/$identificador',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// POST `/obras/{etapaId}/add-tarefa` — `etapaId` é o id da etapa **no servidor**.
class AddObraTarefaCall {
  /// Corpo alinhado ao Postman / web: `tarefa_pai` deve existir (pode ser `null`);
  /// números como string evitam surpresas no cast do Laravel.
  static Future<ApiCallResponse> call({
    String? token = '',
    int? etapaServidorId,
    String? etapaUuid = '',
    required String item,
    dynamic tarefaPai,
    String tipo = 'tarefa',
    String? local,
    required String descricao,
    required double qtd,
    required String unidade,
    double? valorUnitario,
    double? meta,
    String? metaUnidade,
  }) async {
    final identificador = (etapaUuid ?? '').trim().isNotEmpty
        ? etapaUuid!.trim()
        : '${etapaServidorId ?? 0}';
    final loc = local?.trim();
    final metaU = metaUnidade?.trim();
    final map = <String, dynamic>{
      'item': item,
      'tarefa_pai': tarefaPai,
      'tipo': tipo,
      'local': (loc == null || loc.isEmpty) ? null : loc,
      'descricao': descricao,
      'qtd': qtd.toString(),
      'unidade': unidade,
      'valor_unitario': (valorUnitario ?? 0).toString(),
      'meta': (meta ?? 0).toString(),
      'meta_unidade': (metaU == null || metaU.isEmpty) ? null : metaU,
    };
    return ApiManager.instance.makeApiCall(
      callName: 'AddObraTarefa',
      apiUrl: '$kApiBaseUrl/api/obras/$identificador/add-tarefa',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      params: {},
      body: json.encode(map),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PUT `/obras/etapa/{id}/update` — edição de etapa.
class UpdateObraEtapaCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? etapaServidorId,
    String? etapaUuid = '',
    required String item,
    required String nome,
  }) async {
    final identificador = (etapaUuid ?? '').trim().isNotEmpty
        ? etapaUuid!.trim()
        : '${etapaServidorId ?? 0}';
    final body = json.encode({
      'item': item,
      'nome': nome,
    });
    return ApiManager.instance.makeApiCall(
      callName: 'UpdateObraEtapa',
      apiUrl: '$kApiBaseUrl/api/obras/etapa/$identificador/update',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PUT `/obras/tarefa/{id}/update` — edição de tarefa/composição.
class UpdateObraTarefaCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? tarefaServidorId,
    String? tarefaUuid = '',
    required String item,
    required String tipo,
    required String descricao,
    required double qtd,
    required String unidade,
    double? valorUnitario,
    double? meta,
    String? metaUnidade,
  }) async {
    final identificador = (tarefaUuid ?? '').trim().isNotEmpty
        ? tarefaUuid!.trim()
        : '${tarefaServidorId ?? 0}';
    final metaU = metaUnidade?.trim();
    final body = json.encode({
      'item': item,
      'tipo': tipo,
      'descricao': descricao,
      'qtd': qtd.toString(),
      'unidade': unidade,
      'valor_unitario': (valorUnitario ?? 0).toString(),
      'meta': (meta ?? 0).toString(),
      'meta_unidade': (metaU == null || metaU.isEmpty) ? null : metaU,
    });
    return ApiManager.instance.makeApiCall(
      callName: 'UpdateObraTarefa',
      apiUrl:
          '$kApiBaseUrl/api/obras/tarefa/$identificador/update',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// DELETE `/obras/etapas/{id}/destroy` — exclusão de etapa.
class DeleteObraEtapaCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? etapaServidorId,
    String? etapaUuid = '',
  }) async {
    final identificador = (etapaUuid ?? '').trim().isNotEmpty
        ? etapaUuid!.trim()
        : '${etapaServidorId ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'DeleteObraEtapa',
      apiUrl:
          '$kApiBaseUrl/api/obras/etapas/$identificador/destroy',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer $token',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// DELETE `/obras/tarefas/{id}/destroy` — exclusão de tarefa/composição.
class DeleteObraTarefaCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int? tarefaServidorId,
    String? tarefaUuid = '',
  }) async {
    final identificador = (tarefaUuid ?? '').trim().isNotEmpty
        ? tarefaUuid!.trim()
        : '${tarefaServidorId ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'DeleteObraTarefa',
      apiUrl:
          '$kApiBaseUrl/api/obras/tarefas/$identificador/destroy',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer $token',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CadastrarClienteCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    String? nome = '',
    String? telefone = '',
    String? email = '',
    String? juridica = '',
    String? documento = '',
    String? rua = '',
    String? numero = '',
    String? complemento = '',
    String? bairro = '',
    String? cidade = '',
    String? estado = '',
    String? observacoes = '',
  }) async {
    final ffApiRequestBody = '''
{
  "nome": "${escapeStringForJson(nome)}",
  "telefone": "${escapeStringForJson(telefone)}",
  "email": "${escapeStringForJson(email)}",
  "juridica": "${escapeStringForJson(juridica)}",
  "documento": "${escapeStringForJson(documento)}",
  "rua": "${escapeStringForJson(rua)}",
  "numero": "${escapeStringForJson(numero)}",
  "complemento": "${escapeStringForJson(complemento)}",
  "bairro": "${escapeStringForJson(bairro)}",
  "cidade": "${escapeStringForJson(cidade)}",
  "estado": "${escapeStringForJson(estado)}",
  "observacoes": "${escapeStringForJson(observacoes)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'CadastrarCliente',
      apiUrl: '$kApiBaseUrl/api/clientes',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${token}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static List? dados(dynamic response) => getJsonField(
        response,
        r'''$.dados''',
        true,
      ) as List?;
  static bool? result(dynamic response) => castToType<bool>(getJsonField(
        response,
        r'''$.success''',
      ));
}

/// `PUT /api/clientes/{id|uuid}` — mesmo corpo conceitual do cadastro.
class UpdateClienteCall {
  static Future<ApiCallResponse> call({
    int? id,
    String? clienteUuid = '',
    String? token = '',
    String? nome = '',
    String? telefone = '',
    String? email = '',
    String? juridica = '',
    String? documento = '',
    String? rua = '',
    String? numero = '',
    String? complemento = '',
    String? bairro = '',
    String? cidade = '',
    String? estado = '',
    String? observacoes = '',
  }) async {
    final ffApiRequestBody = '''
{
  "nome": "${escapeStringForJson(nome)}",
  "telefone": "${escapeStringForJson(telefone)}",
  "email": "${escapeStringForJson(email)}",
  "juridica": "${escapeStringForJson(juridica)}",
  "documento": "${escapeStringForJson(documento)}",
  "rua": "${escapeStringForJson(rua)}",
  "numero": "${escapeStringForJson(numero)}",
  "complemento": "${escapeStringForJson(complemento)}",
  "bairro": "${escapeStringForJson(bairro)}",
  "cidade": "${escapeStringForJson(cidade)}",
  "estado": "${escapeStringForJson(estado)}",
  "observacoes": "${escapeStringForJson(observacoes)}"
}''';
    final identificador = (clienteUuid ?? '').trim().isNotEmpty
        ? clienteUuid!.trim()
        : '${id ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'UpdateCliente',
      apiUrl: '$kApiBaseUrl/api/clientes/$identificador',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `DELETE /api/clientes/{id|uuid}/destroy` — soft delete (`situacao = -2` no servidor).
class ExcluirClienteCall {
  static Future<ApiCallResponse> call({
    int? id,
    String? clienteUuid = '',
    String? token = '',
  }) async {
    final identificador = (clienteUuid ?? '').trim().isNotEmpty
        ? clienteUuid!.trim()
        : '${id ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'ExcluirCliente',
      apiUrl: '$kApiBaseUrl/api/clientes/$identificador/destroy',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Accept': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/clientes/{id|uuid}/show` — cliente com obras (`Cliente::with('obras')`).
class ClienteDetalhesCall {
  static Future<ApiCallResponse> call({
    int? id,
    String? clienteUuid = '',
    required String token,
  }) async {
    final identificador = (clienteUuid ?? '').trim().isNotEmpty
        ? clienteUuid!.trim()
        : '${id ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'ClienteDetalhes',
      apiUrl: '$kApiBaseUrl/api/clientes/$identificador/show',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ListarUsuariosApiCall {
  static Future<ApiCallResponse> call({
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'ListarUsuarios',
      apiUrl: '$kApiBaseUrl/api/usuarios',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/usuarios/verificar-email?email=` — disponível / vincular / já vinculado.
class VerificarEmailUsuarioCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    required String email,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'VerificarEmailUsuario',
      apiUrl: '$kApiBaseUrl/api/usuarios/verificar-email',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Accept': 'application/json',
      },
      params: {
        'email': email,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static String? status(dynamic response) =>
      castToType<String>(getJsonField(response, r'''$.status'''));

  static String? message(dynamic response) =>
      castToType<String>(getJsonField(response, r'''$.message'''));

  static dynamic user(dynamic response) => getJsonField(response, r'''$.user''');
}

/// `POST /api/usuarios/vincular` — vincula usuário existente ao tenant.
class VincularUsuarioCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    required int userId,
    required String type,
    bool obraTravada = false,
  }) async {
    final ffApiRequestBody = '''
{
  "user_id": $userId,
  "type": "${escapeStringForJson(type)}",
  "obra_travada": ${obraTravada ? 'true' : 'false'}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'VincularUsuario',
      apiUrl: '$kApiBaseUrl/api/usuarios/vincular',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/usuarios/cadastrar-usuario` — cria usuário (senha obrigatória no cadastro).
class CadastrarUsuarioCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    required String nome,
    required String sobrenome,
    required String email,
    required String password,
    required String type,
    bool juridica = false,
    String? telefone,
    String? documento,
    String? rua,
    String? numero,
    String? complemento,
    String? bairro,
    String? cidade,
    String? estado,
    String? cep,
    String? cargo,
    String? registroProfissional,
  }) async {
    final ffApiRequestBody = '''
{
  "nome": "${escapeStringForJson(nome)}",
  "sobrenome": "${escapeStringForJson(sobrenome)}",
  "email": "${escapeStringForJson(email)}",
  "password": "${escapeStringForJson(password)}",
  "type": "${escapeStringForJson(type)}",
  "juridica": ${juridica ? 'true' : 'false'},
  "telefone": "${escapeStringForJson(telefone)}",
  "documento": "${escapeStringForJson(documento)}",
  "rua": "${escapeStringForJson(rua)}",
  "numero": "${escapeStringForJson(numero)}",
  "complemento": "${escapeStringForJson(complemento)}",
  "bairro": "${escapeStringForJson(bairro)}",
  "cidade": "${escapeStringForJson(cidade)}",
  "estado": "${escapeStringForJson(estado)}",
  "cep": "${escapeStringForJson(cep)}",
  "cargo": "${escapeStringForJson(cargo)}",
  "registro_profissional": "${escapeStringForJson(registroProfissional)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'CadastrarUsuario',
      apiUrl: '$kApiBaseUrl/api/usuarios/cadastrar-usuario',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `PUT /api/usuarios/{id|uuid}` — atualiza usuário (senha opcional).
class UpdateUsuarioCall {
  static Future<ApiCallResponse> call({
    int? id,
    String? usuarioUuid = '',
    String? token = '',
    String? nome,
    String? sobrenome,
    String? email,
    String? password,
    String? type,
    int? situacao,
    String? telefone,
    String? documento,
    String? rua,
    String? numero,
    String? complemento,
    String? bairro,
    String? cidade,
    String? estado,
    String? cep,
    String? cargo,
    String? registroProfissional,
  }) async {
    final parts = <String>[];
    if (nome != null) {
      parts.add('"nome": "${escapeStringForJson(nome)}"');
    }
    if (sobrenome != null) {
      parts.add('"sobrenome": "${escapeStringForJson(sobrenome)}"');
    }
    if (email != null) {
      parts.add('"email": "${escapeStringForJson(email)}"');
    }
    if (password != null && password.isNotEmpty) {
      parts.add('"password": "${escapeStringForJson(password)}"');
    }
    if (type != null) {
      parts.add('"type": "${escapeStringForJson(type)}"');
    }
    if (situacao != null) {
      parts.add('"situacao": $situacao');
    }
    if (telefone != null) {
      parts.add('"telefone": "${escapeStringForJson(telefone)}"');
    }
    if (documento != null) {
      parts.add('"documento": "${escapeStringForJson(documento)}"');
    }
    if (rua != null) {
      parts.add('"rua": "${escapeStringForJson(rua)}"');
    }
    if (numero != null) {
      parts.add('"numero": "${escapeStringForJson(numero)}"');
    }
    if (complemento != null) {
      parts.add('"complemento": "${escapeStringForJson(complemento)}"');
    }
    if (bairro != null) {
      parts.add('"bairro": "${escapeStringForJson(bairro)}"');
    }
    if (cidade != null) {
      parts.add('"cidade": "${escapeStringForJson(cidade)}"');
    }
    if (estado != null) {
      parts.add('"estado": "${escapeStringForJson(estado)}"');
    }
    if (cep != null) {
      parts.add('"cep": "${escapeStringForJson(cep)}"');
    }
    if (cargo != null) {
      parts.add('"cargo": "${escapeStringForJson(cargo)}"');
    }
    if (registroProfissional != null) {
      parts.add(
          '"registro_profissional": "${escapeStringForJson(registroProfissional)}"');
    }
    final ffApiRequestBody = '{${parts.join(',')}}';
    final identificador = (usuarioUuid ?? '').trim().isNotEmpty
        ? usuarioUuid!.trim()
        : '${id ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'UpdateUsuario',
      apiUrl: '$kApiBaseUrl/api/usuarios/$identificador',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `DELETE /api/usuarios/{id|uuid}` — soft delete (`situacao = -2`).
class ExcluirUsuarioCall {
  static Future<ApiCallResponse> call({
    int? id,
    String? usuarioUuid = '',
    String? token = '',
  }) async {
    final identificador = (usuarioUuid ?? '').trim().isNotEmpty
        ? usuarioUuid!.trim()
        : '${id ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'ExcluirUsuario',
      apiUrl: '$kApiBaseUrl/api/usuarios/$identificador',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Accept': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

// --- Detalhes do usuário (admin) — alinhado ao Vue `usuarios/detalhes/[id].vue` ---

class GetUsuarioShowCall {
  static Future<ApiCallResponse> call({
    int? id,
    String? usuarioUuid = '',
    String? token = '',
  }) async {
    final identificador = (usuarioUuid ?? '').trim().isNotEmpty
        ? usuarioUuid!.trim()
        : '${id ?? 0}';

    return ApiManager.instance.makeApiCall(
      callName: 'GetUsuarioShow',
      apiUrl: '$kApiBaseUrl/api/usuarios/$identificador',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUsuarioObrasVinculadasCall {
  static Future<ApiCallResponse> call({
    required int usuarioId,
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'GetUsuarioObrasVinculadas',
      apiUrl: '$kApiBaseUrl/api/usuarios/$usuarioId/obras',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ListarObrasResumoCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    int itemsPerPage = 1000,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'ListarObrasResumo',
      apiUrl: '$kApiBaseUrl/api/obras/',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Accept': 'application/json',
      },
      params: {
        'itemsPerPage': itemsPerPage,
        'page': 1,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PutUsuarioObraTravadaCall {
  static Future<ApiCallResponse> call({
    required int usuarioId,
    required bool obraTravada,
    String? token = '',
  }) async {
    final body = '{"obra_travada": ${obraTravada ? 'true' : 'false'}}';
    return ApiManager.instance.makeApiCall(
      callName: 'PutUsuarioObraTravada',
      apiUrl: '$kApiBaseUrl/api/usuarios/$usuarioId/obra-travada',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PostUsuarioVincularObraCall {
  static Future<ApiCallResponse> call({
    required int usuarioId,
    required int obraId,
    required String permissao,
    String? token = '',
  }) async {
    final body =
        '{"obra_id": $obraId, "permissao": "${escapeStringForJson(permissao)}"}';
    return ApiManager.instance.makeApiCall(
      callName: 'PostUsuarioVincularObra',
      apiUrl: '$kApiBaseUrl/api/usuarios/$usuarioId/vincular-obra',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class DeleteUsuarioDesvincularObraCall {
  static Future<ApiCallResponse> call({
    required int usuarioId,
    required int obraId,
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'DeleteUsuarioDesvincularObra',
      apiUrl:
          '$kApiBaseUrl/api/usuarios/$usuarioId/desvincular-obra/$obraId',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Accept': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PutUsuarioAtualizarPermissaoObraCall {
  static Future<ApiCallResponse> call({
    required int usuarioId,
    required int obraId,
    required String permissao,
    String? token = '',
  }) async {
    final body =
        '{"obra_id": $obraId, "permissao": "${escapeStringForJson(permissao)}"}';
    return ApiManager.instance.makeApiCall(
      callName: 'PutUsuarioAtualizarPermissaoObra',
      apiUrl:
          '$kApiBaseUrl/api/usuarios/$usuarioId/atualizar-permissao',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUsersPermissoesListaCall {
  static Future<ApiCallResponse> call({
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'GetUsersPermissoesLista',
      apiUrl: '$kApiBaseUrl/api/users/permissoes',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUsersUsuarioPermissoesCall {
  static Future<ApiCallResponse> call({
    required int userId,
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'GetUsersUsuarioPermissoes',
      apiUrl: '$kApiBaseUrl/api/users/$userId/permissoes',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PutUsersSubstituirPermissoesCall {
  static Future<ApiCallResponse> call({
    required int userId,
    required List<int> permissionIds,
    String? token = '',
  }) async {
    final body = jsonEncode({'permission_ids': permissionIds});
    return ApiManager.instance.makeApiCall(
      callName: 'PutUsersSubstituirPermissoes',
      apiUrl:
          '$kApiBaseUrl/api/users/$userId/permissoes/substituir',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetMeusDadosCall {
  static Future<ApiCallResponse> call({
    String? token = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'GetMeusDados',
      apiUrl: '$kApiBaseUrl/api/users/me/dados',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer ${token}',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static List? dados(dynamic response) => getJsonField(
        response,
        r'''$.dados''',
        true,
      ) as List?;
  static bool? result(dynamic response) => castToType<bool>(getJsonField(
        response,
        r'''$.success''',
      ));
  static int? id(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.value.id''',
      ));
  static String? nome(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.value.nome''',
      ));
  static String? sobrenome(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.value.sobrenome''',
      ));
  static String? telefone(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.value.telefone''',
      ));
  static String? email(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.value.email''',
      ));
  static dynamic cargo(dynamic response) => getJsonField(
        response,
        r'''$.value.cargo''',
      );
  static dynamic registroProfissional(dynamic response) => getJsonField(
        response,
        r'''$.value.registro_profissional''',
      );
}

/// Mesmo contrato de `MeusDados.vue`: `PUT /api/profile/user` (Bearer).
class UpdateProfileUserCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    String? nome = '',
    String? sobrenome = '',
    String? telefone = '',
    String? cargo = '',
    String? registroProfissional = '',
  }) async {
    final ffApiRequestBody = '''
{
  "nome": "${escapeStringForJson(nome)}",
  "sobrenome": "${escapeStringForJson(sobrenome)}",
  "telefone": "${escapeStringForJson(telefone)}",
  "cargo": "${escapeStringForJson(cargo)}",
  "registro_profissional": "${escapeStringForJson(registroProfissional)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'UpdateProfileUser',
      apiUrl: '$kApiBaseUrl/api/profile/user',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static String? message(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.message''',
      ));
}

/// Mesmo contrato de `Seguranca.vue`: `PUT /api/profile/atualizar-senha` (Bearer).
class AtualizarSenhaCall {
  static Future<ApiCallResponse> call({
    String? token = '',
    String? currentPassword = '',
    String? password = '',
    String? passwordConfirmation = '',
  }) async {
    final ffApiRequestBody = '''
{
  "current_password": "${escapeStringForJson(currentPassword)}",
  "password": "${escapeStringForJson(password)}",
  "password_confirmation": "${escapeStringForJson(passwordConfirmation)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'AtualizarSenha',
      apiUrl: '$kApiBaseUrl/api/profile/atualizar-senha',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer ${token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static String? message(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.message''',
      ));
}

/// `GET /api/relatorios/exibir/{camufladoId}` — mesmo contrato do `[token].vue`.
class RelatorioExibirCall {
  static Future<ApiCallResponse> call({
    required String token,
    required String camufladoId,
  }) async {
    final encoded = Uri.encodeComponent(camufladoId);
    return ApiManager.instance.makeApiCall(
      callName: 'RelatorioExibir',
      apiUrl: '$kApiBaseUrl/api/relatorios/exibir/$encoded',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/relatorios/exibir-por-uuid/{uuid}` — mesmo payload que [exibir], para o app Flutter.
class RelatorioExibirPorUuidCall {
  static Future<ApiCallResponse> call({
    required String token,
    required String uuid,
  }) async {
    final encoded = Uri.encodeComponent(uuid.trim());
    return ApiManager.instance.makeApiCall(
      callName: 'RelatorioExibirPorUuid',
      apiUrl:
          '$kApiBaseUrl/api/relatorios/exibir-por-uuid/$encoded',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// Lista paginada por obra — usada para obter `camuflado_id` quando só há `id` local.
class RelatorioListObraCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int obraId,
    int page = 1,
    int itemsPerPage = 100,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'RelatorioListObra',
      apiUrl:
          '$kApiBaseUrl/api/relatorios/obra/$obraId?page=$page&itemsPerPage=$itemsPerPage',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/relatorios/{id}/fluxo-assinaturas` — `id` numérico do relatório.
class RelatorioFluxoAssinaturasCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int relatorioId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'RelatorioFluxoAssinaturas',
      apiUrl:
          '$kApiBaseUrl/api/relatorios/$relatorioId/fluxo-assinaturas',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/relatorios/{id}/enviar-aprovacao` — status 1 → 2 (dono do relatório).
class RelatorioEnviarAprovacaoCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int relatorioId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'RelatorioEnviarAprovacao',
      apiUrl:
          '$kApiBaseUrl/api/relatorios/$relatorioId/enviar-aprovacao',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: '{}',
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/relatorios/{id}/reenviar-aprovacao` — status reprovado → aguardando.
class RelatorioReenviarAprovacaoCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int relatorioId,
    String motivo = '',
  }) async {
    final body = json.encode({'motivo': motivo});
    return ApiManager.instance.makeApiCall(
      callName: 'RelatorioReenviarAprovacao',
      apiUrl:
          '$kApiBaseUrl/api/relatorios/$relatorioId/reenviar-aprovacao',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/assinaturas/relatorio/{id}/pode-processar`
class AssinaturaRelatorioPodeProcessarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int relatorioId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaRelatorioPodeProcessar',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/relatorio/$relatorioId/pode-processar',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/assinaturas/relatorio/{id}/status` — mesmo formato que [fluxo] do relatório.
class AssinaturaRelatorioStatusCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int relatorioId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaRelatorioStatus',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/relatorio/$relatorioId/status',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/assinaturas/relatorio/{id}/aprovar`
class AssinaturaRelatorioAprovarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int relatorioId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaRelatorioAprovar',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/relatorio/$relatorioId/aprovar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: '{}',
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/assinaturas/relatorio/{id}/reprovar` — body `{ "motivo": "..." }` (opcional na API).
class AssinaturaRelatorioReprovarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int relatorioId,
    required String motivo,
  }) async {
    final body = json.encode({'motivo': motivo});
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaRelatorioReprovar',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/relatorio/$relatorioId/reprovar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/ordens-servico/{id}/fluxo-assinaturas`
class OrdemServicoFluxoAssinaturasCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int ordemId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'OrdemServicoFluxoAssinaturas',
      apiUrl:
          '$kApiBaseUrl/api/ordens-servico/$ordemId/fluxo-assinaturas',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/ordens-servico/{id}/enviar-aprovacao` — status 1 → 2.
class OrdemServicoEnviarAprovacaoCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int ordemId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'OrdemServicoEnviarAprovacao',
      apiUrl:
          '$kApiBaseUrl/api/ordens-servico/$ordemId/enviar-aprovacao',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: '{}',
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/assinaturas/ordem-servico/{id}/pode-processar`
class AssinaturaOrdemServicoPodeProcessarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int ordemId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaOrdemServicoPodeProcessar',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/ordem-servico/$ordemId/pode-processar',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/assinaturas/ordem-servico/{id}/status` — fila de assinaturas (par [OrdemServicoFluxoAssinaturasCall]).
class AssinaturaOrdemServicoStatusCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int ordemId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaOrdemServicoStatus',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/ordem-servico/$ordemId/status',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/assinaturas/ordem-servico/{id}/aprovar`
class AssinaturaOrdemServicoAprovarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int ordemId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaOrdemServicoAprovar',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/ordem-servico/$ordemId/aprovar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: '{}',
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/assinaturas/ordem-servico/{id}/reprovar` — body `{ "motivo": "..." }`.
class AssinaturaOrdemServicoReprovarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int ordemId,
    required String motivo,
  }) async {
    final body = json.encode({'motivo': motivo});
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaOrdemServicoReprovar',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/ordem-servico/$ordemId/reprovar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/ordens-servico/{id}/aprovadores` — carimbo quando aprovado.
class OrdemServicoAprovadoresCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int ordemId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'OrdemServicoAprovadores',
      apiUrl:
          '$kApiBaseUrl/api/ordens-servico/$ordemId/aprovadores',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/ordens-servico/{id}/revogacoes` — body `{ "motivo_revogacao": "..." }`.
class OrdemServicoSolicitarRevogacaoCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int ordemId,
    required String motivoRevogacao,
  }) async {
    final body = json.encode({'motivo_revogacao': motivoRevogacao});
    return ApiManager.instance.makeApiCall(
      callName: 'OrdemServicoSolicitarRevogacao',
      apiUrl:
          '$kApiBaseUrl/api/ordens-servico/$ordemId/revogacoes',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/os-revogacoes/{uuid}/aprovar` — body `{ "motivo": "..." }` opcional.
class OsRevogacaoAprovarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required String revogacaoUuid,
    String motivo = '',
  }) async {
    final body = json.encode({'motivo': motivo});
    return ApiManager.instance.makeApiCall(
      callName: 'OsRevogacaoAprovar',
      apiUrl:
          '$kApiBaseUrl/api/os-revogacoes/$revogacaoUuid/aprovar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/os-revogacoes/{uuid}/rejeitar` — body `{ "motivo": "..." }`.
class OsRevogacaoRejeitarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required String revogacaoUuid,
    required String motivo,
  }) async {
    final body = json.encode({'motivo': motivo});
    return ApiManager.instance.makeApiCall(
      callName: 'OsRevogacaoRejeitar',
      apiUrl:
          '$kApiBaseUrl/api/os-revogacoes/$revogacaoUuid/rejeitar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// Baixa PDF da OS para arquivo temporário; retorna o caminho ou null em falha.
class OrdemServicoExportarPdf {
  static Future<String?> downloadToTemp({
    required String token,
    required int ordemId,
    required String baseFileName,
  }) async {
    final uri = Uri.parse(
      '$kApiBaseUrl/api/obras/ordens/$ordemId/exportar-pdf',
    );
    try {
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/pdf',
        },
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }
      final bytes = res.bodyBytes;
      if (bytes.length < 5 ||
          !(bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46)) {
        return null;
      }
      final dir = await getTemporaryDirectory();
      final safe = baseFileName.replaceAll(RegExp(r'[^\w\-\.]'), '_');
      final path = '${dir.path}/$safe.pdf';
      final f = File(path);
      await f.writeAsBytes(bytes);
      return path;
    } catch (_) {
      return null;
    }
  }
}

/// Baixa PDF para arquivo temporário; retorna o caminho ou null em falha.
class RelatorioExportarPdf {
  static Future<String?> downloadToTemp({
    required String token,
    required String camufladoId,
    required String baseFileName,
  }) async {
    final encoded = Uri.encodeComponent(camufladoId);
    final uri = Uri.parse(
      '$kApiBaseUrl/api/relatorios/exportar-pdf/$encoded',
    );
    try {
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/pdf',
        },
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }
      final bytes = res.bodyBytes;
      // Erro JSON (ex.: 404 mal propagado) ou HTML de proxy — não é PDF.
      if (bytes.length < 5 ||
          !(bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46)) {
        return null;
      }
      final dir = await getTemporaryDirectory();
      final safe =
          baseFileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
      if (safe.isEmpty) {
        return null;
      }
      final path = '${dir.path}/$safe.pdf';
      await File(path).writeAsBytes(bytes);
      return path;
    } catch (_) {
      return null;
    }
  }
}

/// `POST /api/relatorios/{id}/revogacoes`
class RelatorioSolicitarRevogacaoCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int relatorioId,
    required String motivoRevogacao,
  }) async {
    final body = json.encode({'motivo_revogacao': motivoRevogacao});
    return ApiManager.instance.makeApiCall(
      callName: 'RelatorioSolicitarRevogacao',
      apiUrl:
          '$kApiBaseUrl/api/relatorios/$relatorioId/revogacoes',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/relatorios/revogacoes/{uuid}/aprovar`
class RelatorioRevogacaoAprovarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required String revogacaoUuid,
    String motivo = '',
  }) async {
    final body = json.encode({'motivo': motivo});
    return ApiManager.instance.makeApiCall(
      callName: 'RelatorioRevogacaoAprovar',
      apiUrl:
          '$kApiBaseUrl/api/relatorios/revogacoes/$revogacaoUuid/aprovar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/relatorios/revogacoes/{uuid}/rejeitar`
class RelatorioRevogacaoRejeitarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required String revogacaoUuid,
    required String motivo,
  }) async {
    final body = json.encode({'motivo': motivo});
    return ApiManager.instance.makeApiCall(
      callName: 'RelatorioRevogacaoRejeitar',
      apiUrl:
          '$kApiBaseUrl/api/relatorios/revogacoes/$revogacaoUuid/rejeitar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CadastrarObraLocalCall {
  static Future<ApiCallResponse> call({
    String? nome = '',
    String? obraUuid = '',
    String? token = '',
  }) async {
    final ffApiRequestBody = '''
{
"obraUuid": "${escapeStringForJson(obraUuid)}",
"nome": "${escapeStringForJson(nome)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'CadastrarObraLocal',
      apiUrl: '$kApiBaseUrl/api/obras/0/locais',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${token}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
      client: ApiManager.getClient(withCredentials: true),
    );
  }
}

/// POST `/api/notificacoes/dispositivo` — grava instalação (`device_id`) e token FCM (`device_token`).
class NotificacaoRegistrarDispositivoCall {
  static Future<ApiCallResponse> call({
    required String token,
    required String deviceId,
    required String platform,
    required String deviceToken,
  }) async {
    final body = <String, dynamic>{
      'device_id': deviceId,
      'platform': platform,
      'device_token': deviceToken,
    };
    final ffApiRequestBody = jsonEncode(body);
    return ApiManager.instance.makeApiCall(
      callName: 'NotificacaoRegistrarDispositivo',
      apiUrl: '$kApiBaseUrl/api/notificacoes/dispositivo',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/api/notificacoes` — lista paginada (mesmo contrato do web).
class NotificacoesListCall {
  static Future<ApiCallResponse> call({
    required String token,
    int page = 1,
    int perPage = 20,
    String filter = 'all',
    String type = 'all',
    String priority = 'all',
    String module = 'all',
  }) async {
    final q = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (filter.isNotEmpty && filter != 'all') {
      q['filter'] = filter;
    }
    if (type.isNotEmpty && type != 'all') {
      q['type'] = type;
    }
    if (priority.isNotEmpty && priority != 'all') {
      q['priority'] = priority;
    }
    if (module.isNotEmpty && module != 'all') {
      q['module'] = module;
    }
    final uri = Uri.parse('$kApiBaseUrl/api/notificacoes')
        .replace(queryParameters: q);
    return ApiManager.instance.makeApiCall(
      callName: 'NotificacoesList',
      apiUrl: uri.toString(),
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PUT `/api/notificacoes/{id}/read`
class NotificacaoMarcarLidaCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'NotificacaoMarcarLida',
      apiUrl: '$kApiBaseUrl/api/notificacoes/$id/read',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PUT `/api/notificacoes/mark-all-read`
class NotificacoesMarcarTodasLidasCall {
  static Future<ApiCallResponse> call({required String token}) async {
    return ApiManager.instance.makeApiCall(
      callName: 'NotificacoesMarcarTodasLidas',
      apiUrl: '$kApiBaseUrl/api/notificacoes/mark-all-read',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// DELETE `/api/notificacoes/{id}`
class NotificacaoExcluirCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'NotificacaoExcluir',
      apiUrl: '$kApiBaseUrl/api/notificacoes/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/api/medicoes` — lista paginada (mesmo contrato do web / `useMedicoes.js`).
/// GET `/api/medicoes/{id}` — detalhe com `obra`, `itens`, `assinaturas`, revogações.
class MedicaoShowCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int medicaoId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'MedicaoShow',
      apiUrl: '$kApiBaseUrl/api/medicoes/$medicaoId',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/api/medicoes/{id}/fluxo-assinaturas` — `fluxo` com `assinaturas` e `proximo`.
class MedicaoFluxoAssinaturasCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int medicaoId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'MedicaoFluxoAssinaturas',
      apiUrl:
          '$kApiBaseUrl/api/medicoes/$medicaoId/fluxo-assinaturas',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/medicoes/{id}/enviar-aprovacao` — status preenchendo → em aprovação.
class MedicaoEnviarAprovacaoCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int medicaoId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'MedicaoEnviarAprovacao',
      apiUrl:
          '$kApiBaseUrl/api/medicoes/$medicaoId/enviar-aprovacao',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: '{}',
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/assinaturas/medicao/{id}/pode-processar`
class AssinaturaMedicaoPodeProcessarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int medicaoId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaMedicaoPodeProcessar',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/medicao/$medicaoId/pode-processar',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/assinaturas/medicao/{id}/status`
class AssinaturaMedicaoStatusCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int medicaoId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaMedicaoStatus',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/medicao/$medicaoId/status',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/assinaturas/medicao/{id}/aprovar`
class AssinaturaMedicaoAprovarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int medicaoId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaMedicaoAprovar',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/medicao/$medicaoId/aprovar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: '{}',
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/assinaturas/medicao/{id}/reprovar` — body `{ "motivo": "..." }`.
class AssinaturaMedicaoReprovarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int medicaoId,
    required String motivo,
  }) async {
    final body = json.encode({'motivo': motivo});
    return ApiManager.instance.makeApiCall(
      callName: 'AssinaturaMedicaoReprovar',
      apiUrl:
          '$kApiBaseUrl/api/assinaturas/medicao/$medicaoId/reprovar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `GET /api/medicoes/{id}/aprovadores` — carimbo quando aprovada.
class MedicaoAprovadoresCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int medicaoId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'MedicaoAprovadores',
      apiUrl: '$kApiBaseUrl/api/medicoes/$medicaoId/aprovadores',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/medicoes/{id}/revogacoes` — `{ "motivo_revogacao": "..." }`.
class MedicaoSolicitarRevogacaoCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int medicaoId,
    required String motivoRevogacao,
  }) async {
    final body = json.encode({'motivo_revogacao': motivoRevogacao});
    return ApiManager.instance.makeApiCall(
      callName: 'MedicaoSolicitarRevogacao',
      apiUrl: '$kApiBaseUrl/api/medicoes/$medicaoId/revogacoes',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/med-revogacoes/{uuid}/aprovar`
class MedRevogacaoAprovarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required String revogacaoUuid,
    String motivo = '',
  }) async {
    final body = json.encode({'motivo': motivo});
    return ApiManager.instance.makeApiCall(
      callName: 'MedRevogacaoAprovar',
      apiUrl:
          '$kApiBaseUrl/api/med-revogacoes/$revogacaoUuid/aprovar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// `POST /api/med-revogacoes/{uuid}/rejeitar`
class MedRevogacaoRejeitarCall {
  static Future<ApiCallResponse> call({
    required String token,
    required String revogacaoUuid,
    required String motivo,
  }) async {
    final body = json.encode({'motivo': motivo});
    return ApiManager.instance.makeApiCall(
      callName: 'MedRevogacaoRejeitar',
      apiUrl:
          '$kApiBaseUrl/api/med-revogacoes/$revogacaoUuid/rejeitar',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// Baixa PDF da medição para arquivo temporário.
class MedicaoExportarPdf {
  static Future<String?> downloadToTemp({
    required String token,
    required int medicaoId,
    required String baseFileName,
  }) async {
    final uri = Uri.parse(
      '$kApiBaseUrl/api/medicoes/$medicaoId/exportar-pdf',
    );
    try {
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/pdf',
        },
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }
      final bytes = res.bodyBytes;
      if (bytes.length < 5 ||
          !(bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46)) {
        return null;
      }
      final dir = await getTemporaryDirectory();
      final safe = baseFileName.replaceAll(RegExp(r'[^\w\-\.]'), '_');
      final path = '${dir.path}/$safe.pdf';
      await File(path).writeAsBytes(bytes);
      return path;
    } catch (_) {
      return null;
    }
  }
}

/// Baixa PDF do checklist preenchido para arquivo temporário.
class ChecklistExportarPdf {
  static Future<String?> downloadToTemp({
    required String token,
    required int checklistId,
    required String baseFileName,
  }) async {
    final uri = Uri.parse(
      '$kApiBaseUrl/api/checklists-preenchidos/$checklistId/exportar-pdf',
    );
    try {
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/pdf',
        },
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }
      final bytes = res.bodyBytes;
      if (bytes.length < 5 ||
          !(bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46)) {
        return null;
      }
      final dir = await getTemporaryDirectory();
      final safe = baseFileName.replaceAll(RegExp(r'[^\w\-\.]'), '_');
      final path = '${dir.path}/$safe.pdf';
      await File(path).writeAsBytes(bytes);
      return path;
    } catch (_) {
      return null;
    }
  }
}

class MedicoesListCall {
  static Future<ApiCallResponse> call({
    required String token,
    int page = 1,
    int perPage = 15,
    int? obraId,
    String? status,
    String? mesReferencia,
  }) async {
    final q = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (obraId != null) q['obra_id'] = '$obraId';
    if (status != null && status.isNotEmpty) q['status'] = status;
    if (mesReferencia != null && mesReferencia.isNotEmpty) {
      q['mes_referencia'] = mesReferencia;
    }
    final uri = Uri.parse('$kApiBaseUrl/api/medicoes')
        .replace(queryParameters: q);
    return ApiManager.instance.makeApiCall(
      callName: 'MedicoesList',
      apiUrl: uri.toString(),
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

// --- Insumos (mesmo contrato do web: `frontend/.../insumos/list/index.vue`) ---

/// GET `/api/insumos` — lista paginada (`search`, `per_page`, `page`, `sort_by`, `sort_order`, `situacao`, `categoria`).
class InsumosListCall {
  static Future<ApiCallResponse> call({
    required String token,
    String search = '',
    int page = 1,
    int perPage = 10,
    String sortBy = 'nome',
    String sortOrder = 'asc',
    String situacao = '',
    String categoria = '',
  }) async {
    final q = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (search.trim().isNotEmpty) {
      q['search'] = search.trim();
    }
    if (situacao.isNotEmpty) {
      q['situacao'] = situacao;
    }
    if (categoria.isNotEmpty) {
      q['categoria'] = categoria;
    }
    final uri = Uri.parse('$kApiBaseUrl/api/insumos')
        .replace(queryParameters: q);
    return ApiManager.instance.makeApiCall(
      callName: 'InsumosList',
      apiUrl: uri.toString(),
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/api/insumos/categorias`
class InsumosCategoriasCall {
  static Future<ApiCallResponse> call({required String token}) async {
    return ApiManager.instance.makeApiCall(
      callName: 'InsumosCategorias',
      apiUrl: '$kApiBaseUrl/api/insumos/categorias',
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/api/insumos/exportar` — dados para exportação (JSON).
class InsumosExportarCall {
  static Future<ApiCallResponse> call({
    required String token,
    String situacao = '',
    String categoria = '',
  }) async {
    final q = <String, String>{};
    if (situacao.isNotEmpty) {
      q['situacao'] = situacao;
    }
    if (categoria.isNotEmpty) {
      q['categoria'] = categoria;
    }
    final base = Uri.parse('$kApiBaseUrl/api/insumos/exportar');
    final uri = q.isEmpty ? base : base.replace(queryParameters: q);
    return ApiManager.instance.makeApiCall(
      callName: 'InsumosExportar',
      apiUrl: uri.toString(),
      callType: ApiCallType.GET,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// POST `/api/insumos`
class InsumoCreateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'InsumoCreate',
      apiUrl: '$kApiBaseUrl/api/insumos',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PUT `/api/insumos/{id}`
class InsumoUpdateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'InsumoUpdate',
      apiUrl: '$kApiBaseUrl/api/insumos/$id',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// DELETE `/api/insumos/{id}`
class InsumoDeleteCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'InsumoDelete',
      apiUrl: '$kApiBaseUrl/api/insumos/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PATCH `/api/insumos/{id}/situacao`
class InsumoPatchSituacaoCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
    required String situacao,
  }) async {
    final body = jsonEncode({'situacao': situacao});
    return ApiManager.instance.makeApiCall(
      callName: 'InsumoPatchSituacao',
      apiUrl: '$kApiBaseUrl/api/insumos/$id/situacao',
      callType: ApiCallType.PATCH,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

// --- Equipamentos (`frontend/.../equipamentos/list/index.vue`) ---

/// POST `/api/equipamentos`
class EquipamentoCreateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'EquipamentoCreate',
      apiUrl: '$kApiBaseUrl/api/equipamentos',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PUT `/api/equipamentos/{id}`
class EquipamentoUpdateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'EquipamentoUpdate',
      apiUrl: '$kApiBaseUrl/api/equipamentos/$id',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// DELETE `/api/equipamentos/{id}`
class EquipamentoDeleteCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'EquipamentoDelete',
      apiUrl: '$kApiBaseUrl/api/equipamentos/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PATCH `/api/equipamentos/{id}/situacao` — `disponivel` | `em_uso` | `manutencao` | `inativo`
class EquipamentoPatchSituacaoCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
    required String situacao,
  }) async {
    final body = jsonEncode({'situacao': situacao});
    return ApiManager.instance.makeApiCall(
      callName: 'EquipamentoPatchSituacao',
      apiUrl: '$kApiBaseUrl/api/equipamentos/$id/situacao',
      callType: ApiCallType.PATCH,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

// --- Mão de obra / profissionais (`frontend/.../mao-obra/list/index.vue`) ---

/// POST `/api/mao-obra-profissionais`
class MaoObraProfissionalCreateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'MaoObraProfissionalCreate',
      apiUrl: '$kApiBaseUrl/api/mao-obra-profissionais',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PUT `/api/mao-obra-profissionais/{id}`
class MaoObraProfissionalUpdateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'MaoObraProfissionalUpdate',
      apiUrl: '$kApiBaseUrl/api/mao-obra-profissionais/$id',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// DELETE `/api/mao-obra-profissionais/{id}`
class MaoObraProfissionalDeleteCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'MaoObraProfissionalDelete',
      apiUrl: '$kApiBaseUrl/api/mao-obra-profissionais/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PATCH `/api/mao-obra-profissionais/{id}/situacao` — `ativo` | `inativo` | `ferias` | `afastado`
class MaoObraProfissionalPatchSituacaoCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
    required String situacao,
  }) async {
    final body = jsonEncode({'situacao': situacao});
    return ApiManager.instance.makeApiCall(
      callName: 'MaoObraProfissionalPatchSituacao',
      apiUrl:
          '$kApiBaseUrl/api/mao-obra-profissionais/$id/situacao',
      callType: ApiCallType.PATCH,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: body,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

// --- Locais (`LocaisController`: nome único por creator) ---

/// POST `/api/locais/`
class LocalCreateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'LocalCreate',
      apiUrl: '$kApiBaseUrl/api/locais',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PUT `/api/locais/{id}`
class LocalUpdateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'LocalUpdate',
      apiUrl: '$kApiBaseUrl/api/locais/$id',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// DELETE `/api/locais/{id}`
class LocalDeleteCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'LocalDelete',
      apiUrl: '$kApiBaseUrl/api/locais/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

// --- Funções de mão de obra (`FuncoesMaoObraController`: nome único por creator) ---

/// POST `/api/funcoes-mao-obra/`
class FuncaoMaoObraCreateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'FuncaoMaoObraCreate',
      apiUrl: '$kApiBaseUrl/api/funcoes-mao-obra',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PUT `/api/funcoes-mao-obra/{id}`
class FuncaoMaoObraUpdateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'FuncaoMaoObraUpdate',
      apiUrl: '$kApiBaseUrl/api/funcoes-mao-obra/$id',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// DELETE `/api/funcoes-mao-obra/{id}`
class FuncaoMaoObraDeleteCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'FuncaoMaoObraDelete',
      apiUrl: '$kApiBaseUrl/api/funcoes-mao-obra/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

// --- Grupos de obras (`GrupoObrasController`: campo `nome`) ---

/// POST `/api/grupo-obras/`
class GrupoObrasCreateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'GrupoObrasCreate',
      apiUrl: '$kApiBaseUrl/api/grupo-obras',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// PUT `/api/grupo-obras/{id}`
class GrupoObrasUpdateCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
    required Map<String, dynamic> body,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'GrupoObrasUpdate',
      apiUrl: '$kApiBaseUrl/api/grupo-obras/$id',
      callType: ApiCallType.PUT,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      params: {},
      body: jsonEncode(body),
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// DELETE `/api/grupo-obras/{id}`
class GrupoObrasDeleteCall {
  static Future<ApiCallResponse> call({
    required String token,
    required int id,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'GrupoObrasDelete',
      apiUrl: '$kApiBaseUrl/api/grupo-obras/$id',
      callType: ApiCallType.DELETE,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      params: {},
      bodyType: BodyType.NONE,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// GET `/api/app/version` — versões Android/iOS (público, sem auth).
class AppVersionPublicCall {
  static Future<ApiCallResponse> call() async {
    return ApiManager.instance.makeApiCall(
      callName: 'AppVersionPublic',
      apiUrl: '$kApiBaseUrl/api/app/version',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String? escapeStringForJson(String? input) {
  if (input == null) {
    return null;
  }
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\t', '\\t');
}

/**
  @file     iot_dpobj.ctl
  @brief    Registro de clases con DP: mapa propiedad -> DPE y jerarquía de cada clase.
  @author   TEST_LIBS

  Documento del módulo: dev/modulos/dpobj.md (en TEST_CLAUDE). La clase raíz está en classes/iot/IotDpObject.ctl.
*/

const string IOT_DPOBJ_DPT_REGISTRO   = "_IotDpClase";
const string IOT_DPOBJ_ELEMENTO_MAPA  = "mapa";
const string IOT_DPOBJ_PREFIJO        = "_IotClase_";
const string IOT_DPOBJ_SEPARADOR      = "-";
const string IOT_DPOBJ_CLASE_RAIZ     = "IotDpObject";
const string IOT_DPOBJ_TIPO_MAPPING   = "mapping";   // se guarda como string JSON
const string IOT_DPOBJ_CLAVE_RUTA     = "ruta";
const string IOT_DPOBJ_CLAVE_TIPO     = "tipo";
const string IOT_DPOBJ_CLAVE_CLASE    = "clase";
const string IOT_DPOBJ_CATALOGO       = "iot_dpobj";
const string IOT_DPOBJ_FLAG           = "iot_dpobj";

const int IOT_DPOBJ_OK           = 0;
const int IOT_DPOBJ_ERR_REGISTRO = -1;   // la clase no tiene registro o está mal formado
const int IOT_DPOBJ_ERR_DP       = -2;   // DP inexistente o fallo de dpGet/dpSet
const int IOT_DPOBJ_ERR_NOMBRE   = -3;   // nombre de DP de registro no válido
const int IOT_DPOBJ_ERR_DPT      = -4;   // no se puede crear el DPT de registro
const int IOT_DPOBJ_ERR_PROPIEDAD = -5;  // la propiedad no está en el registro de la clase

// Códigos del catálogo msg/<idioma>/iot_dpobj.cat
const int IOT_DPOBJ_MSG_SIN_REGISTRO = 1;
const int IOT_DPOBJ_MSG_DP           = 2;
const int IOT_DPOBJ_MSG_NOMBRE       = 3;
const int IOT_DPOBJ_MSG_DPT          = 4;
const int IOT_DPOBJ_MSG_PROPIEDAD    = 5;

// Caché clase -> DP de registro, compartida por todos los scripts del manager (estilo-ctrl.md §5)
global mapping g_iotDpObjRegistros;

/**
  @brief  Mapa de una clase: propiedad -> mapping con las claves ruta, tipo y clase.
  @param  clase  Nombre de la clase.
  @param  mapa   Salida: mapa con la herencia ya resuelta.
  @return IOT_DPOBJ_OK, IOT_DPOBJ_ERR_REGISTRO o IOT_DPOBJ_ERR_DP.
*/
int iot_getDpObjMapa(string clase, mapping &mapa)
{
  mappingClear(mapa);
  string dpRegistro = _iot_findDpObjRegistro(clase);
  if (dpRegistro == "")
    return _iot_logDpObjError(IOT_DPOBJ_ERR_REGISTRO, IOT_DPOBJ_MSG_SIN_REGISTRO, clase);

  string json;
  if (dpGet(dpRegistro + "." + IOT_DPOBJ_ELEMENTO_MAPA, json) != 0)
    return _iot_logDpObjError(IOT_DPOBJ_ERR_DP, IOT_DPOBJ_MSG_DP, dpRegistro);

  anytype decodificado = jsonDecode(json);
  if (getType(decodificado) != MAPPING_VAR)
    return _iot_logDpObjError(IOT_DPOBJ_ERR_REGISTRO, IOT_DPOBJ_MSG_SIN_REGISTRO, dpRegistro);
  mapa = decodificado;
  return IOT_DPOBJ_OK;
}

/**
  @brief  Cadena de clases desde la primera bajo IotDpObject hasta la clase, ambas incluidas.
  @return IOT_DPOBJ_OK o IOT_DPOBJ_ERR_REGISTRO.
*/
int iot_getDpObjJerarquia(string clase, dyn_string &jerarquia)
{
  dynClear(jerarquia);
  string dpRegistro = _iot_findDpObjRegistro(clase);
  if (dpRegistro == "")
    return IOT_DPOBJ_ERR_REGISTRO;
  jerarquia = _iot_getDpObjSegmentos(dpRegistro);
  return IOT_DPOBJ_OK;
}

/**
  @brief  Clases registradas que heredan, directa o indirectamente, de una clase.
  @param  clases  Salida: ordenadas de forma que un padre siempre va antes que sus hijas.
  @return IOT_DPOBJ_OK.
*/
int iot_getDpObjDescendientes(string clase, dyn_string &clases)
{
  dynClear(clases);
  dyn_string registros = _iot_getDpObjRegistros();
  // Por profundidad: un antepasado siempre tiene menos segmentos que sus descendientes
  for (int profundidad = 2; profundidad <= _iot_getDpObjMaxProfundidad(registros); profundidad++)
  {
    for (int i = 1; i <= dynlen(registros); i++)
    {
      dyn_string segmentos = _iot_getDpObjSegmentos(registros[i]);
      int posicion = dynContains(segmentos, clase);
      if (dynlen(segmentos) == profundidad && posicion > 0 && posicion < profundidad)
        dynAppend(clases, segmentos[profundidad]);
    }
  }
  return IOT_DPOBJ_OK;
}

/**
  @brief  Guarda el registro de la última clase de la jerarquía. Crea el DPT de registro si falta
          y renombra el DP si la jerarquía de la clase ha cambiado.
  @param  jerarquia  Clases desde la primera bajo IotDpObject hasta la clase.
  @param  mapa       Propiedad -> mapping con ruta, tipo y clase.
  @return IOT_DPOBJ_OK, IOT_DPOBJ_ERR_DPT, IOT_DPOBJ_ERR_NOMBRE o IOT_DPOBJ_ERR_DP.
*/
int iot_setDpObjRegistro(dyn_string jerarquia, mapping mapa)
{
  if (dynlen(jerarquia) == 0)
    return _iot_logDpObjError(IOT_DPOBJ_ERR_NOMBRE, IOT_DPOBJ_MSG_NOMBRE, "");
  int resultado = _iot_ensureDpObjDptRegistro();
  if (resultado != IOT_DPOBJ_OK)
    return resultado;

  string clase = jerarquia[dynlen(jerarquia)];
  string dpNuevo = IOT_DPOBJ_PREFIJO + strjoin(jerarquia, IOT_DPOBJ_SEPARADOR);
  string comprobado = dpNuevo;
  if (nameCheck(comprobado, NAMETYPE_DP) != 0)
    return _iot_logDpObjError(IOT_DPOBJ_ERR_NOMBRE, IOT_DPOBJ_MSG_NOMBRE, dpNuevo);

  string dpAnterior = _iot_findDpObjRegistro(clase);
  if (!dpExists(dpNuevo) && dpCreate(dpNuevo, IOT_DPOBJ_DPT_REGISTRO) != 0)
    return _iot_logDpObjError(IOT_DPOBJ_ERR_DP, IOT_DPOBJ_MSG_DP, dpNuevo);
  if (dpSetWait(dpNuevo + "." + IOT_DPOBJ_ELEMENTO_MAPA, jsonEncode(mapa)) != 0)
    return _iot_logDpObjError(IOT_DPOBJ_ERR_DP, IOT_DPOBJ_MSG_DP, dpNuevo);

  if (dpAnterior != "" && dpAnterior != dpNuevo && dpDelete(dpAnterior) != 0)
    return _iot_logDpObjError(IOT_DPOBJ_ERR_DP, IOT_DPOBJ_MSG_DP, dpAnterior);
  g_iotDpObjRegistros[clase] = dpNuevo;
  return IOT_DPOBJ_OK;
}

/**
  @brief  Borra el registro de una clase. No toca el de sus descendientes: quien borra una jerarquía empieza por las hojas.
  @param  clase  Nombre de la clase.
  @return IOT_DPOBJ_OK, IOT_DPOBJ_ERR_REGISTRO (la clase no está registrada) o IOT_DPOBJ_ERR_DP.
*/
int iot_deleteDpObjRegistro(string clase)
{
  string dpRegistro = _iot_findDpObjRegistro(clase);
  if (dpRegistro == "")
    return IOT_DPOBJ_ERR_REGISTRO;
  if (dpDelete(dpRegistro) != 0)
    return _iot_logDpObjError(IOT_DPOBJ_ERR_DP, IOT_DPOBJ_MSG_DP, dpRegistro);
  mappingRemove(g_iotDpObjRegistros, clase);
  return IOT_DPOBJ_OK;
}

/**
  @brief  Lee del DP, en ese momento y con un solo dpGet, varias propiedades de un objeto. La usa IotDpObject.
  @param  clase        Clase real del objeto.
  @param  dp           DP del objeto.
  @param  propiedades  Propiedades a leer, heredadas incluidas.
  @param  valores      Salida: propiedad -> valor. Una propiedad mapping se devuelve ya decodificada.
  @return IOT_DPOBJ_OK, IOT_DPOBJ_ERR_REGISTRO, IOT_DPOBJ_ERR_PROPIEDAD o IOT_DPOBJ_ERR_DP. Con error, valores queda vacío.
*/
int iot_getDpObjValores(string clase, string dp, dyn_string propiedades, mapping &valores)
{
  mappingClear(valores);
  dyn_string dpes, tipos;
  int resultado = _iot_getDpObjDpes(clase, dp, propiedades, dpes, tipos);
  if (resultado != IOT_DPOBJ_OK || dynlen(dpes) == 0)
    return resultado;

  dyn_anytype leidos;
  if (dpGet(dpes, leidos) != 0 || dynlen(leidos) != dynlen(dpes))
    return _iot_logDpObjError(IOT_DPOBJ_ERR_DP, IOT_DPOBJ_MSG_DP, dp);
  for (int i = 1; i <= dynlen(propiedades); i++)
  {
    if (tipos[i] == IOT_DPOBJ_TIPO_MAPPING)
      valores[propiedades[i]] = _iot_decodeDpObjMapping(leidos[i]);
    else
      valores[propiedades[i]] = leidos[i];
  }
  return IOT_DPOBJ_OK;
}

/**
  @brief  Escribe en el DP, al momento y con un solo dpSetWait, varias propiedades de un objeto. La usa IotDpObject.
          Si una propiedad no existe no se escribe ninguna.
  @param  valores  Propiedad -> valor. Una propiedad mapping se guarda como JSON.
  @return IOT_DPOBJ_OK, IOT_DPOBJ_ERR_REGISTRO, IOT_DPOBJ_ERR_PROPIEDAD o IOT_DPOBJ_ERR_DP.
*/
int iot_setDpObjValores(string clase, string dp, mapping valores)
{
  dyn_string propiedades = mappingKeys(valores);
  dyn_string dpes, tipos;
  int resultado = _iot_getDpObjDpes(clase, dp, propiedades, dpes, tipos);
  if (resultado != IOT_DPOBJ_OK || dynlen(dpes) == 0)
    return resultado;

  // Por índice, no con dynAppend: un valor dyn_* se añadiría elemento a elemento
  dyn_anytype escritos;
  for (int i = 1; i <= dynlen(propiedades); i++)
  {
    // Un anytype que ya contiene un mapping no cambia de tipo al asignarle un string: variable aparte
    if (tipos[i] == IOT_DPOBJ_TIPO_MAPPING)
    {
      string json = jsonEncode(valores[propiedades[i]]);
      escritos[i] = json;
    }
    else
    {
      escritos[i] = valores[propiedades[i]];
    }
  }
  if (dpSetWait(dpes, escritos) != 0)
    return _iot_logDpObjError(IOT_DPOBJ_ERR_DP, IOT_DPOBJ_MSG_DP, dp);
  return IOT_DPOBJ_OK;
}

// --- Funciones internas ---

/** DPEs y tipos de unas propiedades de una clase para un DP, en el mismo orden. */
int _iot_getDpObjDpes(string clase, string dp, dyn_string propiedades, dyn_string &dpes, dyn_string &tipos)
{
  dynClear(dpes);
  dynClear(tipos);
  if (dp == "" || !dpExists(dp))
    return _iot_logDpObjError(IOT_DPOBJ_ERR_DP, IOT_DPOBJ_MSG_DP, dp);

  mapping mapa;
  int resultado = iot_getDpObjMapa(clase, mapa);
  if (resultado != IOT_DPOBJ_OK)
    return resultado;

  string dpBase = dpSubStr(dp, DPSUB_SYS_DP);
  for (int i = 1; i <= dynlen(propiedades); i++)
  {
    if (!mappingHasKey(mapa, propiedades[i]))
    {
      dynClear(dpes);
      dynClear(tipos);
      return _iot_logDpObjError(IOT_DPOBJ_ERR_PROPIEDAD, IOT_DPOBJ_MSG_PROPIEDAD, clase + "." + propiedades[i]);
    }
    mapping entrada = mapa[propiedades[i]];
    dynAppend(dpes, dpBase + "." + entrada[IOT_DPOBJ_CLAVE_RUTA]);
    dynAppend(tipos, entrada[IOT_DPOBJ_CLAVE_TIPO]);
  }
  return IOT_DPOBJ_OK;
}

/** Un DPE vacío o con JSON que no es un objeto se lee como mapping vacío. */
mapping _iot_decodeDpObjMapping(string json)
{
  anytype decodificado = json == "" ? makeMapping() : jsonDecode(json);
  return getType(decodificado) == MAPPING_VAR ? (mapping)decodificado : makeMapping();
}

/** DP de registro (sin sistema) de una clase, o "" si no está registrada. */
string _iot_findDpObjRegistro(string clase)
{
  if (mappingHasKey(g_iotDpObjRegistros, clase) && dpExists(g_iotDpObjRegistros[clase]))
    return g_iotDpObjRegistros[clase];

  dyn_string registros = _iot_getDpObjRegistros();
  for (int i = 1; i <= dynlen(registros); i++)
  {
    dyn_string segmentos = _iot_getDpObjSegmentos(registros[i]);
    if (dynlen(segmentos) > 0 && segmentos[dynlen(segmentos)] == clase)
    {
      g_iotDpObjRegistros[clase] = registros[i];
      return registros[i];
    }
  }
  return "";
}

dyn_string _iot_getDpObjRegistros()
{
  dyn_string registros;
  if (dynlen(dpTypes(IOT_DPOBJ_DPT_REGISTRO)) == 0)
    return registros;
  dyn_string conSistema = dpNames(IOT_DPOBJ_PREFIJO + "*", IOT_DPOBJ_DPT_REGISTRO);
  for (int i = 1; i <= dynlen(conSistema); i++)
    dynAppend(registros, dpSubStr(conSistema[i], DPSUB_DP));
  return registros;
}

dyn_string _iot_getDpObjSegmentos(string dpRegistro)
{
  return strsplit(substr(dpRegistro, strlen(IOT_DPOBJ_PREFIJO)), IOT_DPOBJ_SEPARADOR);
}

int _iot_getDpObjMaxProfundidad(dyn_string registros)
{
  int maximo = 0;
  for (int i = 1; i <= dynlen(registros); i++)
  {
    int profundidad = dynlen(_iot_getDpObjSegmentos(registros[i]));
    if (profundidad > maximo)
      maximo = profundidad;
  }
  return maximo;
}

int _iot_ensureDpObjDptRegistro()
{
  if (dynlen(dpTypes(IOT_DPOBJ_DPT_REGISTRO)) > 0)
    return IOT_DPOBJ_OK;
  dyn_dyn_string elementos;
  dyn_dyn_int tipos;
  elementos[1] = makeDynString(IOT_DPOBJ_DPT_REGISTRO, "");
  elementos[2] = makeDynString("", IOT_DPOBJ_ELEMENTO_MAPA);
  tipos[1] = makeDynInt(DPEL_STRUCT);
  tipos[2] = makeDynInt(0, DPEL_STRING);
  if (dpTypeCreate(elementos, tipos) != 0)
    return _iot_logDpObjError(IOT_DPOBJ_ERR_DPT, IOT_DPOBJ_MSG_DPT, IOT_DPOBJ_DPT_REGISTRO);
  return IOT_DPOBJ_OK;
}

/** Registra el error con throwError() y devuelve el código para propagarlo. */
int _iot_logDpObjError(int codigo, int mensaje, string elemento)
{
  throwError(makeError(IOT_DPOBJ_CATALOGO, PRIO_WARNING, ERR_CONTROL, mensaje, elemento));
  return codigo;
}

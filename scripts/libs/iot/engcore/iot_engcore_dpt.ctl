/**
  @file     iot_engcore_dpt.ctl
  @brief    Área dpt de engcore: mantiene el DPT de cada clase decorada (y de sus descendientes) igual que la clase.
  @author   TEST_LIBS

  Solo para ingeniería (Script Editor y tests), no se carga en runtime.
  Documento del módulo: dev/modulos/engcore.md (en TEST_CLAUDE).
*/
#uses "iot/dpobj/iot_dpobj"
#uses "iot/engcore/iot_engcore_comun"

const string IOT_ENGCORE_DPT_DECORADOR    = "//@";
const string IOT_ENGCORE_DPT_INICIO       = "//@dp:";
const string IOT_ENGCORE_DPT_FIN          = "//@end";
const string IOT_ENGCORE_DPT_MODIFICADOR  = "protected";
const int    IOT_ENGCORE_DPT_MAX_HERENCIA = 32;   // corta herencias circulares
const string IOT_ENGCORE_DPT_ESPACIOS     = " \t\r";
const string IOT_ENGCORE_DPT_CARACTERES_ID = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789";
const string IOT_ENGCORE_DPT_DIGITOS      = "0123456789";

// Bloque de accesores generados (spec 002.2): se reescribe entero en cada generación
const string IOT_ENGCORE_DPT_GENERADO     = "//@generado";
const string IOT_ENGCORE_DPT_FIN_GENERADO = "//@fin-generado";
const string IOT_ENGCORE_DPT_AVISO_GENERADO = ": no editar, lo reescribe IoT > Generar DPT desde clase";
const string IOT_ENGCORE_DPT_SANGRIA      = "  ";
const dyn_string IOT_ENGCORE_DPT_RESERVADOS = makeDynString("getDp", "setDp", "getVarios", "setVarios");   // métodos de IotDpObject

struct IotDptPropiedad
{
  string nombre;
  string tipo;    // tipo CTRL
  string ruta;    // DPE completo, p. ej. comandos.run
  string clase;   // clase que la declara
  int linea;
};

struct IotDptClase
{
  string nombre;
  string padre;
  string fichero;
  int linea;
  int lineaFin;   // línea de la llave que cierra la clase
  vector<IotDptPropiedad> propiedades;
};

struct IotDptPlan
{
  dyn_string clases;          // orden de aplicación: padres antes que hijas
  mapping jerarquias;         // clase -> dyn_string, desde la primera bajo IotDpObject
  mapping mapas;              // clase -> mapa del registro de dpobj
  dyn_string eliminaciones;   // "Clase: ruta"
  mapping dpsAfectados;       // clase -> número de DPs, solo para clases con eliminaciones
  dyn_string errores;         // "fichero:línea: texto" o "Clase: texto"
};

/**
  @brief  Analiza un texto CTRL y devuelve sus clases con las propiedades decoradas.
  @param  texto    Contenido del fichero.
  @param  clases   Salida: clases en orden de aparición.
  @param  errores  Salida: "<línea>: <texto>".
  @return IOT_ENGCORE_OK o IOT_ENGCORE_ERR_PLAN si hay errores.
*/
int iot_parseDptClases(string texto, vector<IotDptClase> &clases, dyn_string &errores)
{
  clases.clear();
  dynClear(errores);
  dyn_string lineas = _iot_splitDptLineas(texto);

  IotDptClase actual;
  bool enClase = false, abierta = false, enBloque = false, enGenerado = false;
  int profundidad = 0, lineaBloque = 0;
  string rutaBloque;
  mapping metodos;   // métodos declarados a mano en la clase: nombre -> línea

  for (int numero = 1; numero <= dynlen(lineas); numero++)
  {
    string linea = _iot_trimDpt(lineas[numero]);

    if (!enClase)
    {
      if (_iot_startsWithDpt(linea, "class "))
      {
        actual = _iot_parseDptCabecera(linea, numero);
        enClase = true;
        enGenerado = false;
        mappingClear(metodos);
        profundidad = _iot_countDptLlaves(linea);
        abierta = strpos(_iot_stripDptComentario(linea), "{") >= 0;
      }
      else if (_iot_startsWithDpt(linea, IOT_ENGCORE_DPT_DECORADOR))
      {
        dynAppend(errores, _iot_formatDptError(numero, "errDecoradorFueraDeClase"));
      }
      continue;
    }

    if (_iot_isDptInicioGenerado(linea))
    {
      enGenerado = true;
    }
    else if (linea == IOT_ENGCORE_DPT_FIN_GENERADO)
    {
      enGenerado = false;
    }
    else if (_iot_startsWithDpt(linea, IOT_ENGCORE_DPT_INICIO))
    {
      if (enBloque)
      {
        dynAppend(errores, _iot_formatDptError(numero, "errBloqueAnidado"));
        continue;
      }
      rutaBloque = _iot_trimDpt(substr(linea, strlen(IOT_ENGCORE_DPT_INICIO)));
      if (!_iot_isDptRuta(rutaBloque, true))
        dynAppend(errores, _iot_formatDptError(numero, "errRutaInvalida", rutaBloque));
      enBloque = true;
      lineaBloque = numero;
    }
    else if (linea == IOT_ENGCORE_DPT_FIN)
    {
      if (!enBloque)
        dynAppend(errores, _iot_formatDptError(numero, "errEndSinAbrir"));
      enBloque = false;
    }
    else if (_iot_startsWithDpt(linea, IOT_ENGCORE_DPT_DECORADOR))
    {
      dynAppend(errores, _iot_formatDptError(numero, "errDecoradorDesconocido", linea));
    }
    else if (enBloque && !_iot_startsWithDpt(linea, "}"))
    {
      if (linea != "")
        _iot_parseDptDeclaracion(linea, numero, rutaBloque, actual, errores);
    }
    else
    {
      // Una llave de cierre dentro de un bloque: el bloque no se cerró. Se señala el //@dp: y la línea sigue como código
      if (enBloque)
      {
        dynAppend(errores, _iot_formatDptError(lineaBloque, "errBloqueSinCerrar"));
        enBloque = false;
      }
      // Solo cuentan las declaraciones del cuerpo de la clase (profundidad 1), no las llamadas dentro de los métodos
      string metodo = _iot_getDptNombreMetodo(linea);
      if (profundidad == 1 && !enGenerado && metodo != "" && !mappingHasKey(metodos, metodo))
        metodos[metodo] = numero;
      profundidad += _iot_countDptLlaves(linea);
      abierta = abierta || strpos(_iot_stripDptComentario(linea), "{") >= 0;
      if (abierta && profundidad <= 0)
      {
        actual.lineaFin = numero;
        _iot_checkDptAccesores(actual, metodos, errores);
        clases.append(actual);
        enClase = false;
      }
    }
  }

  if (enBloque)
    dynAppend(errores, _iot_formatDptError(lineaBloque, "errBloqueSinCerrar"));
  if (enClase)
  {
    // Clase sin cerrar: el compilador CTRL ya lo señalará
    actual.lineaFin = dynlen(lineas);
    _iot_checkDptAccesores(actual, metodos, errores);
    clases.append(actual);
  }
  return dynlen(errores) == 0 ? IOT_ENGCORE_OK : IOT_ENGCORE_ERR_PLAN;
}

/**
  @brief  Reescribe el bloque //@generado de cada clase del texto con un getter y un setter por propiedad propia.
          Una clase sin propiedades propias se queda sin bloque. El resto de líneas no cambia. Función pura.
  @param  texto    Contenido del fichero.
  @param  lineas   Salida: líneas del fichero resultante, sin fin de línea.
  @param  errores  Salida: errores del análisis ("<línea>: <texto>"). Con errores, lineas queda vacía.
  @return IOT_ENGCORE_OK o IOT_ENGCORE_ERR_PLAN.
*/
int iot_buildDptAccesores(string texto, dyn_string &lineas, dyn_string &errores)
{
  dynClear(lineas);
  vector<IotDptClase> clases;
  if (iot_parseDptClases(texto, clases, errores) != IOT_ENGCORE_OK)
    return IOT_ENGCORE_ERR_PLAN;

  lineas = _iot_splitDptLineas(texto);
  for (int i = 1; i <= dynlen(lineas); i++)
    lineas[i] = strrtrim(lineas[i], "\r");

  // De la última clase a la primera, para que los números de línea de las anteriores sigan valiendo
  for (int i = clases.count() - 1; i >= 0; i--)
  {
    IotDptClase clase = clases.at(i);
    int fin = clase.lineaFin - _iot_removeDptBloqueGenerado(lineas, clase.linea, clase.lineaFin);
    if (clase.propiedades.count() == 0)
      continue;

    dyn_string bloque;
    if (fin > 1 && _iot_trimDpt(lineas[fin - 1]) != "")
      dynAppend(bloque, "");
    dynAppend(bloque, IOT_ENGCORE_DPT_SANGRIA + IOT_ENGCORE_DPT_GENERADO + IOT_ENGCORE_DPT_AVISO_GENERADO);
    for (int j = 0; j < clase.propiedades.count(); j++)
    {
      IotDptPropiedad propiedad = clase.propiedades.at(j);
      dynAppend(bloque, IOT_ENGCORE_DPT_SANGRIA + "public " + propiedad.tipo + " " + _iot_getDptAccesor("get", propiedad.nombre)
                        + "() { return (" + propiedad.tipo + ")_getDp(\"" + propiedad.nombre + "\"); }");
      dynAppend(bloque, IOT_ENGCORE_DPT_SANGRIA + "public int " + _iot_getDptAccesor("set", propiedad.nombre)
                        + "(" + propiedad.tipo + " valor) { return _setDp(\"" + propiedad.nombre + "\", valor); }");
    }
    dynAppend(bloque, IOT_ENGCORE_DPT_SANGRIA + IOT_ENGCORE_DPT_FIN_GENERADO);
    dynInsertAt(lineas, bloque, fin);
  }
  return IOT_ENGCORE_OK;
}

/**
  @brief  Calcula los cambios para las clases decoradas de un fichero y para todas sus descendientes registradas.
          No modifica nada.
  @param  fichero  Ruta absoluta del fichero .ctl.
  @param  plan     Salida.
  @return IOT_ENGCORE_OK, IOT_ENGCORE_ERR_FICHERO o IOT_ENGCORE_ERR_PLAN (ver plan.errores).
*/
int iot_planDptFromFile(string fichero, IotDptPlan &plan)
{
  _iot_clearDptPlan(plan);

  vector<IotDptClase> todas;
  dyn_string objetivos, visitados;
  int resultado = _iot_loadDptFichero(fichero, todas, plan.errores, visitados, objetivos);
  if (resultado == IOT_ENGCORE_ERR_FICHERO)
    return resultado;
  if (dynlen(plan.errores) > 0)
    return IOT_ENGCORE_ERR_PLAN;

  // Clases del fichero: herencia resuelta con el propio fichero y sus #uses
  for (int i = 1; i <= dynlen(objetivos); i++)
    _iot_planDptClase(objetivos[i], todas, plan);
  if (dynlen(plan.errores) > 0)
    return IOT_ENGCORE_ERR_PLAN;

  // Descendientes registradas: se recalculan desde el registro con lo nuevo de su padre
  dyn_string generadas = plan.clases;
  for (int i = 1; i <= dynlen(generadas); i++)
  {
    dyn_string descendientes;
    iot_getDpObjDescendientes(generadas[i], descendientes);
    for (int j = 1; j <= dynlen(descendientes); j++)
    {
      if (dynContains(plan.clases, descendientes[j]) < 1)
        _iot_planDptDescendiente(descendientes[j], plan);
    }
  }

  _iot_sortDptPlan(plan);
  for (int i = 1; i <= dynlen(plan.clases); i++)
    _iot_planDptEliminaciones(plan.clases[i], plan);
  return dynlen(plan.errores) == 0 ? IOT_ENGCORE_OK : IOT_ENGCORE_ERR_PLAN;
}

/**
  @brief  Aplica un plan sin errores: crea o modifica cada DPT (padres antes que hijas) y actualiza su registro.
  @return IOT_ENGCORE_OK, IOT_ENGCORE_ERR_PLAN, IOT_ENGCORE_ERR_DPT o IOT_ENGCORE_ERR_REGISTRO.
*/
int iot_applyDptPlan(IotDptPlan plan)
{
  if (dynlen(plan.errores) > 0)
    return IOT_ENGCORE_ERR_PLAN;

  for (int i = 1; i <= dynlen(plan.clases); i++)
  {
    string clase = plan.clases[i];
    mapping mapa = plan.mapas[clase];
    dyn_string jerarquia = plan.jerarquias[clase];

    if (mappinglen(mapa) > 0)
    {
      dyn_dyn_string elementos;
      dyn_dyn_int tipos;
      _iot_buildDptEstructura(clase, mapa, elementos, tipos);
      int creado = dynlen(dpTypes(clase)) > 0 ? dpTypeChange(elementos, tipos) : dpTypeCreate(elementos, tipos);
      if (creado != 0)
        return _iot_logEngcoreError(IOT_ENGCORE_ERR_DPT, IOT_ENGCORE_MSG_DPT, clase);
    }
    if (iot_setDpObjRegistro(jerarquia, mapa) != IOT_DPOBJ_OK)
      return _iot_logEngcoreError(IOT_ENGCORE_ERR_REGISTRO, IOT_ENGCORE_MSG_REGISTRO, clase);
    DebugFTN(IOT_ENGCORE_FLAG, "aplicada", clase, jerarquia);
  }
  return IOT_ENGCORE_OK;
}

// --- Funciones internas: análisis ---

dyn_string _iot_splitDptLineas(string texto)
{
  dyn_string lineas;
  int inicio = 0;
  int fin = strpos(texto, "\n");
  while (fin >= 0)
  {
    dynAppend(lineas, substr(texto, inicio, fin - inicio));
    inicio = fin + 1;
    fin = strpos(texto, "\n", inicio);
  }
  dynAppend(lineas, substr(texto, inicio));
  return lineas;
}

string _iot_trimDpt(string texto)
{
  return strltrim(strrtrim(texto, IOT_ENGCORE_DPT_ESPACIOS), IOT_ENGCORE_DPT_ESPACIOS);
}

bool _iot_startsWithDpt(string texto, string prefijo)
{
  return strpos(texto, prefijo) == 0;
}

string _iot_stripDptComentario(string linea)
{
  int comentario = strpos(linea, "//");
  return comentario >= 0 ? substr(linea, 0, comentario) : linea;
}

int _iot_countDptLlaves(string linea)
{
  string codigo = _iot_stripDptComentario(linea);
  int balance = 0;
  for (int i = 0; i < strlen(codigo); i++)
  {
    string caracter = substr(codigo, i, 1);
    if (caracter == "{")
      balance++;
    else if (caracter == "}")
      balance--;
  }
  return balance;
}

bool _iot_isDptIdentificador(string texto)
{
  if (texto == "" || strpos(IOT_ENGCORE_DPT_DIGITOS, substr(texto, 0, 1)) >= 0)
    return false;
  for (int i = 0; i < strlen(texto); i++)
  {
    if (strpos(IOT_ENGCORE_DPT_CARACTERES_ID, substr(texto, i, 1)) < 0)
      return false;
  }
  return true;
}

bool _iot_isDptRuta(string ruta, bool vaciaValida)
{
  if (ruta == "")
    return vaciaValida;
  dyn_string segmentos = strsplit(ruta, ".");
  if (dynlen(segmentos) == 0 || substr(ruta, strlen(ruta) - 1) == ".")
    return false;
  for (int i = 1; i <= dynlen(segmentos); i++)
  {
    if (!_iot_isDptIdentificador(segmentos[i]))
      return false;
  }
  return true;
}

dyn_string _iot_splitDptPalabras(string texto)
{
  dyn_string palabras;
  strreplace(texto, "\t", " ");
  dyn_string trozos = strsplit(texto, " ");
  for (int i = 1; i <= dynlen(trozos); i++)
  {
    if (trozos[i] != "")
      dynAppend(palabras, trozos[i]);
  }
  return palabras;
}

/** "class B : A {" -> nombre B y padre A. Sin padre, padre vacío. */
IotDptClase _iot_parseDptCabecera(string linea, int numero)
{
  IotDptClase clase;
  string codigo = _iot_stripDptComentario(linea);
  int llave = strpos(codigo, "{");
  if (llave >= 0)
    codigo = substr(codigo, 0, llave);
  codigo = _iot_trimDpt(substr(codigo, strlen("class ")));

  int dosPuntos = strpos(codigo, ":");
  if (dosPuntos >= 0)
  {
    clase.nombre = _iot_trimDpt(substr(codigo, 0, dosPuntos));
    clase.padre = _iot_trimDpt(substr(codigo, dosPuntos + 1));
  }
  else
  {
    clase.nombre = codigo;
  }
  clase.linea = numero;
  return clase;
}

/** Valida "protected tipo nombre;" y la añade a la clase. Los errores llevan la línea. */
void _iot_parseDptDeclaracion(string linea, int numero, string rutaBloque, IotDptClase &clase, dyn_string &errores)
{
  string codigo = _iot_trimDpt(_iot_stripDptComentario(linea));
  if (strpos(codigo, "=") >= 0)
  {
    dynAppend(errores, _iot_formatDptError(numero, "errInicializador"));
    return;
  }
  if (substr(codigo, strlen(codigo) - 1) != ";")
  {
    dynAppend(errores, _iot_formatDptError(numero, "errNoDeclaracion"));
    return;
  }

  dyn_string palabras = _iot_splitDptPalabras(substr(codigo, 0, strlen(codigo) - 1));
  bool otroModificador = dynlen(palabras) == 3 && (palabras[1] == "private" || palabras[1] == "public");
  if (dynlen(palabras) == 2 || otroModificador)
  {
    dynAppend(errores, _iot_formatDptError(numero, "errSinProtected"));
    return;
  }
  if (dynlen(palabras) != 3 || palabras[1] != IOT_ENGCORE_DPT_MODIFICADOR || !_iot_isDptIdentificador(palabras[3]))
  {
    dynAppend(errores, _iot_formatDptError(numero, "errNoDeclaracion"));
    return;
  }
  if (_iot_getDptTipoDpel(palabras[2]) < 0)
  {
    dynAppend(errores, _iot_formatDptError(numero, "errTipo", palabras[2]));
    return;
  }

  IotDptPropiedad propiedad;
  propiedad.nombre = palabras[3];
  propiedad.tipo = palabras[2];
  propiedad.ruta = rutaBloque == "" ? palabras[3] : rutaBloque + "." + palabras[3];
  propiedad.clase = clase.nombre;
  propiedad.linea = numero;

  for (int i = 0; i < clase.propiedades.count(); i++)
  {
    if (clase.propiedades.at(i).ruta == propiedad.ruta)
    {
      dynAppend(errores, _iot_formatDptError(numero, "errRutaRepetida", propiedad.ruta, clase.nombre));
      return;
    }
  }
  clase.propiedades.append(propiedad);
}

/** "public int getA() {" -> "getA". "" si la línea no declara un método (o es una inicialización con llamada). */
string _iot_getDptNombreMetodo(string linea)
{
  string codigo = _iot_stripDptComentario(linea);
  int parentesis = strpos(codigo, "(");
  if (parentesis < 0)
    return "";
  string antes = substr(codigo, 0, parentesis);
  if (strpos(antes, "=") >= 0)
    return "";
  dyn_string palabras = _iot_splitDptPalabras(antes);
  if (dynlen(palabras) < 2 || !_iot_isDptIdentificador(palabras[dynlen(palabras)]))
    return "";
  return palabras[dynlen(palabras)];
}

/** "//@generado" o "//@generado: aviso". */
bool _iot_isDptInicioGenerado(string linea)
{
  return linea == IOT_ENGCORE_DPT_GENERADO || _iot_startsWithDpt(linea, IOT_ENGCORE_DPT_GENERADO + ":");
}

/** "get", "velocidad" -> "getVelocidad". */
string _iot_getDptAccesor(string prefijo, string nombre)
{
  return prefijo + strtoupper(substr(nombre, 0, 1)) + substr(nombre, 1);
}

/** Error si un accesor que se va a generar ya existe: escrito a mano en la clase o como método de IotDpObject. */
void _iot_checkDptAccesores(IotDptClase &clase, mapping &metodos, dyn_string &errores)
{
  for (int i = 0; i < clase.propiedades.count(); i++)
  {
    IotDptPropiedad propiedad = clase.propiedades.at(i);
    dyn_string accesores = makeDynString(_iot_getDptAccesor("get", propiedad.nombre), _iot_getDptAccesor("set", propiedad.nombre));
    for (int j = 1; j <= dynlen(accesores); j++)
    {
      if (dynContains(IOT_ENGCORE_DPT_RESERVADOS, accesores[j]) > 0)
        dynAppend(errores, _iot_formatDptError(propiedad.linea, "errAccesorReservado", propiedad.nombre, accesores[j]));
      else if (mappingHasKey(metodos, accesores[j]))
        dynAppend(errores, _iot_formatDptError(metodos[accesores[j]], "errMetodoChoca", accesores[j], propiedad.nombre));
    }
  }
}

/**
  Quita de las líneas desde..hasta el bloque //@generado … //@fin-generado y la línea vacía que lo precede.
  @return Número de líneas quitadas.
*/
int _iot_removeDptBloqueGenerado(dyn_string &lineas, int desde, int hasta)
{
  int inicio = 0, fin = 0;
  for (int i = desde; i <= hasta && i <= dynlen(lineas); i++)
  {
    string linea = _iot_trimDpt(lineas[i]);
    if (inicio == 0 && _iot_isDptInicioGenerado(linea))
      inicio = i;
    else if (inicio > 0 && linea == IOT_ENGCORE_DPT_FIN_GENERADO)
    {
      fin = i;
      break;
    }
  }
  if (inicio == 0 || fin == 0)
    return 0;
  if (inicio > desde + 1 && _iot_trimDpt(lineas[inicio - 1]) == "")
    inicio--;
  for (int i = fin; i >= inicio; i--)
    dynRemove(lineas, i);
  return fin - inicio + 1;
}

/** Tipo DPEL_* de un tipo CTRL, o -1 si no se admite. mapping se guarda como string JSON (dpobj). */
int _iot_getDptTipoDpel(string tipo)
{
  mapping tipos = makeMapping("bool", DPEL_BOOL, "int", DPEL_INT, "uint", DPEL_UINT, "float", DPEL_FLOAT,
                              "string", DPEL_STRING, "time", DPEL_TIME, "langString", DPEL_LANGSTRING,
                              "dyn_bool", DPEL_DYN_BOOL, "dyn_int", DPEL_DYN_INT, "dyn_uint", DPEL_DYN_UINT,
                              "dyn_float", DPEL_DYN_FLOAT, "dyn_string", DPEL_DYN_STRING, "dyn_time", DPEL_DYN_TIME,
                              "dyn_langString", DPEL_DYN_LANGSTRING, IOT_DPOBJ_TIPO_MAPPING, DPEL_STRING);
  return mappingHasKey(tipos, tipo) ? tipos[tipo] : -1;
}

string _iot_formatDptError(int numero, string clave, string p1 = "", string p2 = "")
{
  return numero + ": " + iot_getEngcoreTexto(clave, p1, p2);
}

// --- Funciones internas: ficheros y herencia ---

/**
  Analiza un fichero y, recursivamente, sus #uses. Las clases del primer fichero van a objetivos.
  Los errores se prefijan con el nombre del fichero.
*/
int _iot_loadDptFichero(string fichero, vector<IotDptClase> &todas, dyn_string &errores,
                        dyn_string &visitados, dyn_string &objetivos)
{
  if (dynContains(visitados, fichero) > 0)
    return IOT_ENGCORE_OK;
  dynAppend(visitados, fichero);

  string texto;
  if (!fileToString(fichero, texto))
  {
    dynAppend(errores, iot_getEngcoreTexto("errFichero", fichero));
    return IOT_ENGCORE_ERR_FICHERO;
  }

  vector<IotDptClase> clases;
  dyn_string erroresFichero;
  iot_parseDptClases(texto, clases, erroresFichero);
  string nombreFichero = _iot_getDptNombreFichero(fichero);
  for (int i = 1; i <= dynlen(erroresFichero); i++)
    dynAppend(errores, nombreFichero + ":" + erroresFichero[i]);

  bool esPrimero = dynlen(visitados) == 1;
  for (int i = 0; i < clases.count(); i++)
  {
    IotDptClase clase = clases.at(i);
    clase.fichero = nombreFichero;
    todas.append(clase);
    if (esPrimero)
      dynAppend(objetivos, clase.nombre);
  }

  dyn_string usos = _iot_getDptUsos(texto);
  for (int i = 1; i <= dynlen(usos); i++)
  {
    string ruta = getPath(LIBS_REL_PATH, usos[i]);
    if (ruta != "")
      _iot_loadDptFichero(ruta, todas, errores, visitados, objetivos);
  }
  return IOT_ENGCORE_OK;
}

dyn_string _iot_getDptUsos(string texto)
{
  dyn_string usos;
  dyn_string lineas = _iot_splitDptLineas(texto);
  for (int i = 1; i <= dynlen(lineas); i++)
  {
    string linea = _iot_trimDpt(lineas[i]);
    if (!_iot_startsWithDpt(linea, "#uses"))
      continue;
    dyn_string partes = strsplit(linea, "\"");
    if (dynlen(partes) >= 2)
    {
      string uso = partes[2];
      if (strpos(uso, ".ctl") != strlen(uso) - 4)
        uso += ".ctl";
      dynAppend(usos, uso);
    }
  }
  return usos;
}

string _iot_getDptNombreFichero(string fichero)
{
  string normalizado = fichero;
  strreplace(normalizado, "\\", "/");
  dyn_string partes = strsplit(normalizado, "/");
  return dynlen(partes) > 0 ? partes[dynlen(partes)] : fichero;
}

int _iot_findDptClase(vector<IotDptClase> &todas, string nombre)
{
  for (int i = 0; i < todas.count(); i++)
  {
    if (todas.at(i).nombre == nombre)
      return i;
  }
  return -1;
}

/** Plan de una clase del fichero: cadena de herencia hasta IotDpObject, propiedades aplanadas y validación. */
void _iot_planDptClase(string nombre, vector<IotDptClase> &todas, IotDptPlan &plan)
{
  int indice = _iot_findDptClase(todas, nombre);
  IotDptClase clase = todas.at(indice);

  // Cadena desde la clase hacia arriba; se invierte al final
  dyn_int cadena = makeDynInt(indice);
  string padre = clase.padre;
  while (padre != IOT_DPOBJ_CLASE_RAIZ)
  {
    if (padre == "")
    {
      if (clase.propiedades.count() > 0)
        dynAppend(plan.errores, clase.fichero + ":" + clase.linea + ": " + iot_getEngcoreTexto("errSinRaiz", clase.nombre));
      return;  // no es una clase con DP
    }
    int indicePadre = _iot_findDptClase(todas, padre);
    if (indicePadre < 0)
    {
      // Sin decoradores puede ser una clase cualquiera con un padre de otra librería: no es asunto de engcore
      if (clase.propiedades.count() > 0)
        dynAppend(plan.errores, clase.fichero + ":" + clase.linea + ": " + iot_getEngcoreTexto("errPadre", padre));
      return;
    }
    if (dynlen(cadena) >= IOT_ENGCORE_DPT_MAX_HERENCIA || dynContains(cadena, indicePadre) > 0)
    {
      dynAppend(plan.errores, clase.fichero + ":" + clase.linea + ": " + iot_getEngcoreTexto("errHerencia", clase.nombre));
      return;
    }
    dynAppend(cadena, indicePadre);
    padre = todas.at(indicePadre).padre;
  }

  dyn_string jerarquia;
  mapping mapa;
  dyn_string errores;
  for (int i = dynlen(cadena); i >= 1; i--)
  {
    IotDptClase eslabon = todas.at(cadena[i]);
    dynAppend(jerarquia, eslabon.nombre);
    for (int j = 0; j < eslabon.propiedades.count(); j++)
    {
      IotDptPropiedad propiedad = eslabon.propiedades.at(j);
      _iot_addDptEntrada(mapa, propiedad.nombre, propiedad.ruta, propiedad.tipo, propiedad.clase,
                         eslabon.fichero + ":" + propiedad.linea + ": ", errores);
    }
  }
  _iot_addDptClasePlan(nombre, jerarquia, mapa, errores, plan);
}

/** Plan de una descendiente registrada: lo nuevo de su padre (ya en el plan) más sus propias propiedades. */
void _iot_planDptDescendiente(string nombre, IotDptPlan &plan)
{
  dyn_string jerarquiaActual;
  mapping mapaActual;
  if (iot_getDpObjJerarquia(nombre, jerarquiaActual) != IOT_DPOBJ_OK || dynlen(jerarquiaActual) < 2
      || iot_getDpObjMapa(nombre, mapaActual) != IOT_DPOBJ_OK)
  {
    dynAppend(plan.errores, nombre + ": " + iot_getEngcoreTexto("errRegistro", nombre));
    return;
  }
  string padre = jerarquiaActual[dynlen(jerarquiaActual) - 1];
  if (!mappingHasKey(plan.mapas, padre))
  {
    dynAppend(plan.errores, nombre + ": " + iot_getEngcoreTexto("errPadre", padre));
    return;
  }

  dyn_string jerarquia = plan.jerarquias[padre];
  dynAppend(jerarquia, nombre);
  mapping mapaPadre = plan.mapas[padre];
  mapping mapa;
  dyn_string errores;
  for (int i = 1; i <= mappinglen(mapaPadre); i++)
  {
    mapping entrada = mappingGetValue(mapaPadre, i);
    _iot_addDptEntrada(mapa, mappingGetKey(mapaPadre, i), entrada[IOT_DPOBJ_CLAVE_RUTA], entrada[IOT_DPOBJ_CLAVE_TIPO],
                       entrada[IOT_DPOBJ_CLAVE_CLASE], nombre + ": ", errores);
  }
  for (int i = 1; i <= mappinglen(mapaActual); i++)
  {
    mapping entrada = mappingGetValue(mapaActual, i);
    if (entrada[IOT_DPOBJ_CLAVE_CLASE] == nombre)
      _iot_addDptEntrada(mapa, mappingGetKey(mapaActual, i), entrada[IOT_DPOBJ_CLAVE_RUTA], entrada[IOT_DPOBJ_CLAVE_TIPO],
                         nombre, nombre + ": ", errores);
  }
  _iot_addDptClasePlan(nombre, jerarquia, mapa, errores, plan);
}

/** Añade una propiedad al mapa comprobando nombre repetido, ruta repetida y choque de estructura. */
void _iot_addDptEntrada(mapping &mapa, string nombre, string ruta, string tipo, string clase, string prefijo,
                        dyn_string &errores)
{
  if (mappingHasKey(mapa, nombre))
  {
    dynAppend(errores, prefijo + iot_getEngcoreTexto("errNombreRepetido", nombre, clase));
    return;
  }
  for (int i = 1; i <= mappinglen(mapa); i++)
  {
    mapping entrada = mappingGetValue(mapa, i);
    string otra = entrada[IOT_DPOBJ_CLAVE_RUTA];
    if (otra == ruta)
    {
      dynAppend(errores, prefijo + iot_getEngcoreTexto("errRutaRepetida", ruta, clase));
      return;
    }
    if (strpos(otra, ruta + ".") == 0 || strpos(ruta, otra + ".") == 0)
    {
      dynAppend(errores, prefijo + iot_getEngcoreTexto("errEstructura", ruta, otra, clase));
      return;
    }
  }
  mapa[nombre] = makeMapping(IOT_DPOBJ_CLAVE_RUTA, ruta, IOT_DPOBJ_CLAVE_TIPO, tipo, IOT_DPOBJ_CLAVE_CLASE, clase);
}

void _iot_addDptClasePlan(string nombre, dyn_string jerarquia, mapping mapa, dyn_string errores, IotDptPlan &plan)
{
  // Se comprueba antes de añadir: dynAppend con una dyn como origen la vacía
  bool hayErrores = dynlen(errores) > 0;
  dynAppend(plan.errores, errores);
  if (hayErrores)
    return;
  dynAppend(plan.clases, nombre);
  plan.jerarquias[nombre] = jerarquia;
  plan.mapas[nombre] = mapa;
}

/** Ordena por longitud de jerarquía: un padre siempre va antes que sus hijas. */
void _iot_sortDptPlan(IotDptPlan &plan)
{
  dyn_string ordenadas;
  for (int profundidad = 1; dynlen(ordenadas) < dynlen(plan.clases); profundidad++)
  {
    for (int i = 1; i <= dynlen(plan.clases); i++)
    {
      dyn_string jerarquia = plan.jerarquias[plan.clases[i]];
      if (dynlen(jerarquia) == profundidad)
        dynAppend(ordenadas, plan.clases[i]);
    }
    if (profundidad > IOT_ENGCORE_DPT_MAX_HERENCIA)
      break;
  }
  plan.clases = ordenadas;
}

void _iot_clearDptPlan(IotDptPlan &plan)
{
  dynClear(plan.clases);
  mappingClear(plan.jerarquias);
  mappingClear(plan.mapas);
  dynClear(plan.eliminaciones);
  mappingClear(plan.dpsAfectados);
  dynClear(plan.errores);
}

// --- Funciones internas: estructura del DPT ---

/** Elementos del DPT que desaparecen o cambian de tipo respecto al DPT existente. */
void _iot_planDptEliminaciones(string clase, IotDptPlan &plan)
{
  if (dynlen(dpTypes(clase)) == 0)
    return;
  dyn_dyn_string elementos;
  dyn_dyn_int tipos;
  if (dpTypeGet(clase, elementos, tipos) != 0)
    return;

  mapping existentes = _iot_getDptHojas(elementos, tipos);
  mapping nuevas;
  mapping mapa = plan.mapas[clase];
  for (int i = 1; i <= mappinglen(mapa); i++)
  {
    mapping entrada = mappingGetValue(mapa, i);
    nuevas[entrada[IOT_DPOBJ_CLAVE_RUTA]] = _iot_getDptTipoDpel(entrada[IOT_DPOBJ_CLAVE_TIPO]);
  }

  int antes = dynlen(plan.eliminaciones);
  for (int i = 1; i <= mappinglen(existentes); i++)
  {
    string ruta = mappingGetKey(existentes, i);
    if (!mappingHasKey(nuevas, ruta) || nuevas[ruta] != mappingGetValue(existentes, i))
      dynAppend(plan.eliminaciones, clase + ": " + ruta);
  }
  if (dynlen(plan.eliminaciones) > antes)
    plan.dpsAfectados[clase] = dynlen(dpNames("*", clase));
}

/** Hojas de un DPT leído con dpTypeGet: ruta -> tipo DPEL_*. */
mapping _iot_getDptHojas(dyn_dyn_string elementos, dyn_dyn_int tipos)
{
  mapping hojas;
  dyn_string pila;
  for (int fila = 1; fila <= dynlen(elementos); fila++)
  {
    for (int columna = 1; columna <= dynlen(elementos[fila]); columna++)
    {
      if (elementos[fila][columna] == "")
        continue;
      pila[columna] = elementos[fila][columna];
      while (dynlen(pila) > columna)
        dynRemove(pila, dynlen(pila));
      int tipo = columna <= dynlen(tipos[fila]) ? tipos[fila][columna] : DPEL_STRUCT;
      if (columna > 1 && tipo != DPEL_STRUCT)
      {
        dyn_string ruta = pila;
        dynRemove(ruta, 1);
        hojas[strjoin(ruta, ".")] = tipo;
      }
      break;
    }
  }
  return hojas;
}

/** Arrays de dpTypeCreate/dpTypeChange a partir del mapa: árbol agrupado por nodos intermedios. */
void _iot_buildDptEstructura(string clase, mapping mapa, dyn_dyn_string &elementos, dyn_dyn_int &tipos)
{
  mapping hijos;   // ruta del nodo ("" = raíz) -> dyn_string de nombres en orden
  mapping hojas;   // ruta -> DPEL_*
  int maxNivel = 1;
  hijos[""] = makeDynString();
  for (int i = 1; i <= mappinglen(mapa); i++)
  {
    mapping entrada = mappingGetValue(mapa, i);
    dyn_string segmentos = strsplit(entrada[IOT_DPOBJ_CLAVE_RUTA], ".");
    string nodo = "";
    for (int j = 1; j <= dynlen(segmentos); j++)
    {
      dyn_string lista = hijos[nodo];
      if (dynContains(lista, segmentos[j]) < 1)
      {
        dynAppend(lista, segmentos[j]);
        hijos[nodo] = lista;
      }
      nodo = nodo == "" ? segmentos[j] : nodo + "." + segmentos[j];
      if (j < dynlen(segmentos) && !mappingHasKey(hijos, nodo))
        hijos[nodo] = makeDynString();
    }
    hojas[nodo] = _iot_getDptTipoDpel(entrada[IOT_DPOBJ_CLAVE_TIPO]);
    if (dynlen(segmentos) + 1 > maxNivel)
      maxNivel = dynlen(segmentos) + 1;
  }

  dynClear(elementos);
  dynClear(tipos);
  _iot_addDptFila(elementos, tipos, clase, 1, DPEL_STRUCT, maxNivel);
  _iot_addDptNodo("", 2, hijos, hojas, maxNivel, elementos, tipos);
}

void _iot_addDptNodo(string nodo, int nivel, mapping &hijos, mapping &hojas, int maxNivel,
                     dyn_dyn_string &elementos, dyn_dyn_int &tipos)
{
  dyn_string lista = hijos[nodo];
  for (int i = 1; i <= dynlen(lista); i++)
  {
    string ruta = nodo == "" ? lista[i] : nodo + "." + lista[i];
    if (mappingHasKey(hojas, ruta))
    {
      _iot_addDptFila(elementos, tipos, lista[i], nivel, hojas[ruta], maxNivel);
    }
    else
    {
      _iot_addDptFila(elementos, tipos, lista[i], nivel, DPEL_STRUCT, maxNivel);
      _iot_addDptNodo(ruta, nivel + 1, hijos, hojas, maxNivel, elementos, tipos);
    }
  }
}

void _iot_addDptFila(dyn_dyn_string &elementos, dyn_dyn_int &tipos, string nombre, int nivel, int tipo, int maxNivel)
{
  dyn_string fila;
  dyn_int filaTipos;
  for (int i = 1; i <= maxNivel; i++)
  {
    dynAppend(fila, i == nivel ? nombre : "");
    if (i <= nivel)
      dynAppend(filaTipos, i == nivel ? tipo : 0);
  }
  int numero = dynlen(elementos) + 1;
  elementos[numero] = fila;
  tipos[numero] = filaTipos;
}

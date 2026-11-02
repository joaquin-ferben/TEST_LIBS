/**
  @file     iot_engcore_explorador.ctl
  @brief    Área explorador de engcore: las clases con DP vistas desde sus ficheros, y crear, mover y borrar clases.
  @author   TEST_LIBS

  Lo usan el panel iot_engcore_explorador.xml (funciones del final, solo UI) y los tests. No se carga en runtime.
  Documento del módulo: dev/modulos/engcore.md (en TEST_CLAUDE).
*/
#uses "iot/dpobj/iot_dpobj"
#uses "iot/engcore/iot_engcore_comun"
#uses "iot/engcore/iot_engcore_dpt"

const string IOT_ENGCORE_VISTA_INGENIERIA = "IotIngenieria";   // vista CNS del marco de ingeniería
const string IOT_ENGCORE_PANEL_EXPLORADOR = "iot/engcore/iot_engcore_explorador.xml";
const string IOT_ENGCORE_EXP_CARPETA      = "classes/";        // bajo scripts/libs/ (estilo-ctrl.md §2)
const string IOT_ENGCORE_EXP_EXTENSION    = ".ctl";
const int    IOT_ENGCORE_EXP_NIVEL_PROYECTO = 1;   // niveles de getPath: 1 = proyecto, 2 = librería, el último la instalación
const int    IOT_ENGCORE_EXP_NIVEL_LIBRERIA = 2;
const string IOT_ENGCORE_EXP_FIN_LINEA    = "\r\n";             // estilo-ctrl.md §2

// Acciones del menú contextual. El texto de cada una es la clave "exploradorMenu_<acción>" del catálogo
const string IOT_ENGCORE_ACCION_CREAR      = "crear";
const string IOT_ENGCORE_ACCION_BORRAR     = "borrar";
const string IOT_ENGCORE_ACCION_A_LIBRERIA = "aLibreria";
const string IOT_ENGCORE_ACCION_A_PROYECTO = "aProyecto";

// Vista previa: colores de la herramienta de ingeniería, no de una pantalla de operador (spec 002.3)
const string IOT_ENGCORE_EXP_ESTILO_PRE        = "font-family:Consolas,'Courier New',monospace; font-size:11pt";
const string IOT_ENGCORE_EXP_ESTILO_PALABRA    = "color:#0000a0; font-weight:bold";
const string IOT_ENGCORE_EXP_ESTILO_TIPO       = "color:#00707a";
const string IOT_ENGCORE_EXP_ESTILO_COMENTARIO = "color:#3c7a3c";
const string IOT_ENGCORE_EXP_ESTILO_CADENA     = "color:#a04000";
const string IOT_ENGCORE_EXP_ESTILO_DECORADOR  = "color:#8000a0; font-weight:bold";
const string IOT_ENGCORE_EXP_ESTILO_GENERADO   = "background-color:#e4e4f0";
const string IOT_ENGCORE_EXP_PREFIJO_DYN       = "dyn_";
const dyn_string IOT_ENGCORE_EXP_PALABRAS = makeDynString(
  "#uses", "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "return",
  "class", "struct", "enum", "public", "private", "protected", "const", "static", "global", "new", "delete",
  "try", "catch", "throw", "synchronized", "this", "true", "false", "nullptr", "main");
const dyn_string IOT_ENGCORE_EXP_TIPOS = makeDynString(
  "bool", "int", "uint", "long", "ulong", "float", "double", "string", "time", "char", "bit32", "bit64", "blob",
  "anytype", "mixed", "mapping", "void", "shape", "file", "langString", "atime", "errClass", "vector", "shared_ptr",
  "function_ptr", "unsigned");

// Panel del explorador y diálogos estándar de la instalación (spec 002.3, D12)
const string IOT_ENGCORE_EXP_SHAPE_ARBOL   = "tree_clases";
const string IOT_ENGCORE_EXP_SHAPE_CODIGO  = "txt_codigo";
const string IOT_ENGCORE_EXP_SHAPE_FICHERO = "txt_fichero";
const string IOT_ENGCORE_EXP_SHAPE_EDITAR  = "btn_editar";
const string IOT_ENGCORE_EXP_ICONO_PROYECTO  = "iot/engcore/iot_engcore_proyecto.svg";
const string IOT_ENGCORE_EXP_ICONO_LIBRERIA  = "iot/engcore/iot_engcore_libreria.svg";
const string IOT_ENGCORE_EXP_ICONO_DUPLICADA = "iot/engcore/iot_engcore_duplicada.svg";
const string IOT_ENGCORE_EXP_DIALOGO_TEXTO      = "vision/MessageInput";          // devuelve el texto en ds[1]
const string IOT_ENGCORE_EXP_DIALOGO_SI_NO      = "vision/MessageInfo";           // df[1]: 1 = Sí
const string IOT_ENGCORE_EXP_DIALOGO_LISTA      = "vision/MessageInfoList";       // solo Aceptar
const string IOT_ENGCORE_EXP_DIALOGO_LISTA_SI_NO = "vision/MessageInfoListAbort"; // df[1]: 1 = Aceptar, 2 = Cancelar
const string IOT_ENGCORE_EXP_FORMATO_TEXTO = "%s";
const string IOT_ENGCORE_EXP_SEPARADOR_LISTA = "|";
const int    IOT_ENGCORE_EXP_RESPUESTA_SI = 1;

struct IotExploradorClase
{
  string nombre;
  string padre;
  string ruta;           // relativa a scripts/libs/, p. ej. classes/iot/IotMotor.ctl
  string fichero;        // ruta absoluta del fichero que manda (el de mayor prioridad)
  bool enProyecto;       // false: está en la librería
  bool duplicada;        // la misma ruta está en el proyecto y en la librería: el proyecto tapa a la librería
  dyn_string ficheros;   // todas las copias, la que manda primero
};

struct IotExploradorBorrado
{
  dyn_string clases;      // orden de borrado: cada hija antes que su padre
  mapping ficheros;       // clase -> dyn_string con todas las copias de su fichero
  dyn_string dpts;        // clases con DPT
  mapping dps;            // clase -> dyn_string con sus DPs
  dyn_string registros;   // clases con registro en dpobj
  int numDps;
  dyn_string errores;
};

/**
  @brief  Busca las clases que heredan de IotDpObject en los .ctl de scripts/libs/classes/ de todos los proj_path.
          Lee los ficheros, no el registro: salen también las clases sin generar.
  @param  arbol    Salida: IotDpObject y sus descendientes, cada padre antes que sus hijas (ver iot_buildExploradorArbol).
  @param  errores  Salida: ficheros que no se pueden leer y clases repetidas.
  @return IOT_ENGCORE_OK o IOT_ENGCORE_ERR_PLAN si hay errores (el árbol se rellena igualmente).
*/
int iot_findExploradorClases(vector<IotExploradorClase> &arbol, dyn_string &errores)
{
  arbol.clear();
  dynClear(errores);

  mapping niveles;   // ruta relativa -> dyn_int con los niveles donde está, de mayor a menor prioridad
  for (int nivel = IOT_ENGCORE_EXP_NIVEL_PROYECTO; nivel < SEARCH_PATH_LEN; nivel++)   // el último nivel es la instalación
  {
    dyn_string rutas;
    _iot_addExploradorFicheros(_iot_getExploradorBase(nivel), IOT_ENGCORE_EXP_CARPETA, rutas);
    for (int i = 1; i <= dynlen(rutas); i++)
    {
      dyn_int lista = mappingHasKey(niveles, rutas[i]) ? niveles[rutas[i]] : makeDynInt();
      dynAppend(lista, nivel);
      niveles[rutas[i]] = lista;
    }
  }

  dyn_string rutas = mappingKeys(niveles);
  dynSort(rutas);
  vector<IotExploradorClase> todas;
  for (int i = 1; i <= dynlen(rutas); i++)
    _iot_addExploradorClasesFichero(rutas[i], niveles[rutas[i]], todas, errores);

  iot_buildExploradorArbol(todas, arbol, errores);
  return dynlen(errores) == 0 ? IOT_ENGCORE_OK : IOT_ENGCORE_ERR_PLAN;
}

/**
  @brief  Árbol de herencia desde IotDpObject. Función pura.
  @param  todas    Clases encontradas, con o sin IotDpObject como antepasado.
  @param  arbol    Salida: IotDpObject y las clases que llegan a ella, en recorrido en profundidad (cada padre antes
                   que sus hijas, hermanas por orden alfabético). Vacío si IotDpObject no está en todas.
  @param  errores  Entrada y salida: se añade un error por cada clase repetida (se queda la primera).
  @return IOT_ENGCORE_OK o IOT_ENGCORE_ERR_PLAN si hay clases repetidas.
*/
int iot_buildExploradorArbol(vector<IotExploradorClase> &todas, vector<IotExploradorClase> &arbol, dyn_string &errores)
{
  arbol.clear();
  mapping indices;   // nombre -> índice en todas
  mapping hijas;     // padre -> dyn_string
  int erroresAntes = dynlen(errores);
  for (int i = 0; i < todas.count(); i++)
  {
    IotExploradorClase clase = todas.at(i);
    if (mappingHasKey(indices, clase.nombre))
    {
      IotExploradorClase primera = todas.at(indices[clase.nombre]);
      dynAppend(errores, iot_getEngcoreTexto("errExploradorClaseRepetida", clase.nombre, primera.ruta, clase.ruta));
      continue;
    }
    indices[clase.nombre] = i;
    if (clase.padre == "")
      continue;
    dyn_string lista = mappingHasKey(hijas, clase.padre) ? hijas[clase.padre] : makeDynString();
    dynAppend(lista, clase.nombre);
    hijas[clase.padre] = lista;
  }

  if (mappingHasKey(indices, IOT_DPOBJ_CLASE_RAIZ))
    _iot_addExploradorRama(IOT_DPOBJ_CLASE_RAIZ, todas, indices, hijas, arbol);
  return dynlen(errores) == erroresAntes ? IOT_ENGCORE_OK : IOT_ENGCORE_ERR_PLAN;
}

/**
  @brief  Acciones del menú contextual válidas para una clase del árbol (C3.9). Función pura.
  @return IOT_ENGCORE_ACCION_*: crear siempre; borrar y mover nunca en IotDpObject; mover solo si lo permiten las
          reglas de librería y proyecto. Vacía si la clase no está en el árbol.
*/
dyn_string iot_getExploradorAcciones(string nombre, vector<IotExploradorClase> &arbol)
{
  dyn_string acciones;
  int indice = _iot_findExploradorClase(arbol, nombre);
  if (indice < 0)
    return acciones;
  dynAppend(acciones, IOT_ENGCORE_ACCION_CREAR);
  if (nombre == IOT_DPOBJ_CLASE_RAIZ)
    return acciones;
  dynAppend(acciones, IOT_ENGCORE_ACCION_BORRAR);

  dyn_string motivos;
  IotExploradorClase clase = arbol.at(indice);
  if (_iot_checkExploradorMovimiento(nombre, arbol, motivos) == IOT_ENGCORE_OK)
    dynAppend(acciones, clase.enProyecto ? IOT_ENGCORE_ACCION_A_LIBRERIA : IOT_ENGCORE_ACCION_A_PROYECTO);
  return acciones;
}

/**
  @brief  Valida el nombre de una clase nueva: identificador CTRL y que no exista otra clase con ese nombre. Función pura.
  @param  errores  Salida: el motivo, si no es válido.
  @return IOT_ENGCORE_OK o IOT_ENGCORE_ERR_NOMBRE.
*/
int iot_checkExploradorNombre(string nombre, vector<IotExploradorClase> &arbol, dyn_string &errores)
{
  dynClear(errores);
  if (!_iot_isDptIdentificador(nombre))
    dynAppend(errores, iot_getEngcoreTexto("errExploradorNombre", nombre));
  else if (_iot_findExploradorClase(arbol, nombre) >= 0)
    dynAppend(errores, iot_getEngcoreTexto("errExploradorNombreExiste", nombre));
  return dynlen(errores) == 0 ? IOT_ENGCORE_OK : IOT_ENGCORE_ERR_NOMBRE;
}

/**
  @brief  Líneas del fichero de una clase hija nueva: cabecera, #uses del padre, clase con constructor y un bloque
          //@dp: vacío. El constructor sigue la convención (string dp = "") de IotDpObject. Función pura.
*/
dyn_string iot_buildExploradorPlantilla(string nombre, IotExploradorClase padre)
{
  string uso = substr(padre.ruta, 0, strlen(padre.ruta) - strlen(IOT_ENGCORE_EXP_EXTENSION));
  return makeDynString(
    "/**",
    "  @file     " + nombre + IOT_ENGCORE_EXP_EXTENSION,
    "  @brief    " + iot_getEngcoreTexto("exploradorPlantillaBrief", padre.nombre),
    "*/",
    "#uses \"" + uso + "\"",
    "",
    "class " + nombre + " : " + padre.nombre,
    "{",
    IOT_ENGCORE_DPT_SANGRIA + "public " + nombre + "(string dp = \"\") : " + padre.nombre + "(dp) {}",
    "",
    IOT_ENGCORE_DPT_SANGRIA + "// " + iot_getEngcoreTexto("exploradorPlantillaBloque"),
    IOT_ENGCORE_DPT_SANGRIA + IOT_ENGCORE_DPT_INICIO,
    IOT_ENGCORE_DPT_SANGRIA + IOT_ENGCORE_DPT_FIN,
    "};");
}

/**
  @brief  Crea el fichero de una clase hija, siempre en el proyecto y en la misma carpeta relativa que su padre (C3.6).
  @param  fichero  Salida: ruta absoluta del fichero creado.
  @param  errores  Salida: motivos si no se crea.
  @return IOT_ENGCORE_OK, IOT_ENGCORE_ERR_NOMBRE o IOT_ENGCORE_ERR_FICHERO.
*/
int iot_createExploradorHija(string nombre, string padre, vector<IotExploradorClase> &arbol, string &fichero,
                             dyn_string &errores)
{
  fichero = "";
  if (iot_checkExploradorNombre(nombre, arbol, errores) != IOT_ENGCORE_OK)
    return IOT_ENGCORE_ERR_NOMBRE;
  int indice = _iot_findExploradorClase(arbol, padre);
  if (indice < 0)
  {
    dynAppend(errores, iot_getEngcoreTexto("errExploradorNoEncontrada", padre));
    return IOT_ENGCORE_ERR_NOMBRE;
  }
  // nombre ya es un identificador: dpTypes lo busca tal cual, sin comodines
  if (dynlen(dpTypes(nombre)) > 0)
  {
    dynAppend(errores, iot_getEngcoreTexto("errExploradorDptExiste", nombre));
    return IOT_ENGCORE_ERR_NOMBRE;
  }

  IotExploradorClase clasePadre = arbol.at(indice);
  string destino = _iot_getExploradorBase(IOT_ENGCORE_EXP_NIVEL_PROYECTO) + _iot_getExploradorCarpeta(clasePadre.ruta)
                   + nombre + IOT_ENGCORE_EXP_EXTENSION;
  if (isfile(destino))
  {
    dynAppend(errores, iot_getEngcoreTexto("errExploradorFicheroExiste", destino));
    return IOT_ENGCORE_ERR_FICHERO;
  }
  if (!_iot_writeExploradorFichero(destino, iot_buildExploradorPlantilla(nombre, clasePadre)))
    return _iot_failExplorador(IOT_ENGCORE_ERR_FICHERO, "errExploradorEscribir", destino, errores);
  fichero = destino;
  return IOT_ENGCORE_OK;
}

/**
  @brief  Mueve el fichero de una clase al otro proj_path, con la misma ruta relativa (C3.8). Del proyecto va a la
          librería y de la librería al proyecto. El DPT y el registro no cambian.
  @param  destino  Salida: ruta absoluta nueva.
  @param  errores  Salida: motivos si no se mueve.
  @return IOT_ENGCORE_OK, IOT_ENGCORE_ERR_PLAN (las reglas no lo permiten) o IOT_ENGCORE_ERR_FICHERO (destino ocupado o fallo).
*/
int iot_moveExploradorClase(string nombre, vector<IotExploradorClase> &arbol, string &destino, dyn_string &errores)
{
  destino = "";
  dynClear(errores);
  int indice = _iot_findExploradorClase(arbol, nombre);
  if (indice < 0)
  {
    dynAppend(errores, iot_getEngcoreTexto("errExploradorNoEncontrada", nombre));
    return IOT_ENGCORE_ERR_PLAN;
  }
  if (_iot_checkExploradorMovimiento(nombre, arbol, errores) != IOT_ENGCORE_OK)
    return IOT_ENGCORE_ERR_PLAN;

  IotExploradorClase clase = arbol.at(indice);
  int nivel = clase.enProyecto ? IOT_ENGCORE_EXP_NIVEL_LIBRERIA : IOT_ENGCORE_EXP_NIVEL_PROYECTO;
  string nuevo = _iot_getExploradorBase(nivel) + clase.ruta;
  if (isfile(nuevo))
  {
    dynAppend(errores, iot_getEngcoreTexto("errExploradorDestinoOcupado", nuevo));
    return IOT_ENGCORE_ERR_FICHERO;
  }
  if (!_iot_ensureExploradorCarpeta(_iot_getExploradorCarpeta(nuevo)) || !moveFile(clase.fichero, nuevo))
    return _iot_failExplorador(IOT_ENGCORE_ERR_FICHERO, "errExploradorMover", clase.fichero, errores);
  destino = nuevo;
  return IOT_ENGCORE_OK;
}

/**
  @brief  Calcula qué se borra al borrar una clase y todas sus descendientes (C3.7). No modifica nada.
          Las descendientes salen del árbol (ficheros) y del registro (clases generadas cuyo fichero ya no está).
  @param  plan  Salida.
  @return IOT_ENGCORE_OK o IOT_ENGCORE_ERR_PLAN (IotDpObject o clase que no está en el árbol, ver plan.errores).
*/
int iot_planExploradorBorrado(string nombre, vector<IotExploradorClase> &arbol, IotExploradorBorrado &plan)
{
  _iot_clearExploradorBorrado(plan);
  if (nombre == IOT_DPOBJ_CLASE_RAIZ)
    dynAppend(plan.errores, iot_getEngcoreTexto("errExploradorRaiz", nombre));
  else if (_iot_findExploradorClase(arbol, nombre) < 0)
    dynAppend(plan.errores, iot_getEngcoreTexto("errExploradorNoEncontrada", nombre));
  if (dynlen(plan.errores) > 0)
    return IOT_ENGCORE_ERR_PLAN;

  // Orden padre antes que hija; al recorrerlo al revés, cada hija se borra antes que su padre
  dyn_string orden = makeDynString(nombre);
  dynAppend(orden, _iot_getExploradorDescendientes(nombre, arbol));
  dyn_string registradas;
  iot_getDpObjDescendientes(nombre, registradas);
  for (int i = 1; i <= dynlen(registradas); i++)
  {
    if (dynContains(orden, registradas[i]) < 1)
      dynAppend(orden, registradas[i]);
  }
  for (int i = dynlen(orden); i >= 1; i--)
    _iot_planExploradorClase(orden[i], arbol, plan);
  return IOT_ENGCORE_OK;
}

/**
  @brief  Texto del plan de borrado para la primera confirmación: cada clase con sus ficheros, su DPT con sus DPs
          y su registro, en el orden en que se borran.
*/
dyn_string iot_getExploradorResumenBorrado(IotExploradorBorrado plan)
{
  dyn_string lineas;
  for (int i = 1; i <= dynlen(plan.clases); i++)
  {
    string clase = plan.clases[i];
    dynAppend(lineas, clase);
    dyn_string ficheros = plan.ficheros[clase];
    for (int j = 1; j <= dynlen(ficheros); j++)
      dynAppend(lineas, IOT_ENGCORE_DPT_SANGRIA + iot_getEngcoreTexto("exploradorResumenFichero", ficheros[j]));
    dyn_string dps = plan.dps[clase];
    if (dynContains(plan.dpts, clase) > 0)
      dynAppend(lineas, IOT_ENGCORE_DPT_SANGRIA + iot_getEngcoreTexto("exploradorResumenDpt", clase, dynlen(dps)));
    else
      dynAppend(lineas, IOT_ENGCORE_DPT_SANGRIA + iot_getEngcoreTexto("exploradorResumenSinDpt"));
    string claveRegistro = dynContains(plan.registros, clase) > 0 ? "exploradorResumenRegistro" : "exploradorResumenSinRegistro";
    dynAppend(lineas, IOT_ENGCORE_DPT_SANGRIA + iot_getEngcoreTexto(claveRegistro));
  }
  return lineas;
}

/**
  @brief  Borra lo que dice el plan, de las hijas hacia el padre: por cada clase sus DPs, su DPT, su registro y su fichero.
          Se para en el primer fallo, que queda en el log.
  @param  errores  Salida: el fallo, si lo hay.
  @return IOT_ENGCORE_OK, IOT_ENGCORE_ERR_PLAN (plan con errores), IOT_ENGCORE_ERR_DP, _ERR_DPT, _ERR_REGISTRO o _ERR_FICHERO.
*/
int iot_applyExploradorBorrado(IotExploradorBorrado plan, dyn_string &errores)
{
  dynClear(errores);
  if (dynlen(plan.errores) > 0)
  {
    errores = plan.errores;
    return IOT_ENGCORE_ERR_PLAN;
  }
  for (int i = 1; i <= dynlen(plan.clases); i++)
  {
    string clase = plan.clases[i];
    dyn_string dps = plan.dps[clase];
    for (int j = 1; j <= dynlen(dps); j++)
    {
      if (dpExists(dps[j]) && dpDelete(dps[j]) != 0)
        return _iot_failExplorador(IOT_ENGCORE_ERR_DP, "errExploradorBorrarDp", dps[j], errores);
    }
    if (dynContains(plan.dpts, clase) > 0 && dpTypeDelete(clase) != 0)
      return _iot_failExplorador(IOT_ENGCORE_ERR_DPT, "errExploradorBorrarDpt", clase, errores);
    if (dynContains(plan.registros, clase) > 0 && iot_deleteDpObjRegistro(clase) != IOT_DPOBJ_OK)
      return _iot_failExplorador(IOT_ENGCORE_ERR_REGISTRO, "errExploradorBorrarRegistro", clase, errores);
    dyn_string ficheros = plan.ficheros[clase];
    for (int j = 1; j <= dynlen(ficheros); j++)
    {
      if (isfile(ficheros[j]) && remove(ficheros[j]) != 0)
        return _iot_failExplorador(IOT_ENGCORE_ERR_FICHERO, "errExploradorBorrarFichero", ficheros[j], errores);
    }
    DebugFTN(IOT_ENGCORE_FLAG, "borrada", clase);
  }
  return IOT_ENGCORE_OK;
}

/**
  @brief  Código CTRL a HTML coloreado para un TEXT_EDIT en RichText (C3.4): palabras clave, tipos, comentarios,
          cadenas, decoradores y bloque //@generado. Escapa <, > y &. Función pura.
*/
string iot_formatExploradorHtml(string codigo)
{
  dyn_string lineas = _iot_splitDptLineas(codigo);
  dyn_string html;
  bool enComentario = false, enGenerado = false;
  for (int i = 1; i <= dynlen(lineas); i++)
  {
    string linea = strrtrim(lineas[i], "\r");
    string recortada = _iot_trimDpt(linea);
    if (!enComentario && _iot_startsWithDpt(recortada, IOT_ENGCORE_DPT_DECORADOR))
    {
      dynAppend(html, _iot_spanExplorador(linea, IOT_ENGCORE_EXP_ESTILO_DECORADOR));
      if (_iot_isDptInicioGenerado(recortada))
        enGenerado = true;
      else if (recortada == IOT_ENGCORE_DPT_FIN_GENERADO)
        enGenerado = false;
      continue;
    }
    string resultado = _iot_formatExploradorLinea(linea, enComentario);
    if (enGenerado && resultado != "")
      resultado = "<span style=\"" + IOT_ENGCORE_EXP_ESTILO_GENERADO + "\">" + resultado + "</span>";
    dynAppend(html, resultado);
  }
  return "<pre style=\"" + IOT_ENGCORE_EXP_ESTILO_PRE + "\">" + strjoin(html, "\n") + "</pre>";
}

// --- Funciones internas: ficheros ---

/** <proj_path del nivel>/scripts/libs/ */
string _iot_getExploradorBase(int nivel)
{
  return getPath(LIBS_REL_PATH, "", -1, nivel);
}

/** Carpeta de una ruta, con la barra final: "classes/iot/A.ctl" -> "classes/iot/". */
string _iot_getExploradorCarpeta(string ruta)
{
  string normalizada = ruta;
  strreplace(normalizada, "\\", "/");
  dyn_string partes = strsplit(normalizada, "/");
  return substr(normalizada, 0, strlen(normalizada) - strlen(partes[dynlen(partes)]));
}

/** Añade a rutas los .ctl de base + carpeta y de sus subcarpetas, relativos a base. */
void _iot_addExploradorFicheros(string base, string carpeta, dyn_string &rutas)
{
  string absoluta = base + carpeta;
  if (!isdir(absoluta))
    return;
  dyn_string ficheros = getFileNames(absoluta, "*" + IOT_ENGCORE_EXP_EXTENSION, FILTER_FILES);
  for (int i = 1; i <= dynlen(ficheros); i++)
    dynAppend(rutas, carpeta + ficheros[i]);
  dyn_string carpetas = getFileNames(absoluta, "*", FILTER_DIRS);   // incluye "." y ".." (spec 002.3)
  for (int i = 1; i <= dynlen(carpetas); i++)
  {
    if (carpetas[i] != "." && carpetas[i] != "..")
      _iot_addExploradorFicheros(base, carpeta + carpetas[i] + "/", rutas);
  }
}

/** Analiza el fichero que manda de una ruta y añade sus clases a todas. */
void _iot_addExploradorClasesFichero(string ruta, dyn_int niveles, vector<IotExploradorClase> &todas, dyn_string &errores)
{
  string fichero = _iot_getExploradorBase(niveles[1]) + ruta;
  string texto;
  if (!fileToString(fichero, texto))
  {
    dynAppend(errores, iot_getEngcoreTexto("errFichero", fichero));
    return;
  }

  // Los errores de decoradores son cosa del área dpt: aquí solo importan las clases y su herencia
  vector<IotDptClase> clases;
  dyn_string erroresDecoradores;
  iot_parseDptClases(texto, clases, erroresDecoradores);
  dyn_string ficheros;
  for (int i = 1; i <= dynlen(niveles); i++)
    dynAppend(ficheros, _iot_getExploradorBase(niveles[i]) + ruta);

  for (int i = 0; i < clases.count(); i++)
  {
    IotDptClase leida = clases.at(i);
    IotExploradorClase clase;
    clase.nombre = leida.nombre;
    clase.padre = leida.padre;
    clase.ruta = ruta;
    clase.fichero = fichero;
    clase.enProyecto = niveles[1] == IOT_ENGCORE_EXP_NIVEL_PROYECTO;
    clase.duplicada = dynlen(niveles) > 1;
    clase.ficheros = ficheros;
    todas.append(clase);
  }
}

/** Crea una carpeta absoluta y las que le falten por encima. */
bool _iot_ensureExploradorCarpeta(string carpeta)
{
  string normalizada = strrtrim(carpeta, "/");
  if (normalizada == "" || isdir(normalizada))
    return true;
  return _iot_ensureExploradorCarpeta(_iot_getExploradorCarpeta(normalizada)) && mkdir(normalizada);
}

/** Escribe un fichero nuevo con fin de línea CRLF. "wb" para que Windows no convierta los \n. */
bool _iot_writeExploradorFichero(string fichero, dyn_string lineas)
{
  if (!_iot_ensureExploradorCarpeta(_iot_getExploradorCarpeta(fichero)))
    return false;
  file f = fopen(fichero, "wb");
  if (!f || ferror(f))
    return false;
  fputs(strjoin(lineas, IOT_ENGCORE_EXP_FIN_LINEA) + IOT_ENGCORE_EXP_FIN_LINEA, f);
  bool correcto = ferror(f) == 0;
  fclose(f);
  return correcto && isfile(fichero);
}

/** Añade el error, lo registra en el log y devuelve el código para propagarlo. */
int _iot_failExplorador(int codigo, string clave, string elemento, dyn_string &errores)
{
  dynAppend(errores, iot_getEngcoreTexto(clave, elemento));
  return _iot_logEngcoreError(codigo, IOT_ENGCORE_MSG_EXPLORADOR, elemento);
}

// --- Funciones internas: árbol ---

void _iot_addExploradorRama(string nombre, vector<IotExploradorClase> &todas, mapping &indices, mapping &hijas,
                            vector<IotExploradorClase> &arbol)
{
  arbol.append(todas.at(indices[nombre]));
  if (!mappingHasKey(hijas, nombre))
    return;
  // Cada clase tiene un solo padre: desde la raíz no se puede entrar en un ciclo
  dyn_string lista = hijas[nombre];
  dynSort(lista);
  for (int i = 1; i <= dynlen(lista); i++)
    _iot_addExploradorRama(lista[i], todas, indices, hijas, arbol);
}

int _iot_findExploradorClase(vector<IotExploradorClase> &arbol, string nombre)
{
  for (int i = 0; i < arbol.count(); i++)
  {
    if (arbol.at(i).nombre == nombre)
      return i;
  }
  return -1;
}

/** Antepasados de una clase del árbol, desde su padre hasta IotDpObject. */
dyn_string _iot_getExploradorAntepasados(string nombre, vector<IotExploradorClase> &arbol)
{
  dyn_string antepasados;
  int indice = _iot_findExploradorClase(arbol, nombre);
  while (indice >= 0 && dynlen(antepasados) < IOT_ENGCORE_DPT_MAX_HERENCIA)
  {
    string padre = arbol.at(indice).padre;
    indice = padre == "" ? -1 : _iot_findExploradorClase(arbol, padre);
    if (indice >= 0)
      dynAppend(antepasados, padre);
  }
  return antepasados;
}

/** Descendientes de una clase del árbol, en el orden del árbol (cada padre antes que sus hijas). */
dyn_string _iot_getExploradorDescendientes(string nombre, vector<IotExploradorClase> &arbol)
{
  dyn_string descendientes;
  for (int i = 0; i < arbol.count(); i++)
  {
    string otra = arbol.at(i).nombre;
    if (dynContains(_iot_getExploradorAntepasados(otra, arbol), nombre) > 0)
      dynAppend(descendientes, otra);
  }
  return descendientes;
}

/**
  Reglas de C3.8: la librería no puede depender del proyecto. A la librería solo si todos sus antepasados están
  en la librería; al proyecto solo si ninguna descendiente está en la librería. IotDpObject no se mueve.
*/
int _iot_checkExploradorMovimiento(string nombre, vector<IotExploradorClase> &arbol, dyn_string &errores)
{
  if (nombre == IOT_DPOBJ_CLASE_RAIZ)
  {
    dynAppend(errores, iot_getEngcoreTexto("errExploradorRaiz", nombre));
    return IOT_ENGCORE_ERR_PLAN;
  }
  IotExploradorClase clase = arbol.at(_iot_findExploradorClase(arbol, nombre));
  dyn_string otras = clase.enProyecto ? _iot_getExploradorAntepasados(nombre, arbol) : _iot_getExploradorDescendientes(nombre, arbol);
  for (int i = 1; i <= dynlen(otras); i++)
  {
    IotExploradorClase otra = arbol.at(_iot_findExploradorClase(arbol, otras[i]));
    if (clase.enProyecto && otra.enProyecto)
      dynAppend(errores, iot_getEngcoreTexto("errExploradorALibreria", nombre, otra.nombre));
    else if (!clase.enProyecto && !otra.enProyecto)
      dynAppend(errores, iot_getEngcoreTexto("errExploradorAProyecto", nombre, otra.nombre));
  }
  return dynlen(errores) == 0 ? IOT_ENGCORE_OK : IOT_ENGCORE_ERR_PLAN;
}

// --- Funciones internas: borrado ---

void _iot_planExploradorClase(string clase, vector<IotExploradorClase> &arbol, IotExploradorBorrado &plan)
{
  dynAppend(plan.clases, clase);
  int indice = _iot_findExploradorClase(arbol, clase);
  dyn_string ficheros;
  if (indice >= 0)
    ficheros = arbol.at(indice).ficheros;
  plan.ficheros[clase] = ficheros;

  dyn_string dps;
  if (dynlen(dpTypes(clase)) > 0)
  {
    dynAppend(plan.dpts, clase);
    dyn_string conSistema = dpNames("*", clase);
    for (int i = 1; i <= dynlen(conSistema); i++)
      dynAppend(dps, dpSubStr(conSistema[i], DPSUB_DP));
  }
  plan.dps[clase] = dps;
  plan.numDps += dynlen(dps);

  dyn_string jerarquia;
  if (iot_getDpObjJerarquia(clase, jerarquia) == IOT_DPOBJ_OK)
    dynAppend(plan.registros, clase);
}

void _iot_clearExploradorBorrado(IotExploradorBorrado &plan)
{
  dynClear(plan.clases);
  mappingClear(plan.ficheros);
  dynClear(plan.dpts);
  mappingClear(plan.dps);
  dynClear(plan.registros);
  plan.numDps = 0;
  dynClear(plan.errores);
}

// --- Funciones internas: vista previa ---

string _iot_escapeExploradorHtml(string texto)
{
  string escapado = texto;
  strreplace(escapado, "&", "&amp;");   // la primera, para no escapar dos veces
  strreplace(escapado, "<", "&lt;");
  strreplace(escapado, ">", "&gt;");
  return escapado;
}

string _iot_spanExplorador(string texto, string estilo)
{
  if (texto == "")
    return "";
  return "<span style=\"" + estilo + "\">" + _iot_escapeExploradorHtml(texto) + "</span>";
}

/**
  Una línea de código a HTML. enComentario es de entrada y salida: indica si la línea empieza o acaba
  dentro de un comentario de bloque.
*/
string _iot_formatExploradorLinea(string linea, bool &enComentario)
{
  string resultado;
  int longitud = strlen(linea);
  int posicion = 0;
  while (posicion < longitud)
  {
    string caracter = substr(linea, posicion, 1);
    string dos = substr(linea, posicion, 2);
    int fin;
    string estilo = "";
    if (enComentario || dos == "/*")
    {
      int cierre = strpos(linea, "*/", enComentario ? posicion : posicion + 2);
      fin = cierre < 0 ? longitud : cierre + 2;
      enComentario = cierre < 0;
      estilo = IOT_ENGCORE_EXP_ESTILO_COMENTARIO;
    }
    else if (dos == "//")
    {
      fin = longitud;
      estilo = IOT_ENGCORE_EXP_ESTILO_COMENTARIO;
    }
    else if (caracter == "\"" || caracter == "'")
    {
      int cierre = _iot_findExploradorFinCadena(linea, posicion + 1, caracter);
      fin = cierre < 0 ? longitud : cierre + 1;
      estilo = IOT_ENGCORE_EXP_ESTILO_CADENA;
    }
    else if (_iot_isExploradorInicioPalabra(caracter))
    {
      fin = posicion + 1;
      while (fin < longitud && strpos(IOT_ENGCORE_DPT_CARACTERES_ID, substr(linea, fin, 1)) >= 0)
        fin++;
      estilo = _iot_getExploradorEstiloPalabra(substr(linea, posicion, fin - posicion));
    }
    else
    {
      fin = posicion + 1;
    }

    string trozo = substr(linea, posicion, fin - posicion);
    resultado += estilo == "" ? _iot_escapeExploradorHtml(trozo) : _iot_spanExplorador(trozo, estilo);
    posicion = fin;
  }
  return resultado;
}

/** Posición de la comilla que cierra una cadena, saltando las escapadas con \. -1 si no se cierra en la línea. */
int _iot_findExploradorFinCadena(string linea, int desde, string comilla)
{
  int posicion = desde;
  while (posicion < strlen(linea))
  {
    string caracter = substr(linea, posicion, 1);
    if (caracter == "\\")
      posicion += 2;
    else if (caracter == comilla)
      return posicion;
    else
      posicion++;
  }
  return -1;
}

/** Letra, _ o # (#uses): empieza una palabra. Los dígitos no. */
bool _iot_isExploradorInicioPalabra(string caracter)
{
  return caracter == "#"
         || (strpos(IOT_ENGCORE_DPT_CARACTERES_ID, caracter) >= 0 && strpos(IOT_ENGCORE_DPT_DIGITOS, caracter) < 0);
}

string _iot_getExploradorEstiloPalabra(string palabra)
{
  if (dynContains(IOT_ENGCORE_EXP_PALABRAS, palabra) > 0)
    return IOT_ENGCORE_EXP_ESTILO_PALABRA;
  if (dynContains(IOT_ENGCORE_EXP_TIPOS, palabra) > 0 || strpos(palabra, IOT_ENGCORE_EXP_PREFIJO_DYN) == 0)
    return IOT_ENGCORE_EXP_ESTILO_TIPO;
  return "";
}

// --- Funciones del panel iot_engcore_explorador.xml (solo UI) ---
// Se cargan también en los tests (manager CTRL), que no las llaman.

/** Initialize del panel: textos, árbol sin cabecera, vista previa en RichText y carga del árbol. */
void iot_initExplorador()
{
  shape arbol = getShape(IOT_ENGCORE_EXP_SHAPE_ARBOL);
  // Sin al menos una columna el tree widget no pinta los ítems (marco.md)
  arbol.addColumn("");
  arbol.headerHidden(true);
  shape codigo = getShape(IOT_ENGCORE_EXP_SHAPE_CODIGO);
  codigo.textFormat("RichText");
  setValue(IOT_ENGCORE_EXP_SHAPE_EDITAR, "text", iot_getEngcoreTexto("exploradorEditar"), "enabled", false);
  _iot_loadExploradorArbol(IOT_DPOBJ_CLASE_RAIZ);
}

/** selectionChanged del árbol: código coloreado y ubicación de la clase. */
void iot_onExploradorSeleccion(string nombre)
{
  DebugFTN(IOT_ENGCORE_FLAG, "seleccion", nombre);
  IotExploradorClase clase;
  string texto;
  bool encontrada = _iot_getExploradorClase(nombre, clase) && fileToString(clase.fichero, texto);
  setValue(IOT_ENGCORE_EXP_SHAPE_CODIGO, "text", encontrada ? iot_formatExploradorHtml(texto) : "");
  setValue(IOT_ENGCORE_EXP_SHAPE_FICHERO, "text", encontrada ? _iot_getExploradorUbicacion(clase) : "");
  setValue(IOT_ENGCORE_EXP_SHAPE_EDITAR, "enabled", encontrada);
}

/** Clicked de btn_editar: abre la clase seleccionada en el Script Editor, con la ruta absoluta (spec 002.3, D15). */
void iot_onExploradorEditar()
{
  shape arbol = getShape(IOT_ENGCORE_EXP_SHAPE_ARBOL);
  IotExploradorClase clase;
  if (_iot_getExploradorClase(arbol.selectedItem(), clase))
    scriptEditor(makeMapping("fileName", clase.fichero));
}

/**
  @brief  RightMousePressed del árbol: selecciona la clase y abre el menú con sus acciones válidas (C3.9).
  @param  enCabecera  true si el clic es en la cabecera: no hay clase (spec 002.3, D16).
*/
void iot_onExploradorMenu(bool enCabecera, string nombre)
{
  if (enCabecera || nombre == "")
    return;
  shape forma = getShape(IOT_ENGCORE_EXP_SHAPE_ARBOL);
  forma.setSelectedItem(nombre, true);

  vector<IotExploradorClase> arbol;
  dyn_string errores;
  iot_findExploradorClases(arbol, errores);
  dyn_string acciones = iot_getExploradorAcciones(nombre, arbol);
  if (dynlen(acciones) == 0)
    return;

  dyn_mapping menu;
  for (int i = 1; i <= dynlen(acciones); i++)
    menu[i] = makeMapping("label", iot_getEngcoreTexto("exploradorMenu_" + acciones[i]), "value", i);
  int respuesta;
  if (popupMenu(menu, respuesta) != 0 || respuesta < 1 || respuesta > dynlen(acciones))
    return;

  if (acciones[respuesta] == IOT_ENGCORE_ACCION_CREAR)
    _iot_runExploradorCrear(nombre, arbol);
  else if (acciones[respuesta] == IOT_ENGCORE_ACCION_BORRAR)
    _iot_runExploradorBorrar(nombre, arbol);
  else
    _iot_runExploradorMover(nombre, arbol);
}

/** Pide el nombre hasta que es válido o se cancela, crea la hija y la deja seleccionada. */
void _iot_runExploradorCrear(string padre, vector<IotExploradorClase> &arbol)
{
  string nombre = "";
  while (true)
  {
    dyn_float numeros;
    dyn_string textos;
    ChildPanelOnCentralModalReturn(IOT_ENGCORE_EXP_DIALOGO_TEXTO, iot_getEngcoreTexto("exploradorTituloCrear"),
                                   makeDynString("$1:" + iot_getEngcoreTexto("exploradorTextoCrear", padre),
                                                 "$2:" + IOT_ENGCORE_EXP_FORMATO_TEXTO, "$3:" + nombre),
                                   numeros, textos);
    if (dynlen(textos) < 1)
      return;   // Cancelar o la X
    nombre = _iot_trimDpt(textos[1]);
    string fichero;
    dyn_string errores;
    if (iot_createExploradorHija(nombre, padre, arbol, fichero, errores) == IOT_ENGCORE_OK)
    {
      _iot_loadExploradorArbol(nombre);
      return;
    }
    _iot_showExploradorErrores(errores);
  }
}

/** Plan, primera confirmación con todo lo que se borra, segunda confirmación con el total y borrado. */
void _iot_runExploradorBorrar(string nombre, vector<IotExploradorClase> &arbol)
{
  IotExploradorBorrado plan;
  if (iot_planExploradorBorrado(nombre, arbol, plan) != IOT_ENGCORE_OK)
  {
    _iot_showExploradorErrores(plan.errores);
    return;
  }

  string titulo = iot_getEngcoreTexto("exploradorTituloBorrar");
  dyn_float numeros;
  dyn_string textos;
  ChildPanelOnCentralModalReturn(IOT_ENGCORE_EXP_DIALOGO_LISTA_SI_NO, titulo,
                                 makeDynString("$1:" + iot_getEngcoreTexto("exploradorTextoBorrar"),
                                               "$2:" + strjoin(iot_getExploradorResumenBorrado(plan), IOT_ENGCORE_EXP_SEPARADOR_LISTA),
                                               "$3:" + iot_getEngcoreTexto("exploradorBotonContinuar"),
                                               "$4:" + iot_getEngcoreTexto("exploradorBotonCancelar")),
                                 numeros, textos);
  if (dynlen(numeros) < 1 || numeros[1] != IOT_ENGCORE_EXP_RESPUESTA_SI)
    return;
  ChildPanelOnCentralModalReturn(IOT_ENGCORE_EXP_DIALOGO_SI_NO, titulo,
                                 makeDynString("$1:" + iot_getEngcoreTexto("exploradorConfirmarBorrado", dynlen(plan.clases), plan.numDps),
                                               "$2:" + iot_getEngcoreTexto("botonSi"), "$3:" + iot_getEngcoreTexto("botonNo")),
                                 numeros, textos);
  if (dynlen(numeros) < 1 || numeros[1] != IOT_ENGCORE_EXP_RESPUESTA_SI)
    return;

  string padre = arbol.at(_iot_findExploradorClase(arbol, nombre)).padre;
  dyn_string errores;
  if (iot_applyExploradorBorrado(plan, errores) != IOT_ENGCORE_OK)
    _iot_showExploradorErrores(errores);
  _iot_loadExploradorArbol(padre);
}

void _iot_runExploradorMover(string nombre, vector<IotExploradorClase> &arbol)
{
  string destino;
  dyn_string errores;
  if (iot_moveExploradorClase(nombre, arbol, destino, errores) != IOT_ENGCORE_OK)
    _iot_showExploradorErrores(errores);
  _iot_loadExploradorArbol(nombre);
}

/** Rellena el árbol con su icono de ubicación y selecciona una clase (o IotDpObject si ya no está). */
void _iot_loadExploradorArbol(string seleccion)
{
  vector<IotExploradorClase> arbol;
  dyn_string errores;
  iot_findExploradorClases(arbol, errores);
  for (int i = 1; i <= dynlen(errores); i++)
    _iot_logEngcoreError(IOT_ENGCORE_ERR_PLAN, IOT_ENGCORE_MSG_EXPLORADOR, errores[i]);

  shape forma = getShape(IOT_ENGCORE_EXP_SHAPE_ARBOL);
  forma.clear();
  for (int i = 0; i < arbol.count(); i++)
  {
    IotExploradorClase clase = arbol.at(i);
    forma.appendItemNC(clase.nombre == IOT_DPOBJ_CLASE_RAIZ ? "" : clase.padre, clase.nombre, clase.nombre);
    forma.setIcon(clase.nombre, 0, _iot_getExploradorIcono(clase));
  }
  forma.expandAll();

  string elegida = forma.itemExists(seleccion) ? seleccion : IOT_DPOBJ_CLASE_RAIZ;
  if (!forma.itemExists(elegida))
  {
    iot_onExploradorSeleccion("");
    return;
  }
  forma.setSelectedItem(elegida, true);
  forma.ensureItemVisible(elegida);
  DebugFTN(IOT_ENGCORE_FLAG, "arbol cargado", arbol.count(), elegida);
  iot_onExploradorSeleccion(elegida);
}

/** Clase del árbol por su nombre, leyendo otra vez los ficheros. */
bool _iot_getExploradorClase(string nombre, IotExploradorClase &clase)
{
  vector<IotExploradorClase> arbol;
  dyn_string errores;
  iot_findExploradorClases(arbol, errores);
  int indice = _iot_findExploradorClase(arbol, nombre);
  if (indice < 0)
    return false;
  clase = arbol.at(indice);
  return true;
}

string _iot_getExploradorIcono(IotExploradorClase clase)
{
  if (clase.duplicada)
    return IOT_ENGCORE_EXP_ICONO_DUPLICADA;
  return clase.enProyecto ? IOT_ENGCORE_EXP_ICONO_PROYECTO : IOT_ENGCORE_EXP_ICONO_LIBRERIA;
}

string _iot_getExploradorUbicacion(IotExploradorClase clase)
{
  if (clase.duplicada)
    return iot_getEngcoreTexto("exploradorUbicacionDuplicada", clase.fichero);
  return iot_getEngcoreTexto(clase.enProyecto ? "exploradorUbicacionProyecto" : "exploradorUbicacionLibreria", clase.fichero);
}

void _iot_showExploradorErrores(dyn_string errores)
{
  dyn_float numeros;
  dyn_string textos;
  ChildPanelOnCentralModalReturn(IOT_ENGCORE_EXP_DIALOGO_LISTA, iot_getEngcoreTexto("exploradorTituloError"),
                                 makeDynString("$1:" + iot_getEngcoreTexto("exploradorTextoError"),
                                               "$2:" + strjoin(errores, IOT_ENGCORE_EXP_SEPARADOR_LISTA),
                                               "$3:" + iot_getEngcoreTexto("botonAceptar")),
                                 numeros, textos);
}

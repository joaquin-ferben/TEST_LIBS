/**
  @file     iot_nav.ctl
  @brief    Navegación: lee una vista CNS y resuelve cada nodo en su panel, su DP y su ruta.
  @author   TEST_LIBS

  Documento del módulo: dev/modulos/nav.md (en TEST_CLAUDE).
*/
#uses "CtrlCNS"  // las funciones cns* son de esta extensión: el CTRL la trae cargada, la UI no

const string IOT_NAV_VISTA       = "IotNavegacion";  // vista de navegación de la aplicación
const string IOT_NAV_PROP_PANEL  = "iot_panel";
const int    IOT_NAV_MAX_NIVEL   = 4;                // niveles ISA-101
const string IOT_NAV_CATALOGO    = "iot_nav";
const string IOT_NAV_FLAG        = "iot_nav";

const int IOT_NAV_OK                  = 0;
const int IOT_NAV_ERR_CNS             = -1;
const int IOT_NAV_ERR_SIN_PANEL       = -2;
const int IOT_NAV_ERR_PANEL_NO_EXISTE = -3;
const int IOT_NAV_ERR_PROFUNDIDAD     = -4;

// Códigos del catálogo msg/<idioma>/iot_nav.cat
const int IOT_NAV_MSG_CNS             = 1;
const int IOT_NAV_MSG_PANEL_NO_EXISTE = 2;
const int IOT_NAV_MSG_PROFUNDIDAD     = 3;

struct IotNavNodo
{
  string id;       // ID path CNS del nodo
  string texto;    // display name en el idioma activo
  string idPadre;  // vacío en el nodo raíz
  int nivel;       // 1 a IOT_NAV_MAX_NIVEL
};

/**
  @brief  Devuelve todos los nodos de una vista, padre antes que hijos.
  @param  vista  Nombre de la vista en el sistema local (p. ej. IOT_NAV_VISTA).
  @param  nodos  Salida: nodos en recorrido en profundidad.
  @return IOT_NAV_OK, IOT_NAV_ERR_CNS o IOT_NAV_ERR_PROFUNDIDAD.
*/
int iot_getNavNodes(string vista, vector<IotNavNodo> &nodos)
{
  nodos.clear();
  string rutaVista = _iot_getNavRutaVista(vista);
  dyn_string arboles;
  if (!cnsGetTrees(rutaVista, arboles))
    return _iot_logNavError(IOT_NAV_ERR_CNS, IOT_NAV_MSG_CNS, "cnsGetTrees", rutaVista);

  for (int i = 1; i <= dynlen(arboles); i++)
  {
    int resultado = _iot_addNavNodo(arboles[i], "", 1, nodos);
    if (resultado != IOT_NAV_OK)
    {
      nodos.clear();
      return resultado;
    }
  }
  return IOT_NAV_OK;
}

/**
  @brief  Devuelve el panel que abre un nodo y el DP enlazado a él.
  @param  idNodo  ID path CNS del nodo.
  @param  panel   Salida: ruta del panel relativa a panels/. Vacía si hay error.
  @param  dp      Salida: DP enlazado al nodo, vacío si no tiene. Vacío si hay error.
  @return IOT_NAV_OK, IOT_NAV_ERR_CNS, IOT_NAV_ERR_SIN_PANEL o IOT_NAV_ERR_PANEL_NO_EXISTE.
*/
int iot_getNavTarget(string idNodo, string &panel, string &dp)
{
  panel = "";
  dp = "";

  string dpEnlazado;
  if (!cnsGetId(idNodo, dpEnlazado))
    return _iot_logNavError(IOT_NAV_ERR_CNS, IOT_NAV_MSG_CNS, "cnsGetId", idNodo);

  // Un nodo sin la propiedad es un agrupador: es un caso normal, no se registra
  anytype valor;
  if (!cnsGetProperty(idNodo, IOT_NAV_PROP_PANEL, valor))
    return IOT_NAV_ERR_SIN_PANEL;
  string rutaPanel = valor;
  if (rutaPanel == "")
    return IOT_NAV_ERR_SIN_PANEL;

  if (getPath(PANELS_REL_PATH, rutaPanel) == "")
    return _iot_logNavError(IOT_NAV_ERR_PANEL_NO_EXISTE, IOT_NAV_MSG_PANEL_NO_EXISTE, rutaPanel, idNodo);

  panel = rutaPanel;
  dp = dpEnlazado;
  return IOT_NAV_OK;
}

/**
  @brief  Devuelve la ruta desde el nodo raíz hasta un nodo.
  @param  idNodo  ID path CNS del nodo.
  @param  ruta    Salida: IDs desde la raíz hasta idNodo, ambos incluidos. Vacía si hay error.
  @return IOT_NAV_OK, IOT_NAV_ERR_CNS o IOT_NAV_ERR_PROFUNDIDAD.
*/
int iot_getNavPath(string idNodo, dyn_string &ruta)
{
  dynClear(ruta);

  string dpEnlazado;
  if (!cnsGetId(idNodo, dpEnlazado))
    return _iot_logNavError(IOT_NAV_ERR_CNS, IOT_NAV_MSG_CNS, "cnsGetId", idNodo);

  string actual = idNodo;
  while (actual != "")
  {
    if (dynlen(ruta) >= IOT_NAV_MAX_NIVEL)
    {
      dynClear(ruta);
      return _iot_logNavError(IOT_NAV_ERR_PROFUNDIDAD, IOT_NAV_MSG_PROFUNDIDAD, IOT_NAV_MAX_NIVEL, idNodo);
    }
    dynInsertAt(ruta, actual, 1);
    actual = _iot_getNavPadre(actual);
  }
  return IOT_NAV_OK;
}

// --- Funciones internas ---

string _iot_getNavRutaVista(string vista)
{
  return strrtrim(getSystemName(), ":") + "." + vista + ":";
}

/** Padre de un nodo, o "" si es el nodo raíz de su árbol (su padre es la vista). */
string _iot_getNavPadre(string idNodo)
{
  string padre;
  if (!cnsGetParent(idNodo, padre) || padre == "" || strpos(padre, ":") == strlen(padre) - 1)
    return "";
  return padre;
}

int _iot_addNavNodo(string idNodo, string idPadre, int nivel, vector<IotNavNodo> &nodos)
{
  if (nivel > IOT_NAV_MAX_NIVEL)
    return _iot_logNavError(IOT_NAV_ERR_PROFUNDIDAD, IOT_NAV_MSG_PROFUNDIDAD, IOT_NAV_MAX_NIVEL, idNodo);

  langString nombres;
  if (!cnsGetDisplayNames(idNodo, nombres))
    return _iot_logNavError(IOT_NAV_ERR_CNS, IOT_NAV_MSG_CNS, "cnsGetDisplayNames", idNodo);

  IotNavNodo nodo;
  nodo.id = idNodo;
  nodo.texto = nombres;
  nodo.idPadre = idPadre;
  nodo.nivel = nivel;
  nodos.append(nodo);
  DebugFTN(IOT_NAV_FLAG, "nodo", nivel, idNodo);

  dyn_string hijos;
  if (!cnsGetChildren(idNodo, hijos))
    return _iot_logNavError(IOT_NAV_ERR_CNS, IOT_NAV_MSG_CNS, "cnsGetChildren", idNodo);
  for (int i = 1; i <= dynlen(hijos); i++)
  {
    int resultado = _iot_addNavNodo(hijos[i], idNodo, nivel + 1, nodos);
    if (resultado != IOT_NAV_OK)
      return resultado;
  }
  return IOT_NAV_OK;
}

/** Registra el error con throwError() y devuelve el código para propagarlo. */
int _iot_logNavError(int codigo, int mensaje, string detalle, string elemento)
{
  throwError(makeError(IOT_NAV_CATALOGO, PRIO_WARNING, ERR_CONTROL, mensaje, detalle, elemento));
  return codigo;
}

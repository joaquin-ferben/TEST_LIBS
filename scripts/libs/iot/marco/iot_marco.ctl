/**
  @file     iot_marco.ctl
  @brief    Funciones del panel base iot_marco.xml: rellena cabecera y árbol y carga paneles en la zona de trabajo.
  @author   TEST_LIBS

  Solo se usa desde la UI. Documento del módulo: dev/modulos/marco.md (en TEST_CLAUDE).
*/
#uses "panel"
#uses "iot/nav/iot_nav"

const string IOT_MARCO_MODULO       = "IotTrabajo";      // ModuleName del Embedded module mod_trabajo
const string IOT_MARCO_CATALOGO     = "iot_marco";
const string IOT_MARCO_CAT_PLANTA   = "iot_planta";      // catálogo que aporta cada proyecto
const string IOT_MARCO_CLAVE_PLANTA = "nombre";
const string IOT_MARCO_FORMATO_HORA = "%d/%m/%Y %H:%M:%S";
const int    IOT_MARCO_REFRESCO_SEG = 1;
const string IOT_MARCO_FLAG         = "iot_marco";
const string IOT_MARCO_PARAM_VISTA  = "$VISTA";          // vista CNS que navega el marco; sin él, la de la planta

const string IOT_MARCO_SHAPE_ARBOL   = "tree_nav";
const string IOT_MARCO_SHAPE_MODULO  = "mod_trabajo";
const string IOT_MARCO_SHAPE_PLANTA  = "txt_planta";
const string IOT_MARCO_SHAPE_TITULO  = "txt_titulo";
const string IOT_MARCO_SHAPE_USUARIO = "txt_usuario";
const string IOT_MARCO_SHAPE_HORA    = "txt_fechaHora";
const string IOT_MARCO_SHAPE_RUTA    = "btn_ruta";        // btn_ruta1 ... btn_ruta<IOT_NAV_MAX_NIVEL>

// Estado de la UI, un marco por manager UI. Tiene que ser "global": una variable de librería
// sin "global" se copia en cada script, y el Clicked de un botón no vería lo que guardó el Initialize
global mapping g_iotMarcoTextos;     // id de nodo -> texto en el idioma activo
global dyn_string g_iotMarcoRuta;    // ids de la ruta de la pantalla activa

/**
  @brief  Inicializa el marco: cabecera, árbol, zona de trabajo sin escalado y carga del nodo raíz.
          Se llama desde el Initialize del panel. La vista sale de $VISTA, o es IOT_NAV_VISTA si no se pasa.
*/
void iot_initMarco()
{
  string vista = isDollarDefined(IOT_MARCO_PARAM_VISTA) ? getDollarValue(IOT_MARCO_PARAM_VISTA) : IOT_NAV_VISTA;
  setValue(IOT_MARCO_SHAPE_MODULO, "ModuleName", IOT_MARCO_MODULO);
  // 3.21 amplía por defecto los paneles más pequeños que el módulo (spec 001, D5)
  setScaleStyle(SCALE_NONE, IOT_MARCO_MODULO);
  setValue(IOT_MARCO_SHAPE_PLANTA, "text", getCatStr(IOT_MARCO_CAT_PLANTA, IOT_MARCO_CLAVE_PLANTA));
  _iot_showMarcoRuta(makeDynString());
  startThread("_iot_runMarcoReloj");

  vector<IotNavNodo> nodos;
  if (iot_getNavNodes(vista, nodos) != IOT_NAV_OK || nodos.count() == 0)
  {
    setValue(IOT_MARCO_SHAPE_TITULO, "text", getCatStr(IOT_MARCO_CATALOGO, "navNoDisponible"));
    return;
  }

  shape arbol = getShape(IOT_MARCO_SHAPE_ARBOL);
  // Sin al menos una columna el tree widget no pinta los ítems; la cabecera sobra en navegación
  arbol.addColumn("");
  arbol.headerHidden(true);
  mappingClear(g_iotMarcoTextos);
  for (int i = 0; i < nodos.count(); i++)
  {
    IotNavNodo nodo = nodos.at(i);
    g_iotMarcoTextos[nodo.id] = nodo.texto;
    arbol.appendItemNC(nodo.idPadre, nodo.id, nodo.texto);
  }
  arbol.expandAll();
  iot_showMarcoNodo(nodos.at(0).id);
}

/**
  @brief  Carga en la zona de trabajo el panel de un nodo y actualiza ruta y título.
  @param  idNodo  ID path CNS del nodo.
  @return Resultado de iot_getNavTarget. Con error (p. ej. nodo agrupador) la pantalla activa no cambia.
*/
int iot_showMarcoNodo(string idNodo)
{
  string panel, dp;
  int resultado = iot_getNavTarget(idNodo, panel, dp);
  if (resultado != IOT_NAV_OK)
    return resultado;

  dyn_string ruta;
  resultado = iot_getNavPath(idNodo, ruta);
  if (resultado != IOT_NAV_OK)
    return resultado;

  RootPanelOnModule(panel, idNodo, IOT_MARCO_MODULO, makeDynString("$DP:" + dp));
  setValue(IOT_MARCO_SHAPE_TITULO, "text", _iot_getMarcoTexto(idNodo));
  _iot_showMarcoRuta(ruta);
  DebugFTN(IOT_MARCO_FLAG, "pantalla", idNodo, panel, dp);
  return IOT_NAV_OK;
}

/**
  @brief  Vuelve al nivel indicado de la ruta activa. Se llama desde el Clicked de btn_ruta<nivel>.
  @param  nivel  1 a IOT_NAV_MAX_NIVEL.
*/
void iot_onMarcoRuta(int nivel)
{
  if (nivel >= 1 && nivel <= dynlen(g_iotMarcoRuta))
    iot_showMarcoNodo(g_iotMarcoRuta[nivel]);
}

// --- Funciones internas ---

string _iot_getMarcoTexto(string idNodo)
{
  return mappingHasKey(g_iotMarcoTextos, idNodo) ? g_iotMarcoTextos[idNodo] : idNodo;
}

void _iot_showMarcoRuta(dyn_string ruta)
{
  g_iotMarcoRuta = ruta;
  for (int nivel = 1; nivel <= IOT_NAV_MAX_NIVEL; nivel++)
  {
    string boton = IOT_MARCO_SHAPE_RUTA + nivel;
    bool usado = nivel <= dynlen(ruta);
    setValue(boton, "visible", usado);
    if (usado)
      setValue(boton, "text", _iot_getMarcoTexto(ruta[nivel]));
  }
}

/** Refresca fecha, hora y usuario. No hay evento de cambio de usuario (spec 001, D2). */
void _iot_runMarcoReloj()
{
  while (true)
  {
    setValue(IOT_MARCO_SHAPE_HORA, "text", formatTime(IOT_MARCO_FORMATO_HORA, getCurrentTime()));
    setValue(IOT_MARCO_SHAPE_USUARIO, "text", getUserName());
    delay(IOT_MARCO_REFRESCO_SEG);
  }
}

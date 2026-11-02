/**
  @file     test_navegacion.ctl
  @brief    Tests de integración del módulo nav (spec 001, criterios C1 a C5).

  Crea sus propias vistas CNS _TEST_nav y _TEST_nav_prof y el DP _TEST_nav_dp, y los borra al terminar.
*/
#uses "CtrlOaUnit"
#uses "iot/nav/iot_nav"

const string MODULO = "nav";
const string DPT_PRUEBA = "ExampleDP_Float";
const string DP_ENLAZADO = "_TEST_nav_dp";
const dyn_string DPS_PRUEBA = makeDynString(DP_ENLAZADO);
const string VISTA = "_TEST_nav";
const string VISTA_PROFUNDA = "_TEST_nav_prof";
const dyn_string VISTAS_PRUEBA = makeDynString(VISTA, VISTA_PROFUNDA);
const string PANEL_EXISTENTE = "about.pnl";             // panel estándar de la instalación
const string PANEL_INEXISTENTE = "iot/_test_no_existe.xml";
const string TEXTO_RAIZ_IDIOMA_0 = "Root";              // idioma 0 = activo en un CTRL sin UI (spec 001, D1)
const string TEXTO_RAIZ_IDIOMA_1 = "Raiz";

main(string resultFile = "")
{
  if (resultFile == "")
    resultFile = getPath(LOG_REL_PATH) + "oaUnit_" + MODULO + "_navegacion.txt";
  oaUnitSetup(resultFile, makeMapping("UserData", makeMapping("TestSuiteId", MODULO, "TestType", "Integration")));

  borrarDatosPrueba();  // restos de una ejecución anterior interrumpida
  try
  {
    oaUnitAssertTrue(MODULO + "-setup-vistas", crearDatosPrueba());

    string raiz = idNodo(VISTA, "raiz");
    string area = raiz + ".area";
    string equipo = area + ".equipo";
    string detalle = equipo + ".detalle";

    // C1: jerarquía
    vector<IotNavNodo> nodos;
    oaUnitAssertEqual(MODULO + "-C1-resultado", iot_getNavNodes(VISTA, nodos), IOT_NAV_OK);
    dyn_string ids;
    dyn_int niveles;
    for (int i = 0; i < nodos.count(); i++)
    {
      dynAppend(ids, nodos.at(i).id);
      dynAppend(niveles, nodos.at(i).nivel);
    }
    oaUnitAssertEqual(MODULO + "-C1-orden-padre-antes-hijos", ids, makeDynString(raiz, area, equipo, detalle));
    oaUnitAssertEqual(MODULO + "-C1-nivel-por-profundidad", niveles, makeDynInt(1, 2, 3, 4));
    oaUnitAssertEqual(MODULO + "-C1-texto-idioma-activo", nodos.count() > 0 ? nodos.at(0).texto : "", TEXTO_RAIZ_IDIOMA_0);

    // C2: destino
    string panel, dp;
    oaUnitAssertEqual(MODULO + "-C2-panel-y-dp-resultado", iot_getNavTarget(equipo, panel, dp), IOT_NAV_OK);
    oaUnitAssertEqual(MODULO + "-C2-panel-y-dp-panel", panel, PANEL_EXISTENTE);
    oaUnitAssertTrue(MODULO + "-C2-panel-y-dp", strpos(dp, DP_ENLAZADO) >= 0, dp);
    oaUnitAssertEqual(MODULO + "-C2-nodo-sin-dp-resultado", iot_getNavTarget(raiz, panel, dp), IOT_NAV_OK);
    oaUnitAssertEqual(MODULO + "-C2-nodo-sin-dp", dp, "");

    // C3: ruta
    dyn_string ruta;
    oaUnitAssertEqual(MODULO + "-C3-resultado", iot_getNavPath(detalle, ruta), IOT_NAV_OK);
    oaUnitAssertEqual(MODULO + "-C3-ruta-desde-raiz", ruta, makeDynString(raiz, area, equipo, detalle));

    // C4: errores de destino
    oaUnitAssertEqual(MODULO + "-C4-nodo-agrupador", iot_getNavTarget(area, panel, dp), IOT_NAV_ERR_SIN_PANEL);
    oaUnitAssertEqual(MODULO + "-C4-nodo-agrupador-sin-panel", panel, "");
    oaUnitAssertEqual(MODULO + "-C4-panel-inexistente", iot_getNavTarget(detalle, panel, dp), IOT_NAV_ERR_PANEL_NO_EXISTE);

    // C5: profundidad
    vector<IotNavNodo> nodosProfundos;
    oaUnitAssertEqual(MODULO + "-C5-profundidad-maxima", iot_getNavNodes(VISTA_PROFUNDA, nodosProfundos), IOT_NAV_ERR_PROFUNDIDAD);
    oaUnitAssertEqual(MODULO + "-C5-profundidad-sin-nodos", nodosProfundos.count(), 0);
  }
  catch
  {
    oaUnitAbort(MODULO + "-excepcion-navegacion", getLastException());
  }
  oaUnitAssertEqual(MODULO + "-limpieza", borrarDatosPrueba(), 0);
  exit(0);
}

string idNodo(string vista, string ruta)
{
  return strrtrim(getSystemName(), ":") + "." + vista + ":" + ruta;
}

langString textos(string idioma0, string idioma1)
{
  langString resultado;
  setLangString(resultado, 0, idioma0);
  setLangString(resultado, 1, idioma1);
  return resultado;
}

/** Crea una vista con un árbol raíz de un solo nodo. */
bool crearVista(string vista, string raiz, langString textoRaiz)
{
  dyn_dyn_string nombres, dps;
  dyn_dyn_langString textosArbol;
  nombres[1][1] = raiz;
  textosArbol[1][1] = textoRaiz;
  dps[1][1] = "";
  return cnsCreateView(idNodo(vista, ""), textos(vista, vista))
         && cnsAddTree(idNodo(vista, ""), nombres, textosArbol, dps);
}

/**
  _TEST_nav:      raiz (N1, panel) > area (N2, agrupador) > equipo (N3, panel + DP) > detalle (N4, panel inexistente)
  _TEST_nav_prof: cinco niveles, uno más que IOT_NAV_MAX_NIVEL
*/
bool crearDatosPrueba()
{
  string raiz = idNodo(VISTA, "raiz");
  bool ok = dpCreate(DP_ENLAZADO, DPT_PRUEBA) == 0
            && crearVista(VISTA, "raiz", textos(TEXTO_RAIZ_IDIOMA_0, TEXTO_RAIZ_IDIOMA_1))
            && cnsSetProperty(raiz, IOT_NAV_PROP_PANEL, PANEL_EXISTENTE)
            && cnsAddNode(raiz, "area", textos("Area", "Area"), "")
            && cnsAddNode(raiz + ".area", "equipo", textos("Equipment", "Equipo"), DP_ENLAZADO + ".")
            && cnsSetProperty(raiz + ".area.equipo", IOT_NAV_PROP_PANEL, PANEL_EXISTENTE)
            && cnsAddNode(raiz + ".area.equipo", "detalle", textos("Detail", "Detalle"), "")
            && cnsSetProperty(raiz + ".area.equipo.detalle", IOT_NAV_PROP_PANEL, PANEL_INEXISTENTE);

  string actual = idNodo(VISTA_PROFUNDA, "n1");
  ok = ok && crearVista(VISTA_PROFUNDA, "n1", textos("n1", "n1"));
  for (int nivel = 2; ok && nivel <= IOT_NAV_MAX_NIVEL + 1; nivel++)
  {
    ok = cnsAddNode(actual, "n" + nivel, textos("n" + nivel, "n" + nivel), "");
    actual += ".n" + nivel;
  }
  return ok;
}

/**
  @return Número de vistas y DPs de prueba que no se han podido borrar.
*/
int borrarDatosPrueba()
{
  int noBorrados = 0;
  dyn_string vistas;
  cnsGetViews(strrtrim(getSystemName(), ":"), vistas);
  for (int i = 1; i <= dynlen(VISTAS_PRUEBA); i++)
  {
    string vista = idNodo(VISTAS_PRUEBA[i], "");
    if (dynContains(vistas, vista) > 0 && !cnsDeleteView(vista))
      noBorrados++;
  }
  for (int i = 1; i <= dynlen(DPS_PRUEBA); i++)
  {
    if (dpExists(DPS_PRUEBA[i]) && (dpDelete(DPS_PRUEBA[i]) != 0 || dpExists(DPS_PRUEBA[i])))
      noBorrados++;
  }
  return noBorrados;
}

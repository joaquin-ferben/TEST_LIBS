/**
  @file     iot_crearNavegacionIngenieria.ctl
  @brief    Crea (o recrea) la vista CNS del marco de ingeniería. Spec 002.3, C3.1.

  Uso: WCCOActrl -proj TEST_CLAUDE iot_crearNavegacionIngenieria.ctl
  Contenido: un nodo raíz, el explorador de clases, que es la pantalla que abre el marco al arrancar.
  El marco la navega con $VISTA:IotIngenieria (config/progs de cada proyecto).
*/
#uses "iot/nav/iot_nav"
#uses "iot/engcore/iot_engcore_explorador"

const int ERROR_ESTADO_INESPERADO = 54;  // "Unexpected state" en _errors.cat de la instalación

main()
{
  string sistema = strrtrim(getSystemName(), ":");
  string vista = sistema + "." + IOT_ENGCORE_VISTA_INGENIERIA + ":";
  string raiz = vista + "explorador";

  dyn_string vistas;
  cnsGetViews(sistema, vistas);
  if (dynContains(vistas, vista) > 0 && !cnsDeleteView(vista))
    salir("no se ha podido borrar la vista anterior " + vista);

  dyn_dyn_string nombres, dps;
  dyn_dyn_langString textosArbol;
  nombres[1][1] = "explorador";
  textosArbol[1][1] = textos("Class explorer", "Explorador de clases");
  dps[1][1] = "";

  bool ok = cnsCreateView(vista, textos("Engineering", "Ingeniería"))
            && cnsAddTree(vista, nombres, textosArbol, dps)
            && cnsSetProperty(raiz, IOT_NAV_PROP_PANEL, IOT_ENGCORE_PANEL_EXPLORADOR);
  if (!ok)
    salir("no se ha podido crear la vista " + vista);

  DebugTN("iot_crearNavegacionIngenieria: vista creada", vista);
  exit(0);
}

langString textos(string enUS, string esES)
{
  langString resultado;
  setLangString(resultado, 0, enUS);  // orden de langs en config/config de TEST_CLAUDE: en_US, es_ES
  setLangString(resultado, 1, esES);
  return resultado;
}

void salir(string motivo)
{
  throwError(makeError("", PRIO_SEVERE, ERR_CONTROL, ERROR_ESTADO_INESPERADO, "iot_crearNavegacionIngenieria: " + motivo));
  exit(1);
}

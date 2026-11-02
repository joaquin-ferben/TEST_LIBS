/**
  @file     iot_engcore_ext.ctl
  @brief    Extensión del Script Editor: menú "IoT" para generar el DPT y los accesores de las clases del fichero activo.
  @author   TEST_LIBS

  El Script Editor carga al arrancar todos los scripts/scriptEditor/<nombre>_ext.ctl de todos los proj_path (spec 002, D4).
  Documento del módulo: dev/modulos/engcore.md (en TEST_CLAUDE).
*/
#uses "iot/engcore/iot_engcore_dpt"

const string IOT_ENGCORE_ATAJO_GENERAR_DPT = "Ctrl+Shift+G";
const int    IOT_ENGCORE_ANCHO_DIALOGO = 640;
const int    IOT_ENGCORE_ALTO_DIALOGO = 360;
const int    IOT_ENGCORE_ESPERA_APERTURA_DECIMAS = 50;   // si la ventana no llega a abrirse en 5 s, cuenta como cancelada
const int    IOT_ENGCORE_LINEAS_AYUDA = 14;              // claves ayuda01..ayuda14 del catálogo

main()
{
  int menu = moduleAddMenu(iot_getEngcoreTexto("menu"));
  moduleAddAction(iot_getEngcoreTexto("accionGenerar"), "", IOT_ENGCORE_ATAJO_GENERAR_DPT, menu, -1, "_iot_onEngcoreGenerarDpt");
  moduleAddAction(iot_getEngcoreTexto("accionAyuda"), "", "", menu, -1, "_iot_onEngcoreAyuda");
  seAddCompletionItem(IOT_ENGCORE_DPT_INICIO, IOT_ENGCORE_DPT_INICIO);
  seAddCompletionItem(IOT_ENGCORE_DPT_FIN, IOT_ENGCORE_DPT_FIN);
}

/**
  Acción "Generar DPT desde clase": comprueba que el editor está guardado, calcula el plan, pide confirmación
  de los borrados si hace falta, aplica, reescribe el bloque //@generado en el editor y muestra el resumen.
*/
void _iot_onEngcoreGenerarDpt()
{
  string fichero = seGetScriptFileName();
  string texto;
  fileToString(fichero, texto);   // si falla, el plan lo señala con errFichero
  dyn_string lineasDisco = _iot_splitEngcoreLineas(texto);
  if (!_iot_isEngcoreEditorGuardado(lineasDisco))
  {
    _iot_showEngcoreDialogo(IOT_ENGCORE_MODO_AVISO, iot_getEngcoreTexto("tituloSinGuardar"), iot_getEngcoreTexto("textoSinGuardar"), makeDynString());
    return;
  }

  IotDptPlan plan;
  int resultado = iot_planDptFromFile(fichero, plan);
  if (resultado != IOT_ENGCORE_OK)
  {
    _iot_showEngcoreDialogo(IOT_ENGCORE_MODO_AVISO, iot_getEngcoreTexto("tituloErrores"), iot_getEngcoreTexto("textoErrores"), plan.errores);
    return;
  }
  if (dynlen(plan.clases) == 0)
  {
    _iot_showEngcoreDialogo(IOT_ENGCORE_MODO_AVISO, iot_getEngcoreTexto("tituloResumen"), iot_getEngcoreTexto("textoSinClases"), makeDynString());
    return;
  }

  if (dynlen(plan.eliminaciones) > 0)
  {
    dyn_string lista = plan.eliminaciones;
    dynAppend(lista, "");
    for (int i = 1; i <= mappinglen(plan.dpsAfectados); i++)
      dynAppend(lista, iot_getEngcoreTexto("dpsAfectados", mappingGetKey(plan.dpsAfectados, i), mappingGetValue(plan.dpsAfectados, i)));
    int respuesta = _iot_showEngcoreDialogo(IOT_ENGCORE_MODO_CONFIRMAR, iot_getEngcoreTexto("tituloBorrados"),
                                            iot_getEngcoreTexto("textoBorrados"), lista);
    if (respuesta != IOT_ENGCORE_RESPUESTA_SI)
      return;
  }

  resultado = iot_applyDptPlan(plan);
  if (resultado != IOT_ENGCORE_OK)
  {
    _iot_showEngcoreDialogo(IOT_ENGCORE_MODO_AVISO, iot_getEngcoreTexto("tituloErrores"), iot_getEngcoreTexto("errAplicar", resultado), plan.clases);
    return;
  }

  // El bloque se escribe en el editor, no en disco: el fichero está abierto y al guardar se machacaría
  string resumen = iot_getEngcoreTexto("textoResumen");
  dyn_string lineasNuevas, errores;
  if (iot_buildDptAccesores(texto, lineasNuevas, errores) == IOT_ENGCORE_OK && _iot_writeEngcoreEditor(lineasDisco, lineasNuevas))
    resumen = iot_getEngcoreTexto("textoGuardar") + "\n\n" + resumen;
  _iot_showEngcoreDialogo(IOT_ENGCORE_MODO_AVISO, iot_getEngcoreTexto("tituloResumen"), resumen, plan.clases);
}

/** Acción "Ayuda": decoradores e indicaciones básicas de uso, del catálogo. */
void _iot_onEngcoreAyuda()
{
  dyn_string lineas;
  for (int i = 1; i <= IOT_ENGCORE_LINEAS_AYUDA; i++)
    dynAppend(lineas, iot_getEngcoreTexto("ayuda" + (i < 10 ? "0" : "") + i));
  _iot_showEngcoreDialogo(IOT_ENGCORE_MODO_AVISO, iot_getEngcoreTexto("tituloAyuda"), iot_getEngcoreTexto("textoAyuda"), lineas);
}

/** Líneas de un texto sin fin de línea, numeradas como las del editor (la primera es la 0 del editor). */
dyn_string _iot_splitEngcoreLineas(string texto)
{
  dyn_string lineas;
  int inicio = 0;
  int fin = strpos(texto, "\n");
  while (fin >= 0)
  {
    dynAppend(lineas, strrtrim(substr(texto, inicio, fin - inicio), "\r"));
    inicio = fin + 1;
    fin = strpos(texto, "\n", inicio);
  }
  dynAppend(lineas, strrtrim(substr(texto, inicio), "\r"));
  return lineas;
}

/** true si el editor tiene lo mismo que el fichero guardado. Pasado el final, seGetLine devuelve "" (spec 002, D10). */
bool _iot_isEngcoreEditorGuardado(dyn_string lineasDisco)
{
  for (int i = 1; i <= dynlen(lineasDisco); i++)
  {
    if (strrtrim(seGetLine(i - 1), "\r") != lineasDisco[i])
      return false;
  }
  return seGetLine(dynlen(lineasDisco)) == "";
}

/**
  Cambia en el editor solo las líneas que difieren: quita el tramo distinto y pone el nuevo (líneas desde 0, D10).
  @return true si ha cambiado algo.
*/
bool _iot_writeEngcoreEditor(dyn_string antes, dyn_string despues)
{
  int comunInicio = 0;
  while (comunInicio < dynlen(antes) && comunInicio < dynlen(despues) && antes[comunInicio + 1] == despues[comunInicio + 1])
    comunInicio++;
  int comunFin = 0;
  while (comunFin < dynlen(antes) - comunInicio && comunFin < dynlen(despues) - comunInicio
         && antes[dynlen(antes) - comunFin] == despues[dynlen(despues) - comunFin])
    comunFin++;

  int quitar = dynlen(antes) - comunInicio - comunFin;
  int poner = dynlen(despues) - comunInicio - comunFin;
  for (int i = 1; i <= quitar; i++)
    seRemoveLine(comunInicio);
  for (int i = 1; i <= poner; i++)
    seInsertLine(comunInicio + i - 1, despues[comunInicio + i]);
  return quitar > 0 || poner > 0;
}

/**
  @brief  Abre el diálogo en su propia ventana y espera la respuesta. Dentro de una extensión del Script Editor
          no se pueden usar paneles hijos ni popupMenu (spec 002, D5).
  @return IOT_ENGCORE_RESPUESTA_SI, _NO o _NINGUNA (ventana cerrada con la X).
*/
int _iot_showEngcoreDialogo(string modo, string titulo, string texto, dyn_string lista)
{
  _iot_setEngcoreGlobal(IOT_ENGCORE_VAR_MODO, STRING_VAR, modo);
  _iot_setEngcoreGlobal(IOT_ENGCORE_VAR_TEXTO, STRING_VAR, texto);
  _iot_setEngcoreGlobal(IOT_ENGCORE_VAR_LISTA, STRING_VAR, strjoin(lista, "\n"));
  _iot_setEngcoreGlobal(IOT_ENGCORE_VAR_RESPUESTA, INT_VAR, IOT_ENGCORE_RESPUESTA_NINGUNA);

  ModuleOnWithPanel(IOT_ENGCORE_MODULO_DIALOGO, -1, -1, IOT_ENGCORE_ANCHO_DIALOGO, IOT_ENGCORE_ALTO_DIALOGO, 1, 1, "",
                    IOT_ENGCORE_PANEL_DIALOGO, titulo, makeDynString());

  bool vistoAbierto = false;
  int decimas = 0;
  while ((int)getVariable(IOT_ENGCORE_VAR_RESPUESTA) == IOT_ENGCORE_RESPUESTA_NINGUNA)
  {
    bool abierto = isModuleOpen(IOT_ENGCORE_MODULO_DIALOGO);
    vistoAbierto = vistoAbierto || abierto;
    if ((vistoAbierto && !abierto) || (!vistoAbierto && decimas > IOT_ENGCORE_ESPERA_APERTURA_DECIMAS))
      break;
    delay(0, 100);
    decimas++;
  }
  return getVariable(IOT_ENGCORE_VAR_RESPUESTA);
}

void _iot_setEngcoreGlobal(string nombre, int tipo, anytype valor)
{
  if (!globalExists(nombre))
    addGlobal(nombre, tipo);
  setVariable(nombre, valor);
}

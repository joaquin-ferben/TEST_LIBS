/**
  @file     test_explorador_ficheros.ctl
  @brief    Tests de integración del explorador de engcore (spec 002.3, criterios C3.2, C3.3 y C3.6 a C3.8).

  Escribe clases de prueba en scripts/libs/classes/_TEST_engcore/ del proyecto (nivel 1) y de la librería (nivel 2),
  genera su DPT y su registro y crea DPs. Al terminar lo borra todo: carpetas, DPs, registros y DPT.
*/
#uses "CtrlOaUnit"
#uses "iot/engcore/iot_engcore_explorador"

const string MODULO = "engcore";
const string CARPETA = "classes/_TEST_engcore/";
const string BASE = "_TEST_engcore_Base";     // librería, generada
const string HIJA = "_TEST_engcore_Hija";     // proyecto, hija de la base, sin generar al principio
const string DUPLICADA = "_TEST_engcore_Dup"; // en los dos: manda la del proyecto
const string NUEVA = "_TEST_engcore_Nueva";   // la crea el explorador
const dyn_string DPTS_PRUEBA = makeDynString(NUEVA, HIJA, DUPLICADA, BASE);   // hijas antes que padres
const string DP_BASE = "_TEST_engcore_base1";
const string DP_HIJA = "_TEST_engcore_hija1";

main(string resultFile = "")
{
  if (resultFile == "")
    resultFile = getPath(LOG_REL_PATH) + "oaUnit_" + MODULO + "_explorador_ficheros.txt";
  oaUnitSetup(resultFile, makeMapping("UserData", makeMapping("TestSuiteId", MODULO, "TestType", "Integration")));

  borrarDatosPrueba();  // restos de una ejecución anterior interrumpida
  try
  {
    oaUnitAssertTrue(MODULO + "-setup-ficheros", crearFicheros());
    probarBusqueda();
    probarCrear();
    probarMover();
    probarBorrado();
  }
  catch
  {
    oaUnitAbort(MODULO + "-excepcion-explorador-ficheros", getLastException());
  }
  oaUnitAssertEqual(MODULO + "-limpieza", borrarDatosPrueba(), 0);
  exit(0);
}

/** C3.2 y C3.3: clases de los dos proyectos, generadas o no, con su ubicación. */
void probarBusqueda()
{
  vector<IotExploradorClase> arbol;
  dyn_string errores;
  iot_findExploradorClases(arbol, errores);
  IotExploradorClase base = buscar(arbol, BASE);
  IotExploradorClase hija = buscar(arbol, HIJA);
  IotExploradorClase duplicada = buscar(arbol, DUPLICADA);

  oaUnitAssertTrue(MODULO + "-C3.2-encuentra-en-ambos-proyectos", base.nombre == BASE && hija.nombre == HIJA);
  oaUnitAssertEqual(MODULO + "-C3.2-encuentra-padre", hija.padre, BASE);
  oaUnitAssertTrue(MODULO + "-C3.2-encuentra-raiz", buscar(arbol, IOT_DPOBJ_CLASE_RAIZ).nombre == IOT_DPOBJ_CLASE_RAIZ);
  oaUnitAssertTrue(MODULO + "-C3.2-incluye-no-generadas", hija.nombre == HIJA && dynlen(dpTypes(HIJA)) == 0);

  oaUnitAssertTrue(MODULO + "-C3.3-ubicacion", !base.enProyecto && hija.enProyecto);
  oaUnitAssertEqual(MODULO + "-C3.3-ubicacion-fichero", base.fichero, ruta(2, BASE));
  oaUnitAssertTrue(MODULO + "-C3.3-duplicada", duplicada.duplicada && duplicada.enProyecto && !base.duplicada);
  oaUnitAssertEqual(MODULO + "-C3.3-duplicada-manda-proyecto", duplicada.ficheros, makeDynString(ruta(1, DUPLICADA), ruta(2, DUPLICADA)));
}

/** C3.6: la hija se crea en el proyecto, en la carpeta del padre, con CRLF, y aparece en el árbol. */
void probarCrear()
{
  vector<IotExploradorClase> arbol;
  dyn_string errores;
  iot_findExploradorClases(arbol, errores);
  string fichero;
  oaUnitAssertEqual(MODULO + "-C3.6-crea-en-proyecto-resultado", iot_createExploradorHija(NUEVA, BASE, arbol, fichero, errores),
                    IOT_ENGCORE_OK, errores);
  oaUnitAssertEqual(MODULO + "-C3.6-crea-en-proyecto", fichero, ruta(1, NUEVA));
  // fileToString convierte \r\n en \n al leer: en disco hay un byte más por línea
  string texto;
  fileToString(fichero, texto);
  oaUnitAssertEqual(MODULO + "-C3.6-crea-con-crlf", (int)getFileSize(fichero), strlen(texto) + contar(texto, "\n"));

  iot_findExploradorClases(arbol, errores);
  IotExploradorClase nueva = buscar(arbol, NUEVA);
  oaUnitAssertTrue(MODULO + "-C3.6-crea-aparece-bajo-padre", nueva.padre == BASE && nueva.enProyecto);
  oaUnitAssertEqual(MODULO + "-C3.6-crea-repetida", iot_createExploradorHija(NUEVA, BASE, arbol, fichero, errores),
                    IOT_ENGCORE_ERR_NOMBRE);
}

/** C3.8: el fichero cambia de proj_path con la misma ruta relativa; con el destino ocupado no se mueve nada. */
void probarMover()
{
  vector<IotExploradorClase> arbol;
  dyn_string errores;
  iot_findExploradorClases(arbol, errores);
  string destino;
  oaUnitAssertEqual(MODULO + "-C3.8-mueve-con-misma-ruta-resultado", iot_moveExploradorClase(NUEVA, arbol, destino, errores),
                    IOT_ENGCORE_OK, errores);
  oaUnitAssertTrue(MODULO + "-C3.8-mueve-con-misma-ruta", destino == ruta(2, NUEVA) && isfile(ruta(2, NUEVA)) && !isfile(ruta(1, NUEVA)));

  iot_findExploradorClases(arbol, errores);
  oaUnitAssertEqual(MODULO + "-C3.8-mueve-al-proyecto", iot_moveExploradorClase(NUEVA, arbol, destino, errores), IOT_ENGCORE_OK, errores);
  oaUnitAssertTrue(MODULO + "-C3.8-mueve-al-proyecto-fichero", isfile(ruta(1, NUEVA)) && !isfile(ruta(2, NUEVA)));

  iot_findExploradorClases(arbol, errores);
  oaUnitAssertEqual(MODULO + "-C3.8-destino-ocupado", iot_moveExploradorClase(DUPLICADA, arbol, destino, errores), IOT_ENGCORE_ERR_FICHERO);
  oaUnitAssertTrue(MODULO + "-C3.8-destino-ocupado-intacto", isfile(ruta(1, DUPLICADA)) && isfile(ruta(2, DUPLICADA)) && destino == "");
}

/** C3.7: el plan lista la clase, sus descendientes (hijas antes) y sus DPs; el borrado lo quita todo. */
void probarBorrado()
{
  oaUnitAssertEqual(MODULO + "-C3.7-setup-genera-base", generar(ruta(2, BASE)), IOT_ENGCORE_OK);
  oaUnitAssertEqual(MODULO + "-C3.7-setup-genera-hija", generar(ruta(1, HIJA)), IOT_ENGCORE_OK);
  oaUnitAssertEqual(MODULO + "-C3.7-setup-dps", dpCreate(DP_BASE, BASE) + dpCreate(DP_HIJA, HIJA), 0);

  vector<IotExploradorClase> arbol;
  dyn_string errores;
  iot_findExploradorClases(arbol, errores);
  IotExploradorBorrado plan;
  oaUnitAssertEqual(MODULO + "-C3.7-plan-resultado", iot_planExploradorBorrado(BASE, arbol, plan), IOT_ENGCORE_OK, plan.errores);
  oaUnitAssertEqual(MODULO + "-C3.7-plan-incluye-descendientes-y-dps", plan.clases, makeDynString(NUEVA, HIJA, BASE));
  oaUnitAssertEqual(MODULO + "-C3.7-plan-numero-dps", plan.numDps, 2);
  oaUnitAssertEqual(MODULO + "-C3.7-plan-dpt-y-registro", strjoin(plan.dpts, ",") + "|" + strjoin(plan.registros, ","),
                    HIJA + "," + BASE + "|" + HIJA + "," + BASE);
  dyn_string ficherosBase = plan.ficheros[BASE];
  oaUnitAssertEqual(MODULO + "-C3.7-plan-ficheros", ficherosBase, makeDynString(ruta(2, BASE)));
  oaUnitAssertTrue(MODULO + "-C3.7-plan-resumen", dynlen(iot_getExploradorResumenBorrado(plan)) > dynlen(plan.clases));

  oaUnitAssertEqual(MODULO + "-C3.7-borra-en-cascada-resultado", iot_applyExploradorBorrado(plan, errores), IOT_ENGCORE_OK, errores);
  dyn_string jerarquia;
  oaUnitAssertTrue(MODULO + "-C3.7-borra-en-cascada",
                   !dpExists(DP_BASE) && !dpExists(DP_HIJA) && dynlen(dpTypes(BASE)) == 0 && dynlen(dpTypes(HIJA)) == 0
                   && iot_getDpObjJerarquia(BASE, jerarquia) != IOT_DPOBJ_OK && iot_getDpObjJerarquia(HIJA, jerarquia) != IOT_DPOBJ_OK
                   && !isfile(ruta(2, BASE)) && !isfile(ruta(1, HIJA)) && !isfile(ruta(1, NUEVA)));
  iot_findExploradorClases(arbol, errores);
  oaUnitAssertEqual(MODULO + "-C3.7-borra-en-cascada-arbol", buscar(arbol, BASE).nombre, "");
}

// --- Datos de prueba ---

/** Fichero de una clase de prueba en el nivel indicado (1 = proyecto, 2 = librería). */
string ruta(int nivel, string clase)
{
  return getPath(LIBS_REL_PATH, "", -1, nivel) + CARPETA + clase + ".ctl";
}

int contar(string texto, string trozo)
{
  int veces = 0;
  for (int posicion = strpos(texto, trozo); posicion >= 0; posicion = strpos(texto, trozo, posicion + 1))
    veces++;
  return veces;
}

IotExploradorClase buscar(vector<IotExploradorClase> &arbol, string nombre)
{
  for (int i = 0; i < arbol.count(); i++)
  {
    if (arbol.at(i).nombre == nombre)
      return arbol.at(i);
  }
  IotExploradorClase vacia;
  return vacia;
}

bool escribir(int nivel, string clase, dyn_string lineas)
{
  string carpeta = getPath(LIBS_REL_PATH, "", -1, nivel) + CARPETA;
  if (!isdir(carpeta) && !mkdir(carpeta))
    return false;
  file f = fopen(ruta(nivel, clase), "wb");
  fputs(strjoin(lineas, "\r\n") + "\r\n", f);
  fclose(f);
  return isfile(ruta(nivel, clase));
}

dyn_string clase(string nombre, string padre, string uso, string propiedad)
{
  return makeDynString("#uses \"" + uso + "\"", "class " + nombre + " : " + padre, "{",
                       "  public " + nombre + "(string dp = \"\") : " + padre + "(dp) {}",
                       "  //@dp:" + propiedad, "  protected int " + propiedad + ";", "  //@end", "};");
}

bool crearFicheros()
{
  return escribir(2, BASE, clase(BASE, "IotDpObject", "classes/iot/IotDpObject", "base"))
         && escribir(1, HIJA, clase(HIJA, BASE, "classes/_TEST_engcore/" + BASE, "hija"))
         && escribir(2, DUPLICADA, clase(DUPLICADA, "IotDpObject", "classes/iot/IotDpObject", "libreria"))
         && escribir(1, DUPLICADA, clase(DUPLICADA, "IotDpObject", "classes/iot/IotDpObject", "proyecto"));
}

int generar(string fichero)
{
  IotDptPlan plan;
  int resultado = iot_planDptFromFile(fichero, plan);
  return resultado == IOT_ENGCORE_OK ? iot_applyDptPlan(plan) : resultado;
}

/**
  @return Número de DPs, DPs de registro, DPT y carpetas de prueba que no se han podido borrar.
*/
int borrarDatosPrueba()
{
  int noBorrados = 0;
  dyn_string dps = dpNames("_TEST_engcore_*");
  dynAppend(dps, dpNames("_IotClase_*_TEST_engcore_*"));
  for (int i = 1; i <= dynlen(dps); i++)
  {
    if (dpDelete(dps[i]) != 0)
      noBorrados++;
  }
  for (int i = 1; i <= dynlen(DPTS_PRUEBA); i++)
  {
    if (dynlen(dpTypes(DPTS_PRUEBA[i])) > 0 && dpTypeDelete(DPTS_PRUEBA[i]) != 0)
      noBorrados++;
  }
  for (int nivel = 1; nivel <= 2; nivel++)
  {
    string carpeta = getPath(LIBS_REL_PATH, "", -1, nivel) + CARPETA;
    if (isdir(carpeta) && !rmdir(carpeta, true))
      noBorrados++;
  }
  return noBorrados;
}

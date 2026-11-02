/**
  @file     test_dpt_accesores.ctl
  @brief    Tests del bloque //@generado de engcore (spec 002.2, criterio C2.2).

  Los unitarios solo trabajan con texto. El de integración comprueba que la clase _TEST_engcore_Acc de este fichero
  lleva exactamente el bloque que genera engcore, y que ese bloque compila y lee y escribe su DP. Para eso copia la
  clase a <proyecto>/scripts/libs/_TEST_engcore_acc/, genera su DPT y su registro, y al terminar lo borra todo.
*/
#uses "CtrlOaUnit"
#uses "classes/iot/IotDpObject"
#uses "iot/engcore/iot_engcore_dpt"

const string MODULO = "engcore";
const string CLASE = "_TEST_engcore_Acc";
const string CARPETA = "_TEST_engcore_acc";
const string DP_ACC = "_TEST_engcore_acc1";
const string FUENTE = "tests/engcore/test_dpt_accesores.ctl";
const string AVISO = "  //@generado: no editar, lo reescribe IoT > Generar DPT desde clase";
const string FIN = "  //@fin-generado";

class _TEST_engcore_Acc : IotDpObject
{
  public _TEST_engcore_Acc(string dp = "") : IotDpObject(dp) {}

  //@dp:comandos
  protected bool run;
  //@end

  //@dp:estado
  protected float velocidad;
  protected mapping extra;
  protected dyn_string notas;
  //@end

  //@generado: no editar, lo reescribe IoT > Generar DPT desde clase
  public bool getRun() { return (bool)_getDp("run"); }
  public int setRun(bool valor) { return _setDp("run", valor); }
  public float getVelocidad() { return (float)_getDp("velocidad"); }
  public int setVelocidad(float valor) { return _setDp("velocidad", valor); }
  public mapping getExtra() { return (mapping)_getDp("extra"); }
  public int setExtra(mapping valor) { return _setDp("extra", valor); }
  public dyn_string getNotas() { return (dyn_string)_getDp("notas"); }
  public int setNotas(dyn_string valor) { return _setDp("notas", valor); }
  //@fin-generado
};

main(string resultFile = "")
{
  if (resultFile == "")
    resultFile = getPath(LOG_REL_PATH) + "oaUnit_" + MODULO + "_accesores.txt";
  oaUnitSetup(resultFile, makeMapping("UserData", makeMapping("TestSuiteId", MODULO, "TestType", "Integration")));

  borrarDatosPrueba();  // restos de una ejecución anterior interrumpida
  try
  {
    probarGeneraAccesores();
    probarSoloPropias();
    probarReemplazaBloque();
    probarQuitaBloque();
    probarRestoIntacto();
    probarMetodoChoca();
    probarAccesoresFuncionan();
  }
  catch
  {
    oaUnitAbort(MODULO + "-excepcion-accesores", getLastException());
  }
  oaUnitAssertEqual(MODULO + "-limpieza-accesores", borrarDatosPrueba(), 0);
  exit(0);
}

string unir(dyn_string lineas)
{
  return strjoin(lineas, "\n");
}

/** Accesores generados para un texto; con errores devuelve los errores para que se vean en el informe. */
dyn_string generar(dyn_string lineas)
{
  dyn_string resultado, errores;
  if (iot_buildDptAccesores(unir(lineas), resultado, errores) != IOT_ENGCORE_OK)
    return errores;
  return resultado;
}

void probarGeneraAccesores()
{
  dyn_string entrada = makeDynString(
    "class _TEST_engcore_M : IotDpObject",
    "{",
    "  //@dp:comandos",
    "  protected int arranques;",
    "  protected mapping parametros;",
    "  //@end",
    "};");
  dyn_string esperado = makeDynString(
    "class _TEST_engcore_M : IotDpObject",
    "{",
    "  //@dp:comandos",
    "  protected int arranques;",
    "  protected mapping parametros;",
    "  //@end",
    "",
    AVISO,
    "  public int getArranques() { return (int)_getDp(\"arranques\"); }",
    "  public int setArranques(int valor) { return _setDp(\"arranques\", valor); }",
    "  public mapping getParametros() { return (mapping)_getDp(\"parametros\"); }",
    "  public int setParametros(mapping valor) { return _setDp(\"parametros\", valor); }",
    FIN,
    "};");
  oaUnitAssertEqual(MODULO + "-C2.2-genera-accesores", generar(entrada), esperado);
}

void probarSoloPropias()
{
  dyn_string entrada = makeDynString(
    "class _TEST_engcore_A : IotDpObject",
    "{",
    "  //@dp:",
    "  protected bool a;",
    "  //@end",
    "};",
    "class _TEST_engcore_B : _TEST_engcore_A",
    "{",
    "  //@dp:",
    "  protected bool b;",
    "  //@end",
    "};");
  dyn_string esperado = makeDynString(
    "class _TEST_engcore_A : IotDpObject",
    "{",
    "  //@dp:",
    "  protected bool a;",
    "  //@end",
    "",
    AVISO,
    "  public bool getA() { return (bool)_getDp(\"a\"); }",
    "  public int setA(bool valor) { return _setDp(\"a\", valor); }",
    FIN,
    "};",
    "class _TEST_engcore_B : _TEST_engcore_A",
    "{",
    "  //@dp:",
    "  protected bool b;",
    "  //@end",
    "",
    AVISO,
    "  public bool getB() { return (bool)_getDp(\"b\"); }",
    "  public int setB(bool valor) { return _setDp(\"b\", valor); }",
    FIN,
    "};");
  oaUnitAssertEqual(MODULO + "-C2.2-solo-propias", generar(entrada), esperado);
}

void probarReemplazaBloque()
{
  dyn_string entrada = makeDynString(
    "class _TEST_engcore_M : IotDpObject",
    "{",
    "  //@dp:",
    "  protected float nueva;",
    "  //@end",
    "",
    AVISO,
    "  public float getVieja() { return (float)_getDp(\"vieja\"); }",
    "  public int setVieja(float valor) { return _setDp(\"vieja\", valor); }",
    FIN,
    "};");
  dyn_string esperado = makeDynString(
    "class _TEST_engcore_M : IotDpObject",
    "{",
    "  //@dp:",
    "  protected float nueva;",
    "  //@end",
    "",
    AVISO,
    "  public float getNueva() { return (float)_getDp(\"nueva\"); }",
    "  public int setNueva(float valor) { return _setDp(\"nueva\", valor); }",
    FIN,
    "};");
  oaUnitAssertEqual(MODULO + "-C2.2-reemplaza-bloque", generar(entrada), esperado);
}

void probarQuitaBloque()
{
  dyn_string entrada = makeDynString(
    "class _TEST_engcore_M : IotDpObject",
    "{",
    "  public int metodo() { return 1; }",
    "",
    AVISO,
    "  public float getVieja() { return (float)_getDp(\"vieja\"); }",
    "  public int setVieja(float valor) { return _setDp(\"vieja\", valor); }",
    FIN,
    "};");
  dyn_string esperado = makeDynString(
    "class _TEST_engcore_M : IotDpObject",
    "{",
    "  public int metodo() { return 1; }",
    "};");
  oaUnitAssertEqual(MODULO + "-C2.2-quita-bloque-sin-propiedades", generar(entrada), esperado);
}

/** Lo que no es el bloque no cambia, y generar sobre lo ya generado no cambia nada. */
void probarRestoIntacto()
{
  dyn_string entrada = makeDynString(
    "// cabecera",
    "#uses \"classes/iot/IotDpObject\"",
    "class _TEST_engcore_M : IotDpObject",
    "{",
    "  public _TEST_engcore_M(string dp = \"\") : IotDpObject(dp) {}",
    "  public float doble()",
    "  {",
    "    return 2 * getV();   // llamada a un accesor: no es una declaración",
    "  }",
    "  //@dp:",
    "  protected float v;",
    "  //@end",
    "  int sinDecorar;",
    "};",
    "",
    "void otraFuncion() {}",
    "");
  dyn_string generado = generar(entrada);
  dyn_string sinBloque = generado;
  int inicio = dynContains(sinBloque, AVISO) - 1;   // con la línea vacía que añade delante
  int fin = dynContains(sinBloque, FIN);
  for (int i = fin; i >= inicio && inicio > 0; i--)
    dynRemove(sinBloque, i);
  oaUnitAssertEqual(MODULO + "-C2.2-resto-intacto", sinBloque, entrada);
  oaUnitAssertEqual(MODULO + "-C2.2-resto-intacto-idempotente", generar(generado), generado);
}

void probarMetodoChoca()
{
  dyn_string lineas = makeDynString(
    "class _TEST_engcore_M : IotDpObject",                         // 1
    "{",                                                          // 2
    "  public float getVelocidad() { return 1.0; }",              // 3: choca
    "  public void otro()",                                       // 4
    "  {",                                                        // 5
    "    setVelocidad(2.0);   // llamada, no declaración",        // 6
    "  }",                                                        // 7
    "  //@dp:",                                                   // 8
    "  protected float velocidad;",                               // 9
    "  protected string dp;",                                     // 10: genera getDp, de IotDpObject
    "  //@end",                                                   // 11
    "};");                                                        // 12
  vector<IotDptClase> clases;
  dyn_string errores;
  int resultado = iot_parseDptClases(unir(lineas), clases, errores);
  dyn_int lineasError;
  for (int i = 1; i <= dynlen(errores); i++)
    dynAppend(lineasError, (int)substr(errores[i], 0, strpos(errores[i], ":")));
  dynSort(lineasError);
  oaUnitAssertEqual(MODULO + "-C2.2-metodo-choca-con-accesor", lineasError, makeDynInt(3, 10, 10), errores);
  oaUnitAssertEqual(MODULO + "-C2.2-metodo-choca-con-accesor-resultado", resultado, IOT_ENGCORE_ERR_PLAN);
}

/** La clase de este fichero lleva el bloque que genera engcore, compila y lee y escribe su DP. */
void probarAccesoresFuncionan()
{
  dyn_string clase = leerClaseDeEsteFichero();
  oaUnitAssertTrue(MODULO + "-C2.2-accesores-funcionan-clase-leida", dynlen(clase) > 10);
  dyn_string fichero = makeDynString("#uses \"classes/iot/IotDpObject\"");
  dynAppend(fichero, clase);   // vacía clase
  oaUnitAssertEqual(MODULO + "-C2.2-accesores-funcionan-bloque-igual-al-generado", generar(fichero), fichero);

  mkdir(carpeta());
  file f = fopen(carpeta() + "/Acc.ctl", "w");
  fputs(unir(fichero) + "\n", f);
  fclose(f);
  IotDptPlan plan;
  int resultado = iot_planDptFromFile(carpeta() + "/Acc.ctl", plan);
  if (resultado == IOT_ENGCORE_OK)
    resultado = iot_applyDptPlan(plan);
  oaUnitAssertEqual(MODULO + "-C2.2-accesores-funcionan-dpt", resultado, IOT_ENGCORE_OK, plan.errores);
  oaUnitAssertEqual(MODULO + "-C2.2-accesores-funcionan-dp", dpCreate(DP_ACC, CLASE), 0);

  _TEST_engcore_Acc acc = _TEST_engcore_Acc(DP_ACC);
  dyn_int escritos = makeDynInt(acc.setRun(true), acc.setVelocidad(2.5), acc.setExtra(makeMapping("a", 1)),
                                acc.setNotas(makeDynString("x", "y")));
  oaUnitAssertEqual(MODULO + "-C2.2-accesores-funcionan-set", escritos, makeDynInt(0, 0, 0, 0));
  mapping extra = acc.getExtra();
  dyn_string leidos = makeDynString(acc.getRun() ? "true" : "false", (string)acc.getVelocidad(),
                                    mappingHasKey(extra, "a") ? (string)extra["a"] : "", strjoin(acc.getNotas(), ","));
  oaUnitAssertEqual(MODULO + "-C2.2-accesores-funcionan", leidos, makeDynString("true", "2.5", "1", "x,y"));
  float velocidad;
  dpGet(DP_ACC + ".estado.velocidad", velocidad);
  oaUnitAssertEqualDelta(MODULO + "-C2.2-accesores-funcionan-en-el-dp", velocidad, 2.5, 0.000001);
}

/** Líneas de la clase CLASE tal como están en este fichero, desde "class" hasta "};". */
dyn_string leerClaseDeEsteFichero()
{
  string texto;
  fileToString(getPath(SCRIPTS_REL_PATH, FUENTE), texto);
  strreplace(texto, "\r", "");
  dyn_string todas = strsplit(texto, "\n");
  dyn_string clase;
  bool dentro = false;
  for (int i = 1; i <= dynlen(todas); i++)
  {
    if (todas[i] == "class " + CLASE + " : IotDpObject")
      dentro = true;
    if (dentro)
      dynAppend(clase, todas[i]);
    if (dentro && todas[i] == "};")
      break;
  }
  return clase;
}

string carpeta()
{
  return getPath(LIBS_REL_PATH) + CARPETA;
}

/**
  @return Número de DPs, DPs de registro, DPT y ficheros de prueba que no se han podido borrar.
*/
int borrarDatosPrueba()
{
  int noBorrados = 0;
  dyn_string dps = makeDynString(DP_ACC);
  dynAppend(dps, dpNames("_IotClase_*" + CLASE));
  for (int i = 1; i <= dynlen(dps); i++)
  {
    if (dpExists(dps[i]) && dpDelete(dps[i]) != 0)
      noBorrados++;
  }
  if (dynlen(dpTypes(CLASE)) > 0 && dpTypeDelete(CLASE) != 0)
    noBorrados++;
  if (isdir(carpeta()) && !rmdir(carpeta(), true))
    noBorrados++;
  return noBorrados;
}

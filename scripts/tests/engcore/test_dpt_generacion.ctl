/**
  @file     test_dpt_generacion.ctl
  @brief    Tests de integración de engcore (spec 002.1, criterios C1.3, C1.4, C1.7 y C1.8).

  Escribe sus clases de prueba en <proyecto>/scripts/libs/_TEST_engcore/ para probar la herencia entre ficheros
  con #uses, y al terminar borra esos ficheros, los DPs, los DPs de registro y los DPT que crea.
*/
#uses "CtrlOaUnit"
#uses "iot/engcore/iot_engcore_dpt"

const string MODULO = "engcore";
const string CARPETA = "_TEST_engcore";
const string MOTOR = "_TEST_engcore_Motor";
const string BOMBA = "_TEST_engcore_Bomba";
const string DOBLE = "_TEST_engcore_BombaDoble";
const string MALA = "_TEST_engcore_Mala";
const dyn_string DPTS_PRUEBA = makeDynString(DOBLE, BOMBA, MALA, MOTOR);
const string DP_BOMBA = "_TEST_engcore_bomba1";

main(string resultFile = "")
{
  if (resultFile == "")
    resultFile = getPath(LOG_REL_PATH) + "oaUnit_" + MODULO + "_generacion.txt";
  oaUnitSetup(resultFile, makeMapping("UserData", makeMapping("TestSuiteId", MODULO, "TestType", "Integration")));

  borrarDatosPrueba();  // restos de una ejecución anterior interrumpida
  try
  {
    probarGeneracion();
  }
  catch
  {
    oaUnitAbort(MODULO + "-excepcion-generacion", getLastException());
  }
  oaUnitAssertEqual(MODULO + "-limpieza", borrarDatosPrueba(), 0);
  exit(0);
}

void probarGeneracion()
{
  oaUnitAssertTrue(MODULO + "-setup-carpeta", mkdir(carpeta()));
  escribirMotor(makeDynString("  protected bool run;"), true);
  escribir("Bomba", makeDynString("#uses \"" + CARPETA + "/Motor\"", "class " + BOMBA + " : " + MOTOR, "{",
                                  "  //@dp:bomba", "  protected float presion;", "  //@end", "};"));
  escribir("Doble", makeDynString("#uses \"" + CARPETA + "/Bomba\"", "class " + DOBLE + " : " + BOMBA, "{",
                                  "  //@dp:bomba2", "  protected int segunda;", "  //@end", "};"));

  // C4: crea el DPT; mapping como string
  IotDptPlan plan;
  oaUnitAssertEqual(MODULO + "-C1.4-plan", generar("Motor", plan), IOT_ENGCORE_OK, plan.errores);
  oaUnitAssertEqual(MODULO + "-C1.4-crea-dpt", estructura(MOTOR),
                    ordenar(makeDynString("comandos.run:" + DPEL_BOOL, "estado.actual:" + DPEL_FLOAT, "estado.extra:" + DPEL_STRING)));
  oaUnitAssertEqual(MODULO + "-C1.4-mapping-como-string", hojas(MOTOR)["estado.extra"], DPEL_STRING);

  // C3: herencia aplanada entre ficheros (#uses), hasta la nieta
  oaUnitAssertEqual(MODULO + "-C1.3-plan-hija", generar("Bomba", plan), IOT_ENGCORE_OK, plan.errores);
  oaUnitAssertEqual(MODULO + "-C1.3-plan-nieta", generar("Doble", plan), IOT_ENGCORE_OK, plan.errores);
  oaUnitAssertEqual(MODULO + "-C1.3-herencia-aplanada", estructura(DOBLE),
                    ordenar(makeDynString("comandos.run:" + DPEL_BOOL, "estado.actual:" + DPEL_FLOAT, "estado.extra:" + DPEL_STRING,
                                          "bomba.presion:" + DPEL_FLOAT, "bomba2.segunda:" + DPEL_INT)));
  oaUnitAssertTrue(MODULO + "-C1.3-registro-con-jerarquia", dpExists("_IotClase_" + MOTOR + "-" + BOMBA + "-" + DOBLE));

  escribir("Mala", makeDynString("#uses \"" + CARPETA + "/Motor\"", "class " + MALA + " : " + MOTOR, "{",
                                 "  //@dp:comandos", "  protected int run2;", "  //@end",
                                 "  //@dp:estado", "  protected float actual;", "  //@end", "};"));
  oaUnitAssertEqual(MODULO + "-C1.3-ruta-repetida-con-antepasado", generar("Mala", plan), IOT_ENGCORE_ERR_PLAN, plan.errores);

  // C7 y C8: añadir en el padre llega a hija y nieta, y conserva valores
  oaUnitAssertEqual(MODULO + "-C1.7-setup-dp", dpCreate(DP_BOMBA, BOMBA), 0);
  oaUnitAssertEqual(MODULO + "-C1.7-setup-valor", dpSetWait(DP_BOMBA + ".comandos.run", true), 0);
  escribirMotor(makeDynString("  protected bool run;", "  protected int horas;"), true);
  oaUnitAssertEqual(MODULO + "-C1.8-plan", planificar("Motor", plan), IOT_ENGCORE_OK, plan.errores);
  oaUnitAssertEqual(MODULO + "-C1.8-propaga-a-hija-y-nieta", plan.clases, makeDynString(MOTOR, BOMBA, DOBLE));
  oaUnitAssertEqual(MODULO + "-C1.8-aplica", iot_applyDptPlan(plan), IOT_ENGCORE_OK);
  oaUnitAssertTrue(MODULO + "-C1.8-propaga-nieta-dpt", mappingHasKey(hojas(DOBLE), "comandos.horas"));
  bool run;
  dpGet(DP_BOMBA + ".comandos.run", run);
  oaUnitAssertTrue(MODULO + "-C1.7-anade-conserva-valores", run);

  // C7: quitar en el padre se planifica en toda la descendencia con los DPs afectados, y se aplica
  escribirMotor(makeDynString("  protected bool run;", "  protected int horas;"), false);
  oaUnitAssertEqual(MODULO + "-C1.7-plan-borrados", planificar("Motor", plan), IOT_ENGCORE_OK, plan.errores);
  oaUnitAssertEqual(MODULO + "-C1.7-plan-lista-borrados-y-dps", plan.eliminaciones,
                    makeDynString(MOTOR + ": estado.extra", BOMBA + ": estado.extra", DOBLE + ": estado.extra"));
  oaUnitAssertEqual(MODULO + "-C1.7-plan-dps-afectados", mappingHasKey(plan.dpsAfectados, BOMBA) ? plan.dpsAfectados[BOMBA] : -1, 1);
  oaUnitAssertEqual(MODULO + "-C1.7-aplica", iot_applyDptPlan(plan), IOT_ENGCORE_OK);
  oaUnitAssertTrue(MODULO + "-C1.7-aplica-borrados", !mappingHasKey(hojas(BOMBA), "estado.extra") && !dpExists(DP_BOMBA + ".estado.extra"));

  // C8: un choque en una descendiente impide aplicar nada
  escribir("Motor", makeDynString("#uses \"classes/iot/IotDpObject\"", "class " + MOTOR + " : IotDpObject", "{",
                                  "  //@dp:bomba", "  protected float presion;", "  //@end", "};"));
  oaUnitAssertEqual(MODULO + "-C1.8-error-en-hija-no-aplica-nada", planificar("Motor", plan), IOT_ENGCORE_ERR_PLAN, plan.errores);
  oaUnitAssertEqual(MODULO + "-C1.8-error-en-hija-rechaza-aplicar", iot_applyDptPlan(plan), IOT_ENGCORE_ERR_PLAN);
  oaUnitAssertTrue(MODULO + "-C1.8-error-en-hija-dpt-intacto", !mappingHasKey(hojas(MOTOR), "bomba.presion"));
}

string carpeta()
{
  return getPath(LIBS_REL_PATH) + CARPETA;
}

string fichero(string nombre)
{
  return carpeta() + "/" + nombre + ".ctl";
}

void escribir(string nombre, dyn_string lineas)
{
  file f = fopen(fichero(nombre), "w");
  fputs(strjoin(lineas, "\n") + "\n", f);
  fclose(f);
}

/** Motor con las propiedades de comandos indicadas; conExtra añade estado.extra (mapping). */
void escribirMotor(dyn_string comandos, bool conExtra)
{
  dyn_string lineas = makeDynString("#uses \"classes/iot/IotDpObject\"", "class " + MOTOR + " : IotDpObject", "{",
                                    "  //@dp:comandos");
  dynAppend(lineas, comandos);
  dynAppend(lineas, makeDynString("  //@end", "  //@dp:estado", "  protected float actual;"));
  if (conExtra)
    dynAppend(lineas, "  protected mapping extra;");
  dynAppend(lineas, makeDynString("  //@end", "};"));
  escribir("Motor", lineas);
}

int planificar(string nombre, IotDptPlan &plan)
{
  return iot_planDptFromFile(fichero(nombre), plan);
}

/** Planifica y, si no hay errores, aplica. */
int generar(string nombre, IotDptPlan &plan)
{
  int resultado = planificar(nombre, plan);
  return resultado == IOT_ENGCORE_OK ? iot_applyDptPlan(plan) : resultado;
}

/** Estructura del DPT como lista ordenada "ruta:tipo": oaUnitAssertEqual no compara mappings. */
dyn_string estructura(string dpt)
{
  mapping mapa = hojas(dpt);
  dyn_string lista;
  for (int i = 1; i <= mappinglen(mapa); i++)
    dynAppend(lista, mappingGetKey(mapa, i) + ":" + mappingGetValue(mapa, i));
  return ordenar(lista);
}

dyn_string ordenar(dyn_string lista)
{
  dynSort(lista);
  return lista;
}

mapping hojas(string dpt)
{
  dyn_dyn_string elementos;
  dyn_dyn_int tipos;
  if (dynlen(dpTypes(dpt)) == 0 || dpTypeGet(dpt, elementos, tipos) != 0)
    return makeMapping();
  return _iot_getDptHojas(elementos, tipos);
}

/**
  @return Número de DPs, DPs de registro, DPT y ficheros de prueba que no se han podido borrar.
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
  if (isdir(carpeta()) && !rmdir(carpeta(), true))
    noBorrados++;
  return noBorrados;
}

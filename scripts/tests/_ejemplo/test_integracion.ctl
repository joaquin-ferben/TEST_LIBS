/**
  @file     test_integracion.ctl
  @brief    Ejemplo de test de integración con un DP _TEST_ y CtrlOaUnit.

  Los criterios C1/C2 de _ejemplo son ilustrativos: no hay spec detrás.
*/
#uses "CtrlOaUnit"

const string MODULO = "_ejemplo";
const string DPT_PRUEBA = "ExampleDP_Float";
const string DP_VALOR = "_TEST_" + MODULO + "_valor";
const dyn_string DPS_PRUEBA = makeDynString(DP_VALOR);
const float VALOR_ESCRITO = 12.5;

main(string resultFile = "")
{
  if (resultFile == "")
    resultFile = getPath(LOG_REL_PATH) + "oaUnit_" + MODULO + "_integracion.txt";
  oaUnitSetup(resultFile, makeMapping("UserData", makeMapping("TestSuiteId", MODULO, "TestType", "Integration")));

  borrarDpsPrueba();  // restos de una ejecución anterior interrumpida
  try
  {
    oaUnitAssertEqual(MODULO + "-C2-crear-dp", dpCreate(DP_VALOR, DPT_PRUEBA), 0);
    oaUnitAssertTrue(MODULO + "-C2-dp-existe", dpExists(DP_VALOR));

    float valorLeido;
    oaUnitAssertEqual(MODULO + "-C2-escribir", dpSetWait(DP_VALOR + ".", VALOR_ESCRITO), 0);
    oaUnitAssertEqual(MODULO + "-C2-leer", dpGet(DP_VALOR + ".", valorLeido), 0);
    oaUnitAssertEqualDelta(MODULO + "-C2-escribir-leer", valorLeido, VALOR_ESCRITO, 0.000001);
  }
  catch
  {
    oaUnitAbort(MODULO + "-excepcion-integracion", getLastException());
  }
  oaUnitAssertEqual(MODULO + "-C2-limpieza", borrarDpsPrueba(), 0);
  exit(0);
}

/**
  @return Número de DPs de prueba que no se han podido borrar.
*/
int borrarDpsPrueba()
{
  int noBorrados = 0;
  for (int i = 1; i <= dynlen(DPS_PRUEBA); i++)
  {
    if (dpExists(DPS_PRUEBA[i]) && (dpDelete(DPS_PRUEBA[i]) != 0 || dpExists(DPS_PRUEBA[i])))
      noBorrados++;
  }
  return noBorrados;
}

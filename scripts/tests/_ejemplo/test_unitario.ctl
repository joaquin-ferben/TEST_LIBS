/**
  @file     test_unitario.ctl
  @brief    Ejemplo de test unitario (sin DPs) con CtrlOaUnit.
*/
#uses "CtrlOaUnit"

const string MODULO = "_ejemplo";

main(string resultFile = "")
{
  if (resultFile == "")
    resultFile = getPath(LOG_REL_PATH) + "oaUnit_" + MODULO + "_unitario.txt";
  oaUnitSetup(resultFile, makeMapping("UserData", makeMapping("TestSuiteId", MODULO, "TestType", "Unit")));

  try
  {
    oaUnitAssertEqual(MODULO + "-C1-strsplit-cuenta-campos", dynlen(strsplit("a;b;c", ";")), 3);
    oaUnitAssertEqual(MODULO + "-C1-strpos-no-encontrado", strpos("ABC", "X"), -1);
    // Los float se comparan con margen, nunca con AssertEqual
    oaUnitAssertEqualDelta(MODULO + "-C1-suma-float", 0.1 + 0.2, 0.3, 0.000001);
  }
  catch
  {
    oaUnitAbort(MODULO + "-excepcion-unitario", getLastException());
  }
  exit(0);
}

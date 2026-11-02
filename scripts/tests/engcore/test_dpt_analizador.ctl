/**
  @file     test_dpt_analizador.ctl
  @brief    Tests unitarios del analizador de engcore (spec 002.1, criterios C1.1 y C1.2). Solo texto, sin DPs.
*/
#uses "CtrlOaUnit"
#uses "iot/engcore/iot_engcore_dpt"

const string MODULO = "engcore";

main(string resultFile = "")
{
  if (resultFile == "")
    resultFile = getPath(LOG_REL_PATH) + "oaUnit_" + MODULO + "_analizador.txt";
  oaUnitSetup(resultFile, makeMapping("UserData", makeMapping("TestSuiteId", MODULO, "TestType", "Unit")));

  try
  {
    probarClaseCorrecta();
    probarErrores();
  }
  catch
  {
    oaUnitAbort(MODULO + "-excepcion-analizador", getLastException());
  }
  exit(0);
}

string unir(dyn_string lineas)
{
  return strjoin(lineas, "\n");
}

void probarClaseCorrecta()
{
  string texto = unir(makeDynString(
    "#uses \"classes/iot/IotDpObject\"",           // 1
    "class _TEST_engcore_Motor : IotDpObject",       // 2
    "{",                                            // 3
    "  //@dp:",                                     // 4
    "  protected string descripcion;",              // 5
    "  //@end",                                     // 6
    "  //@dp:comandos",                             // 7
    "  protected bool run;  // marcha",             // 8
    "  protected bool stop;",                       // 9
    "  //@end",                                     // 10
    "",                                             // 11
    "  //@dp:estado.velocidad",                     // 12
    "  protected float actual;",                    // 13
    "",                                             // 14
    "  protected mapping extra;",                   // 15
    "  //@end",                                     // 16
    "  int contadorInterno;",                       // 17
    "  public int metodo() { return 1; }",          // 18
    "};"));                                         // 19

  vector<IotDptClase> clases;
  dyn_string errores;
  oaUnitAssertEqual(MODULO + "-C1.1-resultado", iot_parseDptClases(texto, clases, errores), IOT_ENGCORE_OK, errores);
  oaUnitAssertEqual(MODULO + "-C1.1-una-clase", clases.count(), 1);
  if (clases.count() != 1)
    return;

  IotDptClase clase = clases.at(0);
  dyn_string rutas, tipos;
  dyn_int lineas;
  for (int i = 0; i < clase.propiedades.count(); i++)
  {
    dynAppend(rutas, clase.propiedades.at(i).ruta);
    dynAppend(tipos, clase.propiedades.at(i).tipo);
    dynAppend(lineas, clase.propiedades.at(i).linea);
  }
  oaUnitAssertEqual(MODULO + "-C1.1-nombre-y-padre", clase.nombre + ":" + clase.padre, "_TEST_engcore_Motor:IotDpObject");
  oaUnitAssertEqual(MODULO + "-C1.1-bloques-y-rutas", rutas,
                    makeDynString("descripcion", "comandos.run", "comandos.stop", "estado.velocidad.actual", "estado.velocidad.extra"));
  oaUnitAssertEqual(MODULO + "-C1.1-tipos-y-lineas", tipos, makeDynString("string", "bool", "bool", "float", "mapping"));
  oaUnitAssertEqual(MODULO + "-C1.1-tipos-y-lineas-linea", lineas, makeDynInt(5, 8, 9, 13, 15));
  oaUnitAssertEqual(MODULO + "-C1.1-ignora-sin-decorar", clase.propiedades.count(), 5);
}

/** Cada caso: líneas del cuerpo de la clase (empiezan en la línea 3) y líneas esperadas de los errores. */
void probarErrores()
{
  comprobarError("C1.2-bloque-sin-cerrar", makeDynString("  //@dp:a", "  protected int x;"), makeDynInt(3));
  comprobarError("C1.2-bloque-anidado", makeDynString("  //@dp:a", "  //@dp:b", "  protected int x;", "  //@end"), makeDynInt(4));
  comprobarError("C1.2-end-sin-abrir", makeDynString("  //@end"), makeDynInt(3));
  comprobarError("C1.2-inicializador", makeDynString("  //@dp:a", "  protected int x = 3;", "  //@end"), makeDynInt(4));
  comprobarError("C1.2-sin-protected", makeDynString("  //@dp:a", "  int x;", "  public int y;", "  private int z;", "  //@end"),
                 makeDynInt(4, 5, 6));
  comprobarError("C1.2-tipo-no-admitido", makeDynString("  //@dp:a", "  protected blob b;", "  //@end"), makeDynInt(4));
  comprobarError("C1.2-ruta-repetida", makeDynString("  //@dp:a", "  protected int x;", "  //@end", "  //@dp:a", "  protected float x;", "  //@end"),
                 makeDynInt(7));
  comprobarError("C1.2-ruta-invalida", makeDynString("  //@dp:a..b", "  protected int x;", "  //@end"), makeDynInt(3));
  comprobarError("C1.2-decorador-desconocido", makeDynString("  //@dpx:a"), makeDynInt(3));
}

void comprobarError(string caso, dyn_string cuerpo, dyn_int lineasEsperadas)
{
  dyn_string lineas = makeDynString("class _TEST_engcore_Error : IotDpObject", "{");
  dynAppend(lineas, cuerpo);
  dynAppend(lineas, "};");

  vector<IotDptClase> clases;
  dyn_string errores;
  int resultado = iot_parseDptClases(unir(lineas), clases, errores);

  dyn_int lineasObtenidas;
  for (int i = 1; i <= dynlen(errores); i++)
    dynAppend(lineasObtenidas, (int)substr(errores[i], 0, strpos(errores[i], ":")));
  oaUnitAssertEqual(MODULO + "-" + caso, lineasObtenidas, lineasEsperadas, errores);
  oaUnitAssertEqual(MODULO + "-" + caso + "-resultado", resultado, IOT_ENGCORE_ERR_PLAN);
}

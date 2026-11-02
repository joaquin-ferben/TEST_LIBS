/**
  @file     test_lectura_escritura.ctl
  @brief    Tests de integración del módulo dpobj (spec 002.1, criterio C1.5; spec 002.2, criterio C2.1; spec 002.3, criterio C3.7).

  Monta a mano los DPT, los DPs y el registro de dos clases de prueba (sin engcore) y los borra al terminar.
*/
#uses "CtrlOaUnit"
#uses "classes/iot/IotDpObject"

const string MODULO = "dpobj";
const string CLASE_MOTOR = "_TEST_dpobj_Motor";
const string CLASE_BOMBA = "_TEST_dpobj_Bomba";
const string CLASE_OTRO_PADRE = "_TEST_dpobj_Base";
const string DP_MOTOR = "_TEST_dpobj_motor1";
const string DP_BOMBA = "_TEST_dpobj_bomba1";
const string CLASE_SIN_REGISTRO = "_TEST_dpobj_SinRegistro";
const dyn_string DPS_PRUEBA = makeDynString(DP_MOTOR, DP_BOMBA);
const dyn_string DPTS_PRUEBA = makeDynString(CLASE_BOMBA, CLASE_MOTOR);  // hijas antes que padres
const float VALOR_ACTUAL = 12.5;

// Accesores escritos a mano con la misma forma que los generados por engcore: dpobj no depende de engcore
class _TEST_dpobj_Motor : IotDpObject
{
  public _TEST_dpobj_Motor(string dp = "") : IotDpObject(dp) {}
  public string getDescripcion() { return (string)_getDp("descripcion"); }
  public int setDescripcion(string valor) { return _setDp("descripcion", valor); }
  public bool getRun() { return (bool)_getDp("run"); }
  public mapping getExtra() { return (mapping)_getDp("extra"); }
  public int setExtra(mapping valor) { return _setDp("extra", valor); }
  protected string descripcion;
  protected bool run;
  protected float actual;
  protected mapping extra;
};

class _TEST_dpobj_Bomba : _TEST_dpobj_Motor
{
  public _TEST_dpobj_Bomba(string dp = "") : _TEST_dpobj_Motor(dp) {}
  public float getPresion() { return (float)_getDp("presion"); }
  protected float presion;
};

class _TEST_dpobj_SinRegistro : IotDpObject
{
  public _TEST_dpobj_SinRegistro(string dp = "") : IotDpObject(dp) {}
  public bool getRun() { return (bool)_getDp("run"); }
  protected bool run;
};

main(string resultFile = "")
{
  if (resultFile == "")
    resultFile = getPath(LOG_REL_PATH) + "oaUnit_" + MODULO + "_lectura_escritura.txt";
  oaUnitSetup(resultFile, makeMapping("UserData", makeMapping("TestSuiteId", MODULO, "TestType", "Integration")));

  borrarDatosPrueba();  // restos de una ejecución anterior interrumpida
  try
  {
    oaUnitAssertTrue(MODULO + "-setup", crearDatosPrueba());
    probarRegistro();
    probarAccesoAlDp();
    probarErrores();
    probarBorradoRegistro();
  }
  catch
  {
    oaUnitAbort(MODULO + "-excepcion-lectura-escritura", getLastException());
  }
  oaUnitAssertEqual(MODULO + "-limpieza", borrarDatosPrueba(), 0);
  exit(0);
}

/** C1.5: registro con la jerarquía en el nombre y el mapa en JSON. */
void probarRegistro()
{
  oaUnitAssertTrue(MODULO + "-C1.5-nombre-con-jerarquia", dpExists("_IotClase_" + CLASE_MOTOR + "-" + CLASE_BOMBA));
  mapping mapa;
  oaUnitAssertEqual(MODULO + "-C1.5-mapa-json-resultado", iot_getDpObjMapa(CLASE_BOMBA, mapa), IOT_DPOBJ_OK);
  oaUnitAssertEqual(MODULO + "-C1.5-mapa-json", mappingHasKey(mapa, "presion") ? mapa["presion"]["ruta"] : "", "bomba.presion");
  oaUnitAssertEqual(MODULO + "-C1.5-mapa-json-clase", mappingHasKey(mapa, "run") ? mapa["run"]["clase"] : "", CLASE_MOTOR);
  dyn_string descendientes;
  iot_getDpObjDescendientes(CLASE_MOTOR, descendientes);
  oaUnitAssertEqual(MODULO + "-C1.5-descendientes", descendientes, makeDynString(CLASE_BOMBA));

  // Si cambia la jerarquía, el DP de registro se renombra
  oaUnitAssertEqual(MODULO + "-C1.5-renombra-resultado",
                    iot_setDpObjRegistro(makeDynString(CLASE_OTRO_PADRE, CLASE_MOTOR, CLASE_BOMBA), mapaBomba()), IOT_DPOBJ_OK);
  oaUnitAssertTrue(MODULO + "-C1.5-renombra-si-cambia-jerarquia",
                   dpExists("_IotClase_" + CLASE_OTRO_PADRE + "-" + CLASE_MOTOR + "-" + CLASE_BOMBA)
                   && !dpExists("_IotClase_" + CLASE_MOTOR + "-" + CLASE_BOMBA));
  iot_setDpObjRegistro(makeDynString(CLASE_MOTOR, CLASE_BOMBA), mapaBomba());  // se deja como estaba
}

/** C2.1: cada get lee el DP en ese momento y cada set lo escribe al momento. */
void probarAccesoAlDp()
{
  _TEST_dpobj_Motor motor = _TEST_dpobj_Motor(DP_MOTOR);

  dpSetWait(DP_MOTOR + ".descripcion", "fuente externa 1");
  oaUnitAssertEqual(MODULO + "-C2.1-get-lee-dp-actual", motor.getDescripcion(), "fuente externa 1");
  dpSetWait(DP_MOTOR + ".descripcion", "fuente externa 2");
  oaUnitAssertEqual(MODULO + "-C2.1-get-lee-dp-actual-tras-cambio", motor.getDescripcion(), "fuente externa 2");

  oaUnitAssertEqual(MODULO + "-C2.1-set-escribe-al-momento-resultado", motor.setDescripcion("escrito"), IOT_DPOBJ_OK);
  string descripcion;
  dpGet(DP_MOTOR + ".descripcion", descripcion);
  oaUnitAssertEqual(MODULO + "-C2.1-set-escribe-al-momento", descripcion, "escrito");

  // Varias propiedades en una llamada
  oaUnitAssertEqual(MODULO + "-C2.1-varios-set",
                    motor.setVarios(makeMapping("descripcion", "varios", "run", true, "actual", VALOR_ACTUAL)), IOT_DPOBJ_OK);
  mapping valores;
  oaUnitAssertEqual(MODULO + "-C2.1-varios-get", motor.getVarios(makeDynString("descripcion", "run", "actual"), valores), IOT_DPOBJ_OK);
  oaUnitAssertEqual(MODULO + "-C2.1-varios",
                    makeDynString(valores["descripcion"], valores["run"] ? "true" : "false", (string)valores["actual"]),
                    makeDynString("varios", "true", (string)VALOR_ACTUAL));

  // Heredadas: la bomba lee run (del motor) y su propia presión
  dpSetWait(DP_BOMBA + ".comandos.run", true, DP_BOMBA + ".bomba.presion", 3.5);
  _TEST_dpobj_Bomba bomba = _TEST_dpobj_Bomba(DP_BOMBA);
  oaUnitAssertTrue(MODULO + "-C2.1-heredadas", bomba.getRun());
  oaUnitAssertEqualDelta(MODULO + "-C2.1-heredadas-propia", bomba.getPresion(), 3.5, 0.000001);
  oaUnitAssertEqual(MODULO + "-C2.1-heredadas-varios", bomba.getVarios(makeDynString("run", "presion"), valores), IOT_DPOBJ_OK);

  // mapping: JSON en el DPE en los dos sentidos
  oaUnitAssertEqual(MODULO + "-C2.1-mapping-json-set", motor.setExtra(makeMapping("b", "dos")), IOT_DPOBJ_OK);
  string extra;
  dpGet(DP_MOTOR + ".estado.extra", extra);
  oaUnitAssertEqual(MODULO + "-C2.1-mapping-json", extra, jsonEncode(makeMapping("b", "dos")));
  dpSetWait(DP_MOTOR + ".estado.extra", "{\"a\":1}");
  mapping extraLeido = motor.getExtra();
  oaUnitAssertEqual(MODULO + "-C2.1-mapping-json-get", mappingHasKey(extraLeido, "a") ? (int)extraLeido["a"] : -1, 1);
}

/** C2.1: propiedad inexistente, clase sin registro y objeto sin DP. */
void probarErrores()
{
  _TEST_dpobj_Motor motor = _TEST_dpobj_Motor(DP_MOTOR);
  motor.setDescripcion("antes");
  mapping valores;
  oaUnitAssertEqual(MODULO + "-C2.1-propiedad-inexistente", motor.getVarios(makeDynString("descripcion", "zz"), valores),
                    IOT_DPOBJ_ERR_PROPIEDAD);
  oaUnitAssertEqual(MODULO + "-C2.1-propiedad-inexistente-set", motor.setVarios(makeMapping("descripcion", "no", "zz", 1)),
                    IOT_DPOBJ_ERR_PROPIEDAD);
  oaUnitAssertEqual(MODULO + "-C2.1-propiedad-inexistente-no-escribe", motor.getDescripcion(), "antes");

  _TEST_dpobj_SinRegistro sinRegistro = _TEST_dpobj_SinRegistro(DP_MOTOR);
  oaUnitAssertEqual(MODULO + "-C2.1-sin-registro", sinRegistro.getVarios(makeDynString("run"), valores), IOT_DPOBJ_ERR_REGISTRO);
  oaUnitAssertFalse(MODULO + "-C2.1-sin-registro-get-por-defecto", sinRegistro.getRun());

  _TEST_dpobj_Motor sinDp = _TEST_dpobj_Motor("_TEST_dpobj_no_existe");
  oaUnitAssertEqual(MODULO + "-C2.1-sin-dp", sinDp.setDescripcion("x"), IOT_DPOBJ_ERR_DP);
  oaUnitAssertEqual(MODULO + "-C2.1-sin-dp-get-por-defecto", sinDp.getDescripcion(), "");
}

/** C3.7: borrar el registro de una clase, empezando por la hoja, y de una clase sin registro. */
void probarBorradoRegistro()
{
  oaUnitAssertEqual(MODULO + "-C3.7-borra-registro-resultado", iot_deleteDpObjRegistro(CLASE_BOMBA), IOT_DPOBJ_OK);
  oaUnitAssertFalse(MODULO + "-C3.7-borra-registro", dpExists("_IotClase_" + CLASE_MOTOR + "-" + CLASE_BOMBA));
  dyn_string descendientes;
  iot_getDpObjDescendientes(CLASE_MOTOR, descendientes);
  oaUnitAssertEqual(MODULO + "-C3.7-borra-registro-sin-descendiente", dynlen(descendientes), 0);
  oaUnitAssertTrue(MODULO + "-C3.7-borra-registro-padre-intacto", dpExists("_IotClase_" + CLASE_MOTOR));
  oaUnitAssertEqual(MODULO + "-C3.7-borrar-sin-registro", iot_deleteDpObjRegistro(CLASE_SIN_REGISTRO), IOT_DPOBJ_ERR_REGISTRO);
}

mapping entrada(string ruta, string tipo, string clase)
{
  return makeMapping("ruta", ruta, "tipo", tipo, "clase", clase);
}

mapping mapaMotor()
{
  return makeMapping("descripcion", entrada("descripcion", "string", CLASE_MOTOR),
                     "run", entrada("comandos.run", "bool", CLASE_MOTOR),
                     "actual", entrada("estado.actual", "float", CLASE_MOTOR),
                     "extra", entrada("estado.extra", "mapping", CLASE_MOTOR));
}

mapping mapaBomba()
{
  mapping mapa = mapaMotor();
  mapa["presion"] = entrada("bomba.presion", "float", CLASE_BOMBA);
  return mapa;
}

/** DPT del motor; con bomba = true añade el struct bomba.presion. */
bool crearDpt(string nombre, bool conBomba)
{
  dyn_dyn_string elementos;
  dyn_dyn_int tipos;
  elementos[1] = makeDynString(nombre, "", "");
  elementos[2] = makeDynString("", "descripcion", "");
  elementos[3] = makeDynString("", "comandos", "");
  elementos[4] = makeDynString("", "", "run");
  elementos[5] = makeDynString("", "estado", "");
  elementos[6] = makeDynString("", "", "actual");
  elementos[7] = makeDynString("", "", "extra");
  tipos[1] = makeDynInt(DPEL_STRUCT);
  tipos[2] = makeDynInt(0, DPEL_STRING);
  tipos[3] = makeDynInt(0, DPEL_STRUCT);
  tipos[4] = makeDynInt(0, 0, DPEL_BOOL);
  tipos[5] = makeDynInt(0, DPEL_STRUCT);
  tipos[6] = makeDynInt(0, 0, DPEL_FLOAT);
  tipos[7] = makeDynInt(0, 0, DPEL_STRING);
  if (conBomba)
  {
    elementos[8] = makeDynString("", "bomba", "");
    elementos[9] = makeDynString("", "", "presion");
    tipos[8] = makeDynInt(0, DPEL_STRUCT);
    tipos[9] = makeDynInt(0, 0, DPEL_FLOAT);
  }
  return dpTypeCreate(elementos, tipos) == 0;
}

bool crearDatosPrueba()
{
  return crearDpt(CLASE_MOTOR, false)
         && crearDpt(CLASE_BOMBA, true)
         && dpCreate(DP_MOTOR, CLASE_MOTOR) == 0
         && dpCreate(DP_BOMBA, CLASE_BOMBA) == 0
         && iot_setDpObjRegistro(makeDynString(CLASE_MOTOR), mapaMotor()) == IOT_DPOBJ_OK
         && iot_setDpObjRegistro(makeDynString(CLASE_MOTOR, CLASE_BOMBA), mapaBomba()) == IOT_DPOBJ_OK;
}

/**
  @return Número de DPs, DPs de registro y DPT de prueba que no se han podido borrar.
*/
int borrarDatosPrueba()
{
  int noBorrados = 0;
  dyn_string dps = DPS_PRUEBA;
  dynAppend(dps, dpNames("_IotClase_*_TEST_dpobj_*"));
  for (int i = 1; i <= dynlen(dps); i++)
  {
    if (dpExists(dps[i]) && (dpDelete(dps[i]) != 0 || dpExists(dps[i])))
      noBorrados++;
  }
  for (int i = 1; i <= dynlen(DPTS_PRUEBA); i++)
  {
    if (dynlen(dpTypes(DPTS_PRUEBA[i])) > 0 && dpTypeDelete(DPTS_PRUEBA[i]) != 0)
      noBorrados++;
  }
  return noBorrados;
}

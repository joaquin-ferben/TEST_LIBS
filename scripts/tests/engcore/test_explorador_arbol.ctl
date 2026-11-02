/**
  @file     test_explorador_arbol.ctl
  @brief    Tests unitarios del explorador de engcore (spec 002.3, criterios C3.2 y C3.6 a C3.9): árbol, nombres,
            plantilla y reglas de las acciones. Sin DPs ni ficheros.
*/
#uses "CtrlOaUnit"
#uses "iot/engcore/iot_engcore_explorador"

const string MODULO = "engcore";
const string CARPETA = "classes/_TEST_engcore/";
const string RAIZ = "IotDpObject";
const string MOTOR = "_TEST_engcore_Motor";       // proyecto, hija de la raíz
const string BOMBA = "_TEST_engcore_Bomba";       // proyecto, hija del motor
const string BASE = "_TEST_engcore_Base";         // librería, hija de la raíz
const string VALVULA = "_TEST_engcore_Valvula";   // librería, hija de la base
const string SUELTA = "_TEST_engcore_Suelta";     // sin padre: no es una clase con DP
const string HUERFANA = "_TEST_engcore_Huerfana"; // su padre no existe

main(string resultFile = "")
{
  if (resultFile == "")
    resultFile = getPath(LOG_REL_PATH) + "oaUnit_" + MODULO + "_explorador_arbol.txt";
  oaUnitSetup(resultFile, makeMapping("UserData", makeMapping("TestSuiteId", MODULO, "TestType", "Unit")));

  try
  {
    probarArbol();
    probarAcciones();
    probarNombre();
    probarPlantilla();
    probarReglas();
  }
  catch
  {
    oaUnitAbort(MODULO + "-excepcion-explorador-arbol", getLastException());
  }
  exit(0);
}

IotExploradorClase clase(string nombre, string padre, bool enProyecto)
{
  IotExploradorClase resultado;
  resultado.nombre = nombre;
  resultado.padre = padre;
  resultado.ruta = (nombre == RAIZ ? "classes/iot/" : CARPETA) + nombre + ".ctl";
  resultado.fichero = resultado.ruta;
  resultado.enProyecto = enProyecto;
  resultado.ficheros = makeDynString(resultado.ruta);
  return resultado;
}

/** Árbol de ejemplo: raíz > motor (proyecto) > bomba (proyecto); raíz > base (librería) > válvula (librería). */
vector<IotExploradorClase> todas()
{
  vector<IotExploradorClase> lista;
  lista.append(clase(BOMBA, MOTOR, true));
  lista.append(clase(VALVULA, BASE, false));
  lista.append(clase(SUELTA, "", true));
  lista.append(clase(MOTOR, RAIZ, true));
  lista.append(clase(HUERFANA, "_TEST_engcore_NoExiste", true));
  lista.append(clase(RAIZ, "", false));
  lista.append(clase(BASE, RAIZ, false));
  return lista;
}

vector<IotExploradorClase> arbol()
{
  vector<IotExploradorClase> lista = todas();
  vector<IotExploradorClase> resultado;
  dyn_string errores;
  iot_buildExploradorArbol(lista, resultado, errores);
  return resultado;
}

dyn_string nombres(vector<IotExploradorClase> &lista)
{
  dyn_string resultado;
  for (int i = 0; i < lista.count(); i++)
    dynAppend(resultado, lista.at(i).nombre);
  return resultado;
}

/** C3.2: desde IotDpObject, cada hija bajo su padre; fuera las que no llegan a la raíz. */
void probarArbol()
{
  vector<IotExploradorClase> lista = todas();
  vector<IotExploradorClase> resultado;
  dyn_string errores;
  oaUnitAssertEqual(MODULO + "-C3.2-arbol-de-herencia-resultado", iot_buildExploradorArbol(lista, resultado, errores), IOT_ENGCORE_OK);
  // Recorrido en profundidad, hermanas por orden alfabético: _TEST_engcore_Base va antes que _TEST_engcore_Motor
  oaUnitAssertEqual(MODULO + "-C3.2-arbol-de-herencia", nombres(resultado), makeDynString(RAIZ, BASE, VALVULA, MOTOR, BOMBA));

  lista.append(clase(MOTOR, RAIZ, false));
  oaUnitAssertEqual(MODULO + "-C3.2-clase-repetida", iot_buildExploradorArbol(lista, resultado, errores), IOT_ENGCORE_ERR_PLAN);
  oaUnitAssertEqual(MODULO + "-C3.2-clase-repetida-errores", dynlen(errores), 1);

  vector<IotExploradorClase> sinRaiz;
  sinRaiz.append(clase(MOTOR, RAIZ, true));
  dynClear(errores);
  iot_buildExploradorArbol(sinRaiz, resultado, errores);
  oaUnitAssertEqual(MODULO + "-C3.2-sin-raiz-vacio", resultado.count(), 0);
}

/** C3.9: el menú solo ofrece las acciones válidas. */
void probarAcciones()
{
  vector<IotExploradorClase> lista = arbol();
  oaUnitAssertEqual(MODULO + "-C3.9-acciones-validas-raiz", iot_getExploradorAcciones(RAIZ, lista),
                    makeDynString(IOT_ENGCORE_ACCION_CREAR));
  oaUnitAssertEqual(MODULO + "-C3.9-acciones-validas", iot_getExploradorAcciones(MOTOR, lista),
                    makeDynString(IOT_ENGCORE_ACCION_CREAR, IOT_ENGCORE_ACCION_BORRAR, IOT_ENGCORE_ACCION_A_LIBRERIA));
  oaUnitAssertEqual(MODULO + "-C3.9-acciones-validas-hoja-libreria", iot_getExploradorAcciones(VALVULA, lista),
                    makeDynString(IOT_ENGCORE_ACCION_CREAR, IOT_ENGCORE_ACCION_BORRAR, IOT_ENGCORE_ACCION_A_PROYECTO));
  oaUnitAssertEqual(MODULO + "-C3.9-acciones-validas-fuera-del-arbol", dynlen(iot_getExploradorAcciones(SUELTA, lista)), 0);
}

/** C3.6: identificador válido y sin otra clase con ese nombre. */
void probarNombre()
{
  vector<IotExploradorClase> lista = arbol();
  dyn_string errores;
  oaUnitAssertEqual(MODULO + "-C3.6-valida-nombre", iot_checkExploradorNombre("_TEST_engcore_Nueva", lista, errores), IOT_ENGCORE_OK);
  oaUnitAssertEqual(MODULO + "-C3.6-valida-nombre-digito", iot_checkExploradorNombre("1Nueva", lista, errores), IOT_ENGCORE_ERR_NOMBRE);
  oaUnitAssertEqual(MODULO + "-C3.6-valida-nombre-guion", iot_checkExploradorNombre("Nueva-2", lista, errores), IOT_ENGCORE_ERR_NOMBRE);
  oaUnitAssertEqual(MODULO + "-C3.6-valida-nombre-vacio", iot_checkExploradorNombre("", lista, errores), IOT_ENGCORE_ERR_NOMBRE);
  oaUnitAssertEqual(MODULO + "-C3.6-valida-nombre-existe", iot_checkExploradorNombre(BOMBA, lista, errores), IOT_ENGCORE_ERR_NOMBRE);
  oaUnitAssertEqual(MODULO + "-C3.6-valida-nombre-motivo", dynlen(errores), 1);
}

/** C3.6: #uses del padre, clase con constructor y bloque //@dp: vacío, que el analizador acepta. */
void probarPlantilla()
{
  dyn_string lineas = iot_buildExploradorPlantilla("_TEST_engcore_Nueva", clase(MOTOR, RAIZ, true));
  oaUnitAssertTrue(MODULO + "-C3.6-plantilla-con-uses-y-bloque-uses",
                   dynContains(lineas, "#uses \"classes/_TEST_engcore/" + MOTOR + "\"") > 0);
  oaUnitAssertTrue(MODULO + "-C3.6-plantilla-con-uses-y-bloque-constructor",
                   dynContains(lineas, "  public _TEST_engcore_Nueva(string dp = \"\") : " + MOTOR + "(dp) {}") > 0);
  int inicio = dynContains(lineas, "  //@dp:");
  oaUnitAssertTrue(MODULO + "-C3.6-plantilla-con-uses-y-bloque", inicio > 0 && dynContains(lineas, "  //@end") == inicio + 1);

  vector<IotDptClase> clases;
  dyn_string errores;
  oaUnitAssertEqual(MODULO + "-C3.6-plantilla-analizable", iot_parseDptClases(strjoin(lineas, "\n"), clases, errores), IOT_ENGCORE_OK);
  oaUnitAssertEqual(MODULO + "-C3.6-plantilla-clase-y-padre", clases.count() == 1 ? clases.at(0).nombre + ":" + clases.at(0).padre : "",
                    "_TEST_engcore_Nueva:" + MOTOR);
}

/** C3.7 y C3.8: IotDpObject no se borra; la librería no puede depender del proyecto. */
void probarReglas()
{
  vector<IotExploradorClase> lista = arbol();
  IotExploradorBorrado plan;
  oaUnitAssertEqual(MODULO + "-C3.7-raiz-no-se-borra", iot_planExploradorBorrado(RAIZ, lista, plan), IOT_ENGCORE_ERR_PLAN);
  oaUnitAssertEqual(MODULO + "-C3.7-raiz-no-se-borra-plan-vacio", dynlen(plan.clases), 0);

  // La bomba (proyecto) no sube: su padre, el motor, está en el proyecto. El motor sí, sus antepasados están en la librería
  string destino;
  dyn_string errores;
  oaUnitAssertEqual(MODULO + "-C3.8-no-sube-si-padre-en-proyecto", iot_moveExploradorClase(BOMBA, lista, destino, errores),
                    IOT_ENGCORE_ERR_PLAN);
  oaUnitAssertTrue(MODULO + "-C3.8-no-sube-si-padre-en-proyecto-menu",
                   dynContains(iot_getExploradorAcciones(BOMBA, lista), IOT_ENGCORE_ACCION_A_LIBRERIA) < 1);
  oaUnitAssertTrue(MODULO + "-C3.8-sube-si-antepasados-en-libreria",
                   dynContains(iot_getExploradorAcciones(MOTOR, lista), IOT_ENGCORE_ACCION_A_LIBRERIA) > 0);

  // La base (librería) no baja: su hija, la válvula, está en la librería
  oaUnitAssertEqual(MODULO + "-C3.8-no-baja-si-hija-en-libreria", iot_moveExploradorClase(BASE, lista, destino, errores),
                    IOT_ENGCORE_ERR_PLAN);
  oaUnitAssertTrue(MODULO + "-C3.8-no-baja-si-hija-en-libreria-menu",
                   dynContains(iot_getExploradorAcciones(BASE, lista), IOT_ENGCORE_ACCION_A_PROYECTO) < 1);
  oaUnitAssertEqual(MODULO + "-C3.8-raiz-no-se-mueve", iot_moveExploradorClase(RAIZ, lista, destino, errores), IOT_ENGCORE_ERR_PLAN);
  oaUnitAssertEqual(MODULO + "-C3.8-sin-mover-sin-destino", destino, "");
}

/**
  @file     iot_engcore_comun.ctl
  @brief    Área común de engcore: catálogo, códigos de resultado y diálogo propio que comparten las demás áreas.
  @author   TEST_LIBS

  Solo para ingeniería (Script Editor, paneles de ingeniería y tests), no se carga en runtime.
  Documento del módulo: dev/modulos/engcore.md (en TEST_CLAUDE).
*/

const string IOT_ENGCORE_CATALOGO     = "iot_engcore";
const string IOT_ENGCORE_FLAG         = "iot_engcore";

const int IOT_ENGCORE_OK          = 0;
const int IOT_ENGCORE_ERR_PLAN    = -1;   // errores de sintaxis, decoradores o herencia: ver plan.errores
const int IOT_ENGCORE_ERR_FICHERO = -2;
const int IOT_ENGCORE_ERR_DPT     = -3;
const int IOT_ENGCORE_ERR_REGISTRO = -4;
const int IOT_ENGCORE_ERR_NOMBRE   = -5;   // nombre de clase no válido o ya usado
const int IOT_ENGCORE_ERR_DP       = -6;

// Diálogo de la extensión del Script Editor (spec 002, D5): ventana propia y variables globales del manager
const string IOT_ENGCORE_PANEL_DIALOGO  = "iot/engcore/iot_engcore_dialogo.xml";
const string IOT_ENGCORE_MODULO_DIALOGO = "IotEngcoreDialogo";
const string IOT_ENGCORE_VAR_MODO       = "g_iotEngcoreModo";
const string IOT_ENGCORE_VAR_TEXTO      = "g_iotEngcoreTexto";
const string IOT_ENGCORE_VAR_LISTA      = "g_iotEngcoreLista";
const string IOT_ENGCORE_VAR_RESPUESTA  = "g_iotEngcoreRespuesta";
const string IOT_ENGCORE_MODO_AVISO     = "aviso";       // un botón Aceptar
const string IOT_ENGCORE_MODO_CONFIRMAR = "confirmar";   // Sí / No
const int    IOT_ENGCORE_RESPUESTA_NINGUNA = 0;          // cerrado con la X
const int    IOT_ENGCORE_RESPUESTA_SI      = 1;
const int    IOT_ENGCORE_RESPUESTA_NO      = 2;

// Códigos de 5 cifras del catálogo, para makeError
const int IOT_ENGCORE_MSG_DPT      = 1;
const int IOT_ENGCORE_MSG_REGISTRO = 2;
const int IOT_ENGCORE_MSG_EXPLORADOR = 3;

/** Texto del catálogo con $1 y $2 sustituidos. Lo usa también la extensión del Script Editor. */
string iot_getEngcoreTexto(string clave, string p1 = "", string p2 = "", string p3 = "")
{
  string texto = getCatStr(IOT_ENGCORE_CATALOGO, clave);
  strreplace(texto, "$1", p1);
  strreplace(texto, "$2", p2);
  strreplace(texto, "$3", p3);
  return texto;
}

/** Registra el error con throwError() y devuelve el código para propagarlo. */
int _iot_logEngcoreError(int codigo, int mensaje, string elemento)
{
  throwError(makeError(IOT_ENGCORE_CATALOGO, PRIO_WARNING, ERR_CONTROL, mensaje, elemento));
  return codigo;
}

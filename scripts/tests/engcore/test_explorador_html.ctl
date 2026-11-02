/**
  @file     test_explorador_html.ctl
  @brief    Tests unitarios de la vista previa coloreada del explorador de engcore (spec 002.3, criterio C3.4). Solo texto.
*/
#uses "CtrlOaUnit"
#uses "iot/engcore/iot_engcore_explorador"

const string MODULO = "engcore";

main(string resultFile = "")
{
  if (resultFile == "")
    resultFile = getPath(LOG_REL_PATH) + "oaUnit_" + MODULO + "_explorador_html.txt";
  oaUnitSetup(resultFile, makeMapping("UserData", makeMapping("TestSuiteId", MODULO, "TestType", "Unit")));

  try
  {
    probarPalabras();
    probarDecoradores();
    probarEscape();
  }
  catch
  {
    oaUnitAbort(MODULO + "-excepcion-explorador-html", getLastException());
  }
  exit(0);
}

string span(string texto, string estilo)
{
  return "<span style=\"" + estilo + "\">" + texto + "</span>";
}

bool contiene(string html, string trozo)
{
  return strpos(html, trozo) >= 0;
}

/** C3.4: palabras clave, tipos, comentarios y cadenas, cada uno con su estilo. */
void probarPalabras()
{
  string html = iot_formatExploradorHtml(strjoin(makeDynString(
    "#uses \"classes/iot/IotDpObject\"",
    "class A : IotDpObject",
    "{",
    "  public dyn_string lista() { return makeDynString(\"x\"); }  // comentario",
    "  /* bloque",
    "     int dentro; */ int fuera;",
    "};"), "\n"));

  oaUnitAssertTrue(MODULO + "-C3.4-colorea-palabras-clave", contiene(html, span("class", IOT_ENGCORE_EXP_ESTILO_PALABRA))
                   && contiene(html, span("public", IOT_ENGCORE_EXP_ESTILO_PALABRA))
                   && contiene(html, span("#uses", IOT_ENGCORE_EXP_ESTILO_PALABRA)));
  oaUnitAssertTrue(MODULO + "-C3.4-colorea-tipos", contiene(html, span("dyn_string", IOT_ENGCORE_EXP_ESTILO_TIPO))
                   && contiene(html, span("int", IOT_ENGCORE_EXP_ESTILO_TIPO) + " fuera;"));
  oaUnitAssertTrue(MODULO + "-C3.4-colorea-cadenas", contiene(html, span("\"x\"", IOT_ENGCORE_EXP_ESTILO_CADENA))
                   && contiene(html, span("\"classes/iot/IotDpObject\"", IOT_ENGCORE_EXP_ESTILO_CADENA)));
  oaUnitAssertTrue(MODULO + "-C3.4-colorea-comentarios", contiene(html, span("// comentario", IOT_ENGCORE_EXP_ESTILO_COMENTARIO))
                   && contiene(html, span("/* bloque", IOT_ENGCORE_EXP_ESTILO_COMENTARIO))
                   && contiene(html, span("     int dentro; */", IOT_ENGCORE_EXP_ESTILO_COMENTARIO)));
  oaUnitAssertTrue(MODULO + "-C3.4-identificadores-sin-color", contiene(html, " A : IotDpObject"));
  oaUnitAssertTrue(MODULO + "-C3.4-monoespaciada", strpos(html, "<pre style=\"" + IOT_ENGCORE_EXP_ESTILO_PRE + "\">") == 0);
}

/** C3.4: //@dp: y //@end destacados; el bloque //@generado, con fondo propio. */
void probarDecoradores()
{
  string html = iot_formatExploradorHtml(strjoin(makeDynString(
    "  //@dp:comandos",
    "  protected bool run;",
    "  //@end",
    "",
    "  //@generado: no editar",
    "  public bool getRun() { return (bool)_getDp(\"run\"); }",
    "  //@fin-generado",
    "  int otra;"), "\n"));

  oaUnitAssertTrue(MODULO + "-C3.4-destaca-decoradores", contiene(html, span("  //@dp:comandos", IOT_ENGCORE_EXP_ESTILO_DECORADOR))
                   && contiene(html, span("  //@end", IOT_ENGCORE_EXP_ESTILO_DECORADOR))
                   && contiene(html, span("  //@generado: no editar", IOT_ENGCORE_EXP_ESTILO_DECORADOR))
                   && contiene(html, span("  //@fin-generado", IOT_ENGCORE_EXP_ESTILO_DECORADOR)));
  oaUnitAssertTrue(MODULO + "-C3.4-destaca-bloque-generado",
                   contiene(html, "<span style=\"" + IOT_ENGCORE_EXP_ESTILO_GENERADO + "\">  " + span("public", IOT_ENGCORE_EXP_ESTILO_PALABRA)));
  // Fuera del bloque generado no hay fondo
  oaUnitAssertTrue(MODULO + "-C3.4-fuera-del-bloque-sin-fondo",
                   contiene(html, "\n  " + span("int", IOT_ENGCORE_EXP_ESTILO_TIPO) + " otra;"));
  oaUnitAssertTrue(MODULO + "-C3.4-decorador-protected-normal", contiene(html, "\n  " + span("protected", IOT_ENGCORE_EXP_ESTILO_PALABRA)));
}

/** C3.4: <, > y & se escapan, también dentro de cadenas y comentarios. */
void probarEscape()
{
  string html = iot_formatExploradorHtml("if (a < b && c > d) x = \"<b>\"; // a<b & c");
  oaUnitAssertTrue(MODULO + "-C3.4-escapa-html", contiene(html, "a &lt; b &amp;&amp; c &gt; d"));
  oaUnitAssertTrue(MODULO + "-C3.4-escapa-html-cadena", contiene(html, span("\"&lt;b&gt;\"", IOT_ENGCORE_EXP_ESTILO_CADENA)));
  oaUnitAssertTrue(MODULO + "-C3.4-escapa-html-comentario", contiene(html, span("// a&lt;b &amp; c", IOT_ENGCORE_EXP_ESTILO_COMENTARIO)));
  oaUnitAssertFalse(MODULO + "-C3.4-escapa-html-sin-etiquetas-sueltas", contiene(html, "<b>"));
}

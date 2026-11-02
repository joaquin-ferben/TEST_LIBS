/**
  @file     IotDpObject.ctl
  @brief    Clase raíz de las clases con DP: lee y escribe sus propiedades decoradas siempre contra su DP.
  @author   TEST_LIBS

  Las propiedades decoradas de las hijas solo declaran el esquema (nombre y tipo del DPE): no guardan valores.
  Los getters y setters tipados de cada clase los genera engcore en su bloque //@generado.
  El mapa propiedad -> DPE de cada clase lo genera engcore en el registro de dpobj.
  Documento del módulo: dev/modulos/dpobj.md (en TEST_CLAUDE).
*/
#uses "iot/dpobj/iot_dpobj"

class IotDpObject
{
  /**
    @brief  Crea el objeto asociado a un DP.
    @param  dp  DP del objeto. Puede asignarse después con setDp().
  */
  public IotDpObject(string dp = "")
  {
    _dp = dp;
  }

  public void setDp(string dp)
  {
    _dp = dp;
  }

  public string getDp()
  {
    return _dp;
  }

  /**
    @brief  Lee del DP, en ese momento, varias propiedades (heredadas incluidas) con un solo dpGet.
    @param  propiedades  Nombres de las propiedades.
    @param  valores      Salida: propiedad -> valor. Una propiedad mapping se devuelve ya decodificada.
    @return IOT_DPOBJ_OK o el error de dpobj. Con error, valores queda vacío y el error queda en el log.
  */
  public int getVarios(dyn_string propiedades, mapping &valores)
  {
    return iot_getDpObjValores(getTypeName(this), _dp, propiedades, valores);
  }

  /**
    @brief  Escribe en el DP, al momento, varias propiedades (heredadas incluidas) con un solo dpSetWait.
            Si una propiedad no existe no se escribe ninguna.
    @param  valores  Propiedad -> valor.
    @return IOT_DPOBJ_OK o el error de dpobj.
  */
  public int setVarios(mapping valores)
  {
    return iot_setDpObjValores(getTypeName(this), _dp, valores);
  }

  /**
    @brief  Lee una propiedad del DP en ese momento. La usan los getters generados.
    @return El valor; con error, un anytype vacío, que el getter convierte al valor por defecto de su tipo.
  */
  protected anytype _getDp(string propiedad)
  {
    mapping valores;
    anytype valor;
    if (getVarios(makeDynString(propiedad), valores) == IOT_DPOBJ_OK)
      valor = valores[propiedad];
    return valor;
  }

  /**
    @brief  Escribe una propiedad en el DP al momento. La usan los setters generados.
    @return IOT_DPOBJ_OK o el error de dpobj.
  */
  protected int _setDp(string propiedad, anytype valor)
  {
    return setVarios(makeMapping(propiedad, valor));
  }

  private string _dp;
};

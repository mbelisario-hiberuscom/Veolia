/**
 * @name FWCCAL_ControllerClassInterface
 * @version 1.0
 * @creation date 31/10/2025
 * @author Jesus Piriz
 * @description Interfaz para las clases que serán invocadas desde el LWC del FWCCAL
 */
public interface FWCCAL_ControllerClassInterface {
	/**
	 * @name getEvents
	 * @version 1.0
	 * @creation date 31/10/2025
	 * @author Jesus Piriz
	 * @description Método que ejecutará la consulta de registros a mostrar.
	 * @param pastMonths Número de meses hacia atrás a consultar
	 * @param futureMonths Número de meses hacia adelante a consultar
	 * @param rangeFrequency Frecuencia de rango (Mensual, Trimestral, Semestral, Anual)
	 * @param eventLimit Límite de eventos a consultar
	 * @param whatId Id del What (Objeto relacionado) a filtrar
	 * @param whoId Id del Who (Contacto o Lead relacionado) a filtrar
	 * @param ownerId Id del propietario de los registros a filtrar
	 * @param recordId Id del registro desde el que se invoca el FWCCAL
	 * @param startDateTimeOrder Orden de los eventos por fecha de inicio (ASC o DESC)
	 * @param referenceDate Fecha de referencia del mes visible en el calendario
	 * @return String
	 * @exception N/A
	 * @throws N/A
	 */
	String getEvents(
		Integer pastMonths,
		Integer futureMonths,
		String rangeFrequency,
		Integer eventLimit,
		String whatId,
		String whoId,
		String ownerId,
		String recordId,
		String startDateTimeOrder,
		String referenceDate
	);
}
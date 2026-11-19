/**
 * @name FWCCAL_CustomCalendarController
 * @version 1.0
 * @creation date 31/10/2025
 * @author Jesus Piriz
 * @description Clase controladora del componente FWCCAL
 */
public with sharing class FWCCAL_CustomCalendarController {
	/**
	 * @name: getEvents
	 * @version 1.0
	 * @creation date 31/10/2025
	 * @author Jesus Piriz
	 * @description Método que ejecutará la consulta de registros a mostrar.
	 * @param controllerClass Nombre de la clase que implementa la interfaz FWCCAL_ControllerClassInterface
	 * @param pastMonths Número de meses hacia atrás a consultar
	 * @param futureMonths Número de meses hacia adelante a consultar
	 * @param eventLimit Límite de eventos a consultar
	 * @param whatId Id del What (Objeto relacionado) a filtrar
	 * @param whoId Id del Who (Contacto o Lead relacionado) a filtrar
	 * @param ownerId Id del propietario de los registros a filtrar
	 * @param recordId Id del registro desde el que se invoca el FWCCAL
	 * @param referenceDate Fecha de referencia del mes visible en el calendario
	 * @return String
	 * @exception N/A
	 * @throws N/A
	 */
	@AuraEnabled
	public static String getEvents(
		String controllerClass,
		Integer pastMonths,
		Integer futureMonths,
		Integer eventLimit,
		String whatId,
		String whoId,
		String ownerId,
		String recordId,
		String referenceDate
	) {
		Type projectClassType = Type.forName(controllerClass);
		FWCCAL_ControllerClassInterface projectClass = (FWCCAL_ControllerClassInterface) projectClassType.newInstance();
		return projectClass.getEvents(pastMonths, futureMonths, 'MONTH', eventLimit, whatId, whoId, ownerId, recordId, 'ASC', referenceDate);
	}

	/**
	 * @name: getEventsWithFrequency
	 * @version 1.0
	 * @creation date 31/10/2025
	 * @author Jesus Piriz
	 * @description Método que ejecutará la consulta de registros a mostrar.
	 * @param controllerClass Nombre de la clase que implementa la interfaz FWCCAL_ControllerClassInterface
	 * @param pastMonths Número de meses hacia atrás a consultar
	 * @param futureMonths Número de meses hacia adelante a consultar
	 * @param rangeFrequency Frecuencia de rango (Mensual, Trimestral, Semestral, Anual)
	 * @param eventLimit Límite de eventos a consultar
	 * @param whatId Id del What (Objeto relacionado) a filtrar
	 * @param whoId Id del Who (Contacto o Lead relacionado) a filtrar
	 * @param ownerId Id del propietario de los registros a filtrar
	 * @param recordId Id del registro desde el que se invoca el FWCCAL
	 * @param referenceDate Fecha de referencia del mes visible en el calendario
	 * @return String
	 * @exception N/A
	 * @throws N/A
	 */
	@AuraEnabled
	public static String getEventsWithFrequency(
		String controllerClass,
		Integer pastMonths,
		Integer futureMonths,
		String rangeFrequency,
		Integer eventLimit,
		String whatId,
		String whoId,
		String ownerId,
		String recordId,
		String referenceDate
	) {
		Type projectClassType = Type.forName(controllerClass);
		FWCCAL_ControllerClassInterface projectClass = (FWCCAL_ControllerClassInterface) projectClassType.newInstance();
		return projectClass.getEvents(
			pastMonths,
			futureMonths,
			rangeFrequency,
			eventLimit,
			whatId,
			whoId,
			ownerId,
			recordId,
			'ASC',
			referenceDate
		);
	}

	/**
	 * @name: getUpcomingEvents
	 * @version 1.0
	 * @creation date 31/10/2025
	 * @author Jesus Piriz
	 * @description Método que ejecutará la consulta de registros a mostrar.
	 * @param controllerClass Nombre de la clase que implementa la interfaz FWCCAL_ControllerClassInterface
	 * @param eventLimit Límite de eventos a consultar
	 * @param whatId Id del What (Objeto relacionado) a filtrar
	 * @param whoId Id del Who (Contacto o Lead relacionado) a filtrar
	 * @param ownerId Id del propietario de los registros a filtrar
	 * @param recordId Id del registro desde el que se invoca el FWCCAL
	 * @return String
	 * @exception N/A
	 * @throws N/A
	 */
	@AuraEnabled
	public static String getUpcomingEvents(
		String controllerClass,
		Integer eventLimit,
		String whatId,
		String whoId,
		String ownerId,
		String recordId
	) {
		Type projectClassType = Type.forName(controllerClass);
		FWCCAL_ControllerClassInterface projectClass = (FWCCAL_ControllerClassInterface) projectClassType.newInstance();
		return projectClass.getEvents(0, 0, 'MONTH', eventLimit, whatId, whoId, ownerId, recordId, 'ASC', null);
	}
}
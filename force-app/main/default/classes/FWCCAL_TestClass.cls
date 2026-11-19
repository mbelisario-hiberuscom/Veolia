/**
 * @name FWCCAL_TestClass
 * @version 1.0
 * @creation date 31/10/2025
 * @author Jesus Piriz
 * @description Clase para pruebas unitarias que implementa la interfaz FWCCAL_ControllerClassInterface
 */
public with sharing class FWCCAL_TestClass implements FWCCAL_ControllerClassInterface {
	/**
	 * @name: getEvents
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
	public String getEvents(
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
	) {
		Map<String, Object> resultMap = new Map<String, Object>();
		Map<Id, FWCCAL_EventData> eventsDataMap = new Map<Id, FWCCAL_EventData>();

		for (Event recordSObject : [
			SELECT Id, IsAllDayEvent, ActivityDate, Description, EndDateTime, Location, StartDateTime, Subject, Type
			FROM Event
			LIMIT 1
		]) {
			FWCCAL_EventData eventData = new FWCCAL_EventData();
			eventData.id = recordSObject.Id;
			eventData.title = recordSObject.Type;
			eventData.subtitleText = recordSObject.Type;
			eventData.subtitleTextLocal = recordSObject.Type;
			eventData.type = recordSObject.Type;
			eventData.iconName = 'utility:event';
			eventData.startDateTime = recordSObject.StartDateTime.format();
			eventData.endDateTime = recordSObject.EndDateTime.format();
			eventData.allDay = recordSObject.IsAllDayEvent;
			eventData.description = recordSObject.Description;
			eventData.shortDescription = recordSObject.Description;
			eventData.eventURL = '/' + recordSObject.Id;
			eventData.eventURLText = 'Ver evento';
			eventData.eventURLTarget = '_blank';
			eventData.eventURL2 = '/' + recordSObject.Id;
			eventData.eventURLText2 = 'Ver evento';
			eventData.eventURLTarget2 = '_blank';
			eventData.eventImageURL = '/' + recordSObject.Id;
			eventData.detailsURL = '/' + recordSObject.Id;
			eventData.rendering = '';
			eventData.backgroundColor = '#FFFFFF';
			eventData.borderColor = '#FFFFFF';
			eventData.textColor = '#FFFFFF';
			eventData.editable = false;
			eventData.location = recordSObject.Location;

			eventsDataMap.put(eventData.id, eventData);
		}

		resultMap.put('eventsMap', eventsDataMap);
		resultMap.put('timezoneList', new List<String>{ 'America/New_York', 'Europe/Madrid' });
		resultMap.put('siteUrl', System.Site.getBaseUrl());

		return System.JSON.serialize(resultMap);
	}
}
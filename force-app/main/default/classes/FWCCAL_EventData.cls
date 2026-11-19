/**
 * @name FWCCAL_EventData
 * @version 1.0
 * @creation date 31/10/2025
 * @author Jesus Piriz
 * @description Clase para almacenar los datos de los eventos que se mostrarán en el FW
 **/
public with sharing class FWCCAL_EventData {
	/**
	 * @name id
	 * @description id del evento
	 * @type String
	 **/
	@AuraEnabled
	public String id { get; set; }

	/**
	 * @name title
	 * @description Titulo del evento
	 * @type String
	 **/
	@AuraEnabled
	public String title { get; set; }

	/**
	 * @name subtitleText
	 * @description Subtitulo del evento
	 * @type String
	 **/
	@AuraEnabled
	public String subtitleText { get; set; }

	/**
	 * @name subtitleTextLocal
	 * @description Subtitulo del evento. Hora en formato local
	 * @type String
	 **/
	@AuraEnabled
	public String subtitleTextLocal { get; set; }

	/**
	 * @name type
	 * @description Tipo del evento
	 * @type String
	 **/
	@AuraEnabled
	public String type { get; set; }

	/**
	 * @name iconName
	 * @description Icono del evento
	 * @type String
	 **/
	@AuraEnabled
	public String iconName { get; set; }

	/**
	 * @name startDateTime
	 * @description Fecha de inicio del evento
	 * @type String
	 **/
	@AuraEnabled
	public String startDateTime { get; set; }

	/**
	 * @name endDateTime
	 * @description Fecha de fin del evento
	 * @type String
	 **/
	@AuraEnabled
	public String endDateTime { get; set; }

	/**
	 * @name allDay
	 * @description Flag que indica si el evento es de todo el dia o no
	 * @type Boolean
	 **/
	@AuraEnabled
	public Boolean allDay { get; set; }

	/**
	 * @name description
	 * @description Descripción del evento
	 * @type String
	 **/
	@AuraEnabled
	public String description { get; set; }

	/**
	 * @name shortDescription
	 * @description Descripción corta del evento
	 * @type String
	 **/
	@AuraEnabled
	public String shortDescription { get; set; }

	/**
	 * @name eventURL
	 * @description URL del evento
	 * @type String
	 **/
	@AuraEnabled
	public String eventURL { get; set; }

	/**
	 * @name eventURLText
	 * @description Texto del enlace al evento
	 * @type String
	 **/
	@AuraEnabled
	public String eventURLText { get; set; }

	/**
	 * @name eventURLTarget
	 * @description Target del enlace al evento
	 * @type String
	 **/
	@AuraEnabled
	public String eventURLTarget { get; set; }

	/**
	 * @name eventURL2
	 * @description URL2 del evento
	 * @type String
	 **/
	@AuraEnabled
	public String eventURL2 { get; set; }

	/**
	 * @name eventURLText2
	 * @description Texto 2 del enlace al evento
	 * @type String
	 **/
	@AuraEnabled
	public String eventURLText2 { get; set; }

	/**
	 * @name eventURLTarget2
	 * @description Target 2 del enlace al evento
	 * @type String
	 **/
	@AuraEnabled
	public String eventURLTarget2 { get; set; }

	/**
	 * @name eventImageURL
	 * @description URL de la imagen del evento
	 * @type String
	 **/
	@AuraEnabled
	public String eventImageURL { get; set; }

	@AuraEnabled
	/**
	 * @name detailsURL
	 * @description URL de los detalles del evento
	 * @type String
	 **/
	public String detailsURL { get; set; }

	@AuraEnabled
	/**
	 * @name rendering
	 * @description Tipo de renderizado del evento
	 * @type String
	 **/
	public String rendering { get; set; }

	/**
	 * @name backgroundColor
	 * @description Background color del evento
	 * @type String
	 **/
	@AuraEnabled
	public String backgroundColor { get; set; }

	/**
	 * @name borderColor
	 * @description Border color del evento
	 * @type String
	 **/
	@AuraEnabled
	public String borderColor { get; set; }

	/**
	 * @name textColor
	 * @description Text color del evento
	 * @type String
	 **/
	@AuraEnabled
	public String textColor { get; set; }

	/**
	 * @name color
	 * @description Color unificado del evento (FullCalendar v7: sustituye a backgroundColor + borderColor)
	 * @type String
	 **/
	@AuraEnabled
	public String color { get; set; }

	/**
	 * @name contrastColor
	 * @description Color de contraste del texto del evento (FullCalendar v7: sustituye a textColor)
	 * @type String
	 **/
	@AuraEnabled
	public String contrastColor { get; set; }

	/**
	 * @name editable
	 * @description Indica si el evento se puede editar o no
	 * @type Boolean
	 **/
	@AuraEnabled
	public Boolean editable { get; set; }

	/**
	 * @name location
	 * @description Location del evento
	 * @type String
	 **/
	@AuraEnabled
	public String location { get; set; }
}
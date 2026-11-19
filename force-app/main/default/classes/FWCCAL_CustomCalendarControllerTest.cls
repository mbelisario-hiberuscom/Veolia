/**
 * @name FWCCAL_CustomCalendarControllerTest
 * @version 1.0
 * @creation date 31/10/2025
 * @author Jesus Piriz
 * @description Clase de test para la clase controladora FWCCAL_CustomCalendarController
 */
@IsTest
public with sharing class FWCCAL_CustomCalendarControllerTest {
	private static final String TEST_CLASS = 'FWCCAL_TestClass';

	/**
	 * @name: initialSetup
	 * @creation date: 31/10/2025
	 * @author: Jesus Piriz
	 * @description Método de setup para la creación de datos de prueba.
	 */
	@TestSetup
	static void initialSetup() {
		Account acc = new Account();
		if (Schema.sObjectType.Account.fields.Name.isCreateable() && Schema.sObjectType.Account.isCreateable()) {
			acc = VL_TestDataFactory.createAccount('test Account', null);
		}

		Contact con = VL_TestDataFactory.createContact('First Contact', acc, 'first@example.com');

		Event ev = new Event();
		if (
			Schema.sObjectType.Event.fields.Subject.isCreateable() &&
			Schema.sObjectType.Event.fields.WhoId.isCreateable() &&
			Schema.sObjectType.Event.fields.WhatId.isCreateable() &&
			Schema.sObjectType.Event.fields.OwnerId.isCreateable() &&
			Schema.sObjectType.Event.fields.StartDateTime.isCreateable() &&
			Schema.sObjectType.Event.fields.EndDateTime.isCreateable() &&
			Schema.sObjectType.Event.isCreateable()
		) {
			ev.Subject = 'test';
			ev.WhoId = con.Id;
			ev.WhatId = acc.Id;
			ev.OwnerId = System.UserInfo.getUserId();
			ev.StartDateTime = system.today();
			ev.EndDateTime = system.today();

			insert ev;
		}
	}

	/**
	 * @name: getEventsTest
	 * @creation date: 31/10/2025
	 * @author: Jesus Piriz
	 * @description Método para testear el metodo getEvents de la clase FWCCAL_CustomCalendarController.
	 */
	@IsTest
	public static void getEventsTest() {
		System.assertEquals(true, Schema.sObjectType.Account.fields.Name.isAccessible() && Schema.sObjectType.Account.isAccessible());
		System.assertEquals(
			true,
			Schema.sObjectType.Contact.fields.FirstName.isAccessible() &&
				Schema.sObjectType.Contact.fields.LastName.isAccessible() &&
				Schema.sObjectType.Contact.isAccessible()
		);
		System.assertEquals(true, Schema.sObjectType.Event.fields.Subject.isAccessible() && Schema.sObjectType.Event.isAccessible());

		Account acc = [SELECT Id FROM Account WHERE Name = 'test' LIMIT 1];
		Contact con = [SELECT Id FROM Contact WHERE FirstName = 'testF' AND LastName = 'testL' LIMIT 1];
		Event ev = [SELECT Id FROM Event WHERE Subject = 'test' LIMIT 1];

		String eventJSON;

		Test.startTest();
		eventJSON = FWCCAL_CustomCalendarController.getEvents(
			TEST_CLASS,
			6,
			6,
			10,
			String.valueOf(acc.Id),
			String.valueOf(con.Id),
			String.valueOf(System.UserInfo.getUserId()),
			String.valueOf(ev.Id),
			null
		);
		Test.stopTest();

		Map<String, Object> eventObjectMap = (Map<String, Object>) System.JSON.deserializeUntyped(eventJSON);

		System.assertEquals(null, eventObjectMap.get('error'));
		System.assertNotEquals(null, eventObjectMap.get('eventsMap'));
		System.assertNotEquals(null, eventObjectMap.get('timezoneList'));
	}

	/**
	 * @name: getUpcomingEventsTest
	 * @creation date: 31/10/2025
	 * @author: Jesus Piriz
	 * @description Método para testear el metodo getUpcomingEvents de la clase FWCCAL_CustomCalendarController.
	 */
	@IsTest
	public static void getUpcomingEventsTest() {
		System.assertEquals(true, Schema.sObjectType.Account.fields.Name.isAccessible() && Schema.sObjectType.Account.isAccessible());
		System.assertEquals(
			true,
			Schema.sObjectType.Contact.fields.FirstName.isAccessible() &&
				Schema.sObjectType.Contact.fields.LastName.isAccessible() &&
				Schema.sObjectType.Contact.isAccessible()
		);
		System.assertEquals(true, Schema.sObjectType.Event.fields.Subject.isAccessible() && Schema.sObjectType.Event.isAccessible());

		Account acc = [SELECT Id FROM Account WHERE Name = 'test' LIMIT 1];
		Contact con = [SELECT Id FROM Contact WHERE FirstName = 'testF' AND LastName = 'testL' LIMIT 1];
		Event ev = [SELECT Id FROM Event WHERE Subject = 'test' LIMIT 1];

		String eventJSON;

		Test.startTest();
		eventJSON = FWCCAL_CustomCalendarController.getUpcomingEvents(TEST_CLASS, 10, acc.Id, con.Id, System.UserInfo.getUserId(), ev.Id);
		Test.stopTest();

		Map<String, Object> eventObjectMap = (Map<String, Object>) System.JSON.deserializeUntyped(eventJSON);

		System.assertEquals(null, eventObjectMap.get('error'));
		System.assertNotEquals(null, eventObjectMap.get('eventsMap'));
		System.assertNotEquals(null, eventObjectMap.get('timezoneList'));
	}

	/**
	 * @name: getEventsWithFrequencyTest
	 * @creation date: 31/10/2025
	 * @author: Jesus Piriz
	 * @description Método para testear el metodo getEventsWithFrequency de la clase FWCCAL_CustomCalendarController.
	 */
	@IsTest
	public static void getEventsWithFrequencyTest() {
		System.assertEquals(true, Schema.sObjectType.Account.fields.Name.isAccessible() && Schema.sObjectType.Account.isAccessible());
		System.assertEquals(
			true,
			Schema.sObjectType.Contact.fields.FirstName.isAccessible() &&
				Schema.sObjectType.Contact.fields.LastName.isAccessible() &&
				Schema.sObjectType.Contact.isAccessible()
		);
		System.assertEquals(true, Schema.sObjectType.Event.fields.Subject.isAccessible() && Schema.sObjectType.Event.isAccessible());

		Account acc = [SELECT Id FROM Account WHERE Name = 'test' LIMIT 1];
		Contact con = [SELECT Id FROM Contact WHERE FirstName = 'testF' AND LastName = 'testL' LIMIT 1];
		Event ev = [SELECT Id FROM Event WHERE Subject = 'test' LIMIT 1];

		String eventJSON;

		Test.startTest();
		eventJSON = FWCCAL_CustomCalendarController.getEventsWithFrequency(
			TEST_CLASS,
			0,
			1,
			'MONTH',
			10,
			String.valueOf(acc.Id),
			String.valueOf(con.Id),
			String.valueOf(System.UserInfo.getUserId()),
			String.valueOf(ev.Id),
			String.valueOf(Date.today())
		);
		Test.stopTest();

		Map<String, Object> eventObjectMap = (Map<String, Object>) System.JSON.deserializeUntyped(eventJSON);

		System.assertEquals(null, eventObjectMap.get('error'));
		System.assertNotEquals(null, eventObjectMap.get('eventsMap'));
		System.assertNotEquals(null, eventObjectMap.get('timezoneList'));
	}
}
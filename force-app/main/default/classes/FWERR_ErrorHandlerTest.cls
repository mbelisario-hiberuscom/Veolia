/**
 * @name FWERR_ErrorHandlerTest
 * @version 1.0
 * @creation date: 03/11/2025
 * @author: Jesus Piriz
 * @description Test class to test FWERR_ErrorHandler functionality
 **/
@IsTest
public with sharing class FWERR_ErrorHandlerTest {
	@TestSetup
	static void setupData() {
		VL_TestDataFactory.createSystemAdminTestUser();
	}

	/**
	 * @name: insertExceptionErrorTest
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Test method to test insertError when an exception occurs
	 */
	@IsTest
	public static void insertExceptionErrorTest() {
		System.runAs(VL_TestDataFactory.getSystemAdminTestUser()) {
			FWERR_ErrorHandler.throwExceptionTest = true;

			Test.startTest();
			try {
				Account a = new Account();
				a = null;
				insert a;
			} catch (Exception e) {
				//If there is an error we log the method and type of error
				FWERR_ErrorHandler.insertError(e);
			}

			Test.stopTest();
			List<FWERR_ErrorLog__c> lstErrors = [SELECT Id FROM FWERR_ErrorLog__c];
			System.assertEquals(1, lstErrors.size());
		}
	}

	/**
	 * @name: insertErrorTest
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Test the method insertError
	 */
	@IsTest
	public static void insertErrorTest() {
		System.runAs(VL_TestDataFactory.getSystemAdminTestUser()) {
			Test.startTest();
			try {
				Account a = new Account();
				a = null;
				insert a;
			} catch (Exception e) {
				//If there is an error we log the method and type of error
				FWERR_ErrorHandler.insertError(e);
			}

			Test.stopTest();
			List<FWERR_ErrorLog__c> lstErrors = [SELECT Id FROM FWERR_ErrorLog__c];
			System.assertEquals(1, lstErrors.size());
		}
	}

	/**
	 * @name: throwErrorsTest
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Test method to test throwErrors
	 */
	@IsTest
	public static void throwErrorsTest() {
		System.runAs(VL_TestDataFactory.getSystemAdminTestUser()) {
			FWERR_ErrorLog__c errorLog = new FWERR_ErrorLog__c();
			errorLog.FWERR_ClassTxt__c = 'TestClass';
			errorLog.FWERR_MethodTxt__c = 'TestMethod';
			errorLog.FWERR_MessageTxtArea__c = 'Test Message';
			errorLog.FWERR_StackTraceTxtArea__c = 'Test Stack Trace';

			List<FWERR_ErrorLog__c> lstErrors = new List<FWERR_ErrorLog__c>{ errorLog };

			Boolean hasException = false;

			try {
				Test.startTest();
				FWERR_ErrorHandler.throwErrors(lstErrors);
				Test.stopTest();
			} catch (Exception e) {
				hasException = true;
			}

			System.assertEquals(true, hasException);
		}
	}

	/**
	 * @name: insertErrorsHappyPathLogsAllErrors
	 * @creation date: 13/05/2026
	 * @author: Jesus Piriz
	 * @description Test that insertErrors bulk-inserts one log per exception
	 */
	@IsTest
	public static void insertErrorsHappyPathLogsAllErrors() {
		System.runAs(VL_TestDataFactory.getSystemAdminTestUser()) {
			List<Exception> exceptions = new List<Exception>{
				new FWERR_ErrorHandler.FWERR_CustomException('Bulk error 1'),
				new FWERR_ErrorHandler.FWERR_CustomException('Bulk error 2'),
				new FWERR_ErrorHandler.FWERR_CustomException('Bulk error 3')
			};

			Test.startTest();
			FWERR_ErrorHandler.insertErrors(exceptions);
			Test.stopTest();

			List<FWERR_ErrorLog__c> lstErrors = [SELECT Id FROM FWERR_ErrorLog__c];
			System.assertEquals(3, lstErrors.size(), 'Should log one record per exception');
		}
	}

	/**
	 * @name: insertErrorsThrowExceptionThrowsAndLogs
	 * @creation date: 13/05/2026
	 * @author: Jesus Piriz
	 * @description Test that insertErrors logs all errors and rethrows the first when throwException is true
	 */
	@IsTest
	public static void insertErrorsThrowExceptionThrowsAndLogs() {
		System.runAs(VL_TestDataFactory.getSystemAdminTestUser()) {
			List<Exception> exceptions = new List<Exception>{
				new FWERR_ErrorHandler.FWERR_CustomException('Error A'),
				new FWERR_ErrorHandler.FWERR_CustomException('Error B')
			};
			Boolean hasException = false;

			Test.startTest();
			try {
				FWERR_ErrorHandler.insertErrors(exceptions, true);
			} catch (Exception e) {
				hasException = true;
			}
			Test.stopTest();

			List<FWERR_ErrorLog__c> lstErrors = [SELECT Id FROM FWERR_ErrorLog__c];
			System.assertEquals(2, lstErrors.size(), 'Should log both errors before throwing');
			System.assertEquals(true, hasException, 'Should rethrow the first exception');
		}
	}

	/**
	 * @name: insertErrorsEmptyListNoLogs
	 * @creation date: 13/05/2026
	 * @author: Jesus Piriz
	 * @description Test that insertErrors is a no-op when the list is empty
	 */
	@IsTest
	public static void insertErrorsEmptyListNoLogs() {
		System.runAs(VL_TestDataFactory.getSystemAdminTestUser()) {
			Test.startTest();
			FWERR_ErrorHandler.insertErrors(new List<Exception>());
			Test.stopTest();

			List<FWERR_ErrorLog__c> lstErrors = [SELECT Id FROM FWERR_ErrorLog__c];
			System.assertEquals(0, lstErrors.size(), 'Empty list should produce no logs');
		}
	}

	/**
	 * @name: insertErrorsExceptionInDmlLogsHandlerError
	 * @creation date: 13/05/2026
	 * @author: Jesus Piriz
	 * @description Test that insertErrors catches a DML failure and logs a handler-level error
	 */
	@IsTest
	public static void insertErrorsExceptionInDmlLogsHandlerError() {
		System.runAs(VL_TestDataFactory.getSystemAdminTestUser()) {
			FWERR_ErrorHandler.throwExceptionTest = true;
			List<Exception> exceptions = new List<Exception>{ new FWERR_ErrorHandler.FWERR_CustomException('Error DML') };

			Test.startTest();
			FWERR_ErrorHandler.insertErrors(exceptions);
			Test.stopTest();

			List<FWERR_ErrorLog__c> lstErrors = [SELECT Id FROM FWERR_ErrorLog__c];
			System.assertEquals(1, lstErrors.size(), 'Should log the handler-level catch error');
		}
	}
}
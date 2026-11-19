/**
 * @name FWERR_ErrorHandler
 * @version 1.0
 * @creation date: 03/11/2025
 * @author: Jesus Piriz
 * @description Generic error handler class
 **/
public with sharing class FWERR_ErrorHandler {
	@TestVisible
	private static Boolean throwExceptionTest = false;

	private static final String LOGGED_EXCEPTION_HEADER = 'LoggedException: ';

	/**
	 * @name FWERR_CustomException
	 * @version 1.0
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Custom exception class
	 */
	public class FWERR_CustomException extends Exception {
	}

	/**
	 * @name: insertError
	 * @version 1.0
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Public method to insert error log
	 * @param e
	 */
	public static void insertError(Exception e) {
		errorSaveDataBase(e, false);
	}

	/**
	 * @name: insertError
	 * @version 1.0
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Public method to insert error log
	 * @param e
	 * @param throwException
	 */
	public static void insertError(Exception e, Boolean throwException) {
		errorSaveDataBase(e, throwException);
	}

	/**
	 * @name: throwErrors
	 * @version 1.0
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Invocable method to throw errors from a list of FWERR_ErrorLog__c records
	 * @param lstErrors
	 */
	@InvocableMethod(label='FWERR Throw Errors' description='FWERR Throw Errors')
	public static void throwErrors(List<FWERR_ErrorLog__c> lstErrors) {
		for (FWERR_ErrorLog__c error : lstErrors) {
			throw new FWERR_CustomException(
				'Error ' +
					error?.FWERR_StackTraceTxtArea__c +
					' in flow: ' +
					error?.FWERR_ClassTxt__c +
					'.' +
					error?.FWERR_MethodTxt__c +
					' Error:' +
					error?.FWERR_MessageTxtArea__c
			);
		}
	}

	/**
	 * @name: insertErrors
	 * @version 1.0
	 * @creation date: 13/05/2026
	 * @author: Jesus Piriz
	 * @description Public method to bulk-insert a list of error logs
	 * @param exceptions
	 */
	public static void insertErrors(List<Exception> exceptions) {
		errorsSaveDataBase(exceptions, false);
	}

	/**
	 * @name: insertErrors
	 * @version 1.0
	 * @creation date: 13/05/2026
	 * @author: Jesus Piriz
	 * @description Public method to bulk-insert a list of error logs
	 * @param exceptions
	 * @param throwException
	 */
	public static void insertErrors(List<Exception> exceptions, Boolean throwException) {
		errorsSaveDataBase(exceptions, throwException);
	}

	/**
	 * @name: insertError
	 * @version 1.0
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Private method to insert error log
	 * @param e
	 * @param throwException
	 */
	@TestVisible
	private static void errorSaveDataBase(Exception e, Boolean throwException) {
		String methodName = e.getStackTraceString().substringBefore(':').substringAfterLast('.');
		String className = e.getStackTraceString().substringBefore(':').substringBetween('.');
		String appCode = String.isNotBlank(className) ? className.substringBefore('_') : '';

		try {
			if (Test.isRunningTest() && throwExceptionTest) {
				throw new DMLException('FWERR_ErrorHandlerTest');
			}

			if (Schema.sObjectType.FWERR_ErrorLog__c.isCreateable()) {
				Database.insert(
					new FWERR_ErrorLog__c(
						FWERR_ApplicationCodeTxt__c = appCode,
						FWERR_Date__c = System.now(),
						FWERR_UserLookup__c = UserInfo.getUserId(),
						FWERR_ClassTxt__c = className,
						FWERR_MethodTxt__c = methodName,
						FWERR_MessageTxtArea__c = e.getMessage(),
						FWERR_StackTraceTxtArea__c = e.getStackTraceString()
					),
					AccessLevel.SYSTEM_MODE
				);
			}
		} catch (Exception ex) {
			if (Schema.sObjectType.FWERR_ErrorLog__c.isCreateable()) {
				Database.insert(
					new FWERR_ErrorLog__c(
						FWERR_ApplicationCodeTxt__c = FWERR_ErrorHandler.class.getName().substringBefore('_'),
						FWERR_Date__c = DateTime.now(),
						FWERR_UserLookup__c = UserInfo.getUserId(),
						FWERR_ClassTxt__c = ex.getStackTraceString().substringBefore(':').substringBetween('.'),
						FWERR_MethodTxt__c = ex.getStackTraceString().substringBefore(':').substringAfterLast('.'),
						FWERR_MessageTxtArea__c = ex.getMessage(),
						FWERR_StackTraceTxtArea__c = ex.getStackTraceString()
					),
					AccessLevel.SYSTEM_MODE
				);
			}
		}

		if (throwException) {
			e.setMessage(LOGGED_EXCEPTION_HEADER + (e.getMessage().length() < 18000 ? e.getMessage() : e.getMessage().substring(0, 18000)));
			throw e;
		}
	}

	/**
	 * @name: errorsSaveDataBase
	 * @version 1.0
	 * @creation date: 13/05/2026
	 * @author: Jesus Piriz
	 * @description Private method to bulk-insert a list of error logs in a single DML statement.
	 *              When throwException is true, the first exception in the list is rethrown after logging.
	 * @param exceptions
	 * @param throwException
	 */
	@TestVisible
	private static void errorsSaveDataBase(List<Exception> exceptions, Boolean throwException) {
		if (exceptions == null || exceptions.isEmpty()) {
			return;
		}

		List<FWERR_ErrorLog__c> errorLogs = new List<FWERR_ErrorLog__c>();
		for (Exception e : exceptions) {
			String methodName = e.getStackTraceString().substringBefore(':').substringAfterLast('.');
			String className = e.getStackTraceString().substringBefore(':').substringBetween('.');
			String appCode = String.isNotBlank(className) ? className.substringBefore('_') : '';

			errorLogs.add(
				new FWERR_ErrorLog__c(
					FWERR_ApplicationCodeTxt__c = appCode,
					FWERR_Date__c = System.now(),
					FWERR_UserLookup__c = UserInfo.getUserId(),
					FWERR_ClassTxt__c = className,
					FWERR_MethodTxt__c = methodName,
					FWERR_MessageTxtArea__c = e.getMessage(),
					FWERR_StackTraceTxtArea__c = e.getStackTraceString()
				)
			);
		}

		try {
			if (Test.isRunningTest() && throwExceptionTest) {
				throw new DMLException('FWERR_ErrorHandlerTest');
			}

			if (!errorLogs.isEmpty() && Schema.sObjectType.FWERR_ErrorLog__c.isCreateable()) {
				Database.insert(errorLogs, AccessLevel.SYSTEM_MODE);
			}
		} catch (Exception ex) {
			if (Schema.sObjectType.FWERR_ErrorLog__c.isCreateable()) {
				Database.insert(
					new FWERR_ErrorLog__c(
						FWERR_ApplicationCodeTxt__c = FWERR_ErrorHandler.class.getName().substringBefore('_'),
						FWERR_Date__c = DateTime.now(),
						FWERR_UserLookup__c = UserInfo.getUserId(),
						FWERR_ClassTxt__c = ex.getStackTraceString().substringBefore(':').substringBetween('.'),
						FWERR_MethodTxt__c = ex.getStackTraceString().substringBefore(':').substringAfterLast('.'),
						FWERR_MessageTxtArea__c = ex.getMessage(),
						FWERR_StackTraceTxtArea__c = ex.getStackTraceString()
					),
					AccessLevel.SYSTEM_MODE
				);
			}
		}

		if (throwException) {
			Exception first = exceptions[0];
			first.setMessage(
				LOGGED_EXCEPTION_HEADER + (first.getMessage().length() < 18000 ? first.getMessage() : first.getMessage().substring(0, 18000))
			);
			throw first;
		}
	}
}
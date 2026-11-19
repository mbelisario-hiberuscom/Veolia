/**
 * @name VL_GoogleDriveExceptionTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_GoogleDriveException error category classification and recovery detection.
 **/
@IsTest
private class VL_GoogleDriveExceptionTest {
	@TestSetup
	static void setupData() {
		VL_TestDataFactory.createGoogleDriveTestUser();
	}

	/**
	 * @name: recoverableCategoriesReturnTrue
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that RECOVERABLE_ categories return true from isRecoverable.
	 */
	@IsTest
	static void recoverableCategoriesReturnTrue() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveException quota = new VL_GoogleDriveException('quota', VL_GoogleDriveException.ErrorCategory.RECOVERABLE_QUOTA);
			VL_GoogleDriveException timeout = new VL_GoogleDriveException(
				'timeout',
				VL_GoogleDriveException.ErrorCategory.RECOVERABLE_TIMEOUT
			);
			VL_GoogleDriveException server = new VL_GoogleDriveException('server', VL_GoogleDriveException.ErrorCategory.RECOVERABLE_SERVER);

			Test.startTest();
			Boolean quotaResult = quota.isRecoverable();
			Boolean timeoutResult = timeout.isRecoverable();
			Boolean serverResult = server.isRecoverable();
			Test.stopTest();

			System.assertEquals(true, quotaResult, 'RECOVERABLE_QUOTA should be recoverable');
			System.assertEquals(true, timeoutResult, 'RECOVERABLE_TIMEOUT should be recoverable');
			System.assertEquals(true, serverResult, 'RECOVERABLE_SERVER should be recoverable');
		}
	}

	/**
	 * @name: terminalCategoriesReturnFalse
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that TERMINAL_ categories return false from isRecoverable.
	 */
	@IsTest
	static void terminalCategoriesReturnFalse() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			List<VL_GoogleDriveException> terminals = new List<VL_GoogleDriveException>{
				new VL_GoogleDriveException('auth', VL_GoogleDriveException.ErrorCategory.TERMINAL_AUTH),
				new VL_GoogleDriveException('notfound', VL_GoogleDriveException.ErrorCategory.TERMINAL_NOT_FOUND),
				new VL_GoogleDriveException('validation', VL_GoogleDriveException.ErrorCategory.TERMINAL_VALIDATION),
				new VL_GoogleDriveException('config', VL_GoogleDriveException.ErrorCategory.TERMINAL_CONFIG)
			};

			Test.startTest();
			for (VL_GoogleDriveException ex : terminals) {
				System.assertEquals(false, ex.isRecoverable(), ex.getCategory() + ' should not be recoverable');
			}
			Test.stopTest();
		}
	}

	/**
	 * @name: getCategoryAndHttpStatusPreserved
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies category and HTTP status are preserved after construction.
	 */
	@IsTest
	static void getCategoryAndHttpStatusPreserved() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveException ex = new VL_GoogleDriveException(
				'rate limit',
				VL_GoogleDriveException.ErrorCategory.RECOVERABLE_QUOTA,
				429
			);

			Test.startTest();
			VL_GoogleDriveException.ErrorCategory cat = ex.getCategory();
			Integer status = ex.getHttpStatus();
			Test.stopTest();

			System.assertEquals(VL_GoogleDriveException.ErrorCategory.RECOVERABLE_QUOTA, cat, 'Category should be RECOVERABLE_QUOTA');
			System.assertEquals(429, status, 'HTTP status should be 429');
		}
	}

	/**
	 * @name: nullHttpStatusWhenNotProvided
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies HTTP status is null when not supplied to constructor.
	 */
	@IsTest
	static void nullHttpStatusWhenNotProvided() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveException ex = new VL_GoogleDriveException('config missing', VL_GoogleDriveException.ErrorCategory.TERMINAL_CONFIG);

			Test.startTest();
			Integer status = ex.getHttpStatus();
			Test.stopTest();

			System.assertEquals(null, status, 'HTTP status should be null when not provided');
		}
	}
}
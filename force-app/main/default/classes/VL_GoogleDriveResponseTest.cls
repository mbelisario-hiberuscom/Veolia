/**
 * @name VL_GoogleDriveResponseTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_GoogleDriveResponse builder methods and field population.
 **/
@IsTest
private class VL_GoogleDriveResponseTest {
	@TestSetup
	static void setupData() {
		VL_TestDataFactory.createGoogleDriveTestUser();
	}

	/**
	 * @name: buildSuccessPopulatesAllFields
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies buildSuccess sets success=true and all output fields correctly.
	 */
	@IsTest
	static void buildSuccessPopulatesAllFields() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			VL_GoogleDriveResponse resp = VL_GoogleDriveResponse.buildSuccess(
				200,
				'{"id":"file123","webViewLink":"https://drive.google.com/file/d/file123/view"}',
				'file123',
				'https://drive.google.com/file/d/file123/view'
			);
			Test.stopTest();

			System.assertEquals(true, resp.success, 'Success flag should be true');
			System.assertEquals(200, resp.httpStatus, 'HTTP status should be 200');
			System.assertEquals('file123', resp.remoteId, 'Remote Id should be preserved');
			System.assertEquals('https://drive.google.com/file/d/file123/view', resp.webViewLink, 'Web view link should be preserved');
			System.assertEquals(null, resp.category, 'Error category should be null for success');
		}
	}

	/**
	 * @name: buildFailurePopulatesAllFields
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies buildFailure sets success=false and error category correctly.
	 */
	@IsTest
	static void buildFailurePopulatesAllFields() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			VL_GoogleDriveResponse resp = VL_GoogleDriveResponse.buildFailure(
				401,
				'{"error":"unauthorized"}',
				VL_GoogleDriveException.ErrorCategory.TERMINAL_AUTH
			);
			Test.stopTest();

			System.assertEquals(false, resp.success, 'Success flag should be false');
			System.assertEquals(401, resp.httpStatus, 'HTTP status should be 401');
			System.assertEquals(VL_GoogleDriveException.ErrorCategory.TERMINAL_AUTH, resp.category, 'Category should be TERMINAL_AUTH');
			System.assertEquals(null, resp.remoteId, 'Remote Id should be null for failure');
			System.assertEquals(null, resp.webViewLink, 'Web view link should be null for failure');
		}
	}

	/**
	 * @name: buildSuccessWithNullOptionalFields
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies buildSuccess handles null optional fields gracefully.
	 */
	@IsTest
	static void buildSuccessWithNullOptionalFields() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			VL_GoogleDriveResponse resp = VL_GoogleDriveResponse.buildSuccess(201, '{}', null, null);
			Test.stopTest();

			System.assertEquals(true, resp.success, 'Success should be true even with null optional fields');
			System.assertEquals(201, resp.httpStatus, 'HTTP status should be 201');
		}
	}
}
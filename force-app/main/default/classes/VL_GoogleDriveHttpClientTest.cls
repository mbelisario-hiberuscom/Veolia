/**
 * @name VL_GoogleDriveHttpClientTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_GoogleDriveHttpClient covering all HTTP status code classifications
 *              and callout timeout handling using HttpCalloutMock.
 **/
@IsTest
private class VL_GoogleDriveHttpClientTest {
	@TestSetup
	static void setupData() {
		VL_TestDataFactory.createGoogleDriveTestUser();
	}

	private static final String TEST_PATH = '/drive/v3/files';

	/**
	 * @name: sendJsonSuccess200ReturnsSuccessResponse
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a 200 response produces a success VL_GoogleDriveResponse.
	 */
	@IsTest
	static void sendJsonSuccess200ReturnsSuccessResponse() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpMock(200, '{"id":"file1","webViewLink":"https://drive.google.com"}'));

			Test.startTest();
			VL_GoogleDriveResponse resp = new VL_GoogleDriveHttpClient().sendJson('GET', TEST_PATH, null);
			Test.stopTest();

			System.assertEquals(true, resp.success, '200 should produce success=true');
			System.assertEquals(200, resp.httpStatus, 'HTTP status should be 200');
		}
	}

	/**
	 * @name: sendJson401ReturnTerminalAuth
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a 401 response is classified as TERMINAL_AUTH.
	 */
	@IsTest
	static void sendJson401ReturnTerminalAuth() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpMock(401, '{"error":"unauthorized"}'));

			Test.startTest();
			VL_GoogleDriveResponse resp = new VL_GoogleDriveHttpClient().sendJson('GET', TEST_PATH, null);
			Test.stopTest();

			System.assertEquals(false, resp.success, '401 should produce success=false');
			System.assertEquals(VL_GoogleDriveException.ErrorCategory.TERMINAL_AUTH, resp.category, '401 should be TERMINAL_AUTH');
		}
	}

	/**
	 * @name: sendJson403QuotaReasonReturnsRecoverableQuota
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a 403 with quota reason is classified as RECOVERABLE_QUOTA.
	 */
	@IsTest
	static void sendJson403QuotaReasonReturnsRecoverableQuota() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(
				HttpCalloutMock.class,
				new VL_GoogleDriveHttpMock(403, '{"error":{"errors":[{"reason":"userRateLimitExceeded","domain":"usageLimits"}]}}')
			);

			Test.startTest();
			VL_GoogleDriveResponse resp = new VL_GoogleDriveHttpClient().sendJson('GET', TEST_PATH, null);
			Test.stopTest();

			System.assertEquals(
				VL_GoogleDriveException.ErrorCategory.RECOVERABLE_QUOTA,
				resp.category,
				'403 with quota reason should be RECOVERABLE_QUOTA'
			);
		}
	}

	/**
	 * @name: sendJson404ReturnsTerminalNotFound
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a 404 response is classified as TERMINAL_NOT_FOUND.
	 */
	@IsTest
	static void sendJson404ReturnsTerminalNotFound() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpMock(404, '{"error":"not found"}'));

			Test.startTest();
			VL_GoogleDriveResponse resp = new VL_GoogleDriveHttpClient().sendJson('GET', TEST_PATH, null);
			Test.stopTest();

			System.assertEquals(VL_GoogleDriveException.ErrorCategory.TERMINAL_NOT_FOUND, resp.category, '404 should be TERMINAL_NOT_FOUND');
		}
	}

	/**
	 * @name: sendJson429ReturnsRecoverableQuota
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a 429 Too Many Requests is classified as RECOVERABLE_QUOTA.
	 */
	@IsTest
	static void sendJson429ReturnsRecoverableQuota() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpMock(429, '{"error":"rate limit"}'));

			Test.startTest();
			VL_GoogleDriveResponse resp = new VL_GoogleDriveHttpClient().sendJson('GET', TEST_PATH, null);
			Test.stopTest();

			System.assertEquals(VL_GoogleDriveException.ErrorCategory.RECOVERABLE_QUOTA, resp.category, '429 should be RECOVERABLE_QUOTA');
		}
	}

	/**
	 * @name: sendJson500ReturnsRecoverableServer
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that 500/502/503/504 responses are classified as RECOVERABLE_SERVER.
	 */
	@IsTest
	static void sendJson500ReturnsRecoverableServer() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			List<Integer> statusCodes = new List<Integer>{ 500, 502, 503, 504 };
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpSequenceMock(statusCodes));

			Test.startTest();
			for (Integer code : statusCodes) {
				VL_GoogleDriveResponse resp = new VL_GoogleDriveHttpClient().sendJson('GET', TEST_PATH, null);

				System.assertEquals(
					VL_GoogleDriveException.ErrorCategory.RECOVERABLE_SERVER,
					resp.category,
					'HTTP ' + code + ' should be RECOVERABLE_SERVER'
				);
			}
			Test.stopTest();
		}
	}

	/**
	 * @name: sendJson400ReturnTerminalValidation
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a 400 response is classified as TERMINAL_VALIDATION.
	 */
	@IsTest
	static void sendJson400ReturnTerminalValidation() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpMock(400, '{"error":"bad request"}'));

			Test.startTest();
			VL_GoogleDriveResponse resp = new VL_GoogleDriveHttpClient().sendJson('GET', TEST_PATH, null);
			Test.stopTest();

			System.assertEquals(VL_GoogleDriveException.ErrorCategory.TERMINAL_VALIDATION, resp.category, '400 should be TERMINAL_VALIDATION');
		}
	}

	/**
	 * @name: endpointContainsNamedCredentialPrefix
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that the endpoint URL is prefixed with the Named Credential callout prefix.
	 */
	@IsTest
	static void endpointContainsNamedCredentialPrefix() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveHttpMock mock = new VL_GoogleDriveHttpMock(200, '{"id":"x"}');
			Test.setMock(HttpCalloutMock.class, mock);

			Test.startTest();
			new VL_GoogleDriveHttpClient().sendJson('GET', TEST_PATH, null);
			Test.stopTest();

			System.assert(
				mock.capturedEndpoint.startsWith('callout:VL_GoogleDriveNC'),
				'Endpoint must start with Named Credential callout prefix'
			);
		}
	}

	/**
	 * @name: calloutExceptionClassifiedAsRecoverableTimeout
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a CalloutException (e.g. timeout) is classified as RECOVERABLE_TIMEOUT.
	 */
	@IsTest
	static void calloutExceptionClassifiedAsRecoverableTimeout() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpClientTimeoutMock());

			Test.startTest();
			VL_GoogleDriveResponse resp = new VL_GoogleDriveHttpClient().sendJson('GET', TEST_PATH, null);
			Test.stopTest();

			System.assertEquals(false, resp.success, 'Timeout should produce success=false');
			System.assertEquals(
				VL_GoogleDriveException.ErrorCategory.RECOVERABLE_TIMEOUT,
				resp.category,
				'Timeout should be RECOVERABLE_TIMEOUT'
			);
		}
	}

	// ── Inner mock helpers ──────────────────────────────────────────────────────

	/**
	 * @name VL_GoogleDriveHttpSequenceMock
	 * @version 1.0
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description HttpCalloutMock that returns a sequence of HTTP status codes.
	 */
	private class VL_GoogleDriveHttpSequenceMock implements HttpCalloutMock {
		private List<Integer> statusCodes;
		private Integer callIndex = 0;

		/**
		 * @name VL_GoogleDriveHttpSequenceMock
		 * @creation date: 03/09/2026
		 * @author: Jesus Piriz
		 * @description Creates a mock with ordered status codes.
		 * @param statusCodes HTTP status codes returned for successive requests.
		 */
		private VL_GoogleDriveHttpSequenceMock(List<Integer> statusCodes) {
			this.statusCodes = statusCodes;
		}

		/**
		 * @name respond
		 * @creation date: 03/09/2026
		 * @author: Jesus Piriz
		 * @description Returns the next configured HTTP error response.
		 * @param request HTTP request received from the code under test.
		 * @return Mocked HTTP response.
		 */
		public HttpResponse respond(HttpRequest request) {
			HttpResponse response = new HttpResponse();
			response.setStatusCode(statusCodes[callIndex++]);
			response.setBody('{"error":"server error"}');
			return response;
		}
	}

	/**
	 * @name VL_GoogleDriveHttpClientTimeoutMock
	 * @version 1.0
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description HttpCalloutMock that simulates a CalloutException (timeout).
	 */
	public class VL_GoogleDriveHttpClientTimeoutMock implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			throw new CalloutException('Read timed out');
		}
	}
}
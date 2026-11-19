/**
 * @name VL_GoogleDriveFileServiceTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_GoogleDriveFileService upload behavior and endpoint verification.
 **/
@IsTest
private class VL_GoogleDriveFileServiceTest {
	@TestSetup
	static void setupData() {
		VL_TestDataFactory.createGoogleDriveTestUser();
	}

	private static final String FOLDER_ID = 'parentFolder1';
	private static final String EXPECTED_PATH_FRAGMENT = '/upload/drive/v3/files';

	/**
	 * @name: uploadReturnsRemoteIdAndWebViewLink
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a successful upload returns the remote file Id and web view link.
	 */
	@IsTest
	static void uploadReturnsRemoteIdAndWebViewLink() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveFileServiceCapturingMock mock = new VL_GoogleDriveFileServiceCapturingMock(
				200,
				'{"id":"uploadedFile1","webViewLink":"https://drive.google.com/file/d/uploadedFile1/view"}'
			);
			Test.setMock(HttpCalloutMock.class, mock);
			VL_GoogleDriveFileService service = new VL_GoogleDriveFileService(new VL_GoogleDriveHttpClient());

			Test.startTest();
			VL_GoogleDriveResponse resp = service.upload(Blob.valueOf('test content'), 'test.pdf', 'application/pdf', FOLDER_ID);
			Test.stopTest();

			System.assertEquals(true, resp.success, 'Upload should succeed');
			System.assertEquals('uploadedFile1', resp.remoteId, 'Remote Id should match response');
			System.assertEquals('https://drive.google.com/file/d/uploadedFile1/view', resp.webViewLink, 'Web view link should match response');
			System.assertEquals('PUT', mock.uploadMethod, 'Binary content should use the resumable PUT request');
			System.assertEquals(12, mock.uploadBodySize, 'PUT request should preserve the binary content size');
		}
	}

	/**
	 * @name: uploadUsesResumableEndpointWithSupportsAllDrives
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies the resumable upload endpoint includes the required query parameters.
	 */
	@IsTest
	static void uploadUsesResumableEndpointWithSupportsAllDrives() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveFileServiceCapturingMock mock = new VL_GoogleDriveFileServiceCapturingMock(200, '{"id":"file1"}');
			Test.setMock(HttpCalloutMock.class, mock);
			VL_GoogleDriveFileService service = new VL_GoogleDriveFileService(new VL_GoogleDriveHttpClient());

			Test.startTest();
			service.upload(Blob.valueOf('data'), 'doc.pdf', 'application/pdf', FOLDER_ID);
			Test.stopTest();

			System.assert(mock.initiationEndpoint.contains(EXPECTED_PATH_FRAGMENT), 'Endpoint should include ' + EXPECTED_PATH_FRAGMENT);
			System.assert(mock.initiationEndpoint.contains('supportsAllDrives=true'), 'Endpoint should include supportsAllDrives=true');
		}
	}

	/**
	 * @name: uploadFailureSurfacesResponse
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that an API error surfaces in the returned response.
	 */
	@IsTest
	static void uploadFailureSurfacesResponse() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(
				HttpCalloutMock.class,
				new VL_GoogleDriveFileServiceCapturingMock(403, '{"error":{"errors":[{"reason":"storageQuotaExceeded"}]}}')
			);
			VL_GoogleDriveFileService service = new VL_GoogleDriveFileService(new VL_GoogleDriveHttpClient());

			Test.startTest();
			VL_GoogleDriveResponse resp = service.upload(Blob.valueOf('data'), 'large.pdf', 'application/pdf', FOLDER_ID);
			Test.stopTest();

			System.assertEquals(false, resp.success, 'Upload should fail');
			System.assertNotEquals(null, resp.category, 'Error category should be set');
		}
	}

	// ── Mock helper ─────────────────────────────────────────────────────────────

	/**
	 * @name VL_GoogleDriveFileServiceCapturingMock
	 * @version 1.0
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Mock that captures the request endpoint and returns a configurable response.
	 */
	public class VL_GoogleDriveFileServiceCapturingMock implements HttpCalloutMock {
		private Integer statusCode;
		private String body;
		private Integer callCount = 0;
		public String capturedEndpoint;
		public String initiationEndpoint;
		public String uploadMethod;
		public Integer uploadBodySize;

		public VL_GoogleDriveFileServiceCapturingMock(Integer statusCode, String body) {
			this.statusCode = statusCode;
			this.body = body;
		}

		public HttpResponse respond(HttpRequest req) {
			capturedEndpoint = req.getEndpoint();
			if (callCount++ == 0) {
				initiationEndpoint = req.getEndpoint();
				HttpResponse initiationResponse = new HttpResponse();
				initiationResponse.setStatusCode(statusCode);
				if (statusCode >= 200 && statusCode < 300) {
					initiationResponse.setHeader(
						'Location',
						'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&upload_id=test'
					);
				}
				initiationResponse.setBody(statusCode >= 200 && statusCode < 300 ? '{}' : body);
				return initiationResponse;
			}

			uploadMethod = req.getMethod();
			uploadBodySize = req.getBodyAsBlob().size();
			HttpResponse resp = new HttpResponse();
			resp.setStatusCode(statusCode);
			resp.setBody(body);
			return resp;
		}
	}
}
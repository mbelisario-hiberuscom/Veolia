/**
 * @name VL_GoogleDriveHttpClient
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Thin HTTP client for Google Drive API v3. All requests are routed through the
 *              VL_GoogleDriveNC Named Credential so no credential material ever enters Apex code.
 */
public with sharing class VL_GoogleDriveHttpClient {
	@TestVisible
	private static final String NAMED_CREDENTIAL_PREFIX = 'callout:VL_GoogleDriveNC';
	private static final Integer TIMEOUT_MS = 120000;

	/**
	 * @name sendJson
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Sends an HTTP request with a JSON body and returns a classified response.
	 * @param method HTTP method (GET, POST, PATCH, DELETE).
	 * @param path API path appended to the Named Credential endpoint (e.g. /drive/v3/files).
	 * @param body JSON request body, or null for GET/DELETE.
	 * @return VL_GoogleDriveResponse classified response.
	 */
	public VL_GoogleDriveResponse sendJson(String method, String path, String body) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint(NAMED_CREDENTIAL_PREFIX + path);
		req.setMethod(method);
		req.setHeader('Content-Type', 'application/json; charset=UTF-8');
		req.setTimeout(TIMEOUT_MS);
		if (String.isNotBlank(body)) {
			req.setBody(body);
		}
		return executeRequest(req);
	}

	/**
	 * @name sendMultipart
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Starts a resumable Drive upload and sends the binary content directly as a Blob.
	 *              This avoids Base64 and large multipart String allocations in the Apex heap.
	 * @param path API path (e.g. /upload/drive/v3/files?uploadType=resumable&supportsAllDrives=true).
	 * @param binary File binary content as a Blob.
	 * @param contentType MIME type of the file.
	 * @param metadataJson JSON metadata for the Drive file (name, parents, mimeType).
	 * @return VL_GoogleDriveResponse classified response.
	 */
	public VL_GoogleDriveResponse sendMultipart(String path, Blob binary, String contentType, String metadataJson) {
		HttpRequest initiationRequest = new HttpRequest();
		initiationRequest.setEndpoint(NAMED_CREDENTIAL_PREFIX + path);
		initiationRequest.setMethod('POST');
		initiationRequest.setHeader('Content-Type', 'application/json; charset=UTF-8');
		initiationRequest.setHeader('X-Upload-Content-Type', contentType);
		initiationRequest.setHeader('X-Upload-Content-Length', String.valueOf(binary.size()));
		initiationRequest.setTimeout(TIMEOUT_MS);
		initiationRequest.setBody(metadataJson);

		HttpResponse initiationResponse;
		try {
			initiationResponse = new Http().send(initiationRequest);
		} catch (CalloutException ex) {
			return VL_GoogleDriveResponse.buildFailure(0, ex.getMessage(), VL_GoogleDriveException.ErrorCategory.RECOVERABLE_TIMEOUT);
		}

		if (initiationResponse.getStatusCode() < 200 || initiationResponse.getStatusCode() >= 300) {
			return classifyResponse(initiationResponse);
		}

		String uploadLocation = initiationResponse.getHeader('Location');
		if (String.isBlank(uploadLocation)) {
			return VL_GoogleDriveResponse.buildFailure(
				initiationResponse.getStatusCode(),
				'Google Drive did not return a resumable upload Location.',
				VL_GoogleDriveException.ErrorCategory.TERMINAL_VALIDATION
			);
		}

		HttpRequest uploadRequest = new HttpRequest();
		uploadRequest.setEndpoint(toNamedCredentialEndpoint(uploadLocation));
		uploadRequest.setMethod('PUT');
		uploadRequest.setHeader('Content-Type', contentType);
		uploadRequest.setTimeout(TIMEOUT_MS);
		uploadRequest.setBodyAsBlob(binary);
		return executeRequest(uploadRequest);
	}

	// ── Private helpers ────────────────────────────────────────────────────────

	private VL_GoogleDriveResponse executeRequest(HttpRequest req) {
		try {
			HttpResponse httpResp = new Http().send(req);
			return classifyResponse(httpResp);
		} catch (CalloutException ex) {
			return VL_GoogleDriveResponse.buildFailure(0, ex.getMessage(), VL_GoogleDriveException.ErrorCategory.RECOVERABLE_TIMEOUT);
		}
	}

	private static String toNamedCredentialEndpoint(String uploadLocation) {
		Integer schemeEnd = uploadLocation.indexOf('://');
		if (schemeEnd == -1) {
			return NAMED_CREDENTIAL_PREFIX + uploadLocation;
		}

		Integer pathStart = uploadLocation.indexOf('/', schemeEnd + 3);
		if (pathStart == -1) {
			return NAMED_CREDENTIAL_PREFIX + '/';
		}
		return NAMED_CREDENTIAL_PREFIX + uploadLocation.substring(pathStart);
	}

	private static VL_GoogleDriveResponse classifyResponse(HttpResponse httpResp) {
		Integer status = httpResp.getStatusCode();
		String body = httpResp.getBody();
		if (status >= 200 && status < 300) {
			String remoteId = extractJsonField(body, 'id');
			String webViewLink = extractJsonField(body, 'webViewLink');
			return VL_GoogleDriveResponse.buildSuccess(status, body, remoteId, webViewLink);
		}
		VL_GoogleDriveException.ErrorCategory category = classifyErrorStatus(status, body);
		return VL_GoogleDriveResponse.buildFailure(status, body, category);
	}

	private static VL_GoogleDriveException.ErrorCategory classifyErrorStatus(Integer status, String body) {
		if (status == 401) {
			return VL_GoogleDriveException.ErrorCategory.TERMINAL_AUTH;
		}
		if (status == 403) {
			if (
				body != null &&
				(body.containsIgnoreCase('quota') ||
				body.containsIgnoreCase('rateLimitExceeded') ||
				body.containsIgnoreCase('userRateLimitExceeded'))
			) {
				return VL_GoogleDriveException.ErrorCategory.RECOVERABLE_QUOTA;
			}
			return VL_GoogleDriveException.ErrorCategory.TERMINAL_AUTH;
		}
		if (status == 404) {
			return VL_GoogleDriveException.ErrorCategory.TERMINAL_NOT_FOUND;
		}
		if (status == 429) {
			return VL_GoogleDriveException.ErrorCategory.RECOVERABLE_QUOTA;
		}
		if (status == 400) {
			return VL_GoogleDriveException.ErrorCategory.TERMINAL_VALIDATION;
		}
		if (status == 500 || status == 502 || status == 503 || status == 504) {
			return VL_GoogleDriveException.ErrorCategory.RECOVERABLE_SERVER;
		}
		return VL_GoogleDriveException.ErrorCategory.TERMINAL_VALIDATION;
	}

	/** Extracts a top-level JSON string field without a full JSON parse to avoid heap impact. */
	private static String extractJsonField(String json, String fieldName) {
		if (String.isBlank(json)) {
			return null;
		}
		String searchKey = '"' + fieldName + '"';
		Integer keyIdx = json.indexOf(searchKey);
		if (keyIdx == -1) {
			return null;
		}
		Integer colonIdx = json.indexOf(':', keyIdx);
		if (colonIdx == -1) {
			return null;
		}
		Integer startQuote = json.indexOf('"', colonIdx + 1);
		if (startQuote == -1) {
			return null;
		}
		Integer endQuote = json.indexOf('"', startQuote + 1);
		if (endQuote == -1) {
			return null;
		}
		return json.substring(startQuote + 1, endQuote);
	}
}
/**
 * @name VL_GoogleDriveResponse
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Typed wrapper for Google Drive API responses. Carries both success and failure payloads
 *              so callers never handle raw HTTP responses.
 */
public inherited sharing class VL_GoogleDriveResponse {
	/** true when the HTTP call returned a 2xx status. */
	public Boolean success;
	/** HTTP status code returned by the API. */
	public Integer httpStatus;
	/** Raw JSON response body (never logged verbatim to avoid credential leakage). */
	public String bodyJson;
	/** Google Drive file or folder identifier extracted from the success response. */
	public String remoteId;
	/** Shareable web view link extracted from the success response. */
	public String webViewLink;
	/** Error category when success=false. */
	public VL_GoogleDriveException.ErrorCategory category;

	/**
	 * @name buildSuccess
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Factory method for a successful response.
	 * @param httpStatus HTTP status code (2xx).
	 * @param bodyJson Raw JSON body.
	 * @param remoteId Remote file or folder identifier.
	 * @param webViewLink Shareable web view link.
	 * @return VL_GoogleDriveResponse populated success response.
	 */
	public static VL_GoogleDriveResponse buildSuccess(Integer httpStatus, String bodyJson, String remoteId, String webViewLink) {
		VL_GoogleDriveResponse resp = new VL_GoogleDriveResponse();
		resp.success = true;
		resp.httpStatus = httpStatus;
		resp.bodyJson = bodyJson;
		resp.remoteId = remoteId;
		resp.webViewLink = webViewLink;
		return resp;
	}

	/**
	 * @name buildFailure
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Factory method for a failed response.
	 * @param httpStatus HTTP status code.
	 * @param bodyJson Raw JSON body.
	 * @param category Error category.
	 * @return VL_GoogleDriveResponse populated failure response.
	 */
	public static VL_GoogleDriveResponse buildFailure(Integer httpStatus, String bodyJson, VL_GoogleDriveException.ErrorCategory category) {
		VL_GoogleDriveResponse resp = new VL_GoogleDriveResponse();
		resp.success = false;
		resp.httpStatus = httpStatus;
		resp.bodyJson = bodyJson;
		resp.category = category;
		return resp;
	}
}
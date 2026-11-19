/**
 * @name VL_GoogleDriveHttpMock
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Shared HttpCalloutMock for Google Drive tests. Extracted as a top-level @isTest class
 *              so it can be referenced across multiple test classes.
 */
@IsTest
public class VL_GoogleDriveHttpMock implements HttpCalloutMock {
	private Integer statusCode;
	private String body;
	public String capturedEndpoint;

	public VL_GoogleDriveHttpMock(Integer statusCode, String body) {
		this.statusCode = statusCode;
		this.body = body;
	}

	public HttpResponse respond(HttpRequest req) {
		capturedEndpoint = req.getEndpoint();
		HttpResponse resp = new HttpResponse();
		resp.setStatusCode(statusCode);
		resp.setBody(body);
		return resp;
	}
}
/**
 * @name VL_GoogleDriveFileService
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Uploads file binaries to Google Drive via resumable upload.
 *              Returns a classified response with the remote file identifier and shareable link.
 */
public with sharing class VL_GoogleDriveFileService {
	// fields param is required; Drive omits webViewLink from the upload response otherwise.
	private static final String UPLOAD_PATH = '/upload/drive/v3/files?uploadType=resumable&supportsAllDrives=true&fields=id,webViewLink';

	private VL_GoogleDriveHttpClient httpClient;

	/**
	 * @name VL_GoogleDriveFileService
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Constructor accepting the HTTP client dependency.
	 * @param httpClient Configured HTTP client for Drive API calls.
	 */
	public VL_GoogleDriveFileService(VL_GoogleDriveHttpClient httpClient) {
		this.httpClient = httpClient;
	}

	/**
	 * @name upload
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Uploads a binary file to the given Drive folder via resumable upload.
	 * @param content File binary content.
	 * @param fileName File name including extension.
	 * @param mimeType MIME type of the file.
	 * @param parentFolderId Drive Id of the destination folder.
	 * @return VL_GoogleDriveResponse classified response with remoteId and webViewLink on success.
	 */
	public VL_GoogleDriveResponse upload(Blob content, String fileName, String mimeType, String parentFolderId) {
		Map<String, Object> metadata = new Map<String, Object>{ 'name' => fileName, 'parents' => new List<String>{ parentFolderId } };
		return httpClient.sendMultipart(UPLOAD_PATH, content, mimeType, JSON.serialize(metadata));
	}
}
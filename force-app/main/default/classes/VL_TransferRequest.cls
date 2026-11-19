/**
 * @name VL_TransferRequest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Represents one document transfer request passed from the trigger helper to the async Queueable.
 */
public inherited sharing class VL_TransferRequest {
	/** Id of the Salesforce record to which the document is linked. */
	public Id parentRecordId;
	/** API name of the parent record's sObject type. */
	public String parentObjectApiName;
	/** Display name of the parent record (used for folder naming). */
	public String parentRecordName;
	/** Salesforce ContentDocument Id. */
	public String contentDocumentId;
	/** Salesforce ContentVersion Id for the specific version being transferred. */
	public String contentVersionId;
	/** Document title (file name). */
	public String contentTitle;
	/** MIME type of the document. */
	public String mimeType;
	/** Google Drive folder Id selected in the LWC, when supplied by the standard uploader. */
	public String requestedDriveFolderId;
	/** Idempotency key: contentDocumentId + ':' + contentVersionId. */
	public String logicalKey;

	/**
	 * @name VL_TransferRequest
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Constructs a transfer request and computes the logical key.
	 * @param parentRecordId Id of the parent record.
	 * @param parentObjectApiName API name of the parent sObject type.
	 * @param parentRecordName Display name of the parent record.
	 * @param contentDocumentId ContentDocument Id.
	 * @param contentVersionId ContentVersion Id.
	 * @param contentTitle Document title.
	 * @param mimeType MIME type.
	 */
	public VL_TransferRequest(
		Id parentRecordId,
		String parentObjectApiName,
		String parentRecordName,
		String contentDocumentId,
		String contentVersionId,
		String contentTitle,
		String mimeType
	) {
		this.parentRecordId = parentRecordId;
		this.parentObjectApiName = parentObjectApiName;
		this.parentRecordName = parentRecordName;
		this.contentDocumentId = contentDocumentId;
		this.contentVersionId = contentVersionId;
		this.contentTitle = contentTitle;
		this.mimeType = mimeType;
		this.requestedDriveFolderId = null;
		this.logicalKey = contentDocumentId + ':' + contentVersionId;
	}

	/**
	 * @name VL_TransferRequest
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Constructs a transfer request with an optional Google Drive destination folder.
	 * @param parentRecordId Id of the parent record.
	 * @param parentObjectApiName API name of the parent sObject type.
	 * @param parentRecordName Display name of the parent record.
	 * @param contentDocumentId ContentDocument Id.
	 * @param contentVersionId ContentVersion Id.
	 * @param contentTitle Document title.
	 * @param mimeType MIME type.
	 * @param requestedDriveFolderId Google Drive folder Id selected by the user.
	 */
	public VL_TransferRequest(
		Id parentRecordId,
		String parentObjectApiName,
		String parentRecordName,
		String contentDocumentId,
		String contentVersionId,
		String contentTitle,
		String mimeType,
		String requestedDriveFolderId
	) {
		this.parentRecordId = parentRecordId;
		this.parentObjectApiName = parentObjectApiName;
		this.parentRecordName = parentRecordName;
		this.contentDocumentId = contentDocumentId;
		this.contentVersionId = contentVersionId;
		this.contentTitle = contentTitle;
		this.mimeType = mimeType;
		this.requestedDriveFolderId = requestedDriveFolderId;
		this.logicalKey = contentDocumentId + ':' + contentVersionId;
	}
}
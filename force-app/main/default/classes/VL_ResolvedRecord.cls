/**
 * @name VL_ResolvedRecord
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Carries the resolved sObject type name and display name for a Salesforce record Id.
 */
public inherited sharing class VL_ResolvedRecord {
	/** API name of the sObject type (e.g. Opportunity). */
	public String objectApiName;
	/** Display name / Name field value of the record. */
	public String recordName;

	/**
	 * @name VL_ResolvedRecord
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Constructs a resolved record with object API name and record name.
	 * @param objectApiName sObject API name.
	 * @param recordName Display name of the record.
	 */
	public VL_ResolvedRecord(String objectApiName, String recordName) {
		this.objectApiName = objectApiName;
		this.recordName = recordName;
	}
}
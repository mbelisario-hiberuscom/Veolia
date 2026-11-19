/**
 * @name VL_GoogleDriveSubfolderConfigSelector
 * @version 1.0
 * @creation date: 02/09/2026
 * @author: Jesus Piriz
 * @description Reads administrator-configured Google Drive subfolders from Custom Metadata and caches them per object.
 */
public inherited sharing class VL_GoogleDriveSubfolderConfigSelector {
	@TestVisible
	private static Map<String, List<VL_GoogleDriveSubfolderConfigDTO>> cachedByObject;

	/**
	 * @name getForObject
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Returns active subfolder configurations for an object, ordered by configured order and developer name.
	 * @param objectApiName Salesforce object API name.
	 * @return List<VL_GoogleDriveSubfolderConfigDTO> active subfolder configurations.
	 */
	public static List<VL_GoogleDriveSubfolderConfigDTO> getForObject(String objectApiName) {
		List<VL_GoogleDriveSubfolderConfigDTO> emptyResult = new List<VL_GoogleDriveSubfolderConfigDTO>();
		if (String.isBlank(objectApiName)) {
			return emptyResult;
		}

		String normalizedObjectApiName = objectApiName.trim().toLowerCase();
		if (cachedByObject == null) {
			cachedByObject = new Map<String, List<VL_GoogleDriveSubfolderConfigDTO>>();
		}
		if (cachedByObject.containsKey(normalizedObjectApiName)) {
			return cachedByObject.get(normalizedObjectApiName);
		}
		if (!Schema.sObjectType.VL_GoogleDriveSubfolder__mdt.isAccessible()) {
			cachedByObject.put(normalizedObjectApiName, emptyResult);
			return emptyResult;
		}

		List<VL_GoogleDriveSubfolderConfigDTO> result = new List<VL_GoogleDriveSubfolderConfigDTO>();
		for (VL_GoogleDriveSubfolder__mdt metadata : [
			SELECT DeveloperName, VL_ObjectApiNameTxt__c, VL_FolderNameTxt__c, VL_OrderNumber__c, VL_IsActive__c
			FROM VL_GoogleDriveSubfolder__mdt
			WHERE VL_IsActive__c = TRUE
			ORDER BY VL_OrderNumber__c ASC, DeveloperName ASC
		]) {
			if (
				String.isBlank(metadata.VL_ObjectApiNameTxt__c) ||
				metadata.VL_ObjectApiNameTxt__c.trim().toLowerCase() != normalizedObjectApiName
			) {
				continue;
			}
			result.add(
				new VL_GoogleDriveSubfolderConfigDTO(
					metadata.VL_ObjectApiNameTxt__c,
					metadata.VL_FolderNameTxt__c,
					metadata.VL_OrderNumber__c == null ? null : (Integer) metadata.VL_OrderNumber__c,
					metadata.VL_IsActive__c
				)
			);
		}
		cachedByObject.put(normalizedObjectApiName, result);
		return result;
	}
}
/**
 * @name VL_GoogleDriveConfigSelector
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Reads and caches VL_GoogleDriveConfiguration__mdt. Provides object-enabled lookup
 *              and CSV parsing for the enabled-objects field.
 */
public inherited sharing class VL_GoogleDriveConfigSelector {
	@TestVisible
	private static VL_GoogleDriveConfigDTO cachedConfig;

	/** Set to true in tests to simulate absence of an active configuration record. */
	@TestVisible
	private static Boolean noActiveRecordForTest = false;

	/**
	 * @name getActive
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Returns the active Google Drive configuration, reading from Custom Metadata if not cached.
	 * @return VL_GoogleDriveConfigDTO active configuration.
	 * @throws VL_GoogleDriveException TERMINAL_CONFIG when no active record exists.
	 */
	public static VL_GoogleDriveConfigDTO getActive() {
		if (cachedConfig != null) {
			return cachedConfig;
		}
		if (noActiveRecordForTest) {
			throw new VL_GoogleDriveException(
				'No active Google Drive configuration found.',
				VL_GoogleDriveException.ErrorCategory.TERMINAL_CONFIG
			);
		}
		List<VL_GoogleDriveConfiguration__mdt> records = [
			SELECT
				VL_RootFolderIdTxt__c,
				VL_SharedDriveIdTxt__c,
				VL_EnabledObjectsTxtArea__c,
				VL_MaxRetriesNumber__c,
				VL_HasAutoCleanup__c,
				VL_FolderNamingPatternTxt__c,
				VL_IsActive__c,
				VL_MaxFileSizeMbNumber__c
			FROM VL_GoogleDriveConfiguration__mdt
			WHERE VL_IsActive__c = TRUE
			LIMIT 1
		];
		if (records.isEmpty()) {
			throw new VL_GoogleDriveException(
				'No active Google Drive configuration found.',
				VL_GoogleDriveException.ErrorCategory.TERMINAL_CONFIG
			);
		}
		cachedConfig = mapToDto(records[0]);
		return cachedConfig;
	}

	/**
	 * @name isObjectEnabled
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Returns true when the given object API name is in the enabled list and the config is active.
	 * @param apiName Salesforce object API name (case-insensitive).
	 * @return Boolean true when enabled.
	 */
	public static Boolean isObjectEnabled(String apiName) {
		try {
			VL_GoogleDriveConfigDTO config = getActive();
			if (!config.isActive) {
				return false;
			}
			return config.enabledObjects != null && config.enabledObjects.contains(apiName.toLowerCase().trim());
		} catch (VL_GoogleDriveException ex) {
			return false;
		}
	}

	/**
	 * @name parseEnabledObjectsCsv
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Parses a comma-separated object API names string, trimming whitespace and lowercasing.
	 * @param csv Comma-separated list of API names.
	 * @return List<String> normalized API names.
	 */
	@TestVisible
	public static List<String> parseEnabledObjectsCsv(String csv) {
		List<String> result = new List<String>();
		if (String.isBlank(csv)) {
			return result;
		}
		for (String part : csv.split(',')) {
			String normalized = part.trim().toLowerCase();
			if (String.isNotBlank(normalized)) {
				result.add(normalized);
			}
		}
		return result;
	}

	@TestVisible
	private static VL_GoogleDriveConfigDTO mapToDto(VL_GoogleDriveConfiguration__mdt rec) {
		VL_GoogleDriveConfigDTO dto = new VL_GoogleDriveConfigDTO();
		dto.rootFolderId = rec.VL_RootFolderIdTxt__c;
		dto.sharedDriveId = rec.VL_SharedDriveIdTxt__c;
		dto.maxRetries = rec.VL_MaxRetriesNumber__c != null ? (Integer) rec.VL_MaxRetriesNumber__c : 3;
		dto.autoCleanup = rec.VL_HasAutoCleanup__c == true;
		dto.folderNamingPattern = String.isNotBlank(rec.VL_FolderNamingPatternTxt__c)
			? rec.VL_FolderNamingPatternTxt__c
			: '{RecordId}-{RecordName}';
		dto.isActive = rec.VL_IsActive__c == true;
		dto.maxFileSizeMb = rec.VL_MaxFileSizeMbNumber__c != null ? rec.VL_MaxFileSizeMbNumber__c : 25;
		dto.enabledObjects = parseEnabledObjectsCsv(rec.VL_EnabledObjectsTxtArea__c);
		return dto;
	}
}
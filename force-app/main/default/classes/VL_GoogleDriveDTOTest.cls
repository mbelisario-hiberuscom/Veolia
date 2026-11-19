/**
 * @name VL_GoogleDriveDTOTest
 * @version 1.0
 * @creation date: 04/09/2026
 * @author: Jesus Piriz
 * @description Tests constructors for the Google Drive integration data transfer objects.
 **/
@IsTest
private with sharing class VL_GoogleDriveDTOTest {
	/**
	 * @name constructorsInitializeAllFields
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies that each DTO constructor initializes every supplied field.
	 */
	@IsTest
	static void constructorsInitializeAllFields() {
		List<String> enabledObjects = new List<String>{ 'account', 'opportunity' };

		Test.startTest();
		VL_GoogleDriveConfigDTO emptyConfig = new VL_GoogleDriveConfigDTO();
		VL_DriveFolderDTO emptyFolder = new VL_DriveFolderDTO();
		VL_ExternalFileStatusDTO emptyStatus = new VL_ExternalFileStatusDTO();
		VL_DriveItemDTO emptyItem = new VL_DriveItemDTO();
		VL_GoogleDriveConfigDTO config = new VL_GoogleDriveConfigDTO('ROOT', 'SHARED', enabledObjects, 5, true, '{RecordName}', true, 10.5);
		VL_DriveFolderDTO folder = new VL_DriveFolderDTO('FOLDER', 'Contracts');
		VL_ExternalFileStatusDTO status = new VL_ExternalFileStatusDTO(
			'EXTERNAL',
			'Completed',
			'No error',
			'REMOTE',
			'https://drive.google.com/file/REMOTE/view'
		);
		VL_DriveItemDTO item = new VL_DriveItemDTO(
			'FILE',
			'Report.pdf',
			false,
			false,
			true,
			'application/pdf',
			2097152L,
			'2026-09-04T10:00:00.000Z',
			'https://drive.google.com/file/FILE/view',
			'Completed',
			'No error',
			'EXTERNAL'
		);
		Test.stopTest();

		System.assertEquals(null, emptyConfig.rootFolderId, 'Empty configuration root folder should be null');
		System.assertEquals(null, emptyConfig.enabledObjects, 'Empty configuration enabled objects should be null');
		System.assertEquals(null, emptyConfig.maxFileSizeMb, 'Empty configuration file size should be null');
		System.assertEquals(null, emptyFolder.folderId, 'Empty folder Id should be null');
		System.assertEquals(null, emptyFolder.folderName, 'Empty folder name should be null');
		System.assertEquals(null, emptyStatus.externalFileId, 'Empty status external file Id should be null');
		System.assertEquals(null, emptyStatus.status, 'Empty status should be null');
		System.assertEquals(null, emptyStatus.remoteLinkUrl, 'Empty status URL should be null');
		System.assertEquals(null, emptyItem.id, 'Empty Drive item Id should be null');
		System.assertEquals(null, emptyItem.isFolder, 'Empty Drive item folder flag should be null');
		System.assertEquals(null, emptyItem.sizeBytes, 'Empty Drive item size should be null');
		System.assertEquals('ROOT', config.rootFolderId, 'Configuration root folder should be initialized');
		System.assertEquals('SHARED', config.sharedDriveId, 'Configuration shared drive should be initialized');
		System.assertEquals(enabledObjects, config.enabledObjects, 'Enabled objects should be initialized');
		System.assertEquals(5, config.maxRetries, 'Maximum retries should be initialized');
		System.assertEquals(true, config.autoCleanup, 'Auto cleanup should be initialized');
		System.assertEquals('{RecordName}', config.folderNamingPattern, 'Folder pattern should be initialized');
		System.assertEquals(true, config.isActive, 'Active flag should be initialized');
		System.assertEquals(10.5, config.maxFileSizeMb, 'Maximum file size should be initialized');
		System.assertEquals('FOLDER', folder.folderId, 'Folder Id should be initialized');
		System.assertEquals('Contracts', folder.folderName, 'Folder name should be initialized');
		System.assertEquals('EXTERNAL', status.externalFileId, 'External file Id should be initialized');
		System.assertEquals('Completed', status.status, 'Status should be initialized');
		System.assertEquals('No error', status.error, 'Error should be initialized');
		System.assertEquals('REMOTE', status.remoteFileId, 'Remote file Id should be initialized');
		System.assertEquals('https://drive.google.com/file/REMOTE/view', status.remoteLinkUrl, 'Remote URL should be initialized');
		System.assertEquals('FILE', item.id, 'Drive item Id should be initialized');
		System.assertEquals('Report.pdf', item.name, 'Drive item name should be initialized');
		System.assertEquals(false, item.isFolder, 'Folder flag should be initialized');
		System.assertEquals(false, item.isLinkedFolder, 'Linked-folder flag should be initialized');
		System.assertEquals(true, item.isReadOnly, 'Read-only flag should be initialized');
		System.assertEquals('application/pdf', item.mimeType, 'MIME type should be initialized');
		System.assertEquals(2097152L, item.sizeBytes, 'File size should be initialized');
		System.assertEquals('2026-09-04T10:00:00.000Z', item.modifiedTime, 'Modified time should be initialized');
		System.assertEquals('https://drive.google.com/file/FILE/view', item.webViewLink, 'Web URL should be initialized');
		System.assertEquals('Completed', item.syncStatus, 'Sync status should be initialized');
		System.assertEquals('No error', item.syncError, 'Sync error should be initialized');
		System.assertEquals('EXTERNAL', item.externalFileId, 'External file Id should be initialized');
	}
}
/**
 * @name VL_GoogleDriveSubfolderSelectorTest
 * @version 1.0
 * @creation date: 02/09/2026
 * @author: Jesus Piriz
 * @description Tests for administrator-configured Google Drive subfolder selection and caching.
 **/
@IsTest
private class VL_GoogleDriveSubfolderSelectorTest {
	@TestSetup
	static void setupData() {
		VL_TestDataFactory.createGoogleDriveTestUser();
	}

	/**
	 * @name: getForObjectReturnsInjectedConfiguration
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies that configurations are selected case-insensitively and cached per object.
	 */
	@IsTest
	static void getForObjectReturnsInjectedConfiguration() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			List<VL_GoogleDriveSubfolderConfigDTO> configured = new List<VL_GoogleDriveSubfolderConfigDTO>{
				new VL_GoogleDriveSubfolderConfigDTO('Lead', 'Documentacion', 1, true)
			};
			VL_GoogleDriveSubfolderConfigSelector.cachedByObject = new Map<String, List<VL_GoogleDriveSubfolderConfigDTO>>{
				'lead' => configured
			};

			Test.startTest();
			List<VL_GoogleDriveSubfolderConfigDTO> result = VL_GoogleDriveSubfolderConfigSelector.getForObject('lead');
			Test.stopTest();

			System.assertEquals(1, result.size(), 'One configured Lead subfolder should be returned');
			System.assertEquals('Documentacion', result[0].folderName, 'Configured folder name should be preserved');
		}
	}

	/**
	 * @name: blankObjectReturnsEmptyConfiguration
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Blank object names return an empty configuration without querying metadata.
	 */
	@IsTest
	static void blankObjectReturnsEmptyConfiguration() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			List<VL_GoogleDriveSubfolderConfigDTO> result = VL_GoogleDriveSubfolderConfigSelector.getForObject(' ');
			Test.stopTest();

			System.assertEquals(0, result.size(), 'Blank object names should return no configuration');
		}
	}

	/**
	 * @name: metadataConfigurationIsLoadedAndCached
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description A cache miss reads active subfolder metadata and caches the result by object.
	 */
	@IsTest
	static void metadataConfigurationIsLoadedAndCached() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveSubfolderConfigSelector.cachedByObject = null;

			Test.startTest();
			List<VL_GoogleDriveSubfolderConfigDTO> first = VL_GoogleDriveSubfolderConfigSelector.getForObject('Account');
			List<VL_GoogleDriveSubfolderConfigDTO> second = VL_GoogleDriveSubfolderConfigSelector.getForObject('ACCOUNT');
			Test.stopTest();

			System.assertNotEquals(null, first, 'Metadata lookup should return an initialized list');
			System.assert(first === second, 'Repeated lookups should return the cached list');
		}
	}
}
/**
 * @name VL_TestDataFactory
 * @version 1.0
 * @creation date: 01/09/2026
 * @author: Jesus Piriz
 * @description Creates reusable, valid test data for Salesforce unit tests.
 */
@IsTest
public class VL_TestDataFactory {
	private static Integer accountSequence = 0;
	private static final String SYSTEM_ADMIN_TEST_USER_ALIAS = 'vgdrive';
	private static final String SYSTEM_ADMIN_TEST_USER_LAST_NAME = 'Google Drive Test';
	private static final String GOOGLE_DRIVE_PERMISSION_SET = 'VL_GoogleDriveIntegration';

	/**
	 * @name createSystemAdminTestUser
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Creates a System Administrator test user without assigning feature-specific permissions.
	 * @return Inserted System Administrator test user.
	 */
	public static User createSystemAdminTestUser() {
		Profile systemAdministrator = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
		String uniqueKey = String.valueOf(DateTime.now().getTime()) + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
		User testUser = new User(
			Alias = SYSTEM_ADMIN_TEST_USER_ALIAS,
			Email = 'vl.gdrive.test.' + uniqueKey + '@example.com',
			EmailEncodingKey = 'UTF-8',
			LastName = SYSTEM_ADMIN_TEST_USER_LAST_NAME,
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			ProfileId = systemAdministrator.Id,
			TimeZoneSidKey = 'Europe/Madrid',
			Username = 'vl.gdrive.test.' + uniqueKey + '@example.com'
		);
		insert testUser;
		return testUser;
	}

	/**
	 * @name createGoogleDriveTestUser
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Creates a System Administrator test user and assigns the Google Drive integration permission set.
	 * @return Inserted test user with the integration permission set assigned.
	 */
	public static User createGoogleDriveTestUser() {
		User testUser = createSystemAdminTestUser();
		PermissionSet integrationPermissionSet = [SELECT Id FROM PermissionSet WHERE Name = :GOOGLE_DRIVE_PERMISSION_SET LIMIT 1];
		insert new PermissionSetAssignment(AssigneeId = testUser.Id, PermissionSetId = integrationPermissionSet.Id);
		return testUser;
	}

	/**
	 * @name getSystemAdminTestUser
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Retrieves the System Administrator test user created by the current test class setup.
	 * @return The System Administrator test user created by the current test class setup.
	 */
	public static User getSystemAdminTestUser() {
		return [SELECT Id FROM User WHERE Alias = :SYSTEM_ADMIN_TEST_USER_ALIAS AND LastName = :SYSTEM_ADMIN_TEST_USER_LAST_NAME LIMIT 1];
	}

	/**
	 * @name getGoogleDriveTestUser
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Retrieves the Google Drive test user created by the current test class setup.
	 * @return The test user assigned to the Google Drive integration permission set.
	 */
	public static User getGoogleDriveTestUser() {
		return getSystemAdminTestUser();
	}

	/**
	 * @name createCNAE
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts one CNAE record.
	 * @param name CNAE name.
	 * @return Inserted CNAE record.
	 */
	public static VL_CNAE__c createCNAE(String name) {
		VL_CNAE__c cnae = new VL_CNAE__c(Name = String.isBlank(name) ? 'Test CNAE' : name);
		insert cnae;
		return cnae;
	}

	/**
	 * @name createCNAEs
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts N CNAE records by calling createCNAE for each record.
	 * @param recordCount Number of CNAE records to create.
	 * @return Inserted CNAE records.
	 */
	public static List<VL_CNAE__c> createCNAEs(Integer recordCount) {
		List<VL_CNAE__c> cnaes = new List<VL_CNAE__c>();
		if (recordCount == null || recordCount <= 0) {
			return cnaes;
		}
		for (Integer index = 1; index <= recordCount; index++) {
			cnaes.add(createCNAE('Test CNAE ' + index));
		}
		return cnaes;
	}

	/**
	 * @name createLead
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts one valid Lead record using defaults for blank values.
	 * @param firstName Lead first name.
	 * @param lastName Lead last name.
	 * @param company Lead company.
	 * @param email Lead email.
	 * @return Inserted Lead record.
	 */
	public static Lead createLead(String firstName, String lastName, String company, String email) {
		Lead lead = new Lead(
			FirstName = String.isBlank(firstName) ? 'Test' : firstName,
			LastName = String.isBlank(lastName) ? 'Lead' : lastName,
			Company = String.isBlank(company) ? 'Test Company' : company,
			Email = String.isBlank(email) ? 'test@example.com' : email
		);
		insert lead;
		return lead;
	}

	/**
	 * @name createLeads
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts N valid Lead records in one DML operation.
	 * @param recordCount Number of Lead records to create.
	 * @return Inserted Lead records.
	 */
	public static List<Lead> createLeads(Integer recordCount) {
		List<Lead> leads = new List<Lead>();
		if (recordCount == null || recordCount <= 0) {
			return leads;
		}
		for (Integer index = 1; index <= recordCount; index++) {
			leads.add(
				new Lead(
					FirstName = 'Test',
					LastName = 'Test Lead ' + index,
					Company = 'Test Company',
					Email = 'test.lead.' + index + '@example.com'
				)
			);
		}
		insert leads;
		return leads;
	}

	/**
	 * @name createAccount
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts one valid Account record.
	 * @param name Account name.
	 * @param cnae CNAE record assigned to the Account; one is created automatically when null.
	 * @return Inserted Account record.
	 */
	public static Account createAccount(String name, VL_CNAE__c cnae) {
		return createAccount(name, cnae, null, null, null, null, null);
	}

	/**
	 * @name createAccount
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts one valid Account record. Null or blank parameters use factory defaults.
	 * @param name Account name.
	 * @param cnae CNAE record assigned to the Account; one is created automatically when null.
	 * @param kamId User Id assigned to VL_KAM__c; the running user is used when null.
	 * @param market Value assigned to VL_Market__c; Agricultura is used when blank.
	 * @param marketSegment Value assigned to VL_MarketSegment__c; Autoridades locales is used when blank.
	 * @param megaMarket Value assigned to VL_MegaMarket__c; Industrial is used when blank.
	 * @param strategicClassification Value assigned to VL_StrategicClassification__c; Global is used when blank.
	 * @return Inserted Account record.
	 */
	public static Account createAccount(
		String name,
		VL_CNAE__c cnae,
		Id kamId,
		String market,
		String marketSegment,
		String megaMarket,
		String strategicClassification
	) {
		Account account = buildAccount(name, cnae, kamId, market, marketSegment, megaMarket, strategicClassification);
		insert account;
		return account;
	}

	/**
	 * @name createAccount
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Builds one valid Account record and inserts it, optionally bypassing active duplicate rules.
	 * @param name Account name.
	 * @param cnae CNAE record assigned to the Account; one is created automatically when null.
	 * @param allowDuplicates When true the insert bypasses active duplicate rules.
	 * @return Inserted Account record.
	 */
	public static Account createAccount(String name, VL_CNAE__c cnae, Boolean allowDuplicates) {
		Account account = buildAccount(name, cnae, null, null, null, null, null);
		Database.DMLOptions dmlOptions = new Database.DMLOptions();
		dmlOptions.duplicateRuleHeader.allowSave = allowDuplicates == true;
		Database.insert(account, dmlOptions);
		return account;
	}

	/**
	 * @name buildAccount
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Builds one valid Account record in memory without inserting it. Null or blank parameters use factory defaults.
	 * @param name Account name.
	 * @param cnae CNAE record assigned to the Account; one is created automatically when null.
	 * @param kamId User Id assigned to VL_KAM__c; the running user is used when null.
	 * @param market Value assigned to VL_Market__c; Agricultura is used when blank.
	 * @param marketSegment Value assigned to VL_MarketSegment__c; Autoridades locales is used when blank.
	 * @param megaMarket Value assigned to VL_MegaMarket__c; Industrial is used when blank.
	 * @param strategicClassification Value assigned to VL_StrategicClassification__c; Global is used when blank.
	 * @return Unsaved Account record.
	 */
	public static Account buildAccount(
		String name,
		VL_CNAE__c cnae,
		Id kamId,
		String market,
		String marketSegment,
		String megaMarket,
		String strategicClassification
	) {
		if (cnae == null) {
			cnae = createCNAE(null);
		}
		accountSequence++;
		return new Account(
			Name = String.isBlank(name) ? 'Test Account' : name,
			Type = 'Privado',
			Phone = '900000000',
			VL_FiscalNumber__c = buildFiscalNumber(accountSequence),
			VL_CNAECode__c = cnae.Id,
			VL_KAM__c = kamId == null ? UserInfo.getUserId() : kamId,
			VL_Market__c = String.isBlank(market) ? 'Agricultura' : market,
			VL_MarketSegment__c = String.isBlank(marketSegment) ? 'Autoridades locales' : marketSegment,
			VL_MegaMarket__c = String.isBlank(megaMarket) ? 'Industrial' : megaMarket,
			VL_StrategicClassification__c = String.isBlank(strategicClassification) ? 'Global' : strategicClassification
		);
	}

	/**
	 * @name createContact
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts one valid Contact record.
	 * @param lastName Contact last name.
	 * @param account Account related to the Contact; null leaves the Contact without an Account.
	 * @param email Contact email address.
	 * @return Inserted Contact record.
	 */
	public static Contact createContact(String lastName, Account account, String email) {
		Contact contact = new Contact(
			LastName = String.isBlank(lastName) ? 'Test Contact' : lastName,
			AccountId = account == null ? null : account.Id,
			Email = email,
			VL_Ambit__c = 'Comercial',
			VL_Active__c = true
		);
		insert contact;
		return contact;
	}

	/**
	 * @name createAccounts
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts N valid Account records using factory defaults.
	 * @param recordCount Number of Account records to create.
	 * @return Inserted Account records.
	 */
	public static List<Account> createAccounts(Integer recordCount) {
		return createAccounts(recordCount, null, null, null, null, null, null);
	}

	/**
	 * @name createAccounts
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts accounts in one DML operation using factory defaults.
	 * @param names Account names.
	 * @param cnae CNAE record assigned to each Account; one is created automatically when null.
	 * @return Inserted Account records.
	 */
	public static List<Account> createAccounts(List<String> names, VL_CNAE__c cnae) {
		List<Account> accounts = new List<Account>();
		if (names == null || names.isEmpty()) {
			return accounts;
		}
		if (cnae == null) {
			cnae = createCNAE(null);
		}
		for (String name : names) {
			accountSequence++;
			accounts.add(
				new Account(
					Name = String.isBlank(name) ? 'Test Account' : name,
					Type = 'Privado',
					Phone = '900000000',
					VL_FiscalNumber__c = buildFiscalNumber(accountSequence),
					VL_CNAECode__c = cnae.Id,
					VL_KAM__c = UserInfo.getUserId(),
					VL_Market__c = 'Agricultura',
					VL_MarketSegment__c = 'Autoridades locales',
					VL_MegaMarket__c = 'Industrial',
					VL_StrategicClassification__c = 'Global'
				)
			);
		}
		insert accounts;
		return accounts;
	}

	/**
	 * @name createAccounts
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts N valid Account records by calling createAccount for each record.
	 *              Null or blank parameters use factory defaults.
	 * @param recordCount Number of Account records to create.
	 * @param cnae CNAE record assigned to each Account; one is created automatically when null.
	 * @param kamId User Id assigned to VL_KAM__c; the running user is used when null.
	 * @param market Value assigned to VL_Market__c; Agricultura is used when blank.
	 * @param marketSegment Value assigned to VL_MarketSegment__c; Autoridades locales is used when blank.
	 * @param megaMarket Value assigned to VL_MegaMarket__c; Industrial is used when blank.
	 * @param strategicClassification Value assigned to VL_StrategicClassification__c; Global is used when blank.
	 * @return Inserted Account records.
	 */
	public static List<Account> createAccounts(
		Integer recordCount,
		VL_CNAE__c cnae,
		Id kamId,
		String market,
		String marketSegment,
		String megaMarket,
		String strategicClassification
	) {
		List<Account> accounts = new List<Account>();
		if (recordCount == null || recordCount <= 0) {
			return accounts;
		}
		for (Integer index = 1; index <= recordCount; index++) {
			accounts.add(createAccount('Test Account ' + index, cnae, kamId, market, marketSegment, megaMarket, strategicClassification));
		}
		return accounts;
	}

	/**
	 * @name createOpportunity
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts one valid Opportunity. Missing Account or company values are created automatically.
	 * @param name Opportunity name.
	 * @param account Account related to the Opportunity; one is created automatically when null.
	 * @return Inserted Opportunity record.
	 */
	public static Opportunity createOpportunity(String name, Account account) {
		return createOpportunity(name, account, null);
	}

	/**
	 * @name createOpportunity
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts one valid Opportunity using the supplied company lookup when available.
	 * @param name Opportunity name.
	 * @param account Account related to the Opportunity; one is created automatically when null.
	 * @param companyId Company lookup assigned to VL_Company__c; one is created automatically when null.
	 * @return Inserted Opportunity record.
	 */
	public static Opportunity createOpportunity(String name, Account account, Id companyId) {
		if (account == null) {
			account = createAccount(null, null);
		}
		if (companyId == null) {
			companyId = createCompany().Id;
		}
		Opportunity opportunity = new Opportunity(
			Name = String.isBlank(name) ? 'Test Opportunity' : name,
			AccountId = account.Id,
			VL_Company__c = companyId,
			StageName = 'Prospecting',
			CloseDate = Date.today().addDays(30)
		);
		insert opportunity;
		return opportunity;
	}

	/**
	 * @name createOpportunities
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts N valid Opportunity records using factory defaults.
	 * @param recordCount Number of Opportunity records to create.
	 * @return Inserted Opportunity records.
	 */
	public static List<Opportunity> createOpportunities(Integer recordCount) {
		return createOpportunities(recordCount, null, null);
	}

	/**
	 * @name createOpportunities
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts N valid Opportunity records in one DML operation.
	 * @param recordCount Number of Opportunity records to create.
	 * @param account Account related to each Opportunity; one is created automatically when null.
	 * @param companyId Company lookup assigned to each Opportunity; one is created automatically when null.
	 * @return Inserted Opportunity records.
	 */
	public static List<Opportunity> createOpportunities(Integer recordCount, Account account, Id companyId) {
		List<Opportunity> opportunities = new List<Opportunity>();
		if (recordCount == null || recordCount <= 0) {
			return opportunities;
		}
		if (account == null) {
			account = createAccount(null, null);
		}
		if (companyId == null) {
			companyId = createCompany().Id;
		}
		for (Integer index = 1; index <= recordCount; index++) {
			opportunities.add(
				new Opportunity(
					Name = 'Test Opportunity ' + index,
					AccountId = account.Id,
					VL_Company__c = companyId,
					StageName = 'Prospecting',
					CloseDate = Date.today().addDays(30)
				)
			);
		}
		insert opportunities;
		return opportunities;
	}

	/**
	 * @name createCase
	 * @creation date: 04/09/2026
	 * @author: Daniel Landete Martinez
	 * @description Creates and inserts one valid Case related to the supplied Account.
	 * @param account Account related to the Case; one is created automatically when null.
	 * @param subject Case subject.
	 * @return Inserted Case record.
	 */
	public static Case createCase(Account account, String subject) {
		if (account == null) {
			account = createAccount(null, null);
		}
		Case customerCase = new Case(
			AccountId = account.Id,
			Subject = String.isBlank(subject) ? 'Test Case' : subject,
			Status = 'New',
			Origin = 'Phone'
		);
		insert customerCase;
		return customerCase;
	}

	/**
	 * @name createContract
	 * @creation date: 04/09/2026
	 * @author: Daniel Landete Martinez
	 * @description Creates and inserts one activated Contract related to the supplied Account.
	 * @param account Account related to the Contract; one is created automatically when null.
	 * @return Inserted Contract record.
	 */
	public static Contract createContract(Account account) {
		if (account == null) {
			account = createAccount(null, null);
		}
		Contract contract = new Contract(AccountId = account.Id, StartDate = Date.today(), ContractTerm = 12, Status = 'Active');
		insert contract;
		return contract;
	}

	private static String buildSapId() {
		String randomDigits = String.valueOf(Crypto.getRandomLong()).replace('-', '');
		if (randomDigits.length() < 10) {
			randomDigits = randomDigits.leftPad(10, '0');
		}
		return 'TEST-' + randomDigits.right(10);
	}

	private static String buildFiscalNumber(Integer index) {
		String randomDigits = String.valueOf(Crypto.getRandomLong()).replace('-', '');
		if (randomDigits.length() < 7) {
			randomDigits = randomDigits.leftPad(7, '0');
		}
		String digits = randomDigits.right(7);
		Integer controlSum = 0;
		for (Integer position = 0; position < digits.length(); position++) {
			Integer digit = Integer.valueOf(digits.substring(position, position + 1));
			if (Math.mod(position, 2) == 0) {
				Integer doubledDigit = digit * 2;
				controlSum += doubledDigit > 9 ? doubledDigit - 9 : doubledDigit;
			} else {
				controlSum += digit;
			}
		}
		Integer controlDigit = Math.mod(10 - Math.mod(controlSum, 10), 10);
		return 'A' + digits + String.valueOf(controlDigit);
	}

	/**
	 * @name createCompany
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates and inserts one valid VL_Company__c record with unique SAP-style codes.
	 * @return Inserted VL_Company__c record.
	 */
	public static VL_Company__c createCompany() {
		VL_Company__c company = new VL_Company__c(Name = buildSapId(), VL_Code__c = buildSapId(), Type__c = 'Veolia');
		insert company;
		return company;
	}
}
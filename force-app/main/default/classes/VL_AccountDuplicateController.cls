/**
 * @name: VL_AccountDuplicateController
 * @version: 1.0
 * @creation date: 01/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description Read-only controller for Account duplicate resolution.
 */
@SuppressWarnings('PMD.ApexDoc')
public with sharing class VL_AccountDuplicateController {
	/**
	 * @name: DuplicateMatch
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Account candidate returned to the duplicate resolver.
	 */
	@SuppressWarnings('PMD.ApexDoc')
	public class DuplicateMatch {
		@AuraEnabled
		public Id accountId;
		@AuraEnabled
		public String accountName;
		@AuraEnabled
		public String fiscalNumber;
		@AuraEnabled
		public String matchType;

		public DuplicateMatch(Account account, String matchType) {
			this.accountId = account.Id;
			this.accountName = account.Name;
			this.fiscalNumber = account.VL_FiscalNumber__c;
			this.matchType = matchType;
		}
	}

	@AuraEnabled(cacheable=true)
	public static List<DuplicateMatch> findDuplicates(Id accountId, String fiscalNumber, String accountName) {
		if (!Schema.sObjectType.Account.isAccessible() || !areFieldsReadable()) {
			return new List<DuplicateMatch>();
		}
		String normalizedFiscalNumber = normalizeFiscalNumber(fiscalNumber);
		String normalizedName = normalizeName(accountName);
		if (String.isBlank(normalizedFiscalNumber) && String.isBlank(normalizedName)) {
			return new List<DuplicateMatch>();
		}

		String safeFiscalNumber = String.escapeSingleQuotes(normalizedFiscalNumber);
		String safeNamePattern = '%' + String.escapeSingleQuotes(normalizedName) + '%';
		List<Account> accounts;
		if (!String.isBlank(normalizedFiscalNumber) && !String.isBlank(normalizedName)) {
			accounts = [
				SELECT Id, Name, VL_FiscalNumber__c
				FROM Account
				WHERE VL_FiscalNumber__c = :safeFiscalNumber OR Name LIKE :safeNamePattern
				ORDER BY Name
				LIMIT 50
			];
		} else if (!String.isBlank(normalizedFiscalNumber)) {
			accounts = [
				SELECT Id, Name, VL_FiscalNumber__c
				FROM Account
				WHERE VL_FiscalNumber__c = :safeFiscalNumber
				ORDER BY Name
				LIMIT 50
			];
		} else {
			accounts = [
				SELECT Id, Name, VL_FiscalNumber__c
				FROM Account
				WHERE Name LIKE :safeNamePattern
				ORDER BY Name
				LIMIT 50
			];
		}
		List<DuplicateMatch> matches = new List<DuplicateMatch>();
		for (Account account : accounts) {
			if (account.Id == accountId) {
				continue;
			}
			Boolean fiscalMatches = !String.isBlank(normalizedFiscalNumber) && account.VL_FiscalNumber__c == normalizedFiscalNumber;
			matches.add(new DuplicateMatch(account, fiscalMatches ? 'CIF' : 'Nombre'));
		}
		return matches;
	}

	private static Boolean areFieldsReadable() {
		return Schema.sObjectType.Account.fields.Name.isAccessible() && Schema.sObjectType.Account.fields.VL_FiscalNumber__c.isAccessible();
	}

	private static String normalizeFiscalNumber(String fiscalNumber) {
		return String.isBlank(fiscalNumber) ? null : fiscalNumber.replaceAll('[\\s-]', '').toUpperCase();
	}

	private static String normalizeName(String accountName) {
		return String.isBlank(accountName) ? null : accountName.trim();
	}
}
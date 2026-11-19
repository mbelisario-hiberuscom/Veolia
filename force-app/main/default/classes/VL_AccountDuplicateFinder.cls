/**
 * @name VL_AccountDuplicateFinder
 * @version 1.0
 * @creation date: 02/09/2026
 * @author: Daniel Landete
 * @description Finds Account duplicates using the active Salesforce duplicate rules.
 */
public with sharing class VL_AccountDuplicateFinder {
	private static final String NAME_DUPLICATE_RULE = 'Account_VL_Name_Duplicate_Check';

	/**
	 * @name Request
	 * @version 1.0
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Input wrapper for the Account duplicate search Flow action.
	 */
	public class Request {
		@InvocableVariable(required=true)
		public Account account;
	}

	/**
	 * @name Response
	 * @version 1.0
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Output wrapper containing the name duplicate result for Flow.
	 */
	public class Response {
		@InvocableVariable
		public Boolean hasNameDuplicate = false;

		@InvocableVariable
		public String duplicateAccountName;

		@InvocableVariable
		public Id duplicateAccountId;
	}

	/**
	 * @name findNameDuplicates
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Finds Account name duplicates through the active Salesforce duplicate rules.
	 * @param requests Accounts to evaluate.
	 * @return One duplicate result for each input request.
	 */
	@InvocableMethod(
		label='Find Account Name Duplicates'
		description='Finds Account duplicates using the active Salesforce duplicate rules.'
	)
	public static List<Response> findNameDuplicates(List<Request> requests) {
		List<Response> responses = new List<Response>();
		List<Account> candidateAccounts = new List<Account>();
		List<Integer> responseIndexes = new List<Integer>();

		if (requests == null || requests.isEmpty()) {
			return responses;
		}

		for (Request request : requests) {
			responses.add(new Response());
			if (request != null && request.account != null && String.isNotBlank(request.account.Name)) {
				candidateAccounts.add(request.account);
				responseIndexes.add(responses.size() - 1);
			}
		}

		if (candidateAccounts.isEmpty()) {
			return responses;
		}

		List<Datacloud.FindDuplicatesResult> duplicateResults = Datacloud.FindDuplicates.findDuplicates(candidateAccounts);
		for (Integer resultIndex = 0; resultIndex < duplicateResults.size(); resultIndex++) {
			Response response = responses[responseIndexes[resultIndex]];
			for (Datacloud.DuplicateResult duplicateResult : duplicateResults[resultIndex].getDuplicateResults()) {
				if (duplicateResult.getDuplicateRule() != NAME_DUPLICATE_RULE) {
					continue;
				}

				for (Datacloud.MatchResult matchResult : duplicateResult.getMatchResults()) {
					for (Datacloud.MatchRecord matchRecord : matchResult.getMatchRecords()) {
						Account duplicateAccount = (Account) matchRecord.getRecord();
						response.hasNameDuplicate = true;
						response.duplicateAccountName = duplicateAccount.Name;
						response.duplicateAccountId = duplicateAccount.Id;
						break;
					}
					if (response.hasNameDuplicate) {
						break;
					}
				}
				if (response.hasNameDuplicate) {
					break;
				}
			}
		}

		return responses;
	}
}
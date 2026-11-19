/**
 * @name VL_FiscalNumberValidator
 * @version 1.0
 * @creation date: 02/09/2026
 * @author: Daniel Landete
 * @description Validates Spanish fiscal identification numbers for Flow.
 */
public with sharing class VL_FiscalNumberValidator {
	private static final String NIF_CONTROL_LETTERS = 'TRWAGMYFPDXBNJZSQVHLCKE';
	private static final String CIF_CONTROL_LETTERS = 'JABCDEFGHI';
	private static final Set<String> CIF_DIGIT_CONTROL_PREFIXES = new Set<String>{ 'A', 'B', 'E', 'H' };
	private static final Set<String> CIF_LETTER_CONTROL_PREFIXES = new Set<String>{ 'K', 'P', 'Q', 'S' };

	/**
	 * @name Request
	 * @version 1.0
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Input wrapper for fiscal number validation from Flow.
	 */
	public class Request {
		@InvocableVariable(required=false)
		public String fiscalNumber;
	}

	/**
	 * @name Response
	 * @version 1.0
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Output wrapper with validation result details for Flow.
	 */
	public class Response {
		@InvocableVariable
		public Boolean isValid = true;

		@InvocableVariable
		public Boolean isSpanishCompanyFiscalNumber = false;

		@InvocableVariable
		public String normalizedFiscalNumber;
	}

	/**
	 * @name validateFiscalNumbers
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Validates Spanish NIF, NIE and CIF fiscal numbers.
	 * @param requests Fiscal numbers to validate.
	 * @return One validation result for each input request.
	 */
	@InvocableMethod(label='Validate Spanish Fiscal Number' description='Validates Spanish NIF, NIE and CIF fiscal numbers.')
	public static List<Response> validateFiscalNumbers(List<Request> requests) {
		List<Response> responses = new List<Response>();

		if (requests == null || requests.isEmpty()) {
			return responses;
		}

		for (Request request : requests) {
			String normalizedFiscalNumber = normalize(request == null ? null : request.fiscalNumber);
			Response response = new Response();
			response.normalizedFiscalNumber = normalizedFiscalNumber;

			if (String.isBlank(normalizedFiscalNumber)) {
				responses.add(response);
				continue;
			}

			response.isSpanishCompanyFiscalNumber = isCifFormat(normalizedFiscalNumber);
			response.isValid = isValidNif(normalizedFiscalNumber) || isValidNie(normalizedFiscalNumber) || isValidCif(normalizedFiscalNumber);
			responses.add(response);
		}

		return responses;
	}

	private static String normalize(String fiscalNumber) {
		if (String.isBlank(fiscalNumber)) {
			return null;
		}

		return fiscalNumber.deleteWhitespace().replace('-', '').toUpperCase();
	}

	private static Boolean isValidNif(String fiscalNumber) {
		if (!Pattern.matches('^[0-9]{8}[A-Z]$', fiscalNumber)) {
			return false;
		}

		Integer documentNumber = Integer.valueOf(fiscalNumber.substring(0, 8));
		String expectedControlLetter = NIF_CONTROL_LETTERS.substring(Math.mod(documentNumber, 23), Math.mod(documentNumber, 23) + 1);
		return fiscalNumber.right(1) == expectedControlLetter;
	}

	private static Boolean isValidNie(String fiscalNumber) {
		if (!Pattern.matches('^[XYZ][0-9]{7}[A-Z]$', fiscalNumber)) {
			return false;
		}

		String numericPrefix = fiscalNumber.left(1) == 'X' ? '0' : fiscalNumber.left(1) == 'Y' ? '1' : '2';
		return isValidNif(numericPrefix + fiscalNumber.substring(1));
	}

	private static Boolean isCifFormat(String fiscalNumber) {
		return Pattern.matches('^[ABCDEFGHJNPQRSUVW][0-9]{7}[0-9A-J]$', fiscalNumber);
	}

	private static Boolean isValidCif(String fiscalNumber) {
		if (!isCifFormat(fiscalNumber)) {
			return false;
		}

		Integer sum = 0;
		for (Integer index = 1; index <= 7; index++) {
			Integer digit = Integer.valueOf(fiscalNumber.substring(index, index + 1));
			if (Math.mod(index, 2) == 0) {
				sum += digit;
			} else {
				Integer doubledDigit = digit * 2;
				sum += Math.mod(doubledDigit, 10) + (doubledDigit / 10);
			}
		}

		Integer controlDigit = Math.mod(10 - Math.mod(sum, 10), 10);
		String expectedDigit = String.valueOf(controlDigit);
		String expectedLetter = CIF_CONTROL_LETTERS.substring(controlDigit, controlDigit + 1);
		String actualControl = fiscalNumber.right(1);
		String prefix = fiscalNumber.left(1);

		if (CIF_DIGIT_CONTROL_PREFIXES.contains(prefix)) {
			return actualControl == expectedDigit;
		}
		if (CIF_LETTER_CONTROL_PREFIXES.contains(prefix)) {
			return actualControl == expectedLetter;
		}

		return actualControl == expectedDigit || actualControl == expectedLetter;
	}
}
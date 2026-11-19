/**
 * @name: VL_SpanishFiscalNumberValidator
 * @version: 1.0
 * @creation date: 01/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description Validates the control algorithm for Spanish NIF, NIE and CIF identifiers.
 */
@SuppressWarnings('PMD.ApexDoc')
public inherited sharing class VL_SpanishFiscalNumberValidator {
	private static final String NIF_CONTROL_LETTERS = 'TRWAGMYFPDXBNJZSQVHLCKE';
	private static final String CIF_CONTROL_LETTERS = 'JABCDEFGHI';
	private static final String CIF_ALLOWED_LETTERS = 'ABCDEFGHJNPQRSUVW';

	public static Boolean isValid(String fiscalNumber) {
		String normalizedFiscalNumber = normalize(fiscalNumber);
		if (String.isBlank(normalizedFiscalNumber) || normalizedFiscalNumber.length() != 9) {
			return false;
		}
		String firstCharacter = normalizedFiscalNumber.substring(0, 1);
		if (isDigit(firstCharacter)) {
			return isValidNif(normalizedFiscalNumber);
		}
		if ('XYZ'.contains(firstCharacter)) {
			return isValidNie(normalizedFiscalNumber);
		}
		return isValidCif(normalizedFiscalNumber);
	}

	private static Boolean isValidNif(String fiscalNumber) {
		if (!isDigits(fiscalNumber.substring(0, 8)) || !isLetter(fiscalNumber.substring(8, 9))) {
			return false;
		}
		Integer numericValue = Integer.valueOf(fiscalNumber.substring(0, 8));
		Integer controlIndex = Math.mod(numericValue, 23);
		return fiscalNumber.substring(8, 9) == NIF_CONTROL_LETTERS.substring(controlIndex, controlIndex + 1);
	}

	private static Boolean isValidNie(String fiscalNumber) {
		String prefix = fiscalNumber.substring(0, 1);
		String numericPrefix = prefix == 'X' ? '0' : prefix == 'Y' ? '1' : '2';
		return isValidNif(numericPrefix + fiscalNumber.substring(1));
	}

	private static Boolean isValidCif(String fiscalNumber) {
		String prefix = fiscalNumber.substring(0, 1);
		if (!CIF_ALLOWED_LETTERS.contains(prefix) || !isDigits(fiscalNumber.substring(1, 8))) {
			return false;
		}
		Integer total = 0;
		for (Integer index = 1; index <= 7; index++) {
			Integer digit = Integer.valueOf(fiscalNumber.substring(index, index + 1));
			if (Math.mod(index, 2) == 1) {
				Integer doubled = digit * 2;
				total += doubled > 9 ? doubled - 9 : doubled;
			} else {
				total += digit;
			}
		}
		Integer controlDigit = Math.mod(10 - Math.mod(total, 10), 10);
		String control = fiscalNumber.substring(8, 9);
		if (isDigit(control)) {
			return Integer.valueOf(control) == controlDigit;
		}
		return isLetter(control) && control == CIF_CONTROL_LETTERS.substring(controlDigit, controlDigit + 1);
	}

	private static Boolean isDigits(String value) {
		if (String.isBlank(value)) {
			return false;
		}
		for (Integer index = 0; index < value.length(); index++) {
			if (!isDigit(value.substring(index, index + 1))) {
				return false;
			}
		}
		return true;
	}

	private static Boolean isDigit(String value) {
		return String.isNotBlank(value) && value.length() == 1 && '0123456789'.contains(value);
	}

	private static Boolean isLetter(String value) {
		return String.isNotBlank(value) && value.length() == 1 && 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.contains(value);
	}

	private static String normalize(String fiscalNumber) {
		return String.isBlank(fiscalNumber) ? null : fiscalNumber.replaceAll('[\\s-]', '').toUpperCase();
	}
}
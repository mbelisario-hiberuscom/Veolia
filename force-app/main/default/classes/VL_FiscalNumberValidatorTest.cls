/**
 * @name VL_FiscalNumberValidatorTest
 * @version 1.0
 * @creation date: 02/09/2026
 * @author: Daniel Landete
 * @description Tests Spanish fiscal number validation for Flow.
 */
@IsTest
private class VL_FiscalNumberValidatorTest {
	/**
	 * @name validFiscalNumbersReturnValidResults
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Verifies that valid NIF, NIE and CIF values are accepted.
	 */
	@IsTest
	static void validFiscalNumbersReturnValidResults() {
		List<VL_FiscalNumberValidator.Request> requests = new List<VL_FiscalNumberValidator.Request>{
			buildRequest('12345678Z'),
			buildRequest('X1234567L'),
			buildRequest('A58818501')
		};

		Test.startTest();
		List<VL_FiscalNumberValidator.Response> results = VL_FiscalNumberValidator.validateFiscalNumbers(requests);
		Test.stopTest();

		System.assertEquals(3, results.size(), 'One result must be returned per request.');
		System.assertEquals(true, results[0].isValid, 'A valid NIF must be accepted.');
		System.assertEquals(false, results[0].isSpanishCompanyFiscalNumber, 'A NIF is not a company CIF.');
		System.assertEquals(true, results[1].isValid, 'A valid NIE must be accepted.');
		System.assertEquals(false, results[1].isSpanishCompanyFiscalNumber, 'A NIE is not a company CIF.');
		System.assertEquals(true, results[2].isValid, 'A valid CIF must be accepted.');
		System.assertEquals(true, results[2].isSpanishCompanyFiscalNumber, 'A CIF must be flagged as a company fiscal number.');
	}

	/**
	 * @name invalidFiscalNumbersReturnInvalidResults
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Verifies that fiscal numbers with invalid format or control values are rejected.
	 */
	@IsTest
	static void invalidFiscalNumbersReturnInvalidResults() {
		List<VL_FiscalNumberValidator.Request> requests = new List<VL_FiscalNumberValidator.Request>{
			buildRequest('12345678A'),
			buildRequest('X1234567A'),
			buildRequest('A58818502'),
			buildRequest('invalid')
		};

		Test.startTest();
		List<VL_FiscalNumberValidator.Response> results = VL_FiscalNumberValidator.validateFiscalNumbers(requests);
		Test.stopTest();

		System.assertEquals(4, results.size(), 'One result must be returned per request.');
		for (VL_FiscalNumberValidator.Response result : results) {
			System.assertEquals(false, result.isValid, 'Invalid fiscal numbers must be rejected.');
		}
	}

	/**
	 * @name blankFiscalNumberReturnsValidResult
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Verifies that blank fiscal number input remains optional.
	 */
	@IsTest
	static void blankFiscalNumberReturnsValidResult() {
		List<VL_FiscalNumberValidator.Request> requests = new List<VL_FiscalNumberValidator.Request>{ buildRequest(null) };

		Test.startTest();
		List<VL_FiscalNumberValidator.Response> results = VL_FiscalNumberValidator.validateFiscalNumbers(requests);
		Test.stopTest();

		System.assertEquals(1, results.size(), 'One result must be returned for one request.');
		System.assertEquals(true, results[0].isValid, 'Blank fiscal number input must remain optional.');
		System.assertEquals(false, results[0].isSpanishCompanyFiscalNumber, 'Blank input is not a company CIF.');
	}

	private static VL_FiscalNumberValidator.Request buildRequest(String fiscalNumber) {
		VL_FiscalNumberValidator.Request request = new VL_FiscalNumberValidator.Request();
		request.fiscalNumber = fiscalNumber;
		return request;
	}
}
/**
 * @name VL_GoogleDriveException
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Typed exception for Google Drive integration failures.
 *              Carries an error category that drives the retry policy.
 */
public class VL_GoogleDriveException extends Exception {
	/**
	 * @name ErrorCategory
	 * @version 1.0
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Classifies the root cause of a Google Drive API failure.
	 *              RECOVERABLE_ values trigger a retry; TERMINAL_ values stop retries immediately.
	 */
	public enum ErrorCategory {
		RECOVERABLE_QUOTA,
		RECOVERABLE_TIMEOUT,
		RECOVERABLE_SERVER,
		TERMINAL_AUTH,
		TERMINAL_NOT_FOUND,
		TERMINAL_VALIDATION,
		TERMINAL_CONFIG
	}

	private ErrorCategory category;
	private Integer httpStatusCode;

	/**
	 * @name VL_GoogleDriveException
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Constructs an exception with a message and error category.
	 * @param message Human-readable error description.
	 * @param cat Error category controlling retry behaviour.
	 */
	public VL_GoogleDriveException(String message, ErrorCategory cat) {
		this(message);
		this.category = cat;
	}

	/**
	 * @name VL_GoogleDriveException
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Constructs an exception with message, category, and HTTP status code.
	 * @param message Human-readable error description.
	 * @param cat Error category controlling retry behaviour.
	 * @param httpStatus HTTP status code from the Google Drive API response.
	 */
	public VL_GoogleDriveException(String message, ErrorCategory cat, Integer httpStatus) {
		this(message);
		this.category = cat;
		this.httpStatusCode = httpStatus;
	}

	/**
	 * @name getCategory
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Returns the error category for this exception.
	 * @return ErrorCategory enum value.
	 */
	public ErrorCategory getCategory() {
		return this.category;
	}

	/**
	 * @name getHttpStatus
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Returns the HTTP status code associated with this exception, or null when not applicable.
	 * @return Integer HTTP status code, or null.
	 */
	public Integer getHttpStatus() {
		return this.httpStatusCode;
	}

	/**
	 * @name isRecoverable
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Returns true when the error is transient and a retry may succeed.
	 * @return Boolean true for RECOVERABLE_ categories.
	 */
	public Boolean isRecoverable() {
		return this.category == ErrorCategory.RECOVERABLE_QUOTA ||
			this.category == ErrorCategory.RECOVERABLE_TIMEOUT ||
			this.category == ErrorCategory.RECOVERABLE_SERVER;
	}
}
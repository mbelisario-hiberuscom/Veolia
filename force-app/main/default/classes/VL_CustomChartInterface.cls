/**
 * @name VL_CustomChartInterface
 * @version 1.0
 * @creation date 05/05/2026
 * @author Jesus Piriz
 * @description Interface for classes that will be invoked from the vl_CustomXChart LWC
 */
public interface VL_CustomChartInterface {
	/**
	 * @name getData
	 * @version 1.0
	 * @creation date 05/05/2026
	 * @author Jesus Piriz
	 * @description Method that will execute the query to retrieve the records to be displayed.
	 * @param filter
	 * @return List<VL_CustomChartData>
	 * @exception N/A
	 * @throws N/A
	 */
	List<VL_CustomChartData> getData(String filter);
}
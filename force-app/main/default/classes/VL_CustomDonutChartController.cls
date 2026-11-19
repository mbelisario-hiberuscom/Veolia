/**
 * @name VL_CustomDonutChartController
 * @version 1.0
 * @creation date 05/05/2025
 * @author Jesus Piriz
 * @description Controller class for vl_CustomXChart
 */
public with sharing class VL_CustomDonutChartController {
	/**
	 * @name: getData
	 * @version 1.0
	 * @creation date 05/05/2025
	 * @author Jesus Piriz
	 * @description Method that will execute the query to retrieve the records to be displayed.
	 * @param controllerClass
	 * @param filter
	 * @return List<VL_CustomChartData>
	 * @exception N/A
	 * @throws N/A
	 */
	@AuraEnabled
	public static List<VL_CustomChartData> getData(String controllerClass, String filter) {
		Type projectClassType = Type.forName(controllerClass);
		VL_CustomChartInterface projectClass = (VL_CustomChartInterface) projectClassType.newInstance();
		return projectClass.getData(filter);
	}
}
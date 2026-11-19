/**
 * @name VL_CustomChartDataset
 * @version 2.0
 * @creation date 12/05/2026
 * @author Jesus Piriz
 * @description Holds the data for a single chart dataset (values, chart type, chart title,
 *              optional hex color and optional sort order for legend positioning).
 */
public with sharing class VL_CustomChartDataset {
	@AuraEnabled
	public List<String> values;
	@AuraEnabled
	public String chartType;
	@AuraEnabled
	public String chartTitle;
	@AuraEnabled
	public String color;
	@AuraEnabled
	public Integer order;

	/**
	 * @name VL_CustomChartDataset
	 * @version 1.0
	 * @creation date 12/05/2026
	 * @author Jesus Piriz
	 * @description Class constructor
	 * @param values
	 * @param chartType
	 * @param chartTitle
	 */
	public VL_CustomChartDataset(List<String> values, String chartType, String chartTitle) {
		this.values = values;
		this.chartType = chartType;
		this.chartTitle = chartTitle;
	}
}
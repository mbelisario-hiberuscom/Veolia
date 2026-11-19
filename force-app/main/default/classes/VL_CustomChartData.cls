/**
 * @name VL_CustomChartData
 * @version 2.0
 * @creation date 05/05/2025
 * @author Jesus Piriz
 * @description Support class for chart data
 */
public with sharing class VL_CustomChartData {
	@AuraEnabled
	public List<VL_CustomChartLabel> labels;
	@AuraEnabled
	public List<VL_CustomChartDataset> datasets;
	@AuraEnabled
	public Boolean showDiff;
	@AuraEnabled
	public String diffTitle;
	@AuraEnabled
	public Boolean showStacked;
	@AuraEnabled
	public Boolean showPercentInTotal;

	/**
	 * @name VL_CustomChartData
	 * @version 2.0
	 * @creation date 05/05/2025
	 * @author Jesus Piriz
	 * @description Class constructor
	 * @param labels
	 * @param datasets
	 */
	public VL_CustomChartData(List<VL_CustomChartLabel> labels, List<VL_CustomChartDataset> datasets) {
		this.labels = labels;
		this.datasets = datasets;
	}
}
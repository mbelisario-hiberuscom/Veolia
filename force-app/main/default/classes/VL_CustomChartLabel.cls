/**
 * @name VL_CustomChartLabel
 * @version 2.0
 * @creation date 08/05/2026
 * @author Jesus Piriz
 * @description Structure representing a chart label with a display text, identifier value,
 *              optional sort order and optional hex color. When order is null the LWC falls
 *              back to alphabetical sorting. When color is null the LWC assigns a default color.
 */
public with sharing class VL_CustomChartLabel {
	@AuraEnabled
	public String text;
	@AuraEnabled
	public String value;
	@AuraEnabled
	public Integer order;
	@AuraEnabled
	public String color;

	/**
	 * @name VL_CustomChartLabel
	 * @description Constructor
	 * @param text Display text for the label
	 * @param value Identifier value for the label
	 */
	public VL_CustomChartLabel(String text, String value) {
		this.text = text;
		this.value = value;
	}
}
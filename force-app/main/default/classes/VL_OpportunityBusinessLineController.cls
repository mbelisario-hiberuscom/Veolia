/**
 * @name VL_OpportunityBusinessLineController
 * @version 1.0
 * @creation date 17/08/2026
 * @author Jesus Piriz
 * @description Provides mocked opportunity counts grouped by business line and status for a stacked bar chart.
 */
public with sharing class VL_OpportunityBusinessLineController implements VL_CustomChartInterface {
	private static final String ALIVE_STATUS_COLOR = '#00B86B';
	private static final String WON_STATUS_COLOR = '#1769D1';
	private static final String LOST_STATUS_COLOR = '#E83A3A';

	/**
	 * @name getData
	 * @version 1.0
	 * @creation date 17/08/2026
	 * @author Jesus Piriz
	 * @description Returns mocked opportunity counts grouped by business line and status. The production query
	 *              is prepared but kept commented until VL_BusinessLine__c exists in the org.
	 * @param filter Optional chart filter reserved for the production query.
	 * @return List<VL_CustomChartData>
	 */
	public List<VL_CustomChartData> getData(String filter) {
		if (String.isBlank(filter)) {
			return new List<VL_CustomChartData>();
		}

		Id accountId;
		try {
			accountId = Id.valueOf(filter);
		} catch (Exception invalidIdException) {
			return new List<VL_CustomChartData>();
		}
		List<AggregateResult> results = [
			SELECT VL_BusinessLine__c businessLine, IsClosed isClosed, IsWon isWon, COUNT(Id) opportunityCount
			FROM Opportunity
			WHERE AccountId = :accountId AND VL_BusinessLine__c != NULL
			GROUP BY VL_BusinessLine__c, IsClosed, IsWon
			ORDER BY VL_BusinessLine__c
		];
		return buildChartData(results);
	}

	/**
	 * @name buildChartData
	 * @version 1.0
	 * @creation date 17/08/2026
	 * @author Jesus Piriz
	 * @description Maps grouped opportunity results to three status datasets for the generic stacked bar chart DTO.
	 * @param results Grouped opportunity query results.
	 * @return List<VL_CustomChartData>
	 */
	private static List<VL_CustomChartData> buildChartData(List<AggregateResult> results) {
		List<VL_CustomChartLabel> labels = new List<VL_CustomChartLabel>();
		Map<String, Integer> businessLineIndexes = new Map<String, Integer>();
		List<String> aliveValues = new List<String>();
		List<String> wonValues = new List<String>();
		List<String> lostValues = new List<String>();

		for (AggregateResult result : results) {
			String businessLine = (String) result.get('businessLine');
			if (!businessLineIndexes.containsKey(businessLine)) {
				businessLineIndexes.put(businessLine, labels.size());
				labels.add(new VL_CustomChartLabel(businessLine, businessLine));
				aliveValues.add('0');
				wonValues.add('0');
				lostValues.add('0');
			}

			Integer labelIndex = businessLineIndexes.get(businessLine);
			Integer opportunityCount = (Integer) result.get('opportunityCount');
			Boolean isClosed = (Boolean) result.get('isClosed');
			Boolean isWon = (Boolean) result.get('isWon');
			if (isClosed == false) {
				aliveValues.set(labelIndex, String.valueOf(opportunityCount));
			} else if (isWon == true) {
				wonValues.set(labelIndex, String.valueOf(opportunityCount));
			} else {
				lostValues.set(labelIndex, String.valueOf(opportunityCount));
			}
		}

		if (labels.isEmpty()) {
			return new List<VL_CustomChartData>();
		}

		return buildStackedChartData(labels, aliveValues, wonValues, lostValues);
	}

	/**
	 * @name buildStackedChartData
	 * @version 1.0
	 * @creation date 17/08/2026
	 * @author Jesus Piriz
	 * @description Builds the stacked bar chart response with one dataset per opportunity status.
	 * @param labels Business line labels for the x-axis.
	 * @param aliveValues Counts for open opportunities.
	 * @param wonValues Counts for won opportunities.
	 * @param lostValues Counts for lost opportunities.
	 * @return List<VL_CustomChartData>
	 */
	private static List<VL_CustomChartData> buildStackedChartData(
		List<VL_CustomChartLabel> labels,
		List<String> aliveValues,
		List<String> wonValues,
		List<String> lostValues
	) {
		VL_CustomChartDataset aliveDataset = new VL_CustomChartDataset(aliveValues, 'bar', 'Vivas');
		aliveDataset.color = ALIVE_STATUS_COLOR;
		aliveDataset.order = 0;
		VL_CustomChartDataset wonDataset = new VL_CustomChartDataset(wonValues, 'bar', 'Ganadas');
		wonDataset.color = WON_STATUS_COLOR;
		wonDataset.order = 1;
		VL_CustomChartDataset lostDataset = new VL_CustomChartDataset(lostValues, 'bar', 'Perdidas');
		lostDataset.color = LOST_STATUS_COLOR;
		lostDataset.order = 2;

		VL_CustomChartData chartData = new VL_CustomChartData(
			labels,
			new List<VL_CustomChartDataset>{ aliveDataset, wonDataset, lostDataset }
		);
		chartData.showStacked = true;
		return new List<VL_CustomChartData>{ chartData };
	}
}
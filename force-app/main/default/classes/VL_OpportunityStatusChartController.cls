/**
 * @name VL_OpportunityStatusChartController
 * @version 1.0
 * @creation date 14/08/2026
 * @author Jesus Piriz
 * @description Provides mocked opportunity counts grouped by business status for an account donut chart.
 */
public with sharing class VL_OpportunityStatusChartController implements VL_CustomChartInterface {
	private static final String ALIVE_STATUS_COLOR = '#00B86B';
	private static final String WON_STATUS_COLOR = '#1769D1';
	private static final String LOST_STATUS_COLOR = '#E83A3A';

	/**
	 * @name getData
	 * @version 1.0
	 * @creation date 14/08/2026
	 * @author Jesus Piriz
	 * @description Returns opportunity counts grouped by business status for the account Id received in filter.
	 *              The production query is kept commented while the chart is being tested with mock data.
	 * @param filter Account Id received by the generic donut chart controller
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
			SELECT IsClosed isClosed, IsWon isWon, COUNT(Id) opportunityCount
			FROM Opportunity
			WHERE AccountId = :accountId
			GROUP BY IsClosed, IsWon
			ORDER BY IsClosed, IsWon
		];
		return buildChartData(results);
	}

	/**
	 * @name buildChartData
	 * @version 1.0
	 * @creation date 14/08/2026
	 * @author Jesus Piriz
	 * @description Maps grouped opportunity results to the fixed Vivas, Ganadas and Perdidas order.
	 * @param results Grouped opportunity query results
	 * @return List<VL_CustomChartData>
	 */
	private static List<VL_CustomChartData> buildChartData(List<AggregateResult> results) {
		List<String> values = new List<String>{ '0', '0', '0' };

		for (AggregateResult result : results) {
			Integer opportunityCount = (Integer) result.get('opportunityCount');
			Boolean isClosed = (Boolean) result.get('isClosed');
			Boolean isWon = (Boolean) result.get('isWon');
			Integer statusIndex = isClosed == false ? 0 : isWon == true ? 1 : 2;
			values.set(statusIndex, String.valueOf(opportunityCount));
		}

		if (results.isEmpty()) {
			return new List<VL_CustomChartData>();
		}

		return buildStatusChartData(values);
	}

	/**
	 * @name buildStatusChartData
	 * @version 1.0
	 * @creation date 17/08/2026
	 * @author Jesus Piriz
	 * @description Builds the donut response with fixed status order and colors.
	 * @param values Counts ordered as Vivas, Ganadas and Perdidas.
	 * @return List<VL_CustomChartData>
	 */
	private static List<VL_CustomChartData> buildStatusChartData(List<String> values) {
		List<VL_CustomChartLabel> labels = new List<VL_CustomChartLabel>{
			new VL_CustomChartLabel('Vivas', 'Vivas'),
			new VL_CustomChartLabel('Ganadas', 'Ganadas'),
			new VL_CustomChartLabel('Perdidas', 'Perdidas')
		};
		labels[0].order = 0;
		labels[1].order = 1;
		labels[2].order = 2;
		labels[0].color = ALIVE_STATUS_COLOR;
		labels[1].color = WON_STATUS_COLOR;
		labels[2].color = LOST_STATUS_COLOR;

		return new List<VL_CustomChartData>{
			new VL_CustomChartData(labels, new List<VL_CustomChartDataset>{ new VL_CustomChartDataset(values, 'doughnut', 'Opportunities') })
		};
	}
}
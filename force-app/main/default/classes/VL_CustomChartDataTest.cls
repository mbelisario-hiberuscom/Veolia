/**
 * @name VL_CustomChartDataTest
 * @version 1.0
 * @creation date 04/09/2026
 * @author Jesus Piriz
 * @description Tests for the chart support DTOs VL_CustomChartData, VL_CustomChartDataset and VL_CustomChartLabel.
 */
@IsTest
private with sharing class VL_CustomChartDataTest {
	/**
	 * @name: chartLabelStoresConstructorAndOptionalValues
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies VL_CustomChartLabel keeps constructor values and optional order and color.
	 */
	@IsTest
	static void chartLabelStoresConstructorAndOptionalValues() {
		Test.startTest();
		VL_CustomChartLabel label = new VL_CustomChartLabel('Vivas', 'Vivas');
		label.order = 1;
		label.color = '#00B86B';
		Test.stopTest();

		System.assertEquals('Vivas', label.text, 'The display text should match the constructor value.');
		System.assertEquals('Vivas', label.value, 'The identifier value should match the constructor value.');
		System.assertEquals(1, label.order, 'The optional order should be stored.');
		System.assertEquals('#00B86B', label.color, 'The optional color should be stored.');
	}

	/**
	 * @name: chartDatasetStoresConstructorAndOptionalValues
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies VL_CustomChartDataset keeps constructor values and optional color and order.
	 */
	@IsTest
	static void chartDatasetStoresConstructorAndOptionalValues() {
		Test.startTest();
		VL_CustomChartDataset dataset = new VL_CustomChartDataset(new List<String>{ '1', '2' }, 'bar', 'Opportunities');
		dataset.color = '#1769D1';
		dataset.order = 2;
		Test.stopTest();

		System.assertEquals(2, dataset.values.size(), 'The dataset should store the provided values.');
		System.assertEquals('bar', dataset.chartType, 'The chart type should match the constructor value.');
		System.assertEquals('Opportunities', dataset.chartTitle, 'The chart title should match the constructor value.');
		System.assertEquals('#1769D1', dataset.color, 'The optional color should be stored.');
		System.assertEquals(2, dataset.order, 'The optional order should be stored.');
	}

	/**
	 * @name: chartDataStoresConstructorAndOptionalFlags
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies VL_CustomChartData keeps constructor collections and optional display flags.
	 */
	@IsTest
	static void chartDataStoresConstructorAndOptionalFlags() {
		List<VL_CustomChartLabel> labels = new List<VL_CustomChartLabel>{ new VL_CustomChartLabel('Vivas', 'Vivas') };
		List<VL_CustomChartDataset> datasets = new List<VL_CustomChartDataset>{
			new VL_CustomChartDataset(new List<String>{ '5' }, 'doughnut', 'Opportunities')
		};

		Test.startTest();
		VL_CustomChartData chartData = new VL_CustomChartData(labels, datasets);
		chartData.showDiff = true;
		chartData.diffTitle = 'Difference';
		chartData.showStacked = true;
		chartData.showPercentInTotal = true;
		Test.stopTest();

		System.assertEquals(1, chartData.labels.size(), 'The chart data should store the provided labels.');
		System.assertEquals(1, chartData.datasets.size(), 'The chart data should store the provided datasets.');
		System.assertEquals(true, chartData.showDiff, 'The showDiff flag should be stored.');
		System.assertEquals('Difference', chartData.diffTitle, 'The diff title should be stored.');
		System.assertEquals(true, chartData.showStacked, 'The showStacked flag should be stored.');
		System.assertEquals(true, chartData.showPercentInTotal, 'The showPercentInTotal flag should be stored.');
	}
}
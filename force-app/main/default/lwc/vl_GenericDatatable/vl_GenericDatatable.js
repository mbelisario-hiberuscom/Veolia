import LightningDatatable from 'lightning/datatable';
import picklistColorCellTemplate from './vl_PicklistColorCellTemplate.html';
import ratingCellTemplate from './vl_RatingCellTemplate.html';

export default class VlGenericDatatable extends LightningDatatable {
	static customTypes = {
		Rating: {
			template: ratingCellTemplate,
			standardCellLayout: true
		},
		PicklistColor: {
			template: picklistColorCellTemplate,
			standardCellLayout: true,
			typeAttributes: ['colorValue']
		}
	};
}
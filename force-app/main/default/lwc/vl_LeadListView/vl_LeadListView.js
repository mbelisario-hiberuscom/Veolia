import { LightningElement } from 'lwc';

export default class Vl_LeadListView extends LightningElement {
	title = 'Leads';
	connectedCallback() {
		document.title = this.title;
	}
}
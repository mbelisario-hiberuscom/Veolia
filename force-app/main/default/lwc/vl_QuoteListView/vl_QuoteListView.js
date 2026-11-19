import { LightningElement } from 'lwc';

export default class Vl_QuoteListView extends LightningElement {
	title = 'Presupuestos';
	connectedCallback() {
		document.title = this.title;
	}
}
import { LightningElement } from 'lwc';

export default class Vl_ContractListView extends LightningElement {
	title = 'Contratos';
	connectedCallback() {
		document.title = this.title;
	}
}
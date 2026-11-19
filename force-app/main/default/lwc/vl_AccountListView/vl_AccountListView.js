import { LightningElement } from 'lwc';

export default class VlAccountListView extends LightningElement {
	title = 'Cuentas';
	connectedCallback() {
		document.title = this.title;
	}
}
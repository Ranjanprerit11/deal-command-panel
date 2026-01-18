import { LightningElement, api } from 'lwc';

export default class DealSignalCard extends LightningElement {
    @api signalId;
    @api signalName = '';
    @api signalValue = '';
    @api iconName = 'utility:info';
    @api severity = 'neutral'; // 'low', 'medium', 'high', 'neutral'

    get cardClass() {
        const baseClass = 'signal-card slds-card';
        return `${baseClass} severity-${this.severity}`;
    }

    get iconVariant() {
        switch (this.severity) {
            case 'high':
                return 'error';
            case 'medium':
                return 'warning';
            case 'low':
                return 'success';
            default:
                return '';
        }
    }

    get severityIndicatorClass() {
        return `severity-indicator severity-${this.severity}`;
    }
}

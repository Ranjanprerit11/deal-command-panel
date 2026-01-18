import { LightningElement, api } from 'lwc';

export default class DealHealthBadge extends LightningElement {
    @api healthLabel = 'Unknown';
    @api healthScore = 0;

    get badgeClass() {
        const baseClass = 'health-badge slds-badge slds-badge_pill';
        
        switch (this.healthLabel) {
            case 'Healthy':
                return `${baseClass} badge-healthy`;
            case 'Watch':
                return `${baseClass} badge-watch`;
            case 'At Risk':
                return `${baseClass} badge-at-risk`;
            default:
                return `${baseClass} badge-unknown`;
        }
    }

    get iconName() {
        switch (this.healthLabel) {
            case 'Healthy':
                return 'utility:success';
            case 'Watch':
                return 'utility:warning';
            case 'At Risk':
                return 'utility:error';
            default:
                return 'utility:help';
        }
    }

    get displayText() {
        return this.healthLabel;
    }
}

import { createElement } from 'lwc';
import DealHealthBadge from 'c/dealHealthBadge';

describe('c-deal-health-badge', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders healthy badge with correct styling', () => {
        const element = createElement('c-deal-health-badge', {
            is: DealHealthBadge
        });
        element.healthLabel = 'Healthy';
        element.healthScore = 85;
        document.body.appendChild(element);

        const badge = element.shadowRoot.querySelector('.health-badge');
        expect(badge).not.toBeNull();
        expect(badge.classList.contains('badge-healthy')).toBe(true);
    });

    it('renders watch badge with correct styling', () => {
        const element = createElement('c-deal-health-badge', {
            is: DealHealthBadge
        });
        element.healthLabel = 'Watch';
        element.healthScore = 60;
        document.body.appendChild(element);

        const badge = element.shadowRoot.querySelector('.health-badge');
        expect(badge).not.toBeNull();
        expect(badge.classList.contains('badge-watch')).toBe(true);
    });

    it('renders at risk badge with correct styling', () => {
        const element = createElement('c-deal-health-badge', {
            is: DealHealthBadge
        });
        element.healthLabel = 'At Risk';
        element.healthScore = 30;
        document.body.appendChild(element);

        const badge = element.shadowRoot.querySelector('.health-badge');
        expect(badge).not.toBeNull();
        expect(badge.classList.contains('badge-at-risk')).toBe(true);
    });

    it('displays correct icon for healthy status', () => {
        const element = createElement('c-deal-health-badge', {
            is: DealHealthBadge
        });
        element.healthLabel = 'Healthy';
        document.body.appendChild(element);

        const icon = element.shadowRoot.querySelector('lightning-icon');
        expect(icon.iconName).toBe('utility:success');
    });

    it('displays correct icon for watch status', () => {
        const element = createElement('c-deal-health-badge', {
            is: DealHealthBadge
        });
        element.healthLabel = 'Watch';
        document.body.appendChild(element);

        const icon = element.shadowRoot.querySelector('lightning-icon');
        expect(icon.iconName).toBe('utility:warning');
    });

    it('displays correct icon for at risk status', () => {
        const element = createElement('c-deal-health-badge', {
            is: DealHealthBadge
        });
        element.healthLabel = 'At Risk';
        document.body.appendChild(element);

        const icon = element.shadowRoot.querySelector('lightning-icon');
        expect(icon.iconName).toBe('utility:error');
    });

    it('displays the health label text', () => {
        const element = createElement('c-deal-health-badge', {
            is: DealHealthBadge
        });
        element.healthLabel = 'Healthy';
        document.body.appendChild(element);

        const badgeText = element.shadowRoot.querySelector('.badge-text');
        expect(badgeText.textContent).toBe('Healthy');
    });

    it('handles unknown status gracefully', () => {
        const element = createElement('c-deal-health-badge', {
            is: DealHealthBadge
        });
        element.healthLabel = 'Unknown';
        document.body.appendChild(element);

        const badge = element.shadowRoot.querySelector('.health-badge');
        expect(badge.classList.contains('badge-unknown')).toBe(true);
        
        const icon = element.shadowRoot.querySelector('lightning-icon');
        expect(icon.iconName).toBe('utility:help');
    });
});

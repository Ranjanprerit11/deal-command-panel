import { createElement } from 'lwc';
import DealSignalCard from 'c/dealSignalCard';

describe('c-deal-signal-card', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders with correct signal name and value', () => {
        const element = createElement('c-deal-signal-card', {
            is: DealSignalCard
        });
        element.signalName = 'Stage Age';
        element.signalValue = '10 days';
        element.iconName = 'utility:clock';
        element.severity = 'low';
        document.body.appendChild(element);

        const signalName = element.shadowRoot.querySelector('.signal-name');
        const signalValue = element.shadowRoot.querySelector('.signal-value');
        
        expect(signalName.textContent).toBe('Stage Age');
        expect(signalValue.textContent).toBe('10 days');
    });

    it('applies low severity styling', () => {
        const element = createElement('c-deal-signal-card', {
            is: DealSignalCard
        });
        element.severity = 'low';
        document.body.appendChild(element);

        const card = element.shadowRoot.querySelector('.signal-card');
        expect(card.classList.contains('severity-low')).toBe(true);
    });

    it('applies medium severity styling', () => {
        const element = createElement('c-deal-signal-card', {
            is: DealSignalCard
        });
        element.severity = 'medium';
        document.body.appendChild(element);

        const card = element.shadowRoot.querySelector('.signal-card');
        expect(card.classList.contains('severity-medium')).toBe(true);
    });

    it('applies high severity styling', () => {
        const element = createElement('c-deal-signal-card', {
            is: DealSignalCard
        });
        element.severity = 'high';
        document.body.appendChild(element);

        const card = element.shadowRoot.querySelector('.signal-card');
        expect(card.classList.contains('severity-high')).toBe(true);
    });

    it('displays correct icon', () => {
        const element = createElement('c-deal-signal-card', {
            is: DealSignalCard
        });
        element.iconName = 'utility:activity';
        document.body.appendChild(element);

        const icon = element.shadowRoot.querySelector('lightning-icon');
        expect(icon.iconName).toBe('utility:activity');
    });

    it('sets correct icon variant for high severity', () => {
        const element = createElement('c-deal-signal-card', {
            is: DealSignalCard
        });
        element.severity = 'high';
        document.body.appendChild(element);

        const icon = element.shadowRoot.querySelector('lightning-icon');
        expect(icon.variant).toBe('error');
    });

    it('sets correct icon variant for medium severity', () => {
        const element = createElement('c-deal-signal-card', {
            is: DealSignalCard
        });
        element.severity = 'medium';
        document.body.appendChild(element);

        const icon = element.shadowRoot.querySelector('lightning-icon');
        expect(icon.variant).toBe('warning');
    });

    it('sets correct icon variant for low severity', () => {
        const element = createElement('c-deal-signal-card', {
            is: DealSignalCard
        });
        element.severity = 'low';
        document.body.appendChild(element);

        const icon = element.shadowRoot.querySelector('lightning-icon');
        expect(icon.variant).toBe('success');
    });
});

// Mock for lightning/navigation
export const NavigationMixin = (Base) => {
    return class extends Base {
        navigate(pageReference) {
            // Mock implementation
        }
        generateUrl(pageReference) {
            return Promise.resolve('https://example.com');
        }
    };
};

export const CurrentPageReference = {};

// Mock for lightning/uiRecordApi
export const getRecord = jest.fn();
export const getFieldValue = jest.fn((record, field) => {
    if (!record || !record.fields) return undefined;
    const fieldName = typeof field === 'string' ? field : field.fieldApiName;
    return record.fields[fieldName]?.value;
});
export const createRecord = jest.fn();
export const updateRecord = jest.fn();
export const deleteRecord = jest.fn();

/// <reference path="../pb_data/types.d.ts" />

/**
 * Automatically set the "creator" field to the authenticated user
 * when a new record is created.
 */
onRecordCreateRequest((e) => {
    const user = e.auth;
    if (!!user) {
        e.record.set('created_by', user.id);
        e.record.set('updated_by', user.id);
    } else {
        throw new Error('You must be authenticated to create a record.');
    }
    e.next();
}, 'locations');

onRecordUpdateRequest((e) => {
    const user = e.auth;
    if (!!user) {
        e.record.set('updated_by', user.id);
    } else {
        throw new Error('You must be authenticated to update a record.');
    }
    e.next();
}, 'locations');

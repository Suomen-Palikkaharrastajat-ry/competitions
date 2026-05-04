import assert from 'node:assert/strict';
import test from 'node:test';

import { keycloakAuthToElmAuthResponse } from '../src/authInterop.mjs';

test('maps PocketBase OAuth auth data to the Elm AuthResponse port shape', () => {
  // Given PocketBase returns a keycloak_users OAuth auth response
  const authData = {
    token: 'eyJtoken',
    record: {
      id: 'auth1',
      collectionName: 'keycloak_users',
      profile_id: 'profile1',
      email: 'keycloak-participant@example.test',
      display_name: 'Keycloak Participant',
      is_reviewer: false,
    },
  };

  // When JavaScript prepares the successful login payload for Elm
  const payload = keycloakAuthToElmAuthResponse(authData);

  // Then the payload matches Elm's AuthResponse/AuthUser field names exactly
  assert.deepEqual(payload, {
    token: 'eyJtoken',
    record: {
      id: 'auth1',
      authCollection: 'keycloak_users',
      profileId: 'profile1',
      email: 'keycloak-participant@example.test',
      token: 'eyJtoken',
      displayName: 'Keycloak Participant',
      isReviewer: false,
    },
  });
});

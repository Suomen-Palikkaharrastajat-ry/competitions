export function keycloakAuthToElmAuthResponse(authData) {
  const token = authData?.token || '';
  const record = authData?.record || {};

  return {
    token,
    record: {
      id: record.id || '',
      authCollection: record.collectionName || 'keycloak_users',
      profileId: record.profile_id || '',
      email: record.email || '',
      token,
      displayName: record.display_name || '',
      isReviewer: !!record.is_reviewer,
    },
  };
}

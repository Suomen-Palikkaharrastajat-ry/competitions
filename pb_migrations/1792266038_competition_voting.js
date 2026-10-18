/// <reference path="../pb_data/types.d.ts" />
// Ranked voting next to reviews (ADR-0007).
//
// Given a competition that enables voting for a voting period
// When a signed-in user ranks at most five approved entries of it
// Then the ballot is stored once per voter and competition, readable only by
//      the voter and by reviewers (who count the votes).
//
// The voting period, the ranking and the entries on it are checked by
// pb_hooks/votes.pb.js; the rules here only decide who may touch a ballot.
migrate(
  (app) => {
    const competitions = app.findCollectionByNameOrId("competitions");
    competitions.fields.add(new BoolField({ "id": "bool_voting_enabled", "name": "voting_enabled" }));
    // Participants must vote: an entry whose submitter casts no ballot is left
    // out of the vote result.
    competitions.fields.add(new BoolField({ "id": "bool_voting_required", "name": "voting_required" }));
    competitions.fields.add(new DateField({ "id": "date_voting_start", "name": "voting_start_date" }));
    competitions.fields.add(new DateField({ "id": "date_voting_end", "name": "voting_end_date" }));
    app.save(competitions);

    const profiles = app.findCollectionByNameOrId("profiles");
    const votes = new Collection({
      "name": "votes",
      "type": "base",
      "listRule": "voter = @request.auth.profile_id || @request.auth.is_reviewer = true",
      "viewRule": "voter = @request.auth.profile_id || @request.auth.is_reviewer = true",
      "createRule": "@request.auth.profile_id != \"\" && @request.auth.verified = true && @request.body.voter = @request.auth.profile_id",
      "updateRule": "voter = @request.auth.profile_id && @request.auth.verified = true",
      "deleteRule": "voter = @request.auth.profile_id && @request.auth.verified = true",
      "fields": [
        { "id": "rel_vote_competition", "name": "competition", "type": "relation", "required": true, "collectionId": competitions.id, "cascadeDelete": true, "maxSelect": 1 },
        { "id": "rel_vote_voter", "name": "voter", "type": "relation", "required": true, "collectionId": profiles.id, "maxSelect": 1 },
        // Entry ids in preference order: 1st (8 points) to 5th (1 point).
        { "id": "json_vote_ranking", "name": "ranking", "type": "json", "maxSize": 2000 },
        { "id": "autodate_votes_created", "name": "created", "type": "autodate", "onCreate": true, "onUpdate": false },
        { "id": "autodate_votes_updated", "name": "updated", "type": "autodate", "onCreate": true, "onUpdate": true }
      ],
      "indexes": [
        "CREATE UNIQUE INDEX `idx_votes_competition_voter` ON `votes` (`competition`, `voter`)"
      ]
    });
    app.save(votes);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId("votes"));

    const competitions = app.findCollectionByNameOrId("competitions");
    ["bool_voting_enabled", "bool_voting_required", "date_voting_start", "date_voting_end"].forEach((id) => {
      competitions.fields.removeById(id);
    });
    app.save(competitions);
  }
);

// Entry image limit validation.
//
// Given a competition with optional per-entry image limits
// When an entry is submitted or approved
// Then the server enforces the configured min/max counts.

function relationId(value) {
  if (!value) {
    return "";
  }
  if (Array.isArray(value)) {
    return value.length > 0 ? String(value[0]) : "";
  }
  return String(value);
}

function fileCount(value) {
  if (!value) {
    return 0;
  }
  if (Array.isArray(value)) {
    return value.length;
  }
  return 1;
}

function intOrDefault(value, fallback) {
  if (value === null || value === undefined || value === "") {
    return fallback;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : fallback;
}

function imageLimitsForCompetition(competition) {
  const min = intOrDefault(competition.get("min_images_per_entry"), 1);
  const max = intOrDefault(competition.get("max_images_per_entry"), 10);

  if (min < 0 || max < min || max > 10) {
    throw new Error("Kilpailun kuvarajat ovat virheelliset");
  }

  return { min, max };
}

function validateEntryImageLimits(e) {
  const record = e.record;
  const status = String(record.get("status") || "");

  if (status === "" || status === "draft") {
    return e.next();
  }

  const competitionId = relationId(record.get("competition"));
  if (!competitionId) {
    return e.json(400, {
      code: "validation_failed",
      message: "Kilpailu on pakollinen",
      data: { competition: { message: "Kilpailu on pakollinen" } }
    });
  }

  let limits;
  try {
    limits = imageLimitsForCompetition($app.findRecordById("competitions", competitionId));
  } catch (err) {
    return e.json(400, {
      code: "validation_failed",
      message: String(err && err.message ? err.message : err),
      data: { competition: { message: "Kilpailun kuvarajat ovat virheelliset" } }
    });
  }

  const count = fileCount(record.get("images"));
  if (count < limits.min) {
    return e.json(400, {
      code: "validation_failed",
      message: "Liian vahan kuvia",
      data: { images: { message: "Lisaa vahintaan " + limits.min + " kuvaa" } }
    });
  }

  if (count > limits.max) {
    return e.json(400, {
      code: "validation_failed",
      message: "Liian monta kuvaa",
      data: { images: { message: "Enintaan " + limits.max + " kuvaa sallittu" } }
    });
  }

  return e.next();
}

onRecordCreateRequest(validateEntryImageLimits, "entries");
onRecordUpdateRequest(validateEntryImageLimits, "entries");

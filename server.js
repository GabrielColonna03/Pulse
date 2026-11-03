const crypto = require("crypto");
const dns = require("dns");
const fs = require("fs");
const path = require("path");

require("dotenv").config();

const express = require("express");
const multer = require("multer");
const { Pool } = require("pg");
const xlsx = require("xlsx");

const PORT = Number(process.env.PORT) || 4100;
const DATABASE_URL = String(process.env.DATABASE_URL || "").trim();
const CLIENT_ORIGINS = String(process.env.CLIENT_ORIGINS || "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);
const ALLOW_ALL_ORIGINS = CLIENT_ORIGINS.includes("*");

const app = express();
app.set("trust proxy", 1);
const upload = multer({ dest: path.join(__dirname, "uploads") });
const IMPORT_PREVIEW_TTL_MS = 30 * 60 * 1000;
const importPreviewCache = new Map();
const pool = new Pool({
  connectionString: DATABASE_URL,
  family: 4,
  lookup: (hostname, options, callback) => dns.lookup(hostname, { ...options, family: 4 }, callback),
  ssl: DATABASE_URL && !DATABASE_URL.includes("localhost") && !DATABASE_URL.includes("127.0.0.1")
    ? { rejectUnauthorized: false }
    : false
});

app.use(express.json());
app.use((req, res, next) => {
  const origin = req.headers.origin;

  if (!origin) {
    next();
    return;
  }

  const isAllowed = ALLOW_ALL_ORIGINS || CLIENT_ORIGINS.includes(origin);
  if (isAllowed) {
    // Credentialed (cookie) requests cannot use the "*" wildcard, so always echo the exact origin.
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Access-Control-Allow-Credentials", "true");
    res.setHeader("Vary", "Origin");
    res.setHeader("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
  }

  if (req.method === "OPTIONS") {
    res.sendStatus(isAllowed ? 204 : 403);
    return;
  }

  next();
});
app.get(["/", "/login"], (req, res) => {
  res.sendFile(path.join(__dirname, "login.html"));
});
app.get("/dashboard", (req, res) => {
  res.sendFile(path.join(__dirname, "index.html"));
});
app.use(express.static(__dirname));

const categoryModel = {
  income: [
    {
      name: "Income",
      subcategories: ["Salary", "Gambling", "Reselling", "Financial Aid", "Other Income"]
    }
  ],
  expense: [
    {
      name: "Personal",
      subcategories: ["Food", "Entertainment / Activities", "Haircut", "Soccer", "Gaming", "Shopping", "Other"]
    },
    {
      name: "Expenses",
      subcategories: ["Memberships", "Car Payments", "Insurance", "Necessities", "Groceries", "Investments", "Losses"]
    },
    {
      name: "Car",
      subcategories: ["Gas", "Oil Changes", "Repairs", "Tolls", "Parking", "Other Car"]
    },
    {
      name: "Travel",
      subcategories: ["Hotel", "Flights", "Transportation", "Activities"]
    },
    {
      name: "Girlfriend",
      subcategories: ["Gifts", "Dates", "Other"]
    }
  ]
};

const classifyRules = {
  income: [
    {
      parentCategory: "Income",
      category: "Salary",
      keywords: ["paycheck", "salary"]
    },
    {
      parentCategory: "Income",
      category: "Gambling",
      keywords: ["gamble", "casino", "fliff", "underdog", "hard rock", "prize picks", "prizepicks"]
    },
    {
      parentCategory: "Income",
      category: "Reselling",
      keywords: ["resell", "marketplace", "ebay", "jersey", "stockx"]
    },
    {
      parentCategory: "Income",
      category: "Financial Aid",
      keywords: ["financial aid", "grant", "scholarship", "fafsa"]
    },
    {
      parentCategory: "Income",
      category: "Other Income",
      keywords: ["bonus", "refund", "reimbursement", "cashback"]
    }
  ],
  expense: [
    {
      parentCategory: "Expenses",
      category: "Memberships",
      keywords: ["membership", "subscription", "gym", "icloud", "planet fitness", "coursera", "microsoft 365", "pf monthly", "annual fee"]
    },
    {
      parentCategory: "Expenses",
      category: "Car Payments",
      keywords: ["car payment", "auto loan", "pay off car"]
    },
    {
      parentCategory: "Expenses",
      category: "Insurance",
      keywords: ["insurance", "geico"]
    },
    {
      parentCategory: "Expenses",
      category: "Necessities",
      keywords: ["doctor", "dentist", "dental", "medicine", "medication", "prescription", "pharmacy", "glasses", "contacts", "vision", "optometrist", "clinic", "hospital", "urgent care", "copay", "therapy", "health"]
    },
    {
      parentCategory: "Expenses",
      category: "Groceries",
      keywords: ["grocery", "walmart", "costco", "aldi", "target", "publix", "trader joe", "walgreens", "xeela"]
    },
    {
      parentCategory: "Expenses",
      category: "Investments",
      keywords: ["investment", "stock", "crypto", "savings", "wealthfront", "xrp"]
    },
    {
      parentCategory: "Expenses",
      category: "Losses",
      keywords: ["loss", "chargeback", "parking ticket", "parking citation"]
    },
    {
      parentCategory: "Car",
      category: "Gas",
      keywords: ["gas", "fuel", "shell", "chevron"]
    },
    {
      parentCategory: "Car",
      category: "Oil Changes",
      keywords: ["oil change", "tire kingdom"]
    },
    {
      parentCategory: "Car",
      category: "Repairs",
      keywords: ["repair", "maintenance", "mechanic", "car tow", "tow", "brake", "registration renewal"]
    },
    {
      parentCategory: "Car",
      category: "Tolls",
      keywords: ["toll", "tolls"]
    },
    {
      parentCategory: "Car",
      category: "Parking",
      keywords: ["parking"]
    },
    {
      parentCategory: "Car",
      category: "Other Car",
      keywords: ["registration", "dmv"]
    },
    {
      parentCategory: "Travel",
      category: "Hotel",
      keywords: ["hotel", "airbnb", "bnb", "hostel"]
    },
    {
      parentCategory: "Travel",
      category: "Flights",
      keywords: ["flight", "airfare", "spirit", "checked bag", "seatbid", "flight to", "san fran flights"]
    },
    {
      parentCategory: "Travel",
      category: "Transportation",
      keywords: ["lyft", "uber"]
    },
    {
      parentCategory: "Travel",
      category: "Activities",
      keywords: ["activity"]
    },
    {
      parentCategory: "Girlfriend",
      category: "Gifts",
      keywords: ["flowers", "vday", "valentines"]
    },
    {
      parentCategory: "Girlfriend",
      category: "Dates",
      keywords: ["date night", "olive garden", "divieto", "north italia", "wood one ramen"]
    },
    {
      parentCategory: "Girlfriend",
      category: "Other",
      keywords: ["gabby", "publix stuff"]
    },
    {
      parentCategory: "Personal",
      category: "Entertainment / Activities",
      keywords: ["entertainment", "movie", "netflix", "spotify", "amc", "top golf", "miami heat",  "poker", "tequila", "drinks", "heat tickets"]
    },
    {
      parentCategory: "Personal",
      category: "Food",
      keywords: ["doordash", "ubereats", "chipotle", "cfa", "shake shack", "mcd", "mcdonalds", "flanigans", "pubsub", "burger king", "bk", "rcg vending"]
    },
    {
      parentCategory: "Personal",
      category: "Haircut",
      keywords: ["haircut", "barber", "salon"]
    },
    {
      parentCategory: "Personal",
      category: "Soccer",
      keywords: ["soccer", "stadio", "fut5ive", "futbol", "la redonda", "ags"]
    },
    {
      parentCategory: "Personal",
      category: "Gaming",
      keywords: ["psn", "playstation", "gaming", "sony", "marvel rivals", "nba2k", "steam"]
    },
    {
      parentCategory: "Personal",
      category: "Shopping",
      keywords: ["shopping", "amazon", "clothes", "amz", "zara", "souvenir"]
    },
    {
      parentCategory: "Personal",
      category: "Other",
      keywords: ["other", "misc"]
    }
  ]
};

const legacyAliases = {
  "PAYCHECK/SALARY": { parentCategory: "Income", category: "Salary" },
  WEEK: { parentCategory: "Income", category: "Salary" },
  GAM: { parentCategory: "Income", category: "Gambling" },
  RSL: { parentCategory: "Income", category: "Reselling" },
  FAA: { parentCategory: "Income", category: "Financial Aid" },
  OTH: { parentCategory: "Income", category: "Other Income" },
  MEM: { parentCategory: "Expenses", category: "Memberships" },
  VAC: { parentCategory: "Travel", category: "Hotel" },
  INV: { parentCategory: "Expenses", category: "Investments" },
  LSS: { parentCategory: "Expenses", category: "Losses" },
  GAS: { parentCategory: "Car", category: "Gas" },
  INS: { parentCategory: "Expenses", category: "Insurance" },
  HEALTH: { parentCategory: "Expenses", category: "Necessities" },
  MED: { parentCategory: "Expenses", category: "Necessities" },
  DENTAL: { parentCategory: "Expenses", category: "Necessities" },
  OIL: { parentCategory: "Car", category: "Oil Changes" },
  TOL: { parentCategory: "Car", category: "Tolls" },
  PAR: { parentCategory: "Car", category: "Parking" },
  OTH2: { parentCategory: "Car", category: "Other Car" },
  GIFT: { parentCategory: "Girlfriend", category: "Gifts" },
  DATE: { parentCategory: "Girlfriend", category: "Dates" },
  OTH3: { parentCategory: "Girlfriend", category: "Other" },
  ENT: { parentCategory: "Personal", category: "Entertainment / Activities" },
  FOOD: { parentCategory: "Personal", category: "Food" },
  CUT: { parentCategory: "Personal", category: "Haircut" },
  GROC: { parentCategory: "Expenses", category: "Groceries" },
  SOCC: { parentCategory: "Personal", category: "Soccer" },
  PSN: { parentCategory: "Personal", category: "Gaming" },
  SHOP: { parentCategory: "Personal", category: "Shopping" },
  OTH4: { parentCategory: "Personal", category: "Other" },
  CAR: { parentCategory: "Expenses", category: "Car Payments" },
  SALARY: { parentCategory: "Income", category: "Salary" },
  "OTHER INCOME": { parentCategory: "Income", category: "Other Income" },
  "OTHER EXPENSE": { parentCategory: "Expenses", category: "Losses" }
};

function buildDefaultCategoryModel() {
  const rulesByKey = new Map(
    Object.values(classifyRules).flat().map((rule) => [
      `${rule.parentCategory.toLowerCase()}|${rule.category.toLowerCase()}`,
      rule.keywords
    ])
  );

  return Object.fromEntries(
    Object.entries(categoryModel).map(([type, groups]) => [
      type,
      groups.map((group) => ({
        name: group.name,
        subcategories: group.subcategories.map((name) => ({
          name,
          keywords: rulesByKey.get(`${group.name.toLowerCase()}|${name.toLowerCase()}`) || []
        }))
      }))
    ])
  );
}

function normalizeCategoryModel(model) {
  const normalized = {};
  for (const type of ["income", "expense"]) {
    normalized[type] = Array.isArray(model?.[type])
      ? model[type].map((group) => ({
        name: String(group?.name || "").trim(),
        subcategories: Array.isArray(group?.subcategories)
          ? group.subcategories.map((subcategory) => ({
            name: String(subcategory?.name || "").trim(),
            keywords: Array.isArray(subcategory?.keywords)
              ? subcategory.keywords.map((keyword) => String(keyword || "").trim().toLowerCase()).filter(Boolean)
              : []
          })).filter((subcategory) => subcategory.name)
          : []
      })).filter((group) => group.name && group.subcategories.length)
      : [];
  }
  return normalized;
}

function isValidCategoryModel(model) {
  return ["income", "expense"].every((type) => (
    Array.isArray(model?.[type]) &&
    model[type].length > 0 &&
    model[type].every((group) => group.name && group.subcategories.length > 0)
  ));
}

function toPgSql(sql) {
  let index = 0;
  return String(sql).replace(/\?/g, () => `$${++index}`);
}

async function dbQuery(sql, params = []) {
  return pool.query(toPgSql(sql), params);
}

function dbRun(sql, params = []) {
  return dbQuery(sql, params).then((result) => ({
    changes: result.rowCount,
    rows: result.rows
  }));
}

function dbAll(sql, params = []) {
  return dbQuery(sql, params).then((result) => result.rows);
}

function dbGet(sql, params = []) {
  return dbQuery(sql, params).then((result) => result.rows[0]);
}

async function withTransaction(work) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await work(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK").catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

const SESSION_COOKIE_NAME = "pulse_session";
const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const IS_PRODUCTION = process.env.NODE_ENV === "production";
// Seeded for the pre-existing single-user data during the multi-user migration.
const DEFAULT_OWNER_NAME = "Gabriel Colonna";
const DEFAULT_OWNER_PIN = "0307";

function hashPin(pin) {
  const salt = crypto.randomBytes(16).toString("hex");
  const hash = crypto.scryptSync(String(pin), salt, 64).toString("hex");
  return { hash, salt };
}

function verifyPin(pin, hash, salt) {
  const candidate = crypto.scryptSync(String(pin), salt, 64);
  const stored = Buffer.from(String(hash || ""), "hex");
  if (candidate.length !== stored.length) {
    return false;
  }
  return crypto.timingSafeEqual(candidate, stored);
}

function parseCookies(req) {
  const header = req.headers.cookie;
  const cookies = {};
  if (!header) {
    return cookies;
  }

  header.split(";").forEach((part) => {
    const index = part.indexOf("=");
    if (index === -1) {
      return;
    }
    cookies[part.slice(0, index).trim()] = decodeURIComponent(part.slice(index + 1).trim());
  });

  return cookies;
}

function setSessionCookie(res, token, expiresAt) {
  // Production / HTTPS: SameSite=None; Secure so Capacitor and other
  // cross-origin webviews can send credentialed cookies.
  // Local HTTP keeps Lax so localhost cookie auth still works.
  const attributes = [
    `${SESSION_COOKIE_NAME}=${encodeURIComponent(token)}`,
    "Path=/",
    "HttpOnly",
    `Expires=${new Date(expiresAt).toUTCString()}`
  ];
  if (IS_PRODUCTION) {
    attributes.push("SameSite=None", "Secure");
  } else {
    attributes.push("SameSite=Lax");
  }
  res.setHeader("Set-Cookie", attributes.join("; "));
}

function clearSessionCookie(res) {
  const attributes = [
    `${SESSION_COOKIE_NAME}=`,
    "Path=/",
    "HttpOnly",
    "Expires=Thu, 01 Jan 1970 00:00:00 GMT"
  ];
  if (IS_PRODUCTION) {
    attributes.push("SameSite=None", "Secure");
  } else {
    attributes.push("SameSite=Lax");
  }
  res.setHeader("Set-Cookie", attributes.join("; "));
}

function getBearerToken(req) {
  const header = String(req.headers.authorization || "").trim();
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : "";
}

async function resolveSession(req) {
  const cookies = parseCookies(req);
  const cookieToken = cookies[SESSION_COOKIE_NAME];
  const bearerToken = getBearerToken(req);
  return getSessionUser(cookieToken || bearerToken);
}

async function createSession(userId) {
  const token = crypto.randomBytes(32).toString("hex");
  const createdAt = Date.now();
  const expiresAt = createdAt + SESSION_TTL_MS;
  await dbRun(
    "INSERT INTO sessions (token, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)",
    [token, userId, createdAt, expiresAt]
  );
  return { token, expiresAt };
}

async function getSessionUser(token) {
  if (!token) {
    return null;
  }

  const row = await dbGet(
    `SELECT s.user_id AS "userId", s.expires_at AS "expiresAt", u.display_name AS "displayName",
            u.is_admin AS "isAdmin", u.is_new AS "isNew"
     FROM sessions s
     JOIN users u ON u.id = s.user_id
     WHERE s.token = ?`,
    [token]
  );

  if (!row || Number(row.expiresAt) < Date.now()) {
    return null;
  }

  return {
    userId: row.userId,
    displayName: row.displayName,
    isAdmin: Boolean(row.isAdmin),
    isNew: Boolean(row.isNew)
  };
}

async function destroySession(token) {
  if (!token) {
    return;
  }
  await dbRun("DELETE FROM sessions WHERE token = ?", [token]);
}

async function requireAuth(req, res, next) {
  const session = await resolveSession(req);
  if (!session) {
    res.status(401).json({ error: "Not Authenticated" });
    return;
  }

  req.userId = session.userId;
  req.displayName = session.displayName;
  req.isAdmin = session.isAdmin;
  req.sessionToken = getBearerToken(req) || parseCookies(req)[SESSION_COOKIE_NAME] || "";
  next();
}

function requireAdmin(req, res, next) {
  if (!req.isAdmin) {
    res.status(403).json({ error: "Admin Access Required" });
    return;
  }
  next();
}

const loginAttempts = new Map();
const LOGIN_MAX_ATTEMPTS = 8;
const LOGIN_WINDOW_MS = 10 * 60 * 1000;

function isLoginRateLimited(key) {
  const entry = loginAttempts.get(key);
  if (!entry) {
    return false;
  }
  if (Date.now() - entry.firstAttemptAt > LOGIN_WINDOW_MS) {
    loginAttempts.delete(key);
    return false;
  }
  return entry.count >= LOGIN_MAX_ATTEMPTS;
}

function recordLoginAttempt(key) {
  const entry = loginAttempts.get(key);
  if (!entry || Date.now() - entry.firstAttemptAt > LOGIN_WINDOW_MS) {
    loginAttempts.set(key, { count: 1, firstAttemptAt: Date.now() });
    return;
  }
  entry.count += 1;
}

async function ensureDatabase() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      pin_hash TEXT NOT NULL,
      pin_salt TEXT NOT NULL,
      is_admin BOOLEAN NOT NULL DEFAULT FALSE,
      is_new BOOLEAN NOT NULL DEFAULT FALSE,
      created_at BIGINT NOT NULL
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at BIGINT NOT NULL,
      expires_at BIGINT NOT NULL
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_category_models (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      model JSONB NOT NULL,
      updated_at BIGINT NOT NULL
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS trips (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
      created_at BIGINT NOT NULL,
      archived BOOLEAN NOT NULL DEFAULT FALSE
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      date TEXT NOT NULL,
      description TEXT NOT NULL,
      parent_category TEXT,
      trip_id TEXT REFERENCES trips(id) ON DELETE SET NULL,
      user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
      category TEXT NOT NULL,
      type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
      amount REAL NOT NULL,
      created_at BIGINT NOT NULL
    )
  `);

  await pool.query("ALTER TABLE transactions ADD COLUMN IF NOT EXISTS parent_category TEXT");
  await pool.query("ALTER TABLE transactions ADD COLUMN IF NOT EXISTS trip_id TEXT");
  await pool.query("ALTER TABLE transactions ADD COLUMN IF NOT EXISTS user_id TEXT REFERENCES users(id) ON DELETE CASCADE");
  await pool.query("ALTER TABLE trips ADD COLUMN IF NOT EXISTS archived BOOLEAN NOT NULL DEFAULT FALSE");
  await pool.query("ALTER TABLE trips ALTER COLUMN archived TYPE BOOLEAN USING archived::boolean");
  await pool.query("ALTER TABLE trips ALTER COLUMN archived SET DEFAULT FALSE");
  await pool.query("ALTER TABLE trips DROP COLUMN IF EXISTS start_date");
  await pool.query("ALTER TABLE trips DROP COLUMN IF EXISTS end_date");
  await pool.query("ALTER TABLE trips ADD COLUMN IF NOT EXISTS user_id TEXT REFERENCES users(id) ON DELETE CASCADE");

  // Trip names are now unique per user rather than globally.
  await pool.query("ALTER TABLE trips DROP CONSTRAINT IF EXISTS trips_name_key");
  const existingConstraint = await dbGet(
    "SELECT 1 AS found FROM pg_constraint WHERE conname = 'trips_user_id_name_key'"
  );
  if (!existingConstraint) {
    await pool.query("ALTER TABLE trips ADD CONSTRAINT trips_user_id_name_key UNIQUE (user_id, name)");
  }

  await pool.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE");
  await pool.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_new BOOLEAN NOT NULL DEFAULT FALSE");
  const userCount = await dbGet("SELECT COUNT(*)::int AS count FROM users");
  if (!userCount || Number(userCount.count) === 0) {
    const { hash, salt } = hashPin(DEFAULT_OWNER_PIN);
    const defaultUserId = crypto.randomUUID();
    await dbRun(
      "INSERT INTO users (id, display_name, pin_hash, pin_salt, is_admin, created_at) VALUES (?, ?, ?, ?, TRUE, ?)",
      [defaultUserId, DEFAULT_OWNER_NAME, hash, salt, Date.now()]
    );
    await pool.query("UPDATE trips SET user_id = $1 WHERE user_id IS NULL", [defaultUserId]);
    await pool.query("UPDATE transactions SET user_id = $1 WHERE user_id IS NULL", [defaultUserId]);
  }

  const adminCount = await dbGet("SELECT COUNT(*)::int AS count FROM users WHERE is_admin = TRUE");
  if (!adminCount || Number(adminCount.count) === 0) {
    // No admin exists yet (e.g. users table predates is_admin) - promote the original account.
    await pool.query("UPDATE users SET is_admin = TRUE WHERE id = (SELECT id FROM users ORDER BY created_at ASC LIMIT 1)");
  }

  const defaultModel = JSON.stringify(normalizeCategoryModel(buildDefaultCategoryModel()));
  await pool.query(
    `INSERT INTO user_category_models (user_id, model, updated_at)
     SELECT id, $1::jsonb, $2 FROM users
     WHERE NOT EXISTS (
       SELECT 1 FROM user_category_models existing WHERE existing.user_id = users.id
     )`,
    [defaultModel, Date.now()]
  );

  await pool.query("UPDATE transactions SET category = 'Salary' WHERE category = 'Paycheck/Salary'");
  await pool.query("UPDATE transactions SET parent_category = 'Personal' WHERE parent_category = 'Personal Expenses'");
  await pool.query("UPDATE transactions SET category = 'Other Car' WHERE parent_category = 'Car' AND category = 'Other'");
  await pool.query("UPDATE transactions SET category = 'Transportation' WHERE parent_category = 'Travel' AND category = 'Rental'");

  const healthKeywords = ["doctor", "dentist", "dental", "medicine", "medication", "prescription", "pharmacy", "glasses", "contacts", "vision", "optometrist", "clinic", "hospital", "urgent care", "copay", "therapy", "health"];
  const healthPattern = new RegExp(healthKeywords.join("|"), "i");

  const result = await pool.query(
    "SELECT id, description FROM transactions WHERE parent_category = 'Personal' AND category = 'Other' AND type = 'expense'"
  );

  for (const row of result.rows) {
    if (healthPattern.test(row.description)) {
      await pool.query(
        "UPDATE transactions SET parent_category = 'Expenses', category = 'Necessities' WHERE id = $1",
        [row.id]
      );
    }
  }
}

async function resolveTripId(rawTripId, userId) {
  const cleanTripId = String(rawTripId || "").trim();
  if (!cleanTripId) {
    return null;
  }

  const trip = await dbGet("SELECT id FROM trips WHERE id = ? AND user_id = ? AND archived = FALSE", [cleanTripId, userId]);
  if (!trip) {
    const error = new Error("Trip Not Found");
    error.code = "TRIP_NOT_FOUND";
    throw error;
  }

  return trip.id;
}

async function findOrCreateTripByName(rawName, userId) {
  const cleanName = String(rawName || "").trim();
  if (!cleanName) {
    return null;
  }

  const existing = await dbGet("SELECT id FROM trips WHERE lower(name) = lower(?) AND user_id = ? AND archived = FALSE", [cleanName, userId]);
  if (existing?.id) {
    return existing.id;
  }

  const id = crypto.randomUUID();
  await dbRun(
    `INSERT INTO trips (id, name, user_id, created_at, archived)
     VALUES (?, ?, ?, ?, FALSE)`,
    [id, cleanName, userId, Date.now()]
  );

  return id;
}

function normalizeAmount(value) {
  if (typeof value === "number") {
    return value;
  }

  const raw = String(value || "").trim();
  if (!raw) {
    return Number.NaN;
  }

  const cleaned = raw
    .replace(/\$/g, "")
    .replace(/,/g, "")
    .replace(/\((.*)\)/, "-$1");

  return Number(cleaned);
}

function normalizeDate(value) {
  const formatDateParts = (year, month, day) => `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;

  if (typeof value === "string") {
    const rawString = value.trim();
    const isoMatch = rawString.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if (isoMatch) {
      return formatDateParts(Number(isoMatch[1]), Number(isoMatch[2]), Number(isoMatch[3]));
    }

    const slashMatch = rawString.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (slashMatch) {
      return formatDateParts(Number(slashMatch[3]), Number(slashMatch[1]), Number(slashMatch[2]));
    }
  }

  if (value instanceof Date && !Number.isNaN(value.valueOf())) {
    const isUtcMidnight =
      value.getUTCHours() === 0 &&
      value.getUTCMinutes() === 0 &&
      value.getUTCSeconds() === 0 &&
      value.getUTCMilliseconds() === 0;

    if (isUtcMidnight) {
      return formatDateParts(value.getUTCFullYear(), value.getUTCMonth() + 1, value.getUTCDate());
    }

    return formatDateParts(value.getFullYear(), value.getMonth() + 1, value.getDate());
  }

  if (typeof value === "number") {
    const parsed = xlsx.SSF.parse_date_code(value);
    if (parsed) {
      return formatDateParts(parsed.y, parsed.m, parsed.d);
    }
  }

  const raw = String(value || "").trim();
  if (!raw) {
    const today = new Date();
    return formatDateParts(today.getFullYear(), today.getMonth() + 1, today.getDate());
  }

  const candidate = new Date(raw);
  if (!Number.isNaN(candidate.valueOf())) {
    const hasTimezoneHint = /z$/i.test(raw) || /[+-]\d{2}:?\d{2}$/.test(raw);
    if (raw.includes("T") || hasTimezoneHint) {
      return formatDateParts(candidate.getUTCFullYear(), candidate.getUTCMonth() + 1, candidate.getUTCDate());
    }

    return formatDateParts(candidate.getFullYear(), candidate.getMonth() + 1, candidate.getDate());
  }

  const today = new Date();
  return formatDateParts(today.getFullYear(), today.getMonth() + 1, today.getDate());
}

function addDays(dateStr, days) {
  const date = new Date(`${String(dateStr || "").slice(0, 10)}T00:00:00`);
  date.setDate(date.getDate() + days);
  return normalizeDate(date);
}

function addMonths(dateStr, monthsToAdd) {
  const base = new Date(`${String(dateStr || "").slice(0, 10)}T00:00:00`);
  const originalDay = base.getDate();
  const target = new Date(base.getFullYear(), base.getMonth() + monthsToAdd, 1);
  const lastDay = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate();
  target.setDate(Math.min(originalDay, lastDay));
  return normalizeDate(target);
}

function shiftDateByFrequency(dateStr, frequency, occurrenceIndex) {
  if (occurrenceIndex <= 0 || frequency === "none") {
    return normalizeDate(dateStr);
  }

  if (frequency === "weekly") {
    return addDays(dateStr, 7 * occurrenceIndex);
  }

  if (frequency === "biweekly") {
    return addDays(dateStr, 14 * occurrenceIndex);
  }

  if (frequency === "monthly") {
    return addMonths(dateStr, occurrenceIndex);
  }

  return normalizeDate(dateStr);
}

async function getUserCategoryModel(userId) {
  const row = await dbGet("SELECT model FROM user_category_models WHERE user_id = ?", [userId]);
  const model = normalizeCategoryModel(row?.model || {});
  return isValidCategoryModel(model) ? model : normalizeCategoryModel(buildDefaultCategoryModel());
}

function classifyCategory(description, type, model) {
  const lower = String(description || "").toLowerCase();
  const typesToCheck = [type === "income" ? "income" : "expense"];

  for (const typeToCheck of typesToCheck) {
    const groups = model[typeToCheck] || [];
    for (const group of groups) {
      for (const subcategory of group.subcategories) {
        if (subcategory.keywords.some((keyword) => lower.includes(keyword))) {
          return { type: typeToCheck, parentCategory: group.name, category: subcategory.name };
        }
      }
    }
  }

  const groups = model[type] || [];
  const fallbackName = type === "income" ? "Other Income" : "Other";
  const fallbackGroup = groups.find((group) => group.subcategories.some((subcategory) => subcategory.name === fallbackName)) || groups[0];
  const fallbackSubcategory = fallbackGroup?.subcategories.find((subcategory) => subcategory.name === fallbackName) || fallbackGroup?.subcategories[0];
  return {
    type,
    parentCategory: fallbackGroup?.name || (type === "income" ? "Income" : "Personal"),
    category: fallbackSubcategory?.name || (type === "income" ? "Other Income" : "Other")
  };
}

function normalizeCategory({ value, parentCategory, type, description, model }) {
  const rawCategory = String(value || "").trim();
  const rawParent = String(parentCategory || "").trim();
  const normalizedParent = rawParent.toLowerCase() === "personal expenses" ? "Personal" : rawParent;
  const activeModel = model || normalizeCategoryModel(buildDefaultCategoryModel());
  const groups = activeModel[type] || [];

  if (rawCategory) {
    const alias = legacyAliases[rawCategory.toUpperCase()];
    if (alias) {
      return alias;
    }

    for (const group of groups) {
      const subcategory = group.subcategories.find((item) => item.name.toLowerCase() === rawCategory.toLowerCase());
      if (subcategory) {
        return { parentCategory: group.name, category: subcategory.name };
      }
    }
  }

  if (rawCategory && normalizedParent) {
    const parentMatch = groups.find((group) => group.name.toLowerCase() === normalizedParent.toLowerCase());
    if (parentMatch) {
      const sub = parentMatch.subcategories.find((subcategory) => subcategory.name.toLowerCase() === rawCategory.toLowerCase());
      if (sub) {
        return { parentCategory: parentMatch.name, category: sub.name };
      }
    }
  }

  // If user provided both category AND parent, trust their input even if not found
  // (e.g., legacy imports or future-proofing against category model changes)
  if (rawCategory && rawParent) {
    return { parentCategory: normalizedParent || rawParent, category: rawCategory };
  }

  return classifyCategory(description, type, activeModel);
}

function findHeader(headers, patterns) {
  return headers.find((header) => patterns.some((pattern) => pattern.test(header)));
}

function purgeExpiredImportPreviews() {
  const now = Date.now();
  for (const [token, item] of importPreviewCache.entries()) {
    if (!item?.createdAt || now - item.createdAt > IMPORT_PREVIEW_TTL_MS) {
      importPreviewCache.delete(token);
    }
  }
}

function buildImportMapping(headers, overrides = {}) {
  const nextMapping = {
    date: findHeader(headers, [/^date$/i, /transaction\s*date/i, /posted/i]) || "",
    description: findHeader(headers, [/description/i, /merchant/i, /details/i, /memo/i, /name/i]) || "",
    amount: findHeader(headers, [/^amount$/i, /value/i, /total/i, /cost/i]) || "",
    type: findHeader(headers, [/^type$/i, /income|expense/i]) || "",
    parentCategory: findHeader(headers, [/parent/i, /main\s*category/i]) || "",
    category: findHeader(headers, [/^category$/i, /subcategory/i, /group/i, /class/i]) || "",
    trip: findHeader(headers, [/^trip$/i, /trip\s*name/i]) || ""
  };

  const keys = ["date", "description", "amount", "type", "parentCategory", "category", "trip"];
  for (const key of keys) {
    const overrideValue = String(overrides?.[key] || "").trim();
    if (!overrideValue) {
      continue;
    }

    nextMapping[key] = headers.includes(overrideValue) ? overrideValue : "";
  }

  return nextMapping;
}

function getImportRowCell(row, headerName) {
  if (!headerName) {
    return "";
  }

  return row[headerName];
}

async function parseImportRow(row, mapping, rowNumber, overrides = {}, model) {
  const overrideDate = String(overrides.date || "").trim();
  const overrideDescription = String(overrides.description || "").trim();
  const overrideParentCategory = String(overrides.parentCategory || "").trim();
  const overrideCategory = String(overrides.category || "").trim();
  const overrideTripName = String(overrides.tripName || "").trim();
  const overrideType = String(overrides.type || "").trim().toLowerCase();
  const overrideAmount = overrides.amount;

  const description = overrideDescription || String(getImportRowCell(row, mapping.description) || "").trim();
  const amountRaw = overrideAmount !== undefined && overrideAmount !== null && String(overrideAmount).trim() !== ""
    ? normalizeAmount(overrideAmount)
    : normalizeAmount(getImportRowCell(row, mapping.amount));

  if (!description) {
    return { ok: false, reason: "Missing Description", rowNumber };
  }

  if (Number.isNaN(amountRaw) || amountRaw === 0) {
    return { ok: false, reason: "Invalid Amount", rowNumber };
  }

  const typeRaw = overrideType || String(getImportRowCell(row, mapping.type) || "").trim().toLowerCase();
  const type = typeRaw === "income" || typeRaw === "expense"
    ? typeRaw
    : amountRaw < 0
      ? "expense"
      : "income";

  const normalized = normalizeCategory({
    value: overrideCategory || getImportRowCell(row, mapping.category),
    parentCategory: overrideParentCategory || getImportRowCell(row, mapping.parentCategory),
    type,
    description,
    model
  });
  const normalizedType = normalized.type || type;

  const tripName = overrideTripName || String(getImportRowCell(row, mapping.trip) || "").trim();

  return {
    ok: true,
    tx: {
      rowNumber,
      date: normalizeDate(overrideDate || getImportRowCell(row, mapping.date)),
      description,
      parentCategory: normalized.parentCategory,
      category: normalized.category,
      tripName,
      type: normalizedType,
      amount: Math.abs(amountRaw)
    }
  };
}

function buildDuplicateKey(tx) {
  const amount = Number(tx.amount || 0).toFixed(2);
  const normalizedDescription = String(tx.description || "").trim().toLowerCase();
  return `${normalizeDate(tx.date)}|${normalizedDescription}|${tx.type}|${amount}`;
}

async function getExistingDuplicateKeys(userId) {
  const rows = await dbAll("SELECT date, description, type, amount FROM transactions WHERE user_id = ?", [userId]);
  return new Set(rows.map((row) => buildDuplicateKey(row)));
}

async function buildImportPreview(rows, mapping, existingDuplicateKeys, rowOverrides = {}, model) {
  const validTransactions = [];
  const previewRows = [];
  const duplicateCounts = {
    existing: 0,
    file: 0
  };
  const batchDuplicateKeys = new Set();

  for (const [index, row] of rows.entries()) {
    const rowNumber = index + 2;
    const parsed = await parseImportRow(row, mapping, rowNumber, rowOverrides[String(rowNumber)] || rowOverrides[rowNumber] || {}, model);

    if (!parsed.ok) {
      previewRows.push({
        rowNumber,
        description: String(getImportRowCell(row, mapping.description) || "").trim(),
        type: "",
        amount: "",
        status: "invalid",
        reason: parsed.reason
      });
      continue;
    }

    const duplicateKey = buildDuplicateKey(parsed.tx);
    let status = "ready";
    let reason = "";

    if (existingDuplicateKeys.has(duplicateKey)) {
      status = "duplicate-existing";
      reason = "Matches Existing Transaction";
      duplicateCounts.existing += 1;
    } else if (batchDuplicateKeys.has(duplicateKey)) {
      status = "duplicate-file";
      reason = "Duplicate Within File";
      duplicateCounts.file += 1;
    }

    batchDuplicateKeys.add(duplicateKey);
    validTransactions.push(parsed.tx);
    previewRows.push({
      rowNumber,
      date: parsed.tx.date,
      description: parsed.tx.description,
      type: parsed.tx.type,
      parentCategory: parsed.tx.parentCategory,
      category: parsed.tx.category,
      tripName: parsed.tx.tripName,
      amount: parsed.tx.amount,
      status,
      reason
    });
  }

  return {
    validTransactions,
    previewRows,
    invalidCount: previewRows.filter((row) => row.status === "invalid").length,
    duplicateExistingCount: duplicateCounts.existing,
    duplicateFileCount: duplicateCounts.file
  };
}

async function toTransaction(row, mapping, model) {
  const parsed = await parseImportRow(row, mapping, 0, {}, model);
  if (!parsed.ok) {
    return null;
  }

  return {
    id: crypto.randomUUID(),
    date: parsed.tx.date,
    description: parsed.tx.description,
    parentCategory: parsed.tx.parentCategory,
    category: parsed.tx.category,
    tripName: parsed.tx.tripName,
    type: parsed.tx.type,
    amount: parsed.tx.amount,
    createdAt: Date.now()
  };
}

app.post("/api/login", async (req, res) => {
  const rateLimitKey = req.ip || req.socket.remoteAddress || "unknown";
  if (isLoginRateLimited(rateLimitKey)) {
    res.status(429).json({ error: "Too Many Attempts. Try Again Later." });
    return;
  }

  const pin = String(req.body?.pin || "").trim();
  if (!/^\d{4}$/.test(pin)) {
    res.status(400).json({ error: "Invalid PIN" });
    return;
  }

  try {
    const users = await dbAll(
      "SELECT id, display_name AS \"displayName\", pin_hash AS \"pinHash\", pin_salt AS \"pinSalt\" FROM users"
    );
    const matchedUser = users.find((user) => verifyPin(pin, user.pinHash, user.pinSalt));

    if (!matchedUser) {
      recordLoginAttempt(rateLimitKey);
      res.status(401).json({ error: "Incorrect PIN" });
      return;
    }

    loginAttempts.delete(rateLimitKey);
    const session = await createSession(matchedUser.id);
    setSessionCookie(res, session.token, session.expiresAt);
    res.json({
      displayName: matchedUser.displayName,
      token: session.token,
      expiresAt: session.expiresAt
    });
  } catch {
    res.status(500).json({ error: "Failed To Log In" });
  }
});

app.post("/api/logout", async (req, res) => {
  const cookies = parseCookies(req);
  const bearerToken = getBearerToken(req);
  await destroySession(cookies[SESSION_COOKIE_NAME] || bearerToken);
  clearSessionCookie(res);
  res.json({ ok: true });
});

app.get("/api/me", async (req, res) => {
  const session = await resolveSession(req);
  if (!session) {
    res.status(401).json({ error: "Not Authenticated" });
    return;
  }
  res.json({
    displayName: session.displayName,
    isAdmin: session.isAdmin,
    needsOnboarding: session.isNew
  });
});

app.get("/api/category-model", requireAuth, async (req, res) => {
  try {
    res.json(await getUserCategoryModel(req.userId));
  } catch {
    res.status(500).json({ error: "Failed To Load Category Model" });
  }
});

app.put("/api/category-model", requireAuth, async (req, res) => {
  const model = normalizeCategoryModel(req.body?.model);
  if (!isValidCategoryModel(model)) {
    res.status(400).json({ error: "Category Model Must Include Income And Expense Groups With Subcategories" });
    return;
  }

  try {
    await dbRun(
      `INSERT INTO user_category_models (user_id, model, updated_at)
       VALUES (?, ?::jsonb, ?)
       ON CONFLICT (user_id) DO UPDATE SET model = EXCLUDED.model, updated_at = EXCLUDED.updated_at`,
      [req.userId, JSON.stringify(model), Date.now()]
    );
    await dbRun("UPDATE users SET is_new = FALSE WHERE id = ?", [req.userId]);
    res.json(model);
  } catch {
    res.status(500).json({ error: "Failed To Save Category Model" });
  }
});

app.post("/api/me/pin", requireAuth, async (req, res) => {
  const currentPin = String(req.body?.currentPin || "").trim();
  const newPin = String(req.body?.newPin || "").trim();

  if (!/^\d{4}$/.test(newPin)) {
    res.status(400).json({ error: "New PIN Must Be 4 Digits" });
    return;
  }

  try {
    const user = await dbGet(
      "SELECT pin_hash AS \"pinHash\", pin_salt AS \"pinSalt\" FROM users WHERE id = ?",
      [req.userId]
    );

    if (!user || !verifyPin(currentPin, user.pinHash, user.pinSalt)) {
      res.status(401).json({ error: "Current PIN Is Incorrect" });
      return;
    }

    const { hash, salt } = hashPin(newPin);
    await dbRun("UPDATE users SET pin_hash = ?, pin_salt = ? WHERE id = ?", [hash, salt, req.userId]);
    res.json({ ok: true });
  } catch {
    res.status(500).json({ error: "Failed To Update PIN" });
  }
});

app.get("/api/users", requireAuth, requireAdmin, async (req, res) => {
  try {
    const users = await dbAll(
      `SELECT id, display_name AS "displayName", is_admin AS "isAdmin",
              is_new AS "isNew", created_at AS "createdAt"
       FROM users
       ORDER BY created_at ASC`
    );
    res.json(users);
  } catch {
    res.status(500).json({ error: "Failed To Load Users" });
  }
});

app.post("/api/users/:id/onboarding-reset", requireAuth, requireAdmin, async (req, res) => {
  try {
    const user = await dbGet("SELECT id FROM users WHERE id = ?", [req.params.id]);
    if (!user) {
      res.status(404).json({ error: "User Not Found" });
      return;
    }
    await dbRun("UPDATE users SET is_new = TRUE WHERE id = ?", [req.params.id]);
    res.json({ ok: true });
  } catch {
    res.status(500).json({ error: "Failed To Reset Onboarding" });
  }
});

app.delete("/api/users/:id", requireAuth, requireAdmin, async (req, res) => {
  if (req.params.id === req.userId) {
    res.status(400).json({ error: "You Cannot Delete Your Own Account" });
    return;
  }

  try {
    const user = await dbGet("SELECT id, is_admin AS \"isAdmin\" FROM users WHERE id = ?", [req.params.id]);
    if (!user) {
      res.status(404).json({ error: "User Not Found" });
      return;
    }
    if (user.isAdmin) {
      res.status(400).json({ error: "Admin Accounts Cannot Be Deleted Here" });
      return;
    }

    await dbRun("DELETE FROM users WHERE id = ?", [req.params.id]);
    res.json({ ok: true });
  } catch {
    res.status(500).json({ error: "Failed To Delete User" });
  }
});

app.post("/api/users", async (req, res) => {
  const session = await resolveSession(req);
  const requiredKey = String(process.env.ADMIN_SETUP_KEY || "");
  const setupKey = String(req.body?.setupKey || "");
  const isAuthorized = (session && session.isAdmin) || (requiredKey && setupKey === requiredKey);

  if (!isAuthorized) {
    res.status(403).json({ error: "Not Authorized To Create Users" });
    return;
  }

  const displayName = String(req.body?.displayName || "").trim();
  const pin = String(req.body?.pin || "").trim();
  if (!displayName || !/^\d{4}$/.test(pin)) {
    res.status(400).json({ error: "Display Name And 4-Digit PIN Are Required" });
    return;
  }

  try {
    const { hash, salt } = hashPin(pin);
    const id = crypto.randomUUID();
    await dbRun(
      "INSERT INTO users (id, display_name, pin_hash, pin_salt, is_admin, is_new, created_at) VALUES (?, ?, ?, ?, FALSE, TRUE, ?)",
      [id, displayName, hash, salt, Date.now()]
    );
    await dbRun(
      "INSERT INTO user_category_models (user_id, model, updated_at) VALUES (?, ?::jsonb, ?)",
      [id, JSON.stringify(normalizeCategoryModel(buildDefaultCategoryModel())), Date.now()]
    );
    res.status(201).json({ id, displayName, isAdmin: false, createdAt: Date.now() });
  } catch {
    res.status(500).json({ error: "Failed To Create User" });
  }
});

app.get("/api/trips", requireAuth, async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT id, name, archived, created_at AS "createdAt"
       FROM trips
      WHERE user_id = ? AND archived = FALSE
       ORDER BY LOWER(name) ASC`,
      [req.userId]
    );

    res.json(rows);
  } catch {
    res.status(500).json({ error: "Failed To Load Trips" });
  }
});

app.post("/api/trips", requireAuth, async (req, res) => {
  const cleanName = String(req.body?.name || "").trim();
  if (!cleanName) {
    res.status(400).json({ error: "Trip Name Is Required" });
    return;
  }

  try {
    const existing = await dbGet(
      "SELECT id, name, archived, created_at AS \"createdAt\" FROM trips WHERE lower(name) = lower(?) AND user_id = ? AND archived = FALSE",
      [cleanName, req.userId]
    );
    if (existing) {
      res.json(existing);
      return;
    }

    const trip = {
      id: crypto.randomUUID(),
      name: cleanName,
      archived: false,
      createdAt: Date.now()
    };

    await dbRun(
      `INSERT INTO trips (id, name, user_id, created_at, archived)
       VALUES (?, ?, ?, ?, ?)` ,
      [trip.id, trip.name, req.userId, trip.createdAt, trip.archived]
    );

    res.status(201).json(trip);
  } catch {
    res.status(500).json({ error: "Failed To Create Trip" });
  }
});

app.put("/api/trips/:id", requireAuth, async (req, res) => {
  const { id } = req.params;
  const cleanName = String(req.body?.name || "").trim();

  if (!id || !cleanName) {
    res.status(400).json({ error: "Trip Id And Name Are Required" });
    return;
  }

  try {
    const existing = await dbGet(
      "SELECT id FROM trips WHERE id = ? AND user_id = ? AND archived = FALSE",
      [id, req.userId]
    );

    if (!existing) {
      res.status(404).json({ error: "Trip Not Found" });
      return;
    }

    const duplicate = await dbGet(
      "SELECT id FROM trips WHERE lower(name) = lower(?) AND id != ? AND user_id = ? AND archived = FALSE",
      [cleanName, id, req.userId]
    );

    if (duplicate) {
      res.status(409).json({ error: "Trip Name Already Exists" });
      return;
    }

    await dbRun("UPDATE trips SET name = ? WHERE id = ? AND user_id = ?", [cleanName, id, req.userId]);

    const updated = await dbGet(
      `SELECT id, name, archived, created_at AS "createdAt"
       FROM trips
       WHERE id = ? AND user_id = ?`,
      [id, req.userId]
    );

    res.json(updated);
  } catch {
    res.status(500).json({ error: "Failed To Update Trip" });
  }
});

app.delete("/api/trips/:id", requireAuth, async (req, res) => {
  const { id } = req.params;
  if (!id) {
    res.status(400).json({ error: "Trip Id Is Required" });
    return;
  }

  try {
    const deleteResult = await withTransaction(async (client) => {
      const detachResult = await client.query(
        toPgSql("UPDATE transactions SET trip_id = NULL WHERE trip_id = ? AND user_id = ?"),
        [id, req.userId]
      );

      const deleted = await client.query(toPgSql("DELETE FROM trips WHERE id = ? AND user_id = ?"), [id, req.userId]);

      return {
        detachedTransactions: detachResult.rowCount,
        deleted: deleted.rowCount
      };
    });

    if (!deleteResult.deleted) {
      res.status(404).json({ error: "Trip Not Found" });
      return;
    }

    res.json({ ok: true, detachedTransactions: deleteResult.detachedTransactions || 0 });
  } catch {
    res.status(500).json({ error: "Failed To Delete Trip" });
  }
});

app.get("/api/transactions", requireAuth, async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT id, date, description, COALESCE(parent_category, '') AS "parentCategory", COALESCE(trip_id::text, '') AS "tripId", category, type, amount, created_at AS "createdAt"
       FROM transactions
       WHERE user_id = ?
       ORDER BY created_at DESC`,
      [req.userId]
    );

    res.json(rows);
  } catch {
    res.status(500).json({ error: "Failed To Load Transactions" });
  }
});

app.get("/api/transactions/search", requireAuth, async (req, res) => {
  const query = String(req.query.q || "").trim().toLowerCase();
  if (!query) {
    res.json([]);
    return;
  }

  const likeQuery = `%${query}%`;

  try {
    const rows = await dbAll(
      `SELECT t.id, t.date, t.description, COALESCE(t.parent_category, '') AS "parentCategory",
              COALESCE(t.trip_id::text, '') AS "tripId", COALESCE(tr.name, '') AS "tripName",
              t.category, t.type, t.amount, t.created_at AS "createdAt"
       FROM transactions t
       LEFT JOIN trips tr ON tr.id = t.trip_id AND tr.user_id = t.user_id
       WHERE t.user_id = ?
         AND (lower(t.description) LIKE ?
          OR lower(COALESCE(t.parent_category, '')) LIKE ?
          OR lower(COALESCE(t.category, '')) LIKE ?
          OR lower(t.type) LIKE ?
          OR lower(t.date) LIKE ?
          OR lower(COALESCE(tr.name, '')) LIKE ?
          OR CAST(t.amount AS TEXT) LIKE ?)
       ORDER BY t.date DESC, t.created_at DESC`,
      [req.userId, likeQuery, likeQuery, likeQuery, likeQuery, likeQuery, likeQuery, likeQuery]
    );

    res.json(rows);
  } catch {
    res.status(500).json({ error: "Failed To Search Transactions" });
  }
});

app.post("/api/transactions", requireAuth, async (req, res) => {
  const { description, amount, type, date, category, parentCategory, tripId, recurrenceFrequency, recurrenceCount } = req.body || {};
  const cleanDescription = String(description || "").trim();
  const cleanType = type === "income" ? "income" : "expense";
  const cleanAmount = Number(amount);
  const cleanDate = normalizeDate(date);
  const cleanFrequency = ["none", "monthly", "weekly", "biweekly"].includes(String(recurrenceFrequency || "none"))
    ? String(recurrenceFrequency || "none")
    : "none";
  const parsedCount = Number(recurrenceCount);
  const cleanRecurrenceCount = Number.isInteger(parsedCount) && parsedCount > 0 ? parsedCount : 1;

  if (!cleanDescription || Number.isNaN(cleanAmount) || cleanAmount <= 0) {
    res.status(400).json({ error: "Invalid Transaction Payload" });
    return;
  }

  if (cleanRecurrenceCount > 36) {
    res.status(400).json({ error: "Number Of Recurring Entries Cannot Exceed 36" });
    return;
  }

  if (cleanFrequency === "none" && cleanRecurrenceCount > 1) {
    res.status(400).json({ error: "Frequency Must Be Set For Multiple Entries" });
    return;
  }

  try {
    const model = await getUserCategoryModel(req.userId);
    const normalized = normalizeCategory({ value: category, parentCategory, type: cleanType, description: cleanDescription, model });
    const normalizedType = normalized.type || cleanType;
    const cleanTripId = await resolveTripId(tripId, req.userId);

    const entriesToCreate = cleanFrequency === "none" ? 1 : cleanRecurrenceCount;
    const created = [];

    await withTransaction(async (client) => {
      for (let i = 0; i < entriesToCreate; i += 1) {
        const tx = {
          id: crypto.randomUUID(),
          date: shiftDateByFrequency(cleanDate, cleanFrequency, i),
          description: cleanDescription,
          parentCategory: normalized.parentCategory,
          tripId: cleanTripId,
          category: normalized.category,
          type: normalizedType,
          amount: cleanAmount,
          createdAt: Date.now() + i
        };

        await client.query(
          toPgSql(
            `INSERT INTO transactions (id, date, description, parent_category, trip_id, user_id, category, type, amount, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ),
          [tx.id, tx.date, tx.description, tx.parentCategory, tx.tripId, req.userId, tx.category, tx.type, tx.amount, tx.createdAt]
        );

        created.push(tx);
      }
    });

    if (created.length === 1) {
      res.status(201).json(created[0]);
      return;
    }

    res.status(201).json({ created });
  } catch (error) {
    if (error?.code === "TRIP_NOT_FOUND") {
      res.status(400).json({ error: "Selected Trip Does Not Exist" });
      return;
    }
    res.status(500).json({ error: "Failed To Save Transaction" });
  }
});

app.put("/api/transactions/:id", requireAuth, async (req, res) => {
  const { id } = req.params;
  const { description, amount, type, date, category, parentCategory, tripId } = req.body || {};

  const cleanDescription = String(description || "").trim();
  const cleanType = type === "income" ? "income" : "expense";
  const cleanAmount = Number(amount);
  const cleanDate = normalizeDate(date);

  if (!id || !cleanDescription || Number.isNaN(cleanAmount) || cleanAmount <= 0) {
    res.status(400).json({ error: "Invalid Transaction Payload" });
    return;
  }

  try {
    const model = await getUserCategoryModel(req.userId);
    const normalized = normalizeCategory({ value: category, parentCategory, type: cleanType, description: cleanDescription, model });
    const normalizedType = normalized.type || cleanType;
    const cleanTripId = await resolveTripId(tripId, req.userId);

    const result = await dbRun(
      `UPDATE transactions
       SET date = ?, description = ?, parent_category = ?, trip_id = ?, category = ?, type = ?, amount = ?
       WHERE id = ? AND user_id = ?`,
      [cleanDate, cleanDescription, normalized.parentCategory, cleanTripId, normalized.category, normalizedType, cleanAmount, id, req.userId]
    );

    if (!result.changes) {
      res.status(404).json({ error: "Transaction Not Found" });
      return;
    }

    const rows = await dbAll(
      `SELECT id, date, description, COALESCE(parent_category, '') AS "parentCategory", COALESCE(trip_id::text, '') AS "tripId", category, type, amount, created_at AS "createdAt"
       FROM transactions
       WHERE id = ? AND user_id = ?`,
      [id, req.userId]
    );

    res.json(rows[0]);
  } catch (error) {
    if (error?.code === "TRIP_NOT_FOUND") {
      res.status(400).json({ error: "Selected Trip Does Not Exist" });
      return;
    }
    res.status(500).json({ error: "Failed To Update Transaction" });
  }
});

app.delete("/api/transactions/:id", requireAuth, async (req, res) => {
  try {
    const result = await dbRun("DELETE FROM transactions WHERE id = ? AND user_id = ?", [req.params.id, req.userId]);
    if (!result.changes) {
      res.status(404).json({ error: "Transaction Not Found" });
      return;
    }

    res.json({ ok: true });
  } catch {
    res.status(500).json({ error: "Failed To Delete Transaction" });
  }
});

app.delete("/api/transactions", requireAuth, async (req, res) => {
  try {
    await dbRun("DELETE FROM transactions WHERE user_id = ?", [req.userId]);
    res.json({ ok: true });
  } catch {
    res.status(500).json({ error: "Failed To Clear Data" });
  }
});

app.post("/api/import-excel", requireAuth, upload.single("file"), async (req, res) => {
  if (!req.file) {
    res.status(400).json({ error: "No File Uploaded" });
    return;
  }

  let importedCount = 0;
  let skippedCount = 0;

  try {
    const workbook = xlsx.readFile(req.file.path, { cellDates: true });
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];

    if (!sheet) {
      res.status(400).json({ error: "Excel Sheet Is Empty" });
      return;
    }

    const rows = xlsx.utils.sheet_to_json(sheet, { defval: "" });
    if (!rows.length) {
      res.status(400).json({ error: "No Rows Found In Excel" });
      return;
    }

    const headers = Object.keys(rows[0]);
    const mapping = buildImportMapping(headers);

    if (!mapping.description || !mapping.amount) {
      res.status(400).json({ error: "Could Not Detect Description/Amount Columns" });
      return;
    }

    const model = await getUserCategoryModel(req.userId);
    await withTransaction(async (client) => {
      for (const row of rows) {
        const tx = await toTransaction(row, mapping, model);
        if (!tx) {
          skippedCount += 1;
          continue;
        }

        const cleanTripId = tx.tripName ? await findOrCreateTripByName(tx.tripName, req.userId) : null;

        await client.query(
          toPgSql(
            `INSERT INTO transactions (id, date, description, parent_category, trip_id, user_id, category, type, amount, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ),
          [tx.id, tx.date, tx.description, tx.parentCategory, cleanTripId, req.userId, tx.category, tx.type, tx.amount, tx.createdAt]
        );

        importedCount += 1;
      }
    });
    res.json({ importedCount, skippedCount });
  } catch {
    res.status(500).json({ error: "Failed To Import Excel File" });
  } finally {
    fs.unlink(req.file.path, () => {});
  }
});

app.post("/api/import-preview", requireAuth, upload.single("file"), async (req, res) => {
  if (!req.file) {
    res.status(400).json({ error: "No File Uploaded" });
    return;
  }

  try {
    const workbook = xlsx.readFile(req.file.path, { cellDates: true });
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];

    if (!sheet) {
      res.status(400).json({ error: "Excel Sheet Is Empty" });
      return;
    }

    const rows = xlsx.utils.sheet_to_json(sheet, { defval: "" });
    if (!rows.length) {
      res.status(400).json({ error: "No Rows Found In Excel" });
      return;
    }

    const headers = Object.keys(rows[0]);
    const mapping = buildImportMapping(headers);

    if (!mapping.description || !mapping.amount) {
      res.status(400).json({ error: "Could Not Detect Description/Amount Columns" });
      return;
    }

    const existingDuplicateKeys = await getExistingDuplicateKeys(req.userId);
    const model = await getUserCategoryModel(req.userId);
    const preview = await buildImportPreview(rows, mapping, existingDuplicateKeys, {}, model);
    const token = crypto.randomUUID();

    purgeExpiredImportPreviews();
    importPreviewCache.set(token, {
      createdAt: Date.now(),
      rows,
      headers,
      fileName: req.file.originalname || "",
      userId: req.userId
    });

    res.json({
      token,
      fileName: req.file.originalname || "",
      headers,
      mapping,
      summary: {
        totalRows: rows.length,
        readyRows: preview.previewRows.filter((row) => row.status === "ready").length,
        invalidRows: preview.invalidCount,
        duplicateExistingRows: preview.duplicateExistingCount,
        duplicateFileRows: preview.duplicateFileCount
      },
      previewRows: preview.previewRows.slice(0, 150)
    });
  } catch {
    res.status(500).json({ error: "Failed To Build Import Preview" });
  } finally {
    fs.unlink(req.file.path, () => {});
  }
});

app.post("/api/import-commit", requireAuth, async (req, res) => {
  const token = String(req.body?.token || "").trim();
  if (!token) {
    res.status(400).json({ error: "Missing Import Token" });
    return;
  }

  purgeExpiredImportPreviews();
  const cachedPreview = importPreviewCache.get(token);
  if (!cachedPreview || cachedPreview.userId !== req.userId) {
    res.status(410).json({ error: "Import Preview Expired. Please Upload Again." });
    return;
  }

  const mapping = buildImportMapping(cachedPreview.headers, req.body?.mapping || {});
  if (!mapping.description || !mapping.amount) {
    res.status(400).json({ error: "Description And Amount Mappings Are Required" });
    return;
  }

  const skipDuplicates = req.body?.skipDuplicates !== false;
  const rowEdits = req.body?.rowEdits && typeof req.body.rowEdits === "object" ? req.body.rowEdits : {};

  try {
    const existingDuplicateKeys = skipDuplicates ? await getExistingDuplicateKeys(req.userId) : new Set();
    const model = await getUserCategoryModel(req.userId);
    const preview = await buildImportPreview(cachedPreview.rows, mapping, existingDuplicateKeys, rowEdits, model);
    const batchDuplicateKeys = new Set();

    let importedCount = 0;
    let skippedCount = preview.invalidCount;
    let skippedDuplicateCount = 0;

    await withTransaction(async (client) => {
      for (const tx of preview.validTransactions) {
        const duplicateKey = buildDuplicateKey(tx);
        if (skipDuplicates && (existingDuplicateKeys.has(duplicateKey) || batchDuplicateKeys.has(duplicateKey))) {
          skippedCount += 1;
          skippedDuplicateCount += 1;
          continue;
        }

        const cleanTripId = tx.tripName ? await findOrCreateTripByName(tx.tripName, req.userId) : null;
        const createdAt = Date.now() + importedCount;

        await client.query(
          toPgSql(
            `INSERT INTO transactions (id, date, description, parent_category, trip_id, user_id, category, type, amount, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ),
          [crypto.randomUUID(), tx.date, tx.description, tx.parentCategory, cleanTripId, req.userId, tx.category, tx.type, tx.amount, createdAt]
        );

        importedCount += 1;
        batchDuplicateKeys.add(duplicateKey);
        existingDuplicateKeys.add(duplicateKey);
      }
    });
    importPreviewCache.delete(token);

    res.json({
      importedCount,
      skippedCount,
      skippedDuplicateCount,
      invalidCount: preview.invalidCount
    });
  } catch {
    res.status(500).json({ error: "Failed To Commit Import" });
  }
});

app.get("/api/export-excel", requireAuth, async (req, res) => {
  try {
    const transactions = await dbAll(
      `SELECT date, description, COALESCE(parent_category, '') AS "parentCategory", category, type, amount
       FROM transactions
       WHERE user_id = ?
       ORDER BY date ASC, parent_category ASC, type DESC`,
      [req.userId]
    );
    if (!transactions.length) {
      res.status(400).json({ error: "No Transactions To Export" });
      return;
    }

    // Group transactions by month, then by category
    const monthlyData = {};
    const allMonths = [];

    transactions.forEach((tx) => {
      const monthKey = tx.date.substring(0, 7); // YYYY-MM format
      if (!monthlyData[monthKey]) {
        monthlyData[monthKey] = {};
        allMonths.push(monthKey);
      }

      const catKey = tx.parentCategory || "Uncategorized";
      if (!monthlyData[monthKey][catKey]) {
        monthlyData[monthKey][catKey] = [];
      }

      monthlyData[monthKey][catKey].push(tx);
    });

    // Create workbook with multiple sheets
    const workbook = xlsx.utils.book_new();

    // Add summary sheet with monthly breakdown
    const summaryData = [];
    summaryData.push(["Budget Pulse - Export Summary"]);
    summaryData.push([]);
    summaryData.push(["Export Date", new Date().toLocaleDateString()]);
    summaryData.push(["Total Transactions", transactions.length]);
    summaryData.push([]);
    summaryData.push(["Monthly Totals"]);
    summaryData.push(["Month", "Income", "Expenses", "Net"]);

    let overallIncome = 0;
    let overallExpenses = 0;

    allMonths.sort().forEach((month) => {
      const monthTxs = Object.values(monthlyData[month]).flat();
      const monthIncome = monthTxs.filter((t) => t.type === "income").reduce((sum, t) => sum + t.amount, 0);
      const monthExpenses = monthTxs.filter((t) => t.type === "expense").reduce((sum, t) => sum + t.amount, 0);
      const monthNet = monthIncome - monthExpenses;

      overallIncome += monthIncome;
      overallExpenses += monthExpenses;

      // Format month nicely (2026-03 -> March 2026)
      const [year, monthNum] = month.split("-");
      const monthName = new Date(year, parseInt(monthNum) - 1).toLocaleString("default", { month: "long", year: "numeric" });

      summaryData.push([
        monthName,
        monthIncome.toFixed(2),
        monthExpenses.toFixed(2),
        monthNet.toFixed(2)
      ]);
    });

    summaryData.push([]);
    summaryData.push(["OVERALL TOTALS", overallIncome.toFixed(2), overallExpenses.toFixed(2), (overallIncome - overallExpenses).toFixed(2)]);

    const summarySheet = xlsx.utils.aoa_to_sheet(summaryData);
    summarySheet["!cols"] = [{ wch: 25 }, { wch: 15 }, { wch: 15 }, { wch: 15 }];
    xlsx.utils.book_append_sheet(workbook, summarySheet, "Summary");

    // Add sheet for each month
    allMonths.sort().forEach((month) => {
      const monthTxs = monthlyData[month];
      const sheetData = [];

      // Format month nicely
      const [year, monthNum] = month.split("-");
      const monthName = new Date(year, parseInt(monthNum) - 1).toLocaleString("default", { month: "long", year: "numeric" });

      sheetData.push([monthName]);
      sheetData.push([]);

      let monthIncome = 0;
      let monthExpenses = 0;

      // Add each category section - Income first, then alphabetical
      const sortedCategories = Object.keys(monthTxs).sort((a, b) => {
        if (a === "Income") return -1;
        if (b === "Income") return 1;
        return a.localeCompare(b);
      });

      sortedCategories.forEach((category, idx) => {
        if (idx > 0) {
          sheetData.push([]); // blank row between categories
        }

        sheetData.push([category]); // Category header
        sheetData.push(["Date", "Description", "Type", "Subcategory", "Amount"]);

        const categoryTxs = monthTxs[category];

        categoryTxs.forEach((tx) => {
          sheetData.push([
            tx.date,
            tx.description,
            tx.type,
            tx.category,
            Number(tx.amount).toFixed(2)
          ]);

          if (tx.type === "income") {
            monthIncome += tx.amount;
          } else {
            monthExpenses += tx.amount;
          }
        });

        // Category totals
        const catIncome = categoryTxs.filter((t) => t.type === "income").reduce((sum, t) => sum + t.amount, 0);
        const catExpenses = categoryTxs.filter((t) => t.type === "expense").reduce((sum, t) => sum + t.amount, 0);

        sheetData.push([]);
        sheetData.push(["", "", "CATEGORY TOTAL", "", ""]);
        if (catIncome > 0) {
          sheetData.push(["", "", "Income", "", catIncome.toFixed(2)]);
        }
        if (catExpenses > 0) {
          sheetData.push(["", "", "Expenses", "", catExpenses.toFixed(2)]);
        }
      });

      // Month totals
      sheetData.push([]);
      sheetData.push([]);
      sheetData.push(["", "", "MONTH TOTAL", "", ""]);
      sheetData.push(["", "", "Income", "", monthIncome.toFixed(2)]);
      sheetData.push(["", "", "Expenses", "", monthExpenses.toFixed(2)]);
      sheetData.push(["", "", "Net", "", (monthIncome - monthExpenses).toFixed(2)]);

      const sheet = xlsx.utils.aoa_to_sheet(sheetData);
      sheet["!cols"] = [{ wch: 12 }, { wch: 30 }, { wch: 10 }, { wch: 25 }, { wch: 12 }];

      // Format category headers (bold with background)
      const range = xlsx.utils.decode_range(sheet["!ref"] || "A1");
      for (let R = range.s.r; R <= range.e.r; ++R) {
        for (let C = range.s.c; C <= range.e.c; ++C) {
          const address = xlsx.utils.encode_cell({ r: R, c: C });
          if (!sheet[address]) continue;

          const cellValue = sheet[address].v;

          // Format category headers (first column entries that are not in the totals/transaction data)
          if (C === 0 && typeof cellValue === "string" && 
              cellValue !== "Date" && 
              cellValue !== monthName &&
              !cellValue.includes("MONTH") &&
              !cellValue.includes("CATEGORY") &&
              !cellValue.includes("Income") &&
              !cellValue.includes("Expenses") &&
              !cellValue.includes("Net")) {
            sheet[address].s = {
              font: { bold: true, color: { rgb: "FFFFFF" } },
              fill: { fgColor: { rgb: "4472C4" } },
              alignment: { horizontal: "left", vertical: "center" }
            };
          }

          // Format column headers (Date, Description, etc.)
          if (R > 0 && cellValue === "Date") {
            // Find the row with headers and format all of them
            for (let HC = range.s.c; HC <= range.e.c; ++HC) {
              const headerAddr = xlsx.utils.encode_cell({ r: R, c: HC });
              if (sheet[headerAddr]) {
                sheet[headerAddr].s = {
                  font: { bold: true, color: { rgb: "FFFFFF" } },
                  fill: { fgColor: { rgb: "366092" } },
                  alignment: { horizontal: "center", vertical: "center" }
                };
              }
            }
          }
        }
      }

      // Use friendly month name for sheet, truncated to 31 chars if needed
      const sheetName = monthName.substring(0, 31);
      xlsx.utils.book_append_sheet(workbook, sheet, sheetName);
    });

    // Generate file
    const fileBuffer = xlsx.write(workbook, { type: "buffer", bookType: "xlsx" });
    res.setHeader("Content-Disposition", 'attachment; filename="budget-pulse-export.xlsx"');
    res.setHeader("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    res.send(fileBuffer);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed To Export Transactions" });
  }
});

app.get("/api/export-backup-csv", requireAuth, async (req, res) => {
  try {
    const model = await getUserCategoryModel(req.userId);
    const rows = await dbAll(
      `SELECT t.date, t.description, COALESCE(t.parent_category, '') AS "parentCategory", COALESCE(t.trip_id::text, '') AS "tripId",
              t.category, t.type, t.amount, COALESCE(tr.name, '') AS tripName
       FROM transactions t
       LEFT JOIN trips tr ON tr.id = t.trip_id
       WHERE t.user_id = ?
       ORDER BY t.date ASC, t.created_at ASC`,
      [req.userId]
    );

    const headers = ["Date", "Description", "Amount", "Type", "Parent Category", "Category", "Trip"];
    const csvRows = [headers.map(csvQuote).join(",")];

    for (const row of rows) {
      const normalized = normalizeCategory({
        value: row.category,
        parentCategory: row.parentCategory,
        type: row.type,
        description: row.description,
        model
      });

      const line = [
        row.date,
        row.description,
        Number(row.amount).toFixed(2),
        row.type,
        normalized.parentCategory,
        normalized.category,
        row.tripName
      ]
        .map(csvQuote)
        .join(",");

      csvRows.push(line);
    }

    const payload = `${csvRows.join("\r\n")}\r\n`;

    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", "attachment; filename=budget-pulse-backup.csv");
    res.send(payload);
  } catch {
    res.status(500).json({ error: "Failed To Export Backup CSV" });
  }
});

function csvQuote(value) {
  return `"${String(value ?? "").replaceAll('"', '""')}"`;
}

app.get("/api/health", (req, res) => {
  res.json({ status: "ok" });
});

app.get(/.*/, (req, res) => {
  res.sendFile(path.join(__dirname, "index.html"));
});

ensureDatabase()
  .then(() => {
    app.listen(PORT, "0.0.0.0", () => {
      console.log(`Budget Dashboard Running On http://localhost:${PORT}`);
    });
  })
  .catch((error) => {
    console.error("Database Initialization Failed", error);
    process.exit(1);
  });

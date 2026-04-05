const jwt = require("jsonwebtoken");

const JWT_SECRET =
  process.env.JWT_SECRET || "zerodast-test-jwt-secret-not-for-production";

function requireAuth(req, res, next) {
  const header = req.headers.authorization;

  if (!header || !header.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing or invalid Authorization header" });
  }

  const token = header.slice("Bearer ".length);

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = {
      userId: payload.userId,
      role: payload.role,
      email: payload.email,
    };
    return next();
  } catch (error) {
    return res.status(401).json({ error: "Invalid token" });
  }
}

module.exports = {
  requireAuth,
  JWT_SECRET,
};

const jwt = require("jsonwebtoken");

const JWT_SECRET =
  process.env.JWT_SECRET || "zerodast-test-jwt-secret-not-for-production";

function requireAuth(req, res, next) {
  const header = req.headers.authorization;
  const cookieHeader = req.headers.cookie || "";
  let token = "";

  if (header && header.startsWith("Bearer ")) {
    token = header.slice("Bearer ".length);
  } else {
    const cookieMatch = cookieHeader.match(/(?:^|;\s*)zerodast_session=([^;]+)/);
    if (cookieMatch) {
      token = decodeURIComponent(cookieMatch[1]);
    }
  }

  if (!token) {
    return res.status(401).json({ error: "Missing or invalid authentication" });
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = {
      userId: payload.userId,
      role: payload.role,
      email: payload.email,
    };
    return next();
  } catch (_error) {
    return res.status(401).json({ error: "Invalid token" });
  }
}

module.exports = {
  requireAuth,
  JWT_SECRET,
};


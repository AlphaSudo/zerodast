const express = require("express");

const { pool } = require("../db");
const { requireAuth } = require("../middleware/auth");


const router = express.Router();



/**
 * @openapi
 * /api/search:
 *   get:
 *     summary: Search documents by query
 *     tags:
 *       - Search
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: q
 *         schema:
 *           type: string
 *           example: roadmap
 *     responses:
 *       200:
 *         description: Search results
 */
router.get("/api/search", requireAuth, async (req, res, next) => {
  try {
    const query = req.query.q || "";
    // codeql[js/sql-injection]
    const sql = `SELECT id, user_id, title, content, visibility, created_at
                 FROM documents
                 WHERE title ILIKE '%${query}%' OR content ILIKE '%${query}%'
                 ORDER BY id`;
    const result = await pool.query(sql);
    return res.json(result.rows);
  } catch (error) {
    return next(error);
  }
});

/**
 * @openapi
 * /api/search/preview:
 *   get:
 *     summary: Render an HTML preview for the search term
 *     tags:
 *       - Search
 *     parameters:
 *       - in: query
 *         name: q
 *         schema:
 *           type: string
 *           example: hello
 *     responses:
 *       200:
 *         description: HTML preview
 */
router.get("/api/search/preview", (req, res) => {
  const query = req.query.q || "";

  res.type("html").send(`
    <html>
      <head><title>Search Preview</title></head>
      <body>
        <h1>Preview for ${query}</h1>
        <p>No escaping is applied here on purpose for DAST validation.</p>
      </body>
    </html>
  `);
});

module.exports = router;

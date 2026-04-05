const express = require("express");

const { pool } = require("../db");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

/**
 * @openapi
 * /api/documents:
 *   get:
 *     summary: List documents visible to the current user
 *     tags:
 *       - Documents
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Documents list
 */
router.get("/api/documents", requireAuth, async (req, res, next) => {
  try {
    const result = await pool.query(
      `SELECT id, user_id, title, content, visibility, created_at
       FROM documents
       WHERE user_id = $1 OR visibility = 'public'
       ORDER BY id`,
      [req.user.userId]
    );

    return res.json(result.rows);
  } catch (error) {
    return next(error);
  }
});

/**
 * @openapi
 * /api/documents/{id}:
 *   get:
 *     summary: Get a document by id
 *     tags:
 *       - Documents
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *           example: 4
 *     responses:
 *       200:
 *         description: Document
 */
router.get("/api/documents/:id", requireAuth, async (req, res, next) => {
  try {
    const result = await pool.query(
      "SELECT id, user_id, title, content, visibility, created_at FROM documents WHERE id = $1",
      [req.params.id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Document not found" });
    }

    return res.json(result.rows[0]);
  } catch (error) {
    return next(error);
  }
});

/**
 * @openapi
 * /api/documents:
 *   post:
 *     summary: Create a new document
 *     tags:
 *       - Documents
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       201:
 *         description: Document created
 */
router.post("/api/documents", requireAuth, async (req, res, next) => {
  try {
    const { title, content, visibility = "private" } = req.body;
    const result = await pool.query(
      `INSERT INTO documents (user_id, title, content, visibility)
       VALUES ($1, $2, $3, $4)
       RETURNING id, user_id, title, content, visibility, created_at`,
      [req.user.userId, title, content, visibility]
    );

    return res.status(201).json(result.rows[0]);
  } catch (error) {
    return next(error);
  }
});

/**
 * @openapi
 * /api/documents/{id}:
 *   delete:
 *     summary: Delete a document by id
 *     tags:
 *       - Documents
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *           example: 1
 *     responses:
 *       204:
 *         description: Document deleted
 */
router.delete("/api/documents/:id", requireAuth, async (req, res, next) => {
  try {
    const result = await pool.query("DELETE FROM documents WHERE id = $1 RETURNING id", [
      req.params.id,
    ]);

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Document not found" });
    }

    return res.status(204).send();
  } catch (error) {
    return next(error);
  }
});

module.exports = router;

const express = require("express");

const { pool } = require("../db");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

/**
 * @openapi
 * /api/users:
 *   get:
 *     summary: List all users
 *     tags:
 *       - Users
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: All users
 */
router.get("/api/users", requireAuth, async (req, res, next) => {
  try {
    if (req.user.role !== "admin") {
      return res.status(403).json({ error: "Admin access required" });
    }

    const result = await pool.query(
      "SELECT id, email, name, role, created_at FROM users ORDER BY id"
    );
    return res.json(result.rows);
  } catch (error) {
    return next(error);
  }
});

/**
 * @openapi
 * /api/users/{id}:
 *   get:
 *     summary: Get a user profile by id
 *     tags:
 *       - Users
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *           example: 2
 *     responses:
 *       200:
 *         description: User profile
 */
router.get("/api/users/:id", requireAuth, async (req, res, next) => {
  try {
    const result = await pool.query(
      "SELECT id, email, name, role, created_at FROM users WHERE id = $1",
      [req.params.id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    return res.json(result.rows[0]);
  } catch (error) {
    return next(error);
  }
});

/**
 * @openapi
 * /api/users/{id}:
 *   put:
 *     summary: Update a user profile by id
 *     tags:
 *       - Users
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
 *       200:
 *         description: User updated
 */
router.put("/api/users/:id", requireAuth, async (req, res, next) => {
  try {
    const { name } = req.body;
    const result = await pool.query(
      `UPDATE users
       SET name = COALESCE($1, name)
       WHERE id = $2
       RETURNING id, email, name, role, created_at`,
      [name, req.params.id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    return res.json(result.rows[0]);
  } catch (error) {
    return next(error);
  }
});

module.exports = router;

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const swaggerUi = require("swagger-ui-express");

const { waitForDatabase } = require("./db");
const swaggerSpec = require("./swagger");
const authRoutes = require("./routes/auth");
const userRoutes = require("./routes/users");
const documentRoutes = require("./routes/documents");
const searchRoutes = require("./routes/search");
const healthRoutes = require("./routes/health");
const errorHandler = require("./middleware/errorHandler");

const app = express();
const port = Number(process.env.PORT || 8080);

app.use(cors());
app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.json());

app.get("/v3/api-docs", (_req, res) => {
  res.json(swaggerSpec);
});

app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));
app.use(healthRoutes);
app.use(authRoutes);
app.use(userRoutes);
app.use(documentRoutes);
app.use(searchRoutes);

app.get("/api/debug/error", (_req, _res, next) => {
  next(new Error("Intentional demo exception for application error disclosure."));
});

app.use(errorHandler);

async function start() {
  await waitForDatabase();
  app.listen(port, () => {
    console.log(`ZeroDAST demo app listening on port ${port}`);
  });
}

start().catch((error) => {
  console.error("Failed to start demo app", error);
  process.exit(1);
});

module.exports = app;

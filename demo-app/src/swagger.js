const swaggerJSDoc = require("swagger-jsdoc");

const swaggerDefinition = {
  openapi: "3.0.0",
  info: {
    title: "ZeroDAST Demo API",
    version: "0.1.0",
    description: "Intentionally vulnerable REST API used to validate DAST coverage.",
  },
  servers: [
    {
      url: "http://localhost:8080",
    },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
      },
    },
  },
};

const swaggerSpec = swaggerJSDoc({
  definition: swaggerDefinition,
  apis: ["./src/routes/*.js"],
});

module.exports = swaggerSpec;

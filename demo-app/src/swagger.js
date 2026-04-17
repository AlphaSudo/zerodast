const swaggerSpec = {
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
    schemas: {
      ErrorResponse: {
        type: "object",
        properties: {
          error: {
            type: "string",
          },
        },
      },
      User: {
        type: "object",
        properties: {
          id: { type: "integer", example: 1 },
          email: { type: "string", format: "email", example: "alice@test.local" },
          name: { type: "string", example: "Alice" },
          role: { type: "string", example: "user" },
          created_at: { type: "string", format: "date-time" },
        },
      },
      AuthResponse: {
        type: "object",
        properties: {
          token: { type: "string" },
          user: { $ref: "#/components/schemas/User" },
        },
      },
      SessionResponse: {
        type: "object",
        properties: {
          session: { type: "string", example: "established" },
          user: { $ref: "#/components/schemas/User" },
        },
      },
      Document: {
        type: "object",
        properties: {
          id: { type: "integer", example: 1 },
          user_id: { type: "integer", example: 1 },
          title: { type: "string", example: "Quarterly roadmap" },
          content: { type: "string", example: "Internal planning notes" },
          visibility: { type: "string", example: "private" },
          created_at: { type: "string", format: "date-time" },
        },
      },
      Health: {
        type: "object",
        properties: {
          status: { type: "string", example: "ok" },
          timestamp: { type: "string", format: "date-time" },
        },
      },
    },
  },
  paths: {
    "/health": {
      get: {
        summary: "Health check",
        tags: ["Health"],
        responses: {
          200: {
            description: "API is healthy",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Health" },
              },
            },
          },
        },
      },
    },
    "/api/auth/register": {
      post: {
        summary: "Register a new user",
        tags: ["Auth"],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email", "name", "password"],
                properties: {
                  email: {
                    type: "string",
                    format: "email",
                    example: "new.user@test.local",
                  },
                  name: { type: "string", example: "New User" },
                  password: { type: "string", example: "Test123!" },
                  role: { type: "string", example: "user" },
                },
              },
            },
          },
        },
        responses: {
          201: {
            description: "User registered",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/AuthResponse" },
              },
            },
          },
        },
      },
    },
    "/api/auth/login": {
      post: {
        summary: "Login with email and password",
        tags: ["Auth"],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email", "password"],
                properties: {
                  email: {
                    type: "string",
                    format: "email",
                    example: "alice@test.local",
                  },
                  password: { type: "string", example: "Test123!" },
                },
              },
            },
          },
        },
        responses: {
          200: {
            description: "Authenticated",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/AuthResponse" },
              },
            },
          },
        },
      },
    },
    "/api/auth/session-login": {
      post: {
        summary: "Login and issue an authenticated session cookie",
        tags: ["Auth"],
        requestBody: {
          required: true,
          content: {
            "application/x-www-form-urlencoded": {
              schema: {
                type: "object",
                required: ["email", "password"],
                properties: {
                  email: {
                    type: "string",
                    format: "email",
                    example: "alice@test.local",
                  },
                  password: { type: "string", example: "Test123!" },
                },
              },
            },
          },
        },
        responses: {
          200: {
            description: "Authenticated session established",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/SessionResponse" },
              },
            },
          },
        },
      },
    },
    "/api/users": {
      get: {
        summary: "List all users",
        tags: ["Users"],
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "All users",
            content: {
              "application/json": {
                schema: {
                  type: "array",
                  items: { $ref: "#/components/schemas/User" },
                },
              },
            },
          },
        },
      },
    },
    "/api/users/{id}": {
      get: {
        summary: "Get a user profile by id",
        tags: ["Users"],
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            in: "path",
            name: "id",
            required: true,
            schema: { type: "integer", example: 2 },
          },
        ],
        responses: {
          200: {
            description: "User profile",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/User" },
              },
            },
          },
        },
      },
      put: {
        summary: "Update a user profile by id",
        tags: ["Users"],
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            in: "path",
            name: "id",
            required: true,
            schema: { type: "integer", example: 1 },
          },
        ],
        responses: {
          200: {
            description: "User updated",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/User" },
              },
            },
          },
        },
      },
    },
    "/api/documents": {
      get: {
        summary: "List documents visible to the current user",
        tags: ["Documents"],
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "Documents list",
            content: {
              "application/json": {
                schema: {
                  type: "array",
                  items: { $ref: "#/components/schemas/Document" },
                },
              },
            },
          },
        },
      },
      post: {
        summary: "Create a new document",
        tags: ["Documents"],
        security: [{ bearerAuth: [] }],
        responses: {
          201: {
            description: "Document created",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Document" },
              },
            },
          },
        },
      },
    },
    "/api/documents/{id}": {
      get: {
        summary: "Get a document by id",
        tags: ["Documents"],
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            in: "path",
            name: "id",
            required: true,
            schema: { type: "integer", example: 4 },
          },
        ],
        responses: {
          200: {
            description: "Document",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Document" },
              },
            },
          },
        },
      },
      delete: {
        summary: "Delete a document by id",
        tags: ["Documents"],
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            in: "path",
            name: "id",
            required: true,
            schema: { type: "integer", example: 1 },
          },
        ],
        responses: {
          204: {
            description: "Document deleted",
          },
        },
      },
    },
    "/api/search": {
      get: {
        summary: "Search documents by query",
        tags: ["Search"],
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            in: "query",
            name: "q",
            schema: { type: "string", example: "roadmap" },
          },
        ],
        responses: {
          200: {
            description: "Search results",
            content: {
              "application/json": {
                schema: {
                  type: "array",
                  items: { $ref: "#/components/schemas/Document" },
                },
              },
            },
          },
        },
      },
    },
    "/api/search/preview": {
      get: {
        summary: "Render an HTML preview for the search term",
        tags: ["Search"],
        parameters: [
          {
            in: "query",
            name: "q",
            schema: { type: "string", example: "hello" },
          },
        ],
        responses: {
          200: {
            description: "HTML preview",
            content: {
              "text/html": {
                schema: { type: "string" },
              },
            },
          },
        },
      },
    },
    "/api/debug/error": {
      get: {
        summary: "Intentionally triggers a 500 error for DAST validation",
        tags: ["Debug"],
        responses: {
          500: {
            description: "Application error with stack trace",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/ErrorResponse" },
              },
            },
          },
        },
      },
    },
  },
};

module.exports = swaggerSpec;

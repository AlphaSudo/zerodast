function errorHandler(error, _req, res, _next) {
  // codeql[js/stack-trace-exposure]
  return res.status(500).json({
    error: error.message,
    stack: error.stack,
  });
}

module.exports = errorHandler;

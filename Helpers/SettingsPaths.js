.pragma library

function ensureTrailingSlash(path) {
  return path.endsWith("/") ? path : path + "/";
}

function preprocessPath(path, homeDir) {
  if (typeof path !== "string" || path === "") {
    return path;
  }

  if (path.startsWith("~/")) {
    return homeDir + path.substring(1);
  } else if (path === "~") {
    return homeDir;
  }

  return path;
}

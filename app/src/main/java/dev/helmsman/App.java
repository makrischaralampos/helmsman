package dev.helmsman;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

/** Minimal HTTP service used as the deployment target for the Helmsman pipeline. */
public final class App {

    private App() {}

    public static HttpServer start(int port) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);

        server.createContext("/healthz", ex ->
            respond(ex, 200, "{\"status\":\"UP\"}")
        );
        server.createContext("/version", ex ->
            respond(
                ex,
                200,
                "{\"version\":\"" +
                    env("APP_VERSION", "dev") +
                    "\",\"commit\":\"" +
                    env("GIT_COMMIT", "unknown") +
                    "\"}"
            )
        );
        server.createContext("/", ex -> {
            if ("/".equals(ex.getRequestURI().getPath())) {
                respond(ex, 200, "{\"message\":\"Helmsman is steering\"}");
            } else {
                respond(ex, 404, "{\"error\":\"not found\"}");
            }
        });

        server.start();
        return server;
    }

    private static String env(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? fallback : value;
    }

    private static void respond(HttpExchange ex, int status, String body)
        throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type", "application/json");
        ex.sendResponseHeaders(status, bytes.length);
        try (ex; var out = ex.getResponseBody()) {
            out.write(bytes);
        }
    }

    public static void main(String[] args) throws IOException {
        int port = Integer.parseInt(env("PORT", "8080"));
        start(port);
        System.out.println("Helmsman listening on :" + port);
    }
}

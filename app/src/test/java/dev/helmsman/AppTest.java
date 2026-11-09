package dev.helmsman;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

class AppTest {

    private static HttpServer server;
    private static String base;
    private static final HttpClient CLIENT = HttpClient.newHttpClient();

    @BeforeAll
    static void startServer() throws IOException {
        server = App.start(0); // ephemeral port
        base = "http://127.0.0.1:" + server.getAddress().getPort();
    }

    @AfterAll
    static void stopServer() {
        server.stop(0);
    }

    private static HttpResponse<String> get(String path) throws Exception {
        return CLIENT.send(
            HttpRequest.newBuilder(URI.create(base + path))
                .GET()
                .build(),
            HttpResponse.BodyHandlers.ofString()
        );
    }

    @Test
    void healthzReportsUp() throws Exception {
        HttpResponse<String> res = get("/healthz");
        assertEquals(200, res.statusCode());
        assertTrue(res.body().contains("UP"));
    }

    @Test
    void versionExposesBuildInfo() throws Exception {
        HttpResponse<String> res = get("/version");
        assertEquals(200, res.statusCode());
        assertTrue(res.body().contains("\"version\""));
        assertTrue(res.body().contains("\"commit\""));
    }

    @Test
    void unknownPathReturns404() throws Exception {
        assertEquals(404, get("/nope").statusCode());
    }
}

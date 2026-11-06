package com.cia2.gradecalc;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Reports which build is serving the request. The pipeline reads the commit
 * field to prove that the pushed change is the one running on the cluster.
 */
@RestController
public class InfoController {

    public record AppInfo(String message, String version, String commit, String pod) {
    }

    private final AppInfo info;

    public InfoController(
            @Value("${app.message}") String message,
            @Value("${app.version}") String version,
            @Value("${app.commit}") String commit,
            @Value("${HOSTNAME:local}") String pod) {
        this.info = new AppInfo(message, version, commit, pod);
    }

    @GetMapping("/api/info")
    public AppInfo info() {
        return info;
    }
}

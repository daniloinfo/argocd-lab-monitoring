package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
public class QuarkusDemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(QuarkusDemoApplication.class, args);
    }

    @RestController
    @RequestMapping("/hello")
    public static class HelloController {

        @GetMapping("/{name}")
        public String hello(@PathVariable String name) {
            return "Hello " + name + " from Quarkus-style app!";
        }

        @GetMapping("/health")
        public String health() {
            return "OK - App is healthy";
        }

        @GetMapping("/info")
        public AppInfo info() {
            return new AppInfo("Quarkus-style Demo", "1.0.0", "Spring Boot");
        }
    }

    public static class AppInfo {
        private String name;
        private String version;
        private String framework;

        public AppInfo(String name, String version, String framework) {
            this.name = name;
            this.version = version;
            this.framework = framework;
        }

        public String getName() { return name; }
        public String getVersion() { return version; }
        public String getFramework() { return framework; }
        public void setName(String name) { this.name = name; }
        public void setVersion(String version) { this.version = version; }
        public void setFramework(String framework) { this.framework = framework; }
    }
}

package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import io.micrometer.core.annotation.Counted;
import io.micrometer.core.annotation.Timed;

@SpringBootApplication
public class SpringbootDemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(SpringbootDemoApplication.class, args);
    }

    @RestController
    @RequestMapping("/hello")
    public static class HelloController {

        @GetMapping("/{name}")
        @Counted(value = "hello_calls", description = "How many hello calls have been made")
        @Timed(value = "hello_duration", description = "How long it takes to say hello")
        public String hello(@PathVariable String name) {
            return String.format("Hello %s from Spring Boot!", name);
        }

        @GetMapping("/health")
        public String health() {
            return "OK - Spring Boot app is healthy";
        }

        @GetMapping("/info")
        @Counted(value = "info_calls", description = "How many info calls have been made")
        public AppInfo info() {
            return new AppInfo("Spring Boot Demo", "1.0.0", "Spring Boot");
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

        // Getters
        public String getName() { return name; }
        public String getVersion() { return version; }
        public String getFramework() { return framework; }
        
        // Setters
        public void setName(String name) { this.name = name; }
        public void setVersion(String version) { this.version = version; }
        public void setFramework(String framework) { this.framework = framework; }
    }
}

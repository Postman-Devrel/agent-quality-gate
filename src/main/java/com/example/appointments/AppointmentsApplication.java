package com.example.appointments;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Java implementation of the appointments-service contract (contract/openapi.yaml).
 * The contract comes from healthcare-org-app/healthcare-appointments; this code is a
 * small in-memory reimplementation, written for the quality gate demo.
 */
@SpringBootApplication
public class AppointmentsApplication {
    public static void main(String[] args) {
        SpringApplication.run(AppointmentsApplication.class, args);
    }
}

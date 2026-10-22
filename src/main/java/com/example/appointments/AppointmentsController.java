package com.example.appointments;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/** One method per operation of postman/specs/appointments-api/index.yaml. Authentication is out of scope for the demo. */
@RestController
public class AppointmentsController {

    private static final String SERVICE = "appointments-service";

    private final AppointmentStore store;

    public AppointmentsController(AppointmentStore store) {
        this.store = store;
    }

    // The contract documents /api/appointments (no trailing slash); the slash form keeps working.
    @GetMapping({"/api/appointments", "/api/appointments/"})
    public ResponseEntity<?> list(@RequestParam Map<String, String> params) {
        int limit;
        int offset;
        try {
            offset = Integer.parseInt(params.getOrDefault("offset", "0"));
            limit = Math.min(Integer.parseInt(params.getOrDefault("limit", "50")), 500);
        } catch (NumberFormatException e) {
            return error(HttpStatus.BAD_REQUEST, "offset/limit must be integers");
        }
        var filters = new LinkedHashMap<>(params);
        filters.remove("limit");
        filters.remove("offset");

        var page = new LinkedHashMap<String, Object>();
        page.put("count", store.count(filters));
        page.put("items", store.list(filters, limit, offset).stream().map(AppointmentStore.Record::toJson).toList());
        return ResponseEntity.ok(page);
    }

    @PostMapping({"/api/appointments", "/api/appointments/"})
    public ResponseEntity<Map<String, Object>> create(@RequestBody(required = false) Map<String, Object> payload) {
        var record = store.create(payload == null ? Map.of() : payload);
        return ResponseEntity.status(HttpStatus.CREATED).body(record.toJson());
    }

    @GetMapping("/api/appointments/{recordId}")
    public ResponseEntity<?> get(@PathVariable long recordId) {
        var record = store.get(recordId);
        return record == null ? notFound(recordId) : ResponseEntity.ok(record.toJson());
    }

    @RequestMapping(value = "/api/appointments/{recordId}", method = {RequestMethod.PUT, RequestMethod.PATCH})
    public ResponseEntity<?> update(@PathVariable long recordId,
                                    @RequestBody(required = false) Map<String, Object> payload) {
        var record = store.update(recordId, payload == null ? Map.of() : payload);
        return record == null ? notFound(recordId) : ResponseEntity.ok(record.toJson());
    }

    @DeleteMapping("/api/appointments/{recordId}")
    public ResponseEntity<?> deactivate(@PathVariable long recordId) {
        var record = store.setStatus(recordId, "inactive");
        return record == null ? notFound(recordId) : ResponseEntity.ok(Map.of("deactivated", recordId));
    }

    @PostMapping("/api/appointments/{recordId}/cancel")
    public ResponseEntity<?> cancel(@PathVariable long recordId) {
        var record = store.setStatus(recordId, "cancelled");
        return record == null ? error(HttpStatus.NOT_FOUND, "not found") : ResponseEntity.ok(record.toJson());
    }

    @PostMapping("/api/appointments/{recordId}/check-in")
    public ResponseEntity<?> checkIn(@PathVariable long recordId) {
        var record = store.setStatus(recordId, "checked_in");
        return record == null ? error(HttpStatus.NOT_FOUND, "not found") : ResponseEntity.ok(record.toJson());
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of("status", "ok", "service", SERVICE);
    }

    @GetMapping("/ready")
    public Map<String, Object> ready() {
        return Map.of("status", "ok", "service", SERVICE, "problems", List.of());
    }

    private ResponseEntity<Map<String, String>> notFound(long id) {
        return error(HttpStatus.NOT_FOUND, "appointments " + id + " not found");
    }

    private ResponseEntity<Map<String, String>> error(HttpStatus status, String message) {
        return ResponseEntity.status(status).body(Map.of("error", message));
    }
}

package com.example.appointments;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.stereotype.Component;

/**
 * In-memory store. An appointment is a fixed envelope (id, status, timestamps) around a
 * free-form "data" document; responses flatten the two, as the contract describes.
 */
@Component
public class AppointmentStore {

    /** One stored record. */
    record Record(long id, String status, Map<String, Object> data, Instant createdAt, Instant updatedAt) {

        /** Response shape: envelope fields first, then the caller's data keys. */
        Map<String, Object> toJson() {
            var json = new LinkedHashMap<String, Object>();
            json.put("id", id);
            json.put("status", status);
            json.put("created_at", createdAt.toString());
            json.put("updated_at", updatedAt.toString());
            json.putAll(data);
            return json;
        }
    }

    private final Map<Long, Record> records = new ConcurrentHashMap<>();
    private final AtomicLong sequence = new AtomicLong(2317);

    public AppointmentStore() {
        // Seeded so the Postman collection (which uses record 2317) has data on a fresh start.
        var now = Instant.now();
        var data = new LinkedHashMap<String, Object>();
        data.put("patient_id", 77);
        data.put("provider_id", 12);
        data.put("slot_id", 5501);
        data.put("reason", "Annual physical");
        records.put(2317L, new Record(2317, "active", data, now, now));
    }

    public List<Record> list(Map<String, String> filters, int limit, int offset) {
        return filter(filters).stream().skip(offset).limit(limit).toList();
    }

    public long count(Map<String, String> filters) {
        return filter(filters).size();
    }

    /** "status" filters the envelope; any other key filters on the data document. */
    private List<Record> filter(Map<String, String> filters) {
        var result = new ArrayList<Record>();
        for (var r : records.values()) {
            boolean match = filters.entrySet().stream().allMatch(f ->
                    f.getKey().equals("status")
                            ? r.status().equals(f.getValue())
                            : String.valueOf(r.data().get(f.getKey())).equals(f.getValue()));
            if (match) result.add(r);
        }
        result.sort((a, b) -> Long.compare(a.id(), b.id()));
        return result;
    }

    public Record create(Map<String, Object> payload) {
        var data = new LinkedHashMap<>(payload);
        data.remove("id"); // server-assigned
        if (data.get("reason") instanceof String reason) {
            data.put("reason", reason.strip()); // documented optional field: trimmed
        }
        var now = Instant.now();
        var record = new Record(sequence.incrementAndGet(), "active", data, now, now);
        records.put(record.id(), record);
        return record;
    }

    public Record get(long id) {
        return records.get(id);
    }

    /** Shallow-merges the payload into data; "status" is special-cased onto the envelope. */
    public Record update(long id, Map<String, Object> payload) {
        var existing = records.get(id);
        if (existing == null) return null;
        var merged = new LinkedHashMap<>(existing.data());
        var changes = new LinkedHashMap<>(payload);
        changes.remove("id");
        var status = changes.containsKey("status") ? String.valueOf(changes.remove("status")) : existing.status();
        merged.putAll(changes);
        var updated = new Record(id, status, merged, existing.createdAt(), Instant.now());
        records.put(id, updated);
        return updated;
    }

    public Record setStatus(long id, String status) {
        var existing = records.get(id);
        if (existing == null) return null;
        var updated = new Record(id, status, existing.data(), existing.createdAt(), Instant.now());
        records.put(id, updated);
        return updated;
    }
}

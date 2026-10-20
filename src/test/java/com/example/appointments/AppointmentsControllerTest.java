package com.example.appointments;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class AppointmentsControllerTest {

    @Autowired
    MockMvc mvc;

    @Test
    void listReturnsCountAndItems() throws Exception {
        mvc.perform(get("/api/appointments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.count").isNumber())
                .andExpect(jsonPath("$.items[0].id").value(2317));
    }

    @Test
    void collectionPathWorksWithTrailingSlash() throws Exception {
        mvc.perform(get("/api/appointments/")).andExpect(status().isOk());
    }

    @Test
    void createReturns201WithEnvelope() throws Exception {
        mvc.perform(post("/api/appointments").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"patient_id\":77,\"provider_id\":12,\"reason\":\"Checkup\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("active"))
                .andExpect(jsonPath("$.patient_id").value(77))
                .andExpect(jsonPath("$.created_at").exists());
    }

    @Test
    void missingAppointmentReturnsError() throws Exception {
        mvc.perform(get("/api/appointments/999999"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("appointments 999999 not found"));
    }

    @Test
    void cancelSetsStatus() throws Exception {
        mvc.perform(post("/api/appointments/2317/cancel"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("cancelled"));
    }

    @Test
    void rescheduleUpdatesStartsAtAndKeepsStatus() throws Exception {
        mvc.perform(post("/api/appointments/2318/reschedule").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"starts_at\":\"2026-08-21T09:00:00+00:00\",\"slot_id\":5620,\"reason\":\"Patient request\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("checked_in"))
                .andExpect(jsonPath("$.starts_at").value("2026-08-21T09:00:00+00:00"))
                .andExpect(jsonPath("$.slot_id").value(5620))
                .andExpect(jsonPath("$.reason").value("Patient request"));
    }

    @Test
    void rescheduleRejectsMissingOrInvalidStartsAt() throws Exception {
        mvc.perform(post("/api/appointments/2317/reschedule").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("starts_at must be an ISO-8601 date-time"));
        mvc.perform(post("/api/appointments/2317/reschedule").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"starts_at\":\"tomorrow\"}"))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/appointments/2317/reschedule").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"starts_at\":\"2026-08-21T09:00:00Z\",\"nope\":1}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void rescheduleUnknownAppointmentIs404() throws Exception {
        mvc.perform(post("/api/appointments/999999/reschedule").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"starts_at\":\"2026-08-21T09:00:00Z\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("not found"));
    }

    @Test
    void requestIdIsEchoedOrGenerated() throws Exception {
        mvc.perform(get("/health").header("X-Request-Id", "demo-123"))
                .andExpect(header().string("X-Request-Id", "demo-123"));
        mvc.perform(get("/health")).andExpect(header().exists("X-Request-Id"));
    }

    @Test
    void statusFilterWorks() throws Exception {
        mvc.perform(get("/api/appointments?status=cancelled"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].status").value("cancelled"));
    }

    @Test
    void healthIsOk() throws Exception {
        mvc.perform(get("/health")).andExpect(jsonPath("$.status").value("ok"));
    }
}

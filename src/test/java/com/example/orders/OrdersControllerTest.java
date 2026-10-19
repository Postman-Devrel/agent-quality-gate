package com.example.orders;

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
class OrdersControllerTest {

    @Autowired
    MockMvc mvc;

    @Test
    void getReturnsContractFields() throws Exception {
        mvc.perform(get("/orders/ord_1001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("ord_1001"))
                .andExpect(jsonPath("$.totalAmount").value(59.90));
    }

    @Test
    void createReturns201() throws Exception {
        mvc.perform(post("/orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"customerId\":\"cus_1\",\"items\":[{\"sku\":\"A\",\"quantity\":1,\"unitPrice\":5}]}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void missingOrderReturnsErrorSchema() throws Exception {
        mvc.perform(get("/orders/ord_9999"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"));
    }
}

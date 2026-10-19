package com.example.orders;

import java.util.List;

/** Response model. Mirrors the Order schema in contract/openapi.yaml. */
public record Order(String id, String customerId, OrderStatus status,
                    double totalAmount, List<OrderItem> items) {

    public Order withStatus(OrderStatus newStatus) {
        return new Order(id, customerId, newStatus, totalAmount, items);
    }
}

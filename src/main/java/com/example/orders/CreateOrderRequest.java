package com.example.orders;

import java.util.List;

/** Request model. couponCode is optional in the contract. */
public record CreateOrderRequest(String customerId, List<OrderItem> items, String couponCode) {}

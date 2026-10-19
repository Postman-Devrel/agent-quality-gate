package com.example.orders;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** In-memory store, seeded with three PENDING orders so the Postman collection has data. */
@Service
public class OrderService {

    private final Map<String, Order> orders = new ConcurrentHashMap<>();
    private final AtomicInteger sequence = new AtomicInteger(1003);

    public OrderService() {
        for (int i = 1001; i <= 1003; i++) {
            var item = new OrderItem("SKU-1", 2, 29.95);
            orders.put("ord_" + i, new Order("ord_" + i, "cus_42", OrderStatus.PENDING, 59.90, List.of(item)));
        }
    }

    public List<Order> list(OrderStatus status) {
        return orders.values().stream()
                .filter(o -> status == null || o.status() == status)
                .sorted((a, b) -> a.id().compareTo(b.id()))
                .toList();
    }

    public Order get(String id) {
        var order = orders.get(id);
        if (order == null) {
            throw new OrderException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Order " + id + " not found");
        }
        return order;
    }

    public Order create(CreateOrderRequest request) {
        if (request.customerId() == null || request.items() == null || request.items().isEmpty()) {
            throw new OrderException(HttpStatus.BAD_REQUEST, "BAD_REQUEST", "customerId and items are required");
        }
        double total = request.items().stream().mapToDouble(i -> i.quantity() * i.unitPrice()).sum();
        var id = "ord_" + sequence.incrementAndGet();
        var order = new Order(id, request.customerId(), OrderStatus.PENDING, total, request.items());
        orders.put(id, order);
        return order;
    }

    public Order updateStatus(String id, UpdateStatusRequest request) {
        if (request.status() == null) {
            throw new OrderException(HttpStatus.BAD_REQUEST, "BAD_REQUEST", "status is required");
        }
        var order = get(id);
        if (order.status() == OrderStatus.CANCELLED || order.status() == OrderStatus.SHIPPED) {
            throw new OrderException(HttpStatus.CONFLICT, "CONFLICT", "Order is " + order.status());
        }
        var updated = order.withStatus(request.status());
        orders.put(id, updated);
        return updated;
    }

    public Order cancel(String id) {
        var order = get(id);
        if (order.status() == OrderStatus.SHIPPED) {
            throw new OrderException(HttpStatus.CONFLICT, "CONFLICT", "Order already shipped");
        }
        var cancelled = order.withStatus(OrderStatus.CANCELLED);
        orders.put(id, cancelled);
        return cancelled;
    }
}

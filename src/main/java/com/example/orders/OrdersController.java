package com.example.orders;

import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

/** One method per operation of contract/openapi.yaml. */
@RestController
@RequestMapping("/orders")
public class OrdersController {

    private final OrderService service;

    public OrdersController(OrderService service) {
        this.service = service;
    }

    @GetMapping
    public List<Order> list(@RequestParam(required = false) OrderStatus status) {
        return service.list(status);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Order create(@RequestBody CreateOrderRequest request) {
        return service.create(request);
    }

    @GetMapping("/{orderId}")
    public Order get(@PathVariable String orderId) {
        return service.get(orderId);
    }

    @PutMapping("/{orderId}/status")
    public Order updateStatus(@PathVariable String orderId, @RequestBody UpdateStatusRequest request) {
        return service.updateStatus(orderId, request);
    }

    @DeleteMapping("/{orderId}")
    public Order cancel(@PathVariable String orderId) {
        return service.cancel(orderId);
    }
}

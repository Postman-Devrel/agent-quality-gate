package com.example.orders;

import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import org.junit.jupiter.api.Test;

class OrderServiceTest {

    private final OrderService service = new OrderService();

    @Test
    void createComputesTotalAndStartsPending() {
        var order = service.create(new CreateOrderRequest("cus_1", List.of(new OrderItem("A", 3, 10.0)), null));
        assertEquals(OrderStatus.PENDING, order.status());
        assertEquals(30.0, order.totalAmount());
    }

    @Test
    void createRejectsEmptyItems() {
        var ex = assertThrows(OrderException.class,
                () -> service.create(new CreateOrderRequest("cus_1", List.of(), null)));
        assertEquals("BAD_REQUEST", ex.code());
    }

    @Test
    void cancelledOrderCannotChangeStatus() {
        service.cancel("ord_1001");
        assertThrows(OrderException.class,
                () -> service.updateStatus("ord_1001", new UpdateStatusRequest(OrderStatus.PAID)));
    }

    @Test
    void unknownOrderIsNotFound() {
        assertThrows(OrderException.class, () -> service.get("ord_9999"));
    }
}

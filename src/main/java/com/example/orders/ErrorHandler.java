package com.example.orders;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.http.converter.HttpMessageNotReadableException;

/** Maps failures to the Error schema of the contract. */
@RestControllerAdvice
public class ErrorHandler {

    @ExceptionHandler(OrderException.class)
    ResponseEntity<ApiError> handle(OrderException e) {
        return ResponseEntity.status(e.status()).body(new ApiError(e.code(), e.getMessage()));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ApiError> unreadable(HttpMessageNotReadableException e) {
        return ResponseEntity.badRequest().body(new ApiError("BAD_REQUEST", "Malformed request body"));
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiError> fallback(Exception e) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ApiError("INTERNAL_ERROR", "Unexpected error"));
    }
}

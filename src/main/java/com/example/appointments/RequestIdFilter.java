package com.example.appointments;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** The contract declares an X-Request-Id response header: echo the caller's id, or generate one. */
@Component
public class RequestIdFilter extends OncePerRequestFilter {

    static final String HEADER = "X-Request-Id";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        var id = request.getHeader(HEADER);
        response.setHeader(HEADER, id == null || id.isBlank() ? UUID.randomUUID().toString() : id);
        chain.doFilter(request, response);
    }
}

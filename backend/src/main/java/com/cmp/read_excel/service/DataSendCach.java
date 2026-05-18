package com.cmp.read_excel.service;


import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import org.springframework.stereotype.Component;

import java.time.Duration;

@Component
public class DataSendCach {

    private final Cache<String, String> cache = Caffeine.newBuilder()
            .expireAfterWrite(Duration.ofDays(4)) // 🔥 4 días automático
            .maximumSize(1_000_000)               // límite para evitar overflow
            .build();

    public void put(String clave, String id) {
        cache.put(normalize(clave), id);
    }

    public String get(String clave) {
        return cache.getIfPresent(normalize(clave));
    }

    private String normalize(String clave) {
        return clave == null ? "" : clave.trim().toUpperCase();
    }
}

package com.cmp.read_excel.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/status")
public class StatusConection {

    @GetMapping
    public ResponseEntity<Map<String, String>> getStatus(){
        
        Map<String, String> value = new HashMap<>();
        value.put("status", "OK");
        value.put("version", "26.05.16");
        value.put("message", "Everything is working fine");

        return ResponseEntity.ok(value);
    }
}

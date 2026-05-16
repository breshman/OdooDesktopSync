package com.cmp.read_excel.controller;

import com.cmp.read_excel.model.AppConfigModel;
import com.cmp.read_excel.service.ConfigService;
import com.cmp.read_excel.service.ExcelService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/items")
public class ItemController {

    private final ExcelService excelService;
    private final ConfigService configService;

    public ItemController(ExcelService excelService, ConfigService configService) {
        this.excelService = excelService;
        this.configService = configService;
    }

    @PostMapping
    public ResponseEntity<List<Map<String, String>>> loadItems(
            @RequestBody List<String> listPaths
    ) {
        log.info("Loading excel files...");
        List<Map<String, String>> items = excelService.processAndGroupItems(
                excelService.processAllExcelFiles(listPaths)
        );
        return ResponseEntity.ok(items);
    }

    @PostMapping("/send")
    public ResponseEntity<String> sendItems(@RequestBody List<Map<String, String>> items) {
        log.info("Received {} items to send to external API.", items.size());
        AppConfigModel config = configService.loadConfig();
        String apiUrl = "No API Configured";
        if (!config.getApi().isEmpty()) {
            apiUrl = config.getApi().get(0).getUrl(); // Using the first API as default simulation
        }
        
        // TODO: Implement HTTP Client to send these items to 'apiUrl'
        // For now, simulating the send process
        log.info("Simulating send to: {}", apiUrl);
        for (Map<String, String> item : items) {
            log.info("Sending item: {}", item);
        }
        
        return ResponseEntity.ok("Items processed successfully");
    }
}

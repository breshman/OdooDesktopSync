package com.cmp.read_excel.controller;

import com.cmp.read_excel.model.AppConfigModel;
import com.cmp.read_excel.service.ConfigService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/config")
public class ConfigController {

    private final ConfigService configService;

    public ConfigController(ConfigService configService) {
        this.configService = configService;
    }

    @GetMapping
    public ResponseEntity<AppConfigModel> getConfig() {
        return ResponseEntity.ok(configService.loadConfig());
    }

    @PostMapping("/api")
    public ResponseEntity<AppConfigModel> addOrUpdateApi(@RequestBody AppConfigModel.ApiConfig newApi) {
        AppConfigModel config = configService.loadConfig();
        // Just append for now, or update if name exists
        config.getApi().removeIf(a -> a.getName().equals(newApi.getName()));
        config.getApi().add(newApi);
        configService.saveConfig(config);
        return ResponseEntity.ok(config);
    }

    @PostMapping("/paths")
    public ResponseEntity<AppConfigModel> addOrUpdatePath(@RequestBody AppConfigModel.PathConfig newPath) {
        AppConfigModel config = configService.loadConfig();
        // Just append for now, or update if path exists
        config.getConfigPaths().removeIf(p -> p.getPath().equals(newPath.getPath()));
        config.getConfigPaths().add(newPath);
        configService.saveConfig(config);
        return ResponseEntity.ok(config);
    }

    @PutMapping
    public ResponseEntity<AppConfigModel> updateFullConfig(@RequestBody AppConfigModel newConfig) {
        configService.saveConfig(newConfig);
        return ResponseEntity.ok(newConfig);
    }
}

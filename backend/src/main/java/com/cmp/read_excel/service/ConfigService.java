package com.cmp.read_excel.service;

import com.cmp.read_excel.model.AppConfigModel;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.File;
import java.io.IOException;

@Slf4j
@Service
public class ConfigService {

    private final ObjectMapper objectMapper;
    private final String CONFIG_FILE_PATH = "config.json";

    public ConfigService(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public AppConfigModel loadConfig() {
        File configFile = new File(CONFIG_FILE_PATH);
        if (configFile.exists()) {
            try {
                return objectMapper.readValue(configFile, AppConfigModel.class);
            } catch (IOException e) {
                log.error("Error reading config.json: {}", e.getMessage());
            }
        } else {
            log.warn("config.json not found, creating default.");
            AppConfigModel defaultConfig = createDefaultConfig();
            saveConfig(defaultConfig);
            return defaultConfig;
        }
        
        // Return a fallback configuration if file creation fails
        return createDefaultConfig();
    }

    public void saveConfig(AppConfigModel config) {
        File configFile = new File(CONFIG_FILE_PATH);
        try {
            objectMapper.writerWithDefaultPrettyPrinter().writeValue(configFile, config);
        } catch (IOException e) {
            log.error("Error saving config.json: {}", e.getMessage());
        }
    }

    private AppConfigModel createDefaultConfig() {
        AppConfigModel config = new AppConfigModel();
        config.getApi().add(new AppConfigModel.ApiConfig("https://api.miempresa.com", "url producion"));
        config.getApi().add(new AppConfigModel.ApiConfig("https://api.miempresa.com", "url test"));
        
        config.getConfigPaths().add(new AppConfigModel.PathConfig("C:/excel", true));
        config.getConfigPaths().add(new AppConfigModel.PathConfig("C:/excel_2", false));
        return config;
    }
}


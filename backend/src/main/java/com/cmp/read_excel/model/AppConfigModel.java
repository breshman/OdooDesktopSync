package com.cmp.read_excel.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

import java.util.ArrayList;
import java.util.List;

@Data
public class AppConfigModel {

    private List<ApiConfig> api = new ArrayList<>();

    @JsonProperty("config_paths")
    private List<PathConfig> configPaths = new ArrayList<>();

    @Data
    public static class ApiConfig {
        private String url;
        private String name;

        public ApiConfig() {}

        public ApiConfig(String url, String name) {
            this.url = url;
            this.name = name;
        }
    }

    @Data
    public static class PathConfig {
        private String path;
        @JsonProperty("is_active")
        private boolean isActive;

        public PathConfig() {}

        public PathConfig(String path, boolean isActive) {
            this.path = path;
            this.isActive = isActive;
        }
    }
}

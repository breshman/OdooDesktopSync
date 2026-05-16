package com.cmp.read_excel.model;

import lombok.Data;

@Data
public class ExcelItem {
    private String codigo;
    private String descripcion;
    private Double cantidad;
    private Boolean selected = true; // Default selected
}

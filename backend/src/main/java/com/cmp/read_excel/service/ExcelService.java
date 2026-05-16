package com.cmp.read_excel.service;

import com.cmp.read_excel.model.AppConfigModel;
import com.cmp.read_excel.model.ExcelItem;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;

import java.io.File;
import java.io.FileInputStream;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
public class ExcelService {

    private final ConfigService configService;

    public ExcelService(ConfigService configService) {
        this.configService = configService;
    }

    public List<ExcelItem> processAllExcelFiles() {
        AppConfigModel config = configService.loadConfig();
        List<ExcelItem> allItems = new ArrayList<>();

        for (AppConfigModel.PathConfig pathConfig : config.getConfigPaths()) {
            if (!pathConfig.isActive()) {
                continue;
            }

            String folderPath = pathConfig.getPath();
            File folder = new File(folderPath);
            if (!folder.exists() || !folder.isDirectory()) {
                log.error("The configured excel path does not exist or is not a directory: {}", folderPath);
                continue;
            }

            File[] files = folder.listFiles((dir, name) -> name.toLowerCase().endsWith(".xlsx") && !name.startsWith("~"));
            if (files == null || files.length == 0) {
                log.info("No .xlsx files found in {}", folderPath);
                continue;
            }

            for (File file : files) {
                log.info("Processing file: {}", file.getName());
                allItems.addAll(readExcelFile(file));
            }
        }

        return allItems;
    }

    private List<ExcelItem> readExcelFile(File file) {
        List<ExcelItem> items = new ArrayList<>();
        try (FileInputStream fis = new FileInputStream(file);
             Workbook workbook = new XSSFWorkbook(fis)) {
             
            Sheet sheet = workbook.getSheetAt(0); // Only reading first sheet
            boolean firstRow = true;
            for (Row row : sheet) {
                if (firstRow) {
                    firstRow = false; // Skip header
                    continue;
                }
                
                // Example assumptions for columns:
                // 0: Codigo
                // 1: Descripcion
                // 2: Cantidad
                
                ExcelItem item = new ExcelItem();
                Cell cellCodigo = row.getCell(0);
                if (cellCodigo != null) {
                    cellCodigo.setCellType(CellType.STRING);
                    item.setCodigo(cellCodigo.getStringCellValue());
                }
                
                Cell cellDescripcion = row.getCell(1);
                if (cellDescripcion != null) {
                    cellDescripcion.setCellType(CellType.STRING);
                    item.setDescripcion(cellDescripcion.getStringCellValue());
                }
                
                Cell cellCantidad = row.getCell(2);
                if (cellCantidad != null) {
                    if (cellCantidad.getCellType() == CellType.NUMERIC) {
                        item.setCantidad(cellCantidad.getNumericCellValue());
                    } else if (cellCantidad.getCellType() == CellType.STRING) {
                        try {
                            item.setCantidad(Double.parseDouble(cellCantidad.getStringCellValue()));
                        } catch (NumberFormatException e) {
                            item.setCantidad(0.0);
                        }
                    }
                }
                
                // Only add if codigo is present
                if (item.getCodigo() != null && !item.getCodigo().trim().isEmpty()) {
                    items.add(item);
                }
            }
        } catch (Exception e) {
            log.error("Failed to read excel file {}: {}", file.getName(), e.getMessage());
        }
        return items;
    }
}

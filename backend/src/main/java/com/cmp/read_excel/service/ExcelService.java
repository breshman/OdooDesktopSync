package com.cmp.read_excel.service;

import com.cmp.read_excel.model.AppConfigModel;
import com.github.pjfanning.xlsx.StreamingReader;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.*;
import org.springframework.stereotype.Service;

import java.io.File;
import java.io.FileInputStream;
import java.math.BigDecimal;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Slf4j
@Service
public class ExcelService {

    private final ConfigService configService;
    private static final int SKIP_ROWS = 11;
    private static final String COL_EMPRESA    = "EMPRESA";
    private static final String COL_SERIE      = "SERIE";
    private static final String COL_NUMERO     = "NUMERO";
    private static final String COL_IMPORTE_ME = "IMPORTE ME";
    private static final String COL_PESO_TOTAL = "PESO TOTAL";
    private static final String COL_CLAVE      = "CLAVE";

    public ExcelService(ConfigService configService) {
        this.configService = configService;
    }

    // ─── Procesamiento paralelo de archivos ───────────────────────────────────
    public List<Map<String, String>> processAllExcelFiles(
            List<String> listPaths
    ) {

        List<File> validFiles = listPaths.stream()
                .map(File::new)
                .filter(f -> {
                    String name = f.getName().toLowerCase();
                    boolean valid = f.exists() && f.isFile()
                            && name.endsWith(".xlsx")
                            && !name.startsWith("~");
                    if (!valid) {
                        String error = "Archivo inválido o no encontrado: " + f.getPath();
                        log.warn(error);

                        try {
                            throw new Exception(error);
                        } catch (Exception e) {
                            throw new RuntimeException(e);
                        }

                    }
                    return valid;
                })
                .collect(Collectors.toList());

        // Procesar archivos en paralelo con ForkJoinPool
        return validFiles.parallelStream()
                .map(file -> {
                    log.info("Procesando archivo: {}", file.getName());
                    try {
                        return readExcelFile(file);
                    } catch (Exception e) {
                        throw new RuntimeException(e);
                    }
                })
                .flatMap(Collection::stream)
                .collect(Collectors.toList());
    }

    // ─── Lectura optimizada con SXSSFWorkbook (streaming) ────────────────────
    private List<Map<String, String>> readExcelFile(File file) throws Exception {
        List<Map<String, String>> allRows = new ArrayList<>(512);

        try (FileInputStream fis = new FileInputStream(file);
             Workbook workbook = StreamingReader.builder()
                     .rowCacheSize(100)    // filas en memoria
                     .bufferSize(4096)     // buffer de lectura en bytes
                     .open(fis)) {

            Sheet sheet = workbook.getSheetAt(0);
            List<String> headers = new ArrayList<>();
            int rowIndex = 0;

            for (Row row : sheet) {
                if (rowIndex < SKIP_ROWS) { rowIndex++; continue; }

                if (rowIndex == SKIP_ROWS) {
                    // Cabecera
                    for (Cell cell : row) {
                        headers.add(getCellValueAsString(cell).trim());
                    }
                    rowIndex++;
                    continue;
                }

                // Datos
                Map<String, String> rowMap = new LinkedHashMap<>(headers.size() * 2);
                boolean hasData = false;

                for (int i = 0; i < headers.size(); i++) {
                    Cell cell = row.getCell(i, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
                    String value = cell != null ? getCellValueAsString(cell).trim() : "";
                    if (!value.isEmpty()) hasData = true;
                    rowMap.put(headers.get(i), value);
                }

                if (hasData) allRows.add(rowMap);
                rowIndex++;
            }

        } catch (Exception e) {
            log.error("Error al leer el archivo {}: {}", file.getName(), e.getMessage());
            throw new Exception("Error al leer el archivo " + file.getName() + " => "+ e.getMessage());
        }

        return allRows;
    }

    // ─── Agrupación optimizada con streams y BigDecimal ──────────────────────
    public List<Map<String, String>> processAndGroupItems(List<Map<String, String>> allItems) {
        // Agrupar en paralelo cuando hay muchos registros
        Map<String, Map<String, String>> grouped = allItems.parallelStream()
                .collect(Collectors.toConcurrentMap(
                        row -> buildKey(row),
                        row -> {
                            Map<String, String> newRow = new LinkedHashMap<>(row);
                            newRow.put(COL_CLAVE,      buildKey(row));
                            newRow.put(COL_IMPORTE_ME, row.getOrDefault(COL_IMPORTE_ME, "0"));
                            newRow.put(COL_PESO_TOTAL, row.getOrDefault(COL_PESO_TOTAL, "0"));
                            return newRow;
                        },
                        (existing, incoming) -> {
                            // Merge: sumar IMPORTE ME y PESO TOTAL
                            existing.put(COL_IMPORTE_ME,
                                    parseBigDecimal(existing.get(COL_IMPORTE_ME))
                                            .add(parseBigDecimal(incoming.get(COL_IMPORTE_ME)))
                                            .toPlainString());
                            existing.put(COL_PESO_TOTAL,
                                    parseBigDecimal(existing.get(COL_PESO_TOTAL))
                                            .add(parseBigDecimal(incoming.get(COL_PESO_TOTAL)))
                                            .toPlainString());
                            return existing;
                        },
                        ConcurrentHashMap::new
                ));

        return new ArrayList<>(grouped.values());
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    private String buildKey(Map<String, String> row) {
        return row.getOrDefault(COL_EMPRESA, "").trim() + " - " +
               row.getOrDefault(COL_SERIE,   "").trim() + " - " +
               row.getOrDefault(COL_NUMERO,  "").trim();
    }

    private String getCellValueAsString(Cell cell) {
        if (cell == null) return "";
        switch (cell.getCellType()) {
            case STRING:  return cell.getStringCellValue();
            case NUMERIC:
                if (DateUtil.isCellDateFormatted(cell))
                    return cell.getLocalDateTimeCellValue().toString();
                return new BigDecimal(cell.getNumericCellValue())
                        .stripTrailingZeros().toPlainString();
            case BOOLEAN: return String.valueOf(cell.getBooleanCellValue());
            case FORMULA:
                try { return new BigDecimal(cell.getNumericCellValue())
                        .stripTrailingZeros().toPlainString(); }
                catch (Exception e) { return cell.getStringCellValue(); }
            default:      return "";
        }
    }

    private BigDecimal parseBigDecimal(String value) {
        try {
            if (value == null || value.isBlank()) return BigDecimal.ZERO;
            return new BigDecimal(value.trim());
        } catch (NumberFormatException e) {
            log.warn("Valor numérico inválido: '{}'", value);
            return BigDecimal.ZERO;
        }
    }
}
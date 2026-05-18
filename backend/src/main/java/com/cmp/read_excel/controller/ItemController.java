package com.cmp.read_excel.controller;

import com.cmp.read_excel.model.AppConfigModel;
import com.cmp.read_excel.model.ErrorResponseBr;
import com.cmp.read_excel.service.ConfigService;
import com.cmp.read_excel.service.DataSendCach;
import com.cmp.read_excel.service.ExcelService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/excel")
public class ItemController {

    private final ExcelService excelService;

    private final DataSendCach dataSendCach;
    public ItemController() {
        this.dataSendCach = new DataSendCach();
        this.excelService = new ExcelService(this.dataSendCach);

    }


    @PostMapping("/items")
    public ResponseEntity<?> loadItems(
            @RequestBody List<String> listPaths,
            HttpServletRequest request
    ) {

        try {

            log.info("Loading excel files...");

            List<Map<String, String>> items =
                    excelService.processAndGroupItems(
                            excelService.processAllExcelFiles(listPaths)
                    );

            return ResponseEntity.ok(items);

        } catch (RuntimeException e) {

            ErrorResponseBr error = new ErrorResponseBr(
                    LocalDateTime.now(),
                    HttpStatus.BAD_REQUEST.value(),
                    "Bad Request",
                    e.getMessage(),
                    request.getRequestURI()
            );

            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(error);

        } catch (Exception e) {

            log.error("Error processing excel files", e);

            ErrorResponseBr error = new ErrorResponseBr(
                    LocalDateTime.now(),
                    HttpStatus.INTERNAL_SERVER_ERROR.value(),
                    "Internal Server Error",
                    "An unexpected error occurred",
                    request.getRequestURI()
            );

            return ResponseEntity
                    .status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(error);
        }
    }

    @PostMapping("/cache")
    public ResponseEntity<String> sendItems(
            @RequestBody List<Map<String, Object>> data
    ) {

        log.info("Saving {} trazabilidad records", data.size());

        data.forEach(item -> {
            String clave = item.get("unique_key").toString();
            String id = item.get("doc_traceability_id").toString();

            dataSendCach.put(clave, id);
        });

        return ResponseEntity.ok("Datos guardados en memoria");

    }
}

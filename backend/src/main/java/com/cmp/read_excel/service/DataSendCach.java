package com.cmp.read_excel.service;


import com.cmp.read_excel.entity.DataSendCacheEntity;
import com.cmp.read_excel.entity.DataSendCacheRepository;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;


import java.time.LocalDateTime;
import java.util.Optional;

@Component
public class DataSendCach {

    private final DataSendCacheRepository repository;

    public DataSendCach(DataSendCacheRepository repository) {
        this.repository = repository;
    }

    @PostConstruct
    public void init() {

        cleanOldRecords();
    }


    public void put(String clave, String id) {

        String key = normalize(clave);

        Optional<DataSendCacheEntity> existe =
                repository.findById(key);

        if (existe.isPresent()) {

            DataSendCacheEntity entity = existe.get();

            entity.setValor(id);

            repository.save(entity);

        } else {

            repository.save(
                    new DataSendCacheEntity(key, id)
            );
        }
    }

    public String get(String clave) {

        return repository
                .findById(normalize(clave))
                .map(DataSendCacheEntity::getValor)
                .orElse(null);
    }

    private String normalize(String clave) {
        return clave == null
                ? ""
                : clave.trim().toUpperCase();
    }

    private void cleanOldRecords() {

        LocalDateTime limit =
                LocalDateTime.now().minusDays(4);

        repository.deleteByCreateAtBefore(limit);
    }
}
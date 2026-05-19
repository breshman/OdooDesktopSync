package com.cmp.read_excel.entity;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;


public interface  DataSendCacheRepository extends JpaRepository<DataSendCacheEntity, String> {

    void deleteByCreateAtBefore(LocalDateTime dateTime);
}

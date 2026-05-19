package com.cmp.read_excel.entity;


import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.Date;

@Entity
@Table(name = "data_send_cache")
public class DataSendCacheEntity {


    @Id
    @Column(length = 100, unique = true)
    private String clave;

    @Column(length = 10)
    private String valor;

    @Temporal(TemporalType.TIMESTAMP)
    @CreationTimestamp
    @Column(name = "create_at", nullable = false, updatable = false)
    private LocalDateTime createAt;

    public DataSendCacheEntity() {
    }

    public DataSendCacheEntity(String clave, String valor) {
        this.clave = clave;
        this.valor = valor;
    }

    public String getClave() {
        return clave;
    }

    public void setClave(String clave) {
        this.clave = clave;
    }

    public String getValor() {
        return valor;
    }

    public void setValor(String valor) {
        this.valor = valor;
    }

    public LocalDateTime  getCreateAt(){
        return createAt;
    }
}

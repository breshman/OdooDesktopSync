package com.cmp.read_excel;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import java.io.File;

@SpringBootApplication
public class Main {

	public static void main(String[] args) {

		File dataDir = new File("./data");

		if (!dataDir.exists()) {
			dataDir.mkdirs();
		}

		SpringApplication.run(Main.class, args);
	}

}

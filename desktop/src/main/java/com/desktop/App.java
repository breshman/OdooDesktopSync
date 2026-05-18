package com.desktop;

import me.friwi.jcefmaven.CefAppBuilder;
import me.friwi.jcefmaven.CefInitializationException;
import me.friwi.jcefmaven.UnsupportedPlatformException;
import org.cef.CefApp;
import org.cef.CefApp.CefAppState;
import org.cef.CefClient;
import org.cef.browser.CefBrowser;
import org.cef.browser.CefMessageRouter;

import javax.swing.*;
import java.awt.*;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.File;
import java.io.IOException;

public class App {

    private static Process backendProcess = null;

    public static void main(String[] args) {
        System.out.println("Starting Odoo Desktop Sync...");

        // 1. Attempt to start the backend if app.jar exists
        startBackendProcess();

        // 2. Initialize JCEF and Swing UI
        try {
            // Build CefApp
            CefAppBuilder builder = new CefAppBuilder();
            // Windowless rendering is usually not needed for a standard desktop app, 
            // but setting it up depends on OS. We'll use standard rendering.
            builder.getCefSettings().windowless_rendering_enabled = false;
            
            // Set an install directory for JCEF binaries
            builder.setInstallDir(new File("jcef-bundle"));

            CefApp cefApp = builder.build();

            // Create client
            CefClient client = cefApp.createClient();
            CefMessageRouter msgRouter = CefMessageRouter.create();
            client.addMessageRouter(msgRouter);

            // Create browser instance pointing to the backend/frontend URL
            // Defaulting to 8080 (Spring Boot) or 5173 (Vite Dev)
//            String startUrl = "http://localhost:8018";
            String startUrl = "https://110931090-18-0-all.runbot302.odoo.com";
            CefBrowser browser = client.createBrowser(startUrl, false, false);
            Component browserUI = browser.getUIComponent();

            // Create JFrame
            JFrame frame = new JFrame("Odoo Desktop Sync");
            frame.getContentPane().add(browserUI, BorderLayout.CENTER);
            ImageIcon icon = new ImageIcon("icons/logo odoo CMP.png");
            frame.setIconImage(icon.getImage());
            frame.setSize(1200, 800);
            frame.setLocationRelativeTo(null); // Center on screen
            
            // Handle window close to dispose JCEF and terminate backend
            frame.addWindowListener(new WindowAdapter() {
                @Override
                public void windowClosing(WindowEvent e) {
                    System.out.println("Closing application...");
                    CefApp.getInstance().dispose();
                    frame.dispose();
                    
                    if (backendProcess != null && backendProcess.isAlive()) {
                        System.out.println("Stopping backend process...");
                        backendProcess.destroy();
                    }
                    
                    System.exit(0);
                }
            });

            // Show window
            frame.setVisible(true);

        } catch (UnsupportedPlatformException | CefInitializationException | IOException | InterruptedException e) {
            e.printStackTrace();
            JOptionPane.showMessageDialog(null, "Error initializing Chromium: " + e.getMessage());
            System.exit(1);
        }
    }

    /**
     * Helper to start the Spring Boot backend via ProcessBuilder if 'app.jar' is found.
     * In a real production release, 'app.jar' would be placed next to the executable.
     */
    private static void startBackendProcess() {
        File backendJar = new File("app.jar");
        
        // As a fallback for development, check if it's in the backend target folder
        if (!backendJar.exists()) {
            backendJar = new File("../backend/target/app.jar");
        }

        if (backendJar.exists()) {
            System.out.println("Found backend JAR: " + backendJar.getAbsolutePath() + ". Starting it...");
            try {
                ProcessBuilder pb = new ProcessBuilder("java", "-jar", backendJar.getAbsolutePath());
                pb.inheritIO(); // Pipe output to the current console
                backendProcess = pb.start();
                
                // Give it a couple of seconds to boot up before the browser tries to load
                Thread.sleep(3000);
            } catch (IOException | InterruptedException e) {
                System.err.println("Failed to start backend process: " + e.getMessage());
            }
        } else {
            System.out.println("Backend JAR not found. Assuming backend is running independently (e.g. from IDE).");
        }
    }
}

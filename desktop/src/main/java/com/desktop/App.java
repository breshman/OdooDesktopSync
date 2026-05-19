package com.desktop;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
import java.awt.*;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.File;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;

public class App {

    public enum BackendStatus {
        STOPPED,
        STARTING,
        RUNNING,
        STOPPING
    }

    private static Process backendProcess = null;
    private static BackendStatus currentStatus = BackendStatus.STOPPED;

    // UI Elements
    private static JLabel statusDot;
    private static JLabel statusLabel;
    private static JButton startBtn;
    private static JButton stopBtn;
    private static JButton restartBtn;
    private static JFrame frame;

    public static void main(String[] args) {
        System.out.println("Starting Odoo Desktop Sync Panel...");

        // Initialize FlatLaf Dark theme for modern state-of-the-art UI
        try {
            UIManager.setLookAndFeel(new com.formdev.flatlaf.FlatDarkLaf());
            // Customizations for cleaner visual aesthetics
            UIManager.put("Button.arc", 10);
            UIManager.put("Component.arc", 10);
        } catch (Exception e) {
            System.err.println("FlatLaf not supported, using default system look and feel.");
        }

        // Initialize Swing UI on the Event Dispatch Thread
        SwingUtilities.invokeLater(() -> {
            // Create JFrame
            frame = new JFrame("Odoo Desktop Sync");
            frame.setDefaultCloseOperation(JFrame.DO_NOTHING_ON_CLOSE);
            ImageIcon icon = new ImageIcon("icons/logo odoo CMP.png");
            if (new File("icons/logo odoo CMP.png").exists()) {
                frame.setIconImage(icon.getImage());
            }
            frame.setSize(480, 280);
            frame.setLocationRelativeTo(null); // Center on screen
            frame.setResizable(false);

            // Set main layout and background
            JPanel mainContainer = new JPanel(new BorderLayout());
            mainContainer.setBackground(new Color(24, 24, 26)); // Ultra-modern dark background
            frame.setContentPane(mainContainer);

            // 1. Header Panel
            JPanel headerPanel = new JPanel(new GridBagLayout());
            headerPanel.setOpaque(false);
            headerPanel.setBorder(new EmptyBorder(20, 24, 4, 24));
            
            GridBagConstraints gbc = new GridBagConstraints();
            gbc.gridx = 0;
            gbc.gridy = 0;
            gbc.anchor = GridBagConstraints.WEST;
            
            JLabel titleLabel = new JLabel("Odoo Desktop Sync");
            titleLabel.setFont(new Font("Segoe UI", Font.BOLD, 22));
            titleLabel.setForeground(Color.WHITE);
            headerPanel.add(titleLabel, gbc);

            gbc.gridy = 1;
            gbc.insets = new Insets(2, 0, 0, 0);
            JLabel subtitleLabel = new JLabel("Control de Servicio del Servidor");
            subtitleLabel.setFont(new Font("Segoe UI", Font.PLAIN, 12));
            subtitleLabel.setForeground(new Color(150, 150, 155));
            headerPanel.add(subtitleLabel, gbc);

            mainContainer.add(headerPanel, BorderLayout.NORTH);

            // 2. Central Service Status & Buttons Panel
            JPanel contentCard = new JPanel(new GridBagLayout());
            contentCard.setBackground(new Color(34, 34, 38));
            contentCard.setBorder(BorderFactory.createCompoundBorder(
                    BorderFactory.createLineBorder(new Color(62, 62, 66), 1, true),
                    new EmptyBorder(16, 20, 16, 20)
            ));

            GridBagConstraints cGbc = new GridBagConstraints();
            cGbc.gridx = 0;
            cGbc.gridy = 0;
            cGbc.weightx = 1.0;
            cGbc.anchor = GridBagConstraints.CENTER;
            cGbc.insets = new Insets(0, 0, 16, 0);

            // Status Indicator Row (Dot + Status Text)
            JPanel statusPanel = new JPanel(new FlowLayout(FlowLayout.CENTER, 8, 0));
            statusPanel.setOpaque(false);

            statusDot = new JLabel("●");
            statusDot.setFont(new Font("Segoe UI", Font.BOLD, 24));
            statusDot.setForeground(new Color(255, 85, 85));

            statusLabel = new JLabel("Backend: Offline");
            statusLabel.setFont(new Font("Segoe UI", Font.BOLD, 15));
            statusLabel.setForeground(new Color(230, 230, 235));

            statusPanel.add(statusDot);
            statusPanel.add(statusLabel);
            contentCard.add(statusPanel, cGbc);

            // Buttons Row
            cGbc.gridy = 1;
            cGbc.fill = GridBagConstraints.HORIZONTAL;
            cGbc.insets = new Insets(0, 0, 0, 0);

            JPanel buttonsPanel = new JPanel(new GridLayout(1, 3, 10, 0));
            buttonsPanel.setOpaque(false);

            startBtn = new JButton("▶ Iniciar");
            startBtn.setFont(new Font("Segoe UI", Font.BOLD, 12));
            startBtn.setBackground(new Color(36, 110, 50));
            startBtn.setForeground(Color.WHITE);
            startBtn.setPreferredSize(new Dimension(110, 36));

            stopBtn = new JButton("■ Detener");
            stopBtn.setFont(new Font("Segoe UI", Font.BOLD, 12));
            stopBtn.setBackground(new Color(140, 32, 32));
            stopBtn.setForeground(Color.WHITE);
            stopBtn.setPreferredSize(new Dimension(110, 36));

            restartBtn = new JButton("↻ Reiniciar");
            restartBtn.setFont(new Font("Segoe UI", Font.BOLD, 12));
            restartBtn.setPreferredSize(new Dimension(110, 36));

            buttonsPanel.add(startBtn);
            buttonsPanel.add(stopBtn);
            buttonsPanel.add(restartBtn);
            contentCard.add(buttonsPanel, cGbc);

            // Add Margin around the card
            JPanel cardContainer = new JPanel(new BorderLayout());
            cardContainer.setOpaque(false);
            cardContainer.setBorder(new EmptyBorder(10, 24, 24, 24));
            cardContainer.add(contentCard, BorderLayout.CENTER);

            mainContainer.add(cardContainer, BorderLayout.CENTER);

            // Action Listeners for Service Controls
            startBtn.addActionListener(e -> startBackendProcessAsync());
            stopBtn.addActionListener(e -> stopBackendProcessAsync());
            restartBtn.addActionListener(e -> restartBackendProcessAsync());

            // Handle window close cleanly
            frame.addWindowListener(new WindowAdapter() {
                @Override
                public void windowClosing(WindowEvent e) {
                    System.out.println("Closing application, cleaning up processes...");
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

            // Initialize status monitor and auto-start the backend
            updateStatus(BackendStatus.STOPPED);
            startStatusMonitor();
            startBackendProcessAsync();
        });
    }

    /**
     * Updates the UI status controls safely on the Event Dispatch Thread.
     */
    private static void updateStatus(BackendStatus status) {
        currentStatus = status;
        SwingUtilities.invokeLater(() -> {
            switch (status) {
                case STOPPED:
                    statusDot.setForeground(new Color(255, 85, 85)); // Pastel Red
                    statusLabel.setText("Backend: Offline");
                    startBtn.setEnabled(true);
                    stopBtn.setEnabled(false);
                    restartBtn.setEnabled(false);
                    break;
                case STARTING:
                    statusDot.setForeground(new Color(255, 184, 108)); // Pastel Orange/Yellow
                    statusLabel.setText("Backend: Iniciando...");
                    startBtn.setEnabled(false);
                    stopBtn.setEnabled(false);
                    restartBtn.setEnabled(false);
                    break;
                case RUNNING:
                    statusDot.setForeground(new Color(80, 250, 123)); // Pastel Green
                    statusLabel.setText("Backend: Online (Port 8542)");
                    startBtn.setEnabled(false);
                    stopBtn.setEnabled(true);
                    restartBtn.setEnabled(true);
                    break;
                case STOPPING:
                    statusDot.setForeground(new Color(255, 184, 108)); // Pastel Orange/Yellow
                    statusLabel.setText("Backend: Deteniendo...");
                    startBtn.setEnabled(false);
                    stopBtn.setEnabled(false);
                    restartBtn.setEnabled(false);
                    break;
            }
        });
    }

    /**
     * Starts the Spring Boot backend jar in a background thread.
     */
    private static void startBackendProcessAsync() {
        updateStatus(BackendStatus.STARTING);
        new Thread(() -> {
            File backendJar = new File("app.jar");
            if (!backendJar.exists()) {
                backendJar = new File("../backend/target/app.jar");
            }

            if (backendJar.exists()) {
                System.out.println("Found backend JAR: " + backendJar.getAbsolutePath() + ". Starting process...");
                try {
                    ProcessBuilder pb = new ProcessBuilder("java", "-jar", backendJar.getAbsolutePath());
                    pb.inheritIO();
                    backendProcess = pb.start();

                    // Poll the service port until it responds or fails
                    int maxSeconds = 30;
                    for (int i = 0; i < maxSeconds; i++) {
                        if (backendProcess == null || !backendProcess.isAlive()) {
                            break;
                        }
                        if (isBackendResponsive()) {
                            updateStatus(BackendStatus.RUNNING);
                            return;
                        }
                        Thread.sleep(1000);
                    }

                    if (backendProcess != null && backendProcess.isAlive()) {
                        updateStatus(BackendStatus.RUNNING);
                    } else {
                        updateStatus(BackendStatus.STOPPED);
                    }

                } catch (Exception e) {
                    System.err.println("Failed to start backend process: " + e.getMessage());
                    updateStatus(BackendStatus.STOPPED);
                }
            } else {
                System.out.println("Backend JAR (app.jar) not found. Checking if backend is already listening...");
                if (isBackendResponsive()) {
                    updateStatus(BackendStatus.RUNNING);
                } else {
                    updateStatus(BackendStatus.STOPPED);
                    SwingUtilities.invokeLater(() -> {
                        JOptionPane.showMessageDialog(frame,
                                "No se encontró 'app.jar'. Por favor compile el backend primero\n" +
                                "usando 'BuildAndPackage.ps1' o ejecutando 'mvnw.cmd clean package' en la carpeta backend.",
                                "Backend JAR No Encontrado", JOptionPane.WARNING_MESSAGE);
                    });
                }
            }
        }).start();
    }

    /**
     * Stops the Spring Boot backend process cleanly.
     */
    private static void stopBackendProcessAsync() {
        updateStatus(BackendStatus.STOPPING);
        new Thread(() -> {
            try {
                if (backendProcess != null) {
                    backendProcess.destroy();
                    int count = 0;
                    while (backendProcess.isAlive() && count < 10) {
                        Thread.sleep(500);
                        count++;
                    }
                    if (backendProcess.isAlive()) {
                        backendProcess.destroyForcibly();
                    }
                    backendProcess = null;
                }
            } catch (Exception e) {
                System.err.println("Error stopping backend process: " + e.getMessage());
            } finally {
                updateStatus(BackendStatus.STOPPED);
            }
        }).start();
    }

    /**
     * Restarts the Spring Boot backend process.
     */
    private static void restartBackendProcessAsync() {
        updateStatus(BackendStatus.STOPPING);
        new Thread(() -> {
            try {
                if (backendProcess != null) {
                    backendProcess.destroy();
                    int count = 0;
                    while (backendProcess.isAlive() && count < 10) {
                        Thread.sleep(500);
                        count++;
                    }
                    if (backendProcess.isAlive()) {
                        backendProcess.destroyForcibly();
                    }
                    backendProcess = null;
                }
                Thread.sleep(1000); // Allow OS to fully release port
                startBackendProcessAsync();
            } catch (Exception e) {
                System.err.println("Error restarting backend process: " + e.getMessage());
                updateStatus(BackendStatus.STOPPED);
            }
        }).start();
    }

    /**
     * Checks if the backend port (8542) is actively listening and responsive.
     */
    private static boolean isBackendResponsive() {
        try {
            URL url = new URL("http://localhost:8542");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(800);
            conn.setReadTimeout(800);
            int code = conn.getResponseCode();
            return code >= 200 && code < 400 || code == 404;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Periodically monitors the backend status in the background.
     */
    private static void startStatusMonitor() {
        Thread monitor = new Thread(() -> {
            while (true) {
                try {
                    Thread.sleep(2000);
                    if (currentStatus == BackendStatus.RUNNING) {
                        if (backendProcess == null || !backendProcess.isAlive() || !isBackendResponsive()) {
                            updateStatus(BackendStatus.STOPPED);
                        }
                    } else if (currentStatus == BackendStatus.STOPPED) {
                        if (isBackendResponsive()) {
                            updateStatus(BackendStatus.RUNNING);
                        }
                    }
                } catch (InterruptedException e) {
                    break;
                }
            }
        });
        monitor.setDaemon(true);
        monitor.start();
    }
}

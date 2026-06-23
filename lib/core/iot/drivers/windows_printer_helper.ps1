param(
    [string]$Action,
    [string]$PrinterName,
    [string]$FilePath,
    [string]$Protocol
)

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

$code = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class RawPrinterHelper {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public class DOCINFOA {
        [MarshalAs(UnmanagedType.LPStr)]
        public string pDocName;
        [MarshalAs(UnmanagedType.LPStr)]
        public string pOutputFile;
        [MarshalAs(UnmanagedType.LPStr)]
        public string pDataType;
    }

    [DllImport("winspool.Drv", EntryPoint = "OpenPrinterA", SetLastError = true, CharSet = CharSet.Ansi, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPStr)] string szPrinter, out IntPtr hPrinter, IntPtr pd);

    [DllImport("winspool.Drv", EntryPoint = "ClosePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartDocPrinterA", SetLastError = true, CharSet = CharSet.Ansi, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, Int32 level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);

    [DllImport("winspool.Drv", EntryPoint = "EndDocPrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "EndPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "WritePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, Int32 dwCount, out Int32 dwWritten);

    public static bool SendBytesToPrinter(string szPrinterName, byte[] bytes) {
        IntPtr hPrinter = new IntPtr(0);
        DOCINFOA di = new DOCINFOA();
        bool bSuccess = false;

        di.pDocName = "Odoo Print Job";
        di.pDataType = "RAW";

        if (OpenPrinter(szPrinterName, out hPrinter, IntPtr.Zero)) {
            if (StartDocPrinter(hPrinter, 1, di)) {
                if (StartPagePrinter(hPrinter)) {
                    IntPtr pBytes = Marshal.AllocCoTaskMem(bytes.Length);
                    Marshal.Copy(bytes, 0, pBytes, bytes.Length);
                    Int32 dwWritten = 0;
                    bSuccess = WritePrinter(hPrinter, pBytes, bytes.Length, out dwWritten);
                    Marshal.FreeCoTaskMem(pBytes);
                    EndPagePrinter(hPrinter);
                }
                EndDocPrinter(hPrinter);
            }
            ClosePrinter(hPrinter);
        }
        return bSuccess;
    }

    public static bool SendFileToPrinter(string szPrinterName, string szFileName) {
        if (!File.Exists(szFileName)) return false;
        try {
            byte[] bytes = File.ReadAllBytes(szFileName);
            return SendBytesToPrinter(szPrinterName, bytes);
        } catch {
            return false;
        }
    }

    public static bool SendImageToPrinter(string szPrinterName, string imagePath, string protocol) {
        if (!File.Exists(imagePath)) return false;
        try {
            byte[] bytes = (protocol.ToLower() == "star") 
                ? GetStarRasterBytes(imagePath) 
                : GetEscPosRasterBytes(imagePath);
            return SendBytesToPrinter(szPrinterName, bytes);
        } catch {
            return false;
        }
    }

    private static byte[] GetEscPosRasterBytes(string imagePath) {
        using (Bitmap bmp = new Bitmap(imagePath)) {
            int width = bmp.Width;
            int height = bmp.Height;
            int widthBytes = (width + 7) / 8;
            
            List<byte> rasterData = new List<byte>();
            byte[] rasterSend = new byte[] { 0x1D, 0x76, 0x30, 0x00 };
            int maxSliceHeight = 255;
            int currentY = 0;
            
            while (currentY < height) {
                int sliceHeight = Math.Min(maxSliceHeight, height - currentY);
                rasterData.AddRange(rasterSend);
                rasterData.Add((byte)(widthBytes & 0xFF));
                rasterData.Add((byte)((widthBytes >> 8) & 0xFF));
                rasterData.Add((byte)(sliceHeight & 0xFF));
                rasterData.Add((byte)((sliceHeight >> 8) & 0xFF));
                
                for (int y = 0; y < sliceHeight; y++) {
                    int pixelY = currentY + y;
                    for (int xByte = 0; xByte < widthBytes; xByte++) {
                        byte b = 0;
                        for (int bit = 0; bit < 8; bit++) {
                            int pixelX = xByte * 8 + bit;
                            if (pixelX < width) {
                                Color c = bmp.GetPixel(pixelX, pixelY);
                                double gray = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B;
                                if (gray < 128) {
                                    b |= (byte)(1 << (7 - bit));
                                }
                            }
                        }
                        rasterData.Add(b);
                    }
                }
                currentY += sliceHeight;
            }
            rasterData.AddRange(new byte[] { 0x1D, 0x56, 0x41, 0x00 });
            return rasterData.ToArray();
        }
    }

    private static byte[] GetStarRasterBytes(string imagePath) {
        using (Bitmap bmp = new Bitmap(imagePath)) {
            int width = bmp.Width;
            int height = bmp.Height;
            int widthBytes = (width + 7) / 8;
            
            List<byte> rasterData = new List<byte>();
            rasterData.AddRange(new byte[] { 0x1B, 0x2A, 0x72, 0x41 });
            rasterData.AddRange(new byte[] { 0x1B, 0x2A, 0x72, 0x50, 0x30, 0x00 });
            
            for (int y = 0; y < height; y++) {
                rasterData.Add((byte)'b');
                rasterData.Add((byte)(widthBytes & 0xFF));
                rasterData.Add((byte)((widthBytes >> 8) & 0xFF));
                
                for (int xByte = 0; xByte < widthBytes; xByte++) {
                    byte b = 0;
                    for (int bit = 0; bit < 8; bit++) {
                        int pixelX = xByte * 8 + bit;
                        if (pixelX < width) {
                            Color c = bmp.GetPixel(pixelX, y);
                            double gray = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B;
                            if (gray < 128) {
                                b |= (byte)(1 << (7 - bit));
                            }
                        }
                    }
                    rasterData.Add(b);
                }
            }
            rasterData.AddRange(new byte[] { 0x1B, 0x2A, 0x72, 0x42 });
            rasterData.AddRange(new byte[] { 0x1B, 0x64, 0x02 });
            return rasterData.ToArray();
        }
    }
}
"@

Add-Type -TypeDefinition $code -ReferencedAssemblies "System.Drawing"

if ($Action -eq "raw") {
    $res = [RawPrinterHelper]::SendFileToPrinter($PrinterName, $FilePath)
    Write-Output $res
} elseif ($Action -eq "image") {
    $res = [RawPrinterHelper]::SendImageToPrinter($PrinterName, $FilePath, $Protocol)
    Write-Output $res
} elseif ($Action -eq "pdf") {
    try {
        $proc = Start-Process -FilePath $FilePath -Verb PrintTo -ArgumentList $PrinterName -WindowStyle Hidden -PassThru -ErrorAction Stop
        Start-Sleep -Seconds 5
        if ($proc -and -not $proc.HasExited) { $proc.Kill() }
        Write-Output "True"
    } catch {
        try {
            $oldDefault = Get-CimInstance -Query "Select * from Win32_Printer Where Default = True"
            (Get-CimInstance -Query "Select * from Win32_Printer Where Name = '$PrinterName'").SetDefaultPrinter()
            $proc = Start-Process -FilePath $FilePath -Verb Print -WindowStyle Hidden -PassThru
            Start-Sleep -Seconds 5
            if ($proc -and -not $proc.HasExited) { $proc.Kill() }
            (Get-CimInstance -Query "Select * from Win32_Printer Where Name = '$($oldDefault.Name)'").SetDefaultPrinter()
            Write-Output "True"
        } catch {
            Write-Output "False"
        }
    }
}

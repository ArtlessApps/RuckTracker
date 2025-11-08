//
//  DebugLogger.swift
//  RuckTracker
//
//  Simple file logger for capturing logs during outdoor testing
//

import Foundation
import SwiftUI

class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    
    private var logFile: URL?
    private let dateFormatter: DateFormatter
    @Published var logContents: String = ""
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        
        // Create log file in Documents directory
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            logFile = documentsPath.appendingPathComponent("MARCH_Log_\(timestamp).txt")
            
            print("📝 Log file will be saved to: \(logFile?.path ?? "unknown")")
            
            // Write header
            log("===== RUCK TRACKER DEBUG LOG =====")
            log("Started: \(Date())")
            log("Path: \(logFile?.path ?? "unknown")")
            log("===================================\n")
        }
    }
    
    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // Also print to console
        print(message)
        
        // Update in-memory log (for viewer)
        DispatchQueue.main.async {
            self.logContents += logMessage
        }
        
        // Write to file
        guard let logFile = logFile else { return }
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                // Append to existing file
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // Create new file
                try? data.write(to: logFile)
            }
        }
    }
    
    func getLogFilePath() -> String? {
        return logFile?.path
    }
    
    func getLogFileURL() -> URL? {
        return logFile
    }
    
    func getAllLogs() -> String {
        guard let logFile = logFile else { return "No log file" }
        
        if let contents = try? String(contentsOf: logFile, encoding: .utf8) {
            return contents
        }
        return "Unable to read log file"
    }
    
    func shareLogs() -> URL? {
        return logFile
    }
    
    func clearLogs() {
        guard let logFile = logFile else { return }
        try? FileManager.default.removeItem(at: logFile)
        
        logContents = ""
        
        // Create new log file
        log("===== LOG CLEARED =====\n")
    }
}

// MARK: - Debug Log Viewer
struct DebugLogViewer: View {
    @StateObject private var logger = DebugLogger.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Info bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug Logs")
                            .font(.headline)
                        if let path = logger.getLogFilePath() {
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        logger.clearLogs()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Log contents
                ScrollView {
                    ScrollViewReader { proxy in
                        Text(logger.logContents.isEmpty ? "No logs yet. Start a workout to see logs appear." : logger.logContents)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .id("bottom")
                            .onChange(of: logger.logContents) { _, _ in
                                withAnimation {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = logger.shareLogs() {
                    ShareSheet(items: [url])
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


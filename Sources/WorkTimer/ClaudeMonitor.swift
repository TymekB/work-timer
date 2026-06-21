import Foundation

final class ClaudeMonitor {
    var cpuThreshold: Double

    private(set) var lastCpu: Double = 0
    private(set) var lastRunning: Bool = false

    init(cpuThreshold: Double) {
        self.cpuThreshold = cpuThreshold
    }

    func isWorking() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pcpu,comm"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else { return false }

        var totalCpu = 0.0
        var running = false

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let spaceIndex = trimmed.firstIndex(of: " ") else { continue }
            let cpuString = String(trimmed[trimmed.startIndex..<spaceIndex])
            let comm = String(trimmed[trimmed.index(after: spaceIndex)...]).trimmingCharacters(in: .whitespaces)

            guard comm == "claude", let cpu = Double(cpuString) else { continue }
            running = true
            totalCpu += cpu
        }

        lastCpu = totalCpu
        lastRunning = running
        return running && totalCpu >= cpuThreshold
    }
}

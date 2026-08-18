import Darwin
import Foundation
import ShixinStressPowerCore

@main
struct ShixinStressPowerHelperMain {
    static func main() async {
        let arguments = CommandLine.arguments
        if arguments.contains("--temperature-debug") {
            print(HardwareDiagnostics.temperatureDebugSummary())
            exit(0)
        }

        if arguments.contains("--sample") {
            let sample = await TelemetrySampler().sample(preferHelper: false)
            do {
                let data = try JSONEncoder.helperEncoder.encode(sample)
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
                exit(sample.isDegraded ? 2 : 0)
            } catch {
                fputs("encode failed: \(error.localizedDescription)\n", stderr)
                exit(3)
            }
        }

        let server = HelperSocketServer()
        let signalQueue = DispatchQueue(
            label: "com.shixinqvq.shixinlab.macstresspower.helper.signals"
        )
        var signalSources: [DispatchSourceSignal] = []
        for signalNumber in [SIGTERM, SIGINT] {
            Darwin.signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(
                signal: signalNumber,
                queue: signalQueue
            )
            source.setEventHandler {
                server.stop()
            }
            source.resume()
            signalSources.append(source)
        }
        defer {
            signalSources.forEach { $0.cancel() }
        }

        do {
            try server.run()
        } catch {
            fputs("helper failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

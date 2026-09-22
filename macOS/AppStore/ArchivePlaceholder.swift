import Foundation

// Xcode provides the signed app-bundle/archive envelope. The build phase replaces
// this placeholder executable with the real SwiftPM product before code signing.
@main
struct ByteKibbleArchivePlaceholder {
    static func main() {}
}

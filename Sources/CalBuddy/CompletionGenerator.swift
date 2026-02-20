import ArgumentParser
import Foundation

func generateCompletionScript(for shell: String) -> String? {
    switch shell.lowercased() {
    case "bash":
        return CalBuddyCLI.completionScript(for: .bash)
    case "zsh":
        return CalBuddyCLI.completionScript(for: .zsh)
    case "fish":
        return CalBuddyCLI.completionScript(for: .fish)
    default:
        return nil
    }
}


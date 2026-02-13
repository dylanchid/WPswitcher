import SwiftUI

struct ErrorBanner: View {
    @ObservedObject var errorManager: ErrorManager

    var body: some View {
        VStack {
            if errorManager.showError, let error = errorManager.currentError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: errorManager.dismissCurrentError) {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: errorManager.showError)
            }
            
            Spacer()
        }
    }
}

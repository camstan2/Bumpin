import SwiftUI

struct QueueStatusView: View {
    @ObservedObject var viewModel: RandomChatViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Status Header
            VStack(spacing: 8) {
                // Progress Indicator
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(Color.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
                    
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
                
                Text(viewModel.queueStatusText)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Queue time: \(viewModel.queueTimeString)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Group Status (if applicable)
            if viewModel.groupSize > 1 {
                VStack(spacing: 8) {
                    Text("Group Status")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        ForEach(0..<viewModel.groupSize, id: \.self) { index in
                            let isFilled = index < viewModel.connectedGroupMembers.count
                            Circle()
                                .fill(isFilled ? Color.purple : Color(.systemGray5))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(isFilled ? .white : .secondary)
                                )
                        }
                    }
                    
                    Text("\(viewModel.connectedGroupMembers.count)/\(viewModel.groupSize) group members ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Queue Stats
            HStack(spacing: 24) {
                VStack {
                    Text("\(viewModel.queuedUsers)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("In Queue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(viewModel.activeChats)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Active Chats")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(viewModel.averageWaitTime)s")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Avg. Wait")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            
            // Cancel Button
            Button(role: .destructive) {
                viewModel.leaveQueue()
            } label: {
                Text("Leave Queue")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
}

// MARK: - Queue Status Display
extension QueueStatus {
    var displayText: String {
        switch self {
        case .waiting:
            return "Finding your match..."
        case .matching:
            return "Match found! Connecting..."
        case .matched:
            return "Match ready!"
        case .failed:
            return "Matching failed"
        }
    }
}

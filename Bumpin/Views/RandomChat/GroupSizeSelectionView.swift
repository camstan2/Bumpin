import SwiftUI

struct GroupSizeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RandomChatViewModel
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Solo Queue
                    Button {
                        viewModel.setGroupSize(1)
                        dismiss()
                        viewModel.joinQueue()
                    } label: {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.purple)
                            Text("Solo Chat")
                            Spacer()
                            Text("1v1")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 2v2 Queue
                    Button {
                        viewModel.setGroupSize(2)
                        showInviteFriends()
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.purple)
                            Text("Double Chat")
                            Spacer()
                            Text("2v2")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 3v3 Queue
                    Button {
                        viewModel.setGroupSize(3)
                        showInviteFriends()
                    } label: {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.purple)
                            Text("Triple Chat")
                            Spacer()
                            Text("3v3")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Select Chat Size")
                } footer: {
                    Text("For group chats (2v2 or 3v3), you'll need to invite friends to join your group before queuing.")
                }
            }
            .navigationTitle("Chat Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func showInviteFriends() {
        dismiss()
        viewModel.showInviteFriends()
    }
}

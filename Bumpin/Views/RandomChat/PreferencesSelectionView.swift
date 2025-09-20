import SwiftUI

struct PreferencesSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RandomChatViewModel
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Gender Preference
                    Picker("Gender Preference", selection: $viewModel.genderPreference) {
                        Text("Any").tag(GenderPreference.any)
                        Text("Male").tag(GenderPreference.male)
                        Text("Female").tag(GenderPreference.female)
                    }
                    .pickerStyle(.menu)
                    
                    // Age Range (future feature)
                    /*
                    HStack {
                        Text("Age Range")
                        Spacer()
                        Text("18-99")
                            .foregroundColor(.secondary)
                    }
                    */
                    
                    // Language (future feature)
                    /*
                    HStack {
                        Text("Language")
                        Spacer()
                        Text("English")
                            .foregroundColor(.secondary)
                    }
                    */
                } header: {
                    Text("Match Preferences")
                } footer: {
                    Text("These preferences help us match you with people you're more likely to connect with. Note that strict matching may increase queue times.")
                }
                
                Section {
                    // Topics of Interest (future feature)
                    /*
                    ForEach(viewModel.selectedTopics, id: \.self) { topic in
                        HStack {
                            Text(topic)
                            Spacer()
                            Button {
                                viewModel.removeTopic(topic)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button {
                        viewModel.showTopicPicker = true
                    } label: {
                        Label("Add Topic", systemImage: "plus.circle.fill")
                    }
                    */
                } header: {
                    Text("Topics")
                } footer: {
                    Text("Topics help us match you with people who share your interests.")
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

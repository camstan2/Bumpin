import SwiftUI

// MARK: - Demo Launcher for Testing Daily Prompts

struct DailyPromptDemoLauncher: View {
    @State private var showDemo = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎵 Daily Prompts Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("See the Daily Prompts feature in action with realistic community responses and interactions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Launch Demo") {
                showDemo = true
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Text("Demo Features:")
                    .font(.headline)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 8) {
                    demoFeature("📝", "View active prompt with community responses")
                    demoFeature("🎵", "Experience song selection and submission flow")
                    demoFeature("🏆", "See real-time leaderboard with rankings")
                    demoFeature("💬", "Interact with responses (likes, comments)")
                    demoFeature("📊", "Track personal stats and streaks")
                    demoFeature("📱", "Native Social tab integration")
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.top, 40)
        .fullScreenCover(isPresented: $showDemo) {
            DailyPromptDemoView()
        }
    }
    
    private func demoFeature(_ icon: String, _ description: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Integration Instructions

struct DailyPromptIntegrationInstructions: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("🚀 Daily Prompts Integration")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                instructionSection(
                    title: "1. Test the Demo",
                    content: "Use the demo above to experience the complete Daily Prompts feature with realistic data and interactions."
                )
                
                instructionSection(
                    title: "2. Social Tab Integration",
                    content: "The feature is already integrated into your Social tab. Look for the 'Daily Prompt' filter option alongside All, Followers, Explore, and Genres."
                )
                
                instructionSection(
                    title: "3. Deploy Firebase Configuration",
                    content: """
                    Run the deployment script to set up Firebase:
                    
                    ```bash
                    cd /Users/camstanley/Desktop/Bumpin/Bumpin
                    ./scripts/deploy_daily_prompts.sh
                    ```
                    """
                )
                
                instructionSection(
                    title: "4. Create Your First Prompt",
                    content: "Use the admin interface or template library to create and activate your first daily prompt. Try: 'First song you play on vacation'"
                )
                
                instructionSection(
                    title: "5. User Flow",
                    content: """
                    Complete user experience:
                    • Social Tab → Daily Prompt Filter
                    • View today's prompt and community responses
                    • Tap "Pick Your Song" to submit response
                    • Engage with community via likes and comments
                    • Track personal streaks and achievements
                    """
                )
                
                VStack(spacing: 12) {
                    Text("🎯 Ready for Launch!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("The Daily Prompts feature is fully implemented and ready to drive daily engagement in your music social app.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .navigationTitle("Integration Guide")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func instructionSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Temporary Demo Access

/// Add this to your app temporarily to access the demo
/// You can add this as a button in your settings or admin view
struct DailyPromptDemoAccess: View {
    @State private var showDemo = false
    
    var body: some View {
        Button("🎵 Daily Prompts Demo") {
            showDemo = true
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(.purple)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .fullScreenCover(isPresented: $showDemo) {
            DailyPromptDemoLauncher()
        }
    }
}

#Preview("Demo Launcher") {
    DailyPromptDemoLauncher()
}

#Preview("Integration Instructions") {
    NavigationView {
        DailyPromptIntegrationInstructions()
    }
}

#Preview("Demo Access Button") {
    DailyPromptDemoAccess()
}

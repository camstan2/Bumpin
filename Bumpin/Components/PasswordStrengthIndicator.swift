import SwiftUI

// MARK: - Password Strength Indicator

struct PasswordStrengthIndicator: View {
    let password: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Strength bar
            HStack(spacing: 4) {
                ForEach(0..<4) { index in
                    Rectangle()
                        .fill(barColor(for: index))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
            }
            
            // Requirements checklist
            VStack(alignment: .leading, spacing: 4) {
                RequirementRow(
                    text: "At least 8 characters",
                    isMet: password.count >= 8
                )
                RequirementRow(
                    text: "One uppercase letter (A-Z)",
                    isMet: password.range(of: "[A-Z]", options: .regularExpression) != nil
                )
                RequirementRow(
                    text: "One lowercase letter (a-z)",
                    isMet: password.range(of: "[a-z]", options: .regularExpression) != nil
                )
                RequirementRow(
                    text: "One number (0-9)",
                    isMet: password.range(of: "[0-9]", options: .regularExpression) != nil
                )
                RequirementRow(
                    text: "One special character (!@#$%^&*)",
                    isMet: password.range(of: "[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>/?]", options: .regularExpression) != nil
                )
            }
            .padding(.top, 4)
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let strength = passwordStrength
        
        switch strength {
        case .weak:
            return index == 0 ? .red : Color(.systemGray5)
        case .fair:
            return index <= 1 ? .orange : Color(.systemGray5)
        case .good:
            return index <= 2 ? .yellow : Color(.systemGray5)
        case .strong:
            return .green
        }
    }
    
    private var passwordStrength: PasswordStrength {
        let metRequirements = [
            password.count >= 8,
            password.range(of: "[A-Z]", options: .regularExpression) != nil,
            password.range(of: "[a-z]", options: .regularExpression) != nil,
            password.range(of: "[0-9]", options: .regularExpression) != nil,
            password.range(of: "[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>/?]", options: .regularExpression) != nil
        ].filter { $0 }.count
        
        switch metRequirements {
        case 0...1: return .weak
        case 2...3: return .fair
        case 4: return .good
        case 5: return .strong
        default: return .weak
        }
    }
}

// MARK: - Password Strength Enum

enum PasswordStrength {
    case weak, fair, good, strong
    
    var description: String {
        switch self {
        case .weak: return "Weak"
        case .fair: return "Fair"
        case .good: return "Good"
        case .strong: return "Strong"
        }
    }
}

// MARK: - Requirement Row

struct RequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isMet ? .green : .secondary)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? .primary : .secondary)
        }
    }
}

// MARK: - Password Validator

struct PasswordValidator {
    static func isValid(_ password: String) -> Bool {
        return password.count >= 8 &&
            password.range(of: "[A-Z]", options: .regularExpression) != nil &&
            password.range(of: "[a-z]", options: .regularExpression) != nil &&
            password.range(of: "[0-9]", options: .regularExpression) != nil &&
            password.range(of: "[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>/?]", options: .regularExpression) != nil
    }
    
    static func validationError(_ password: String) -> String? {
        if password.isEmpty {
            return "Password is required"
        }
        if password.count < 8 {
            return "Password must be at least 8 characters"
        }
        if password.range(of: "[A-Z]", options: .regularExpression) == nil {
            return "Password must contain an uppercase letter"
        }
        if password.range(of: "[a-z]", options: .regularExpression) == nil {
            return "Password must contain a lowercase letter"
        }
        if password.range(of: "[0-9]", options: .regularExpression) == nil {
            return "Password must contain a number"
        }
        if password.range(of: "[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>/?]", options: .regularExpression) == nil {
            return "Password must contain a special character"
        }
        return nil
    }
}

#Preview {
    VStack {
        PasswordStrengthIndicator(password: "Test123!")
            .padding()
        
        PasswordStrengthIndicator(password: "weak")
            .padding()
    }
}


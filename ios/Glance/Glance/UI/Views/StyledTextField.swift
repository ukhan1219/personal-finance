import SwiftUI

struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .sentences

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.textFieldPlaceholder))
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.textFieldPlaceholder))
            }
        }
        .font(.custom("Inter-Medium", size: 14))
        .kerning(-0.01 * 14)
        .foregroundColor(.textFieldText)
        .padding()
        .frame(height: 54)
        .background(Color.textFieldBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.textFieldStroke, lineWidth: 1)
        )
        .keyboardType(keyboardType)
        .autocapitalization(autocapitalization)
    }
}

#Preview {
    VStack {
        StyledTextField(placeholder: "Email", text: .constant(""), keyboardType: .emailAddress, autocapitalization: .none)
        StyledTextField(placeholder: "Password", text: .constant(""), isSecure: true)
    }
    .padding()
    .background(Color.appBackground)
} 
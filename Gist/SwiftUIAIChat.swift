//
//  SimpleAIChat.swift
//  SwiftUIiOS26

import FoundationModels
import SwiftUI

struct SimpleAIChat: View {
    @State private var response = ""
    @State private var prompt: String = "What is PencilKit?"
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(response)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 20))
                } header: {
                    Text("Response")
                }
                
                Section {
                    VStack {
                        TextEditor(text: $prompt)
                            .font(.caption)
                            .padding()
                            .foregroundStyle(.secondary)
                            .glassEffect(in: .rect(cornerRadius: 20))
                        
                        HStack {
                            Spacer()
                            
                            Button{
                                let session = LanguageModelSession()
                                
                                Task {
                                    response = try! await session.respond(to: Prompt(prompt)).content
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                    Text("Send")
                                }
                            }
                            .padding(.top, 8)
                            .buttonStyle(.glassProminent)
                            .tint(.indigo)
                            .disabled(prompt.isEmpty)
                        }
                    }
                } header: {
                    Text("Prompt")
                }
            }
            .listStyle(.insetGrouped)
            .navigationBarTitle("Simple AI Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SimpleAIChat()
        .preferredColorScheme(.dark)
}

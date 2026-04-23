import MacDjVuCore
import SwiftUI

struct SearchBar: View {
    @Environment(ViewerState.self) private var state
    @FocusState private var isFieldFocused: Bool
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))

                TextField("Search", text: Binding(
                    get: { state.searchQuery },
                    set: { newValue in
                        state.searchQuery = newValue
                        debounceSearch(newValue)
                    }
                ))
                .textFieldStyle(.plain)
                .focused($isFieldFocused)
                .onSubmit { submitSearch() }
                .frame(maxWidth: 220)

                if !state.searchQuery.isEmpty {
                    Text(matchCountLabel)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .layoutPriority(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            Button {
                state.previousMatch()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(state.searchMatches.isEmpty)

            Button {
                state.nextMatch()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(state.searchMatches.isEmpty)

            Button("Done") {
                state.dismissSearch()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .onAppear { isFieldFocused = true }
        .onDisappear { searchTask?.cancel() }
    }

    private var matchCountLabel: String {
        if state.searchMatches.isEmpty {
            return "No matches"
        }
        if let idx = state.currentMatchIndex {
            return "\(idx + 1) of \(state.searchMatches.count)"
        }
        return "\(state.searchMatches.count) matches"
    }

    private func submitSearch() {
        searchTask?.cancel()
        if state.searchMatches.isEmpty && !state.searchQuery.isEmpty {
            // Debounce hasn't fired yet — run search immediately.
            searchTask = Task {
                await state.performSearch(state.searchQuery)
            }
        } else {
            state.nextMatch()
        }
    }

    private func debounceSearch(_ query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await state.performSearch(query)
        }
    }
}

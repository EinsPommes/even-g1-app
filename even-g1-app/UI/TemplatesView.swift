//
//  TemplatesView.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bleManager: BLEManager
    @StateObject private var templateStore = TemplateStore()
    
    @State private var searchText = ""
    @State private var selectedTags: [String] = []
    @State private var showingFavoritesOnly = false
    @State private var showingAddTemplate = false
    @State private var showingTagFilter = false
    @State private var editingTemplate: Template? = nil
    
    private var filteredTemplates: [Template] {
        templateStore.searchTemplates(
            query: searchText,
            tags: selectedTags,
            favoritesOnly: showingFavoritesOnly
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Filter bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        // Favorites filter
                        Button(action: {
                            showingFavoritesOnly.toggle()
                        }) {
                            HStack {
                                Image(systemName: showingFavoritesOnly ? "star.fill" : "star")
                                Text("Favorites")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(showingFavoritesOnly ? Color.yellow.opacity(0.2) : Color.secondary.opacity(0.1))
                            )
                            .foregroundColor(showingFavoritesOnly ? .yellow : .primary)
                        }
                        
                        // Tags filter
                        Button(action: {
                            showingTagFilter = true
                        }) {
                            HStack {
                                Image(systemName: "tag")
                                Text("Tags")
                                if !selectedTags.isEmpty {
                                    Text("(\(selectedTags.count))")
                                        .font(.caption)
                                        .padding(4)
                                        .background(Circle().fill(Color.blue.opacity(0.2)))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(!selectedTags.isEmpty ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
                            )
                            .foregroundColor(!selectedTags.isEmpty ? .blue : .primary)
                        }
                        
                        // Display selected tags
                        ForEach(selectedTags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Button(action: {
                                    if let index = selectedTags.firstIndex(of: tag) {
                                        selectedTags.remove(at: index)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.2))
                            )
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Template list
                if templateStore.isLoading {
                    ProgressView("Loading templates...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredTemplates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No templates found")
                            .font(.headline)
                        
                        if !searchText.isEmpty || !selectedTags.isEmpty || showingFavoritesOnly {
                            Button(action: resetFilters) {
                                Text("Reset Filters")
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button(action: { showingAddTemplate = true }) {
                                Text("Create First Template")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredTemplates) { template in
                            TemplateRow(template: template)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingTemplate = template
                                }
                                .contextMenu {
                                    Button(action: {
                                        editingTemplate = template
                                    }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Button(action: {
                                        // Duplicate the template
                                        let duplicate = template.duplicate()
                                        templateStore.saveTemplate(duplicate)
                                    }) {
                                        Label("Duplicate", systemImage: "doc.on.doc")
                                    }
                                    
                                    Button(action: {
                                        // Send the text to the glasses
                                        Task {
                                            _ = await bleManager.broadcastText(template.body)
                                            appState.addRecentTemplate(template)
                                        }
                                    }) {
                                        Label("Send to Glasses", systemImage: "paperplane")
                                    }
                                    .disabled(bleManager.connectedDevices.isEmpty)
                                    
                                    Button(action: {
                                        // Open in teleprompter
                                        appState.teleprompterText = template.body
                                        appState.selectedTab = .teleprompter
                                    }) {
                                        Label("Open in Teleprompter", systemImage: "text.viewfinder")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive, action: {
                                        templateStore.deleteTemplate(withId: template.id)
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        templateStore.deleteTemplate(withId: template.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        editingTemplate = template
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        var updatedTemplate = template
                                        updatedTemplate.favorite.toggle()
                                        templateStore.saveTemplate(updatedTemplate)
                                    } label: {
                                        Label(
                                            template.favorite ? "Remove from Favorites" : "Add to Favorites",
                                            systemImage: template.favorite ? "star.slash" : "star.fill"
                                        )
                                    }
                                    .tint(.yellow)
                                    
                                    Button {
                                        // Send the text to the glasses
                                        Task {
                                            _ = await bleManager.broadcastText(template.body)
                                            appState.addRecentTemplate(template)
                                        }
                                    } label: {
                                        Label("Send", systemImage: "paperplane.fill")
                                    }
                                    .tint(.green)
                                    .disabled(bleManager.connectedDevices.isEmpty)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Templates")
            .searchable(text: $searchText, prompt: "Search templates")
            .refreshable {
                templateStore.loadTemplates()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTemplate = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingTagFilter) {
                TagFilterView(
                    allTags: templateStore.getAllTags(),
                    selectedTags: $selectedTags
                )
            }
            .sheet(isPresented: $showingAddTemplate) {
                TemplateEditorView(
                    mode: .create,
                    onSave: { newTemplate in
                        templateStore.saveTemplate(newTemplate)
                        showingAddTemplate = false
                    },
                    onCancel: {
                        showingAddTemplate = false
                    }
                )
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorView(
                    mode: .edit(template),
                    onSave: { updatedTemplate in
                        templateStore.saveTemplate(updatedTemplate)
                        editingTemplate = nil
                    },
                    onCancel: {
                        editingTemplate = nil
                    }
                )
            }
            .onAppear {
                templateStore.loadTemplates()
            }
        }
    }
    
    private func resetFilters() {
        searchText = ""
        selectedTags = []
        showingFavoritesOnly = false
    }
}

// MARK: - Template Row

struct TemplateRow: View {
    let template: Template
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.title)
                    .font(.headline)
                
                Spacer()
                
                if template.favorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            Text(template.previewText())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(template.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.1))
                                )
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                // Reading time
                Text(template.formattedReadingTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tag Filter View

struct TagFilterView: View {
    let allTags: [String]
    @Binding var selectedTags: [String]
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredTags: [String] {
        if searchText.isEmpty {
            return allTags
        }
        return allTags.filter { $0.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if filteredTags.isEmpty {
                    Text("No tags found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredTags, id: \.self) { tag in
                        Button(action: {
                            toggleTag(tag)
                        }) {
                            HStack {
                                Text(tag)
                                Spacer()
                                if selectedTags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Filter Tags")
            .searchable(text: $searchText, prompt: "Search tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        selectedTags = []
                    }
                    .disabled(selectedTags.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func toggleTag(_ tag: String) {
        if let index = selectedTags.firstIndex(of: tag) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }
}

// MARK: - Template Editor View

struct TemplateEditorView: View {
    enum Mode {
        case create
        case edit(Template)
    }
    
    let mode: Mode
    let onSave: (Template) -> Void
    let onCancel: () -> Void
    
    @State private var title = ""
    @State private var templateBody = ""
    @State private var tags: [String] = []
    @State private var favorite = false
    @State private var showingTagEditor = false
    @State private var newTag = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Title")) {
                    TextField("Template title", text: $title)
                }
                
                Section(header: Text("Text")) {
                    TextEditor(text: $templateBody)
                        .frame(minHeight: 200)
                }
                
                Section(header: Text("Tags")) {
                    if tags.isEmpty {
                        Text("No tags")
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tags, id: \.self) { tag in
                                    HStack {
                                        Text(tag)
                                        Button(action: {
                                            if let index = tags.firstIndex(of: tag) {
                                                tags.remove(at: index)
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        showingTagEditor = true
                    }) {
                        Label("Add Tag", systemImage: "plus")
                    }
                }
                
                Section {
                    Toggle("Mark as Favorite", isOn: $favorite)
                }
            }
            .navigationTitle(isEditMode ? "Edit Template" : "New Template")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(title.isEmpty || templateBody.isEmpty)
                }
            }
            .onAppear {
                setupInitialValues()
            }
            .alert("Add Tag", isPresented: $showingTagEditor) {
                TextField("New Tag", text: $newTag)
                Button("Cancel", role: .cancel) {
                    newTag = ""
                }
                Button("Add") {
                    if !newTag.isEmpty && !tags.contains(newTag) {
                        tags.append(newTag)
                        newTag = ""
                    }
                }
            }
        }
    }
    
    private var isEditMode: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }
    
    private func setupInitialValues() {
        if case .edit(let template) = mode {
            title = template.title
            templateBody = template.body
            tags = template.tags
            favorite = template.favorite
        }
    }
    
    private func saveTemplate() {
        let template: Template
        
        if case .edit(let existingTemplate) = mode {
            template = Template(
                id: existingTemplate.id,
                title: title,
                body: templateBody,
                tags: tags,
                favorite: favorite,
                updatedAt: Date(),
                createdAt: existingTemplate.createdAt
            )
        } else {
            template = Template(
                title: title,
                body: templateBody,
                tags: tags,
                favorite: favorite
            )
        }
        
        onSave(template)
    }
}

// MARK: - Preview

struct TemplatesView_Previews: PreviewProvider {
    static var previews: some View {
        TemplatesView()
            .environmentObject(AppState())
            .environmentObject(BLEManager())
    }
}

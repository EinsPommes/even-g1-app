//
//  TemplatesPickerView.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI

struct TemplatesPickerView: View {
    @EnvironmentObject private var templateStore: TemplateStore
    @State private var searchText = ""
    @State private var showingFavoritesOnly = false
    @State private var showingTagFilter = false
    @State private var selectedTags: Set<String> = []
    
    var onSelectTemplate: (Template) -> Void
    
    var body: some View {
        List {
            // Filter options
            Section {
                Toggle(isOn: $showingFavoritesOnly) {
                    Label("Favorites Only", systemImage: "star.fill")
                }
                
                Button(action: {
                    showingTagFilter = true
                }) {
                    HStack {
                        Label("Filter by Tags", systemImage: "tag")
                        Spacer()
                        if !selectedTags.isEmpty {
                            Text("\(selectedTags.count) selected")
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !selectedTags.isEmpty {
                    Button(action: {
                        selectedTags.removeAll()
                    }) {
                        Label("Reset Filters", systemImage: "xmark.circle")
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Templates list
            Section {
                if templateStore.isLoading {
                    ProgressView("Loading templates...")
                } else if filteredTemplates.isEmpty {
                    Text("No templates found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(filteredTemplates) { template in
                        Button(action: {
                            onSelectTemplate(template)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.title)
                                        .font(.headline)
                                    
                                    Text(template.body.prefix(50))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    
                                    if !template.tags.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack {
                                                ForEach(template.tags, id: \.self) { tag in
                                                    Text(tag)
                                                        .font(.caption)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(Color.blue.opacity(0.1))
                                                        .cornerRadius(4)
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                if template.favorite {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search templates")
        .sheet(isPresented: $showingTagFilter) {
            TagFilterView(selectedTags: $selectedTags, availableTags: allTags)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            templateStore.loadTemplates()
        }
    }
    
    private var filteredTemplates: [Template] {
        var result = templateStore.templates
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) || 
                                    $0.body.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Filter by favorites
        if showingFavoritesOnly {
            result = result.filter { $0.favorite }
        }
        
        // Filter by tags
        if !selectedTags.isEmpty {
            result = result.filter { template in
                !Set(template.tags).isDisjoint(with: selectedTags)
            }
        }
        
        return result
    }
    
    private var allTags: [String] {
        var tags = Set<String>()
        for template in templateStore.templates {
            for tag in template.tags {
                tags.insert(tag)
            }
        }
        return Array(tags).sorted()
    }
}

struct TagFilterView: View {
    @Binding var selectedTags: Set<String>
    let availableTags: [String]
    @State private var searchText = ""
    @State private var newTagName = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filteredTags, id: \.self) { tag in
                        Button(action: {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
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
                        .buttonStyle(.plain)
                    }
                    
                    if filteredTags.isEmpty && !searchText.isEmpty {
                        HStack {
                            Text("No tags found")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        selectedTags.removeAll()
                    }) {
                        Text("Reset")
                            .foregroundColor(.red)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search tags")
            .navigationTitle("Filter Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Just dismiss the sheet
                    }
                }
            }
        }
    }
    
    private var filteredTags: [String] {
        if searchText.isEmpty {
            return availableTags
        } else {
            return availableTags.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

struct TemplatesPickerView_Previews: PreviewProvider {
    static var previews: some View {
        TemplatesPickerView { _ in }
            .environmentObject(TemplateStore())
    }
}

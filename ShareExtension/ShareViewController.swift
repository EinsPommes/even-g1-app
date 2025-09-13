//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Jannik Kugler on 09.09.25.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    // UI-Elemente
    private let textView = UITextView()
    private let sendButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let saveTemplateButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    
    // Geteilter Text
    private var sharedText: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        extractSharedText()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Titel
        titleLabel.text = "An G1-Brille senden"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        
        // Text-Ansicht
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.isEditable = true
        
        // Senden-Button
        sendButton.setTitle("Senden", for: .normal)
        sendButton.backgroundColor = .systemBlue
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.layer.cornerRadius = 8
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        
        // Abbrechen-Button
        cancelButton.setTitle("Abbrechen", for: .normal)
        cancelButton.setTitleColor(.systemBlue, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        // Als Vorlage speichern Button
        saveTemplateButton.setTitle("Als Vorlage speichern", for: .normal)
        saveTemplateButton.setTitleColor(.systemBlue, for: .normal)
        saveTemplateButton.addTarget(self, action: #selector(saveTemplateButtonTapped), for: .touchUpInside)
        
        // Layout
        view.addSubview(titleLabel)
        view.addSubview(textView)
        view.addSubview(sendButton)
        view.addSubview(cancelButton)
        view.addSubview(saveTemplateButton)
        
        // Auto-Layout-Constraints
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        saveTemplateButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.heightAnchor.constraint(equalToConstant: 200),
            
            saveTemplateButton.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 16),
            saveTemplateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            sendButton.topAnchor.constraint(equalTo: saveTemplateButton.bottomAnchor, constant: 16),
            sendButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sendButton.heightAnchor.constraint(equalToConstant: 44),
            
            cancelButton.topAnchor.constraint(equalTo: sendButton.bottomAnchor, constant: 16),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Extract Shared Text
    
    private func extractSharedText() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            return
        }
        
        // Prüfe auf Text
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (data, error) in
                guard let self = self else { return }
                
                if let text = data as? String {
                    DispatchQueue.main.async {
                        self.sharedText = text
                        self.textView.text = text
                    }
                } else if let error = error {
                    print("Fehler beim Laden des Texts: \(error.localizedDescription)")
                }
            }
        }
        // Prüfe auf URL
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
                guard let self = self else { return }
                
                if let url = data as? URL {
                    DispatchQueue.main.async {
                        self.sharedText = url.absoluteString
                        self.textView.text = url.absoluteString
                    }
                } else if let error = error {
                    print("Fehler beim Laden der URL: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func sendButtonTapped() {
        // Aktualisiere den Text aus dem TextView
        sharedText = textView.text
        
        // Speichere den Text in den App-Gruppenbereich
        let sharedDefaults = UserDefaults(suiteName: "group.com.g1teleprompter")
        sharedDefaults?.set(sharedText, forKey: "SharedText")
        sharedDefaults?.set(true, forKey: "HasSharedText")
        sharedDefaults?.synchronize()
        
        // Öffne die Hauptapp
        let url = URL(string: "g1teleprompter://share")!
        let selector = #selector(UIApplication.open(_:options:completionHandler:))
        
        var responder = self as UIResponder?
        while let nextResponder = responder?.next {
            if nextResponder.responds(to: selector) {
                responder = nextResponder
                break
            }
            responder = nextResponder
        }
        
        responder?.perform(selector, with: url, with: [:])
        
        // Schließe die Extension
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    @objc private func cancelButtonTapped() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    @objc private func saveTemplateButtonTapped() {
        // Zeige einen Dialog zum Eingeben des Titels
        let alertController = UIAlertController(title: "Als Vorlage speichern", message: "Gib einen Titel für die Vorlage ein", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "Titel"
        }
        
        let saveAction = UIAlertAction(title: "Speichern", style: .default) { [weak self] _ in
            guard let self = self,
                  let title = alertController.textFields?.first?.text,
                  !title.isEmpty else {
                return
            }
            
            // Speichere die Vorlage in den App-Gruppenbereich
            let sharedDefaults = UserDefaults(suiteName: "group.com.g1teleprompter")
            
            let templateData: [String: Any] = [
                "title": title,
                "body": self.textView.text ?? "",
                "createdAt": Date().timeIntervalSince1970
            ]
            
            sharedDefaults?.set(templateData, forKey: "SharedTemplate")
            sharedDefaults?.set(true, forKey: "HasSharedTemplate")
            sharedDefaults?.synchronize()
            
            // Zeige eine Bestätigung
            let confirmationAlert = UIAlertController(title: "Vorlage gespeichert", message: "Die Vorlage wurde erfolgreich gespeichert.", preferredStyle: .alert)
            confirmationAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(confirmationAlert, animated: true)
        }
        
        let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel, handler: nil)
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
}

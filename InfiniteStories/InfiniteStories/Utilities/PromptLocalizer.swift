//
//  PromptLocalizer.swift
//  InfiniteStories
//
//  Created on 1/13/25.
//

import Foundation

struct PromptLocalizer {
    
    // MARK: - Language Detection
    static func getLanguageInstruction(for language: String) -> String {
        switch language {
        case "Spanish":
            return "Please respond entirely in Spanish."
        case "French":
            return "Please respond entirely in French."
        case "German":
            return "Please respond entirely in German."
        case "Italian":
            return "Please respond entirely in Italian."
        default:
            return "Please respond entirely in English."
        }
    }
    
    // MARK: - System Messages
    static func getSystemMessage(for language: String) -> String {
        let baseMessage = """
        You are a skilled children's storyteller who creates engaging, age-appropriate stories for bedtime. Your stories should be calming, imaginative, and help children feel safe and ready for sleep. Avoid scary elements or intense conflict. Focus on gentle adventures, friendship, and positive messages.
        """
        
        // Add language instruction at the end
        return baseMessage + " " + getLanguageInstruction(for: language)
    }
    
    // MARK: - Prompt Templates
    static func getPromptTemplate(for language: String, storyLength: Int, hero: String, traits: String, event: String) -> String {
        switch language {
        case "Spanish":
            return """
            Crea un cuento para dormir de \(storyLength) minutos sobre \(hero).
            
            Rasgos del personaje:
            \(traits)
            
            Evento de la historia: \(event)
            
            Requisitos:
            - Debe ser relajante y apropiado para dormir
            - Incluir elementos de los rasgos del personaje
            - Centrado en el evento mencionado
            - Apropiado para niños de 4-10 años
            - Aproximadamente \(storyLength * 150) palabras
            
            Formatea tu respuesta así:
            [Título de la historia]
            
            [Contenido de la historia...]
            """
            
        case "French":
            return """
            Créez une histoire pour dormir de \(storyLength) minutes sur \(hero).
            
            Traits du personnage:
            \(traits)
            
            Événement de l'histoire: \(event)
            
            Exigences:
            - Doit être apaisant et approprié pour le coucher
            - Inclure des éléments des traits du personnage
            - Centré sur l'événement mentionné
            - Approprié pour les enfants de 4 à 10 ans
            - Environ \(storyLength * 150) mots
            
            Formatez votre réponse comme ceci:
            [Titre de l'histoire]
            
            [Contenu de l'histoire...]
            """
            
        case "German":
            return """
            Erstelle eine \(storyLength)-minütige Gute-Nacht-Geschichte über \(hero).
            
            Charaktereigenschaften:
            \(traits)
            
            Ereignis der Geschichte: \(event)
            
            Anforderungen:
            - Sollte beruhigend und schlaffördernd sein
            - Elemente der Charaktereigenschaften einbeziehen
            - Fokussiert auf das genannte Ereignis
            - Geeignet für Kinder von 4-10 Jahren
            - Ungefähr \(storyLength * 150) Wörter
            
            Formatiere deine Antwort so:
            [Titel der Geschichte]
            
            [Inhalt der Geschichte...]
            """
            
        case "Italian":
            return """
            Crea una storia della buonanotte di \(storyLength) minuti su \(hero).
            
            Tratti del personaggio:
            \(traits)
            
            Evento della storia: \(event)
            
            Requisiti:
            - Deve essere rilassante e adatta per dormire
            - Includere elementi dei tratti del personaggio
            - Incentrata sull'evento menzionato
            - Adatta per bambini di 4-10 anni
            - Circa \(storyLength * 150) parole
            
            Formatta la tua risposta così:
            [Titolo della storia]
            
            [Contenuto della storia...]
            """
            
        default: // English
            return """
            Create a \(storyLength)-minute bedtime story about \(hero).
            
            Character traits:
            \(traits)
            
            Story event: \(event)
            
            Requirements:
            - Should be calming and sleep-inducing
            - Include elements from the character traits
            - Centered around the mentioned event
            - Appropriate for children aged 4-10
            - Approximately \(storyLength * 150) words
            
            Format your response as:
            [Story Title]
            
            [Story content...]
            """
        }
    }
    
    // MARK: - Event Translations
    static func getLocalizedEvent(_ event: String, language: String) -> String {
        // For now, we'll use the English event names as-is
        // This can be expanded later to translate event names
        return event
    }
    
    // MARK: - Trait Translations
    static func getLocalizedTraits(_ traits: [String], language: String) -> String {
        // For now, join traits as-is
        // This can be expanded later to translate trait names
        return traits.joined(separator: ", ")
    }
    
    // MARK: - Audio Instructions
    static func getAudioInstructions(for language: String, voice: String) -> String {
        let languageInstruction = getLanguageInstruction(for: language)
        
        switch language {
        case "Spanish":
            return "Lee esta historia en español con una voz cálida y tranquilizadora, perfecta para la hora de dormir. " + languageInstruction
        case "French":
            return "Lisez cette histoire en français avec une voix chaleureuse et apaisante, parfaite pour l'heure du coucher. " + languageInstruction
        case "German":
            return "Lesen Sie diese Geschichte auf Deutsch mit einer warmen und beruhigenden Stimme, perfekt für die Schlafenszeit. " + languageInstruction
        case "Italian":
            return "Leggi questa storia in italiano con una voce calda e rassicurante, perfetta per l'ora della nanna. " + languageInstruction
        default:
            return "Read this story with a warm and soothing voice, perfect for bedtime. " + languageInstruction
        }
    }
}

//
//  CharacterTraits.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import Foundation
import SwiftUI

enum CharacterTrait: String, CaseIterable, Codable {
    case brave = "Brave"
    case kind = "Kind"
    case curious = "Curious"
    case funny = "Funny"
    case smart = "Smart"
    case adventurous = "Adventurous"
    case creative = "Creative"
    case helpful = "Helpful"
    case gentle = "Gentle"
    case magical = "Magical"

    /// Localized display name for the trait
    var localizedName: String {
        switch self {
        case .brave: return String(localized: "model.trait.brave", comment: "Character trait name: Brave")
        case .kind: return String(localized: "model.trait.kind", comment: "Character trait name: Kind")
        case .curious: return String(localized: "model.trait.curious", comment: "Character trait name: Curious")
        case .funny: return String(localized: "model.trait.funny", comment: "Character trait name: Funny")
        case .smart: return String(localized: "model.trait.smart", comment: "Character trait name: Smart")
        case .adventurous: return String(localized: "model.trait.adventurous", comment: "Character trait name: Adventurous")
        case .creative: return String(localized: "model.trait.creative", comment: "Character trait name: Creative")
        case .helpful: return String(localized: "model.trait.helpful", comment: "Character trait name: Helpful")
        case .gentle: return String(localized: "model.trait.gentle", comment: "Character trait name: Gentle")
        case .magical: return String(localized: "model.trait.magical", comment: "Character trait name: Magical")
        }
    }

    /// Localized description for the trait
    var localizedDescription: String {
        switch self {
        case .brave: return String(localized: "model.trait.brave.description", comment: "Character trait description: Brave")
        case .kind: return String(localized: "model.trait.kind.description", comment: "Character trait description: Kind")
        case .curious: return String(localized: "model.trait.curious.description", comment: "Character trait description: Curious")
        case .funny: return String(localized: "model.trait.funny.description", comment: "Character trait description: Funny")
        case .smart: return String(localized: "model.trait.smart.description", comment: "Character trait description: Smart")
        case .adventurous: return String(localized: "model.trait.adventurous.description", comment: "Character trait description: Adventurous")
        case .creative: return String(localized: "model.trait.creative.description", comment: "Character trait description: Creative")
        case .helpful: return String(localized: "model.trait.helpful.description", comment: "Character trait description: Helpful")
        case .gentle: return String(localized: "model.trait.gentle.description", comment: "Character trait description: Gentle")
        case .magical: return String(localized: "model.trait.magical.description", comment: "Character trait description: Magical")
        }
    }

    /// English description for AI prompts (unchanged, used for story generation)
    var description: String {
        switch self {
        case .brave:
            return "Always ready to face challenges and help others"
        case .kind:
            return "Shows compassion and cares deeply about friends"
        case .curious:
            return "Loves to explore and learn new things"
        case .funny:
            return "Makes everyone laugh with jokes and silly adventures"
        case .smart:
            return "Solves problems with clever thinking"
        case .adventurous:
            return "Seeks exciting journeys and new discoveries"
        case .creative:
            return "Uses imagination to create wonderful things"
        case .helpful:
            return "Always ready to lend a hand to those in need"
        case .gentle:
            return "Treats everyone with care and kindness"
        case .magical:
            return "Has special abilities to make amazing things happen"
        }
    }
}

enum StoryEvent: String, CaseIterable, Codable {
    case bedtime = "Bedtime Adventure"
    case schoolDay = "School Day Fun"
    case birthday = "Birthday Celebration"
    case weekend = "Weekend Explorer"
    case rainyDay = "Rainy Day Magic"
    case family = "Family Time"
    case friendship = "Making Friends"
    case learning = "Learning Something New"
    case helping = "Helping Others"
    case holiday = "Holiday Adventure"

    /// Localized display name for the event
    var localizedName: String {
        switch self {
        case .bedtime: return String(localized: "model.event.bedtime", comment: "Story event name: Bedtime Adventure")
        case .schoolDay: return String(localized: "model.event.schoolDay", comment: "Story event name: School Day Fun")
        case .birthday: return String(localized: "model.event.birthday", comment: "Story event name: Birthday Celebration")
        case .weekend: return String(localized: "model.event.weekend", comment: "Story event name: Weekend Explorer")
        case .rainyDay: return String(localized: "model.event.rainyDay", comment: "Story event name: Rainy Day Magic")
        case .family: return String(localized: "model.event.family", comment: "Story event name: Family Time")
        case .friendship: return String(localized: "model.event.friendship", comment: "Story event name: Making Friends")
        case .learning: return String(localized: "model.event.learning", comment: "Story event name: Learning Something New")
        case .helping: return String(localized: "model.event.helping", comment: "Story event name: Helping Others")
        case .holiday: return String(localized: "model.event.holiday", comment: "Story event name: Holiday Adventure")
        }
    }

    /// Localized short description for the event (shown in pickers / UI).
    /// Must NOT reuse `promptSeed` — that value is English-only and feeds the AI.
    var localizedDescription: String {
        switch self {
        case .bedtime: return String(localized: "model.event.bedtime.description", comment: "Story event description: bedtime. Shown in Story Generation event picker list and trigger.")
        case .schoolDay: return String(localized: "model.event.schoolDay.description", comment: "Story event description: schoolDay. Shown in Story Generation event picker list and trigger.")
        case .birthday: return String(localized: "model.event.birthday.description", comment: "Story event description: birthday. Shown in Story Generation event picker list and trigger.")
        case .weekend: return String(localized: "model.event.weekend.description", comment: "Story event description: weekend. Shown in Story Generation event picker list and trigger.")
        case .rainyDay: return String(localized: "model.event.rainyDay.description", comment: "Story event description: rainyDay. Shown in Story Generation event picker list and trigger.")
        case .family: return String(localized: "model.event.family.description", comment: "Story event description: family. Shown in Story Generation event picker list and trigger.")
        case .friendship: return String(localized: "model.event.friendship.description", comment: "Story event description: friendship. Shown in Story Generation event picker list and trigger.")
        case .learning: return String(localized: "model.event.learning.description", comment: "Story event description: learning. Shown in Story Generation event picker list and trigger.")
        case .helping: return String(localized: "model.event.helping.description", comment: "Story event description: helping. Shown in Story Generation event picker list and trigger.")
        case .holiday: return String(localized: "model.event.holiday.description", comment: "Story event description: holiday. Shown in Story Generation event picker list and trigger.")
        }
    }

    /// English prompt seed for AI story generation (unchanged)
    var promptSeed: String {
        switch self {
        case .bedtime:
            return "a calm bedtime adventure that helps prepare for sleep"
        case .schoolDay:
            return "an exciting day at school with learning and fun"
        case .birthday:
            return "a magical birthday celebration with surprises"
        case .weekend:
            return "a fun weekend adventure exploring new places"
        case .rainyDay:
            return "a creative indoor adventure on a rainy day"
        case .family:
            return "a heartwarming adventure with family"
        case .friendship:
            return "a story about making new friends and friendship"
        case .learning:
            return "an adventure while learning something exciting and new"
        case .helping:
            return "a story about helping others and being kind"
        case .holiday:
            return "a festive holiday adventure full of joy"
        }
    }

    var icon: String {
        switch self {
        case .bedtime:
            return "moon.stars"
        case .schoolDay:
            return "backpack"
        case .birthday:
            return "birthday.cake"
        case .weekend:
            return "sun.max"
        case .rainyDay:
            return "cloud.rain"
        case .family:
            return "house.fill"
        case .friendship:
            return "person.2"
        case .learning:
            return "book"
        case .helping:
            return "heart"
        case .holiday:
            return "gift"
        }
    }
}
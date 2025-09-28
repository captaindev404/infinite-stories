//
//  CharacterTraits.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import Foundation

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
//
//  Endpoint.swift
//  InfiniteStories
//
//  API endpoint definitions for backend communication
//

import Foundation

enum HTTPMethod: String {
    case GET, POST, PATCH, DELETE, PUT
}

enum Endpoint {
    // MARK: - Authentication
    case signIn(email: String, password: String)
    case signUp(email: String, password: String, name: String?)
    case refreshSession
    case signOut
    case getSession

    // MARK: - Heroes
    case getHeroes(limit: Int, offset: Int, includeStories: Bool)
    case getHero(id: String, includeStories: Bool)
    case createHero(data: HeroCreateRequest)
    case updateHero(id: String, data: HeroUpdateRequest)
    case deleteHero(id: String)
    case generateAvatar(heroId: String, prompt: String)

    // MARK: - Hero Visual Profile
    case getVisualProfile(heroId: String)
    case createVisualProfile(heroId: String, data: VisualProfileCreateRequest)
    case updateVisualProfile(heroId: String, data: VisualProfileUpdateRequest)
    case deleteVisualProfile(heroId: String)
    case extractVisualProfile(heroId: String)

    // MARK: - Stories
    case getStories(heroId: String?, limit: Int, offset: Int, includeIllustrations: Bool)
    case getStory(id: String, includeIllustrations: Bool)
    case createStory(data: StoryCreateRequest)
    case updateStory(id: String, data: StoryUpdateRequest)
    case deleteStory(id: String)
    case generateAudio(storyId: String, language: String, voice: String)
    case generateIllustrations(storyId: String)
    case getIllustrationStatus(storyId: String)

    // MARK: - Custom Events
    case getCustomEvents(limit: Int, offset: Int)
    case getCustomEvent(id: String)
    case createCustomEvent(data: CustomEventCreateRequest)
    case updateCustomEvent(id: String, data: CustomEventUpdateRequest)
    case deleteCustomEvent(id: String)
    case enhanceCustomEvent(id: String)

    // MARK: - User
    case getUserProfile
    case updateUserProfile(data: UserProfileUpdateRequest)
    case getUserUsage
    case deleteAccount
    case updatePlayCount(storyId: String)

    // MARK: - Health
    case healthCheck

    // MARK: - Analytics
    case reportListeningSession(data: ListeningSessionRequest)
    case getAnalyticsSummary(refresh: Bool)
    case getListeningActivity(range: TimeRange)
    case getHeroAnalytics
    case getMilestones
    case getInsights

    // MARK: - Computed Properties

    var path: String {
        switch self {
        // Authentication
        case .signIn:
            return "/api/auth/sign-in"
        case .signUp:
            return "/api/auth/sign-up"
        case .refreshSession:
            return "/api/auth/session/refresh"
        case .signOut:
            return "/api/auth/sign-out"
        case .getSession:
            return "/api/auth/session"

        // Heroes
        case .getHeroes:
            return "/api/v1/heroes"
        case .getHero(let id, _):
            return "/api/v1/heroes/\(id)"
        case .createHero:
            return "/api/v1/heroes"
        case .updateHero(let id, _):
            return "/api/v1/heroes/\(id)"
        case .deleteHero(let id):
            return "/api/v1/heroes/\(id)"
        case .generateAvatar(let heroId, _):
            return "/api/v1/heroes/\(heroId)/avatar"

        // Hero Visual Profile
        case .getVisualProfile(let heroId):
            return "/api/v1/heroes/\(heroId)/visual-profile"
        case .createVisualProfile(let heroId, _):
            return "/api/v1/heroes/\(heroId)/visual-profile"
        case .updateVisualProfile(let heroId, _):
            return "/api/v1/heroes/\(heroId)/visual-profile"
        case .deleteVisualProfile(let heroId):
            return "/api/v1/heroes/\(heroId)/visual-profile"
        case .extractVisualProfile(let heroId):
            return "/api/v1/heroes/\(heroId)/visual-profile/extract"

        // Stories
        case .getStories:
            return "/api/v1/stories"
        case .getStory(let id, _):
            return "/api/v1/stories/\(id)"
        case .createStory:
            return "/api/v1/stories"
        case .updateStory(let id, _):
            return "/api/v1/stories/\(id)"
        case .deleteStory(let id):
            return "/api/v1/stories/\(id)"
        case .generateAudio(let storyId, _, _):
            return "/api/v1/stories/\(storyId)/audio"
        case .generateIllustrations(let storyId):
            return "/api/v1/stories/\(storyId)/illustrations"
        case .getIllustrationStatus(let storyId):
            return "/api/v1/stories/\(storyId)/illustrations/status"

        // Custom Events
        case .getCustomEvents:
            return "/api/v1/custom-events"
        case .getCustomEvent(let id):
            return "/api/v1/custom-events/\(id)"
        case .createCustomEvent:
            return "/api/v1/custom-events"
        case .updateCustomEvent(let id, _):
            return "/api/v1/custom-events/\(id)"
        case .deleteCustomEvent(let id):
            return "/api/v1/custom-events/\(id)"
        case .enhanceCustomEvent(let id):
            return "/api/v1/custom-events/\(id)/enhance"

        // User
        case .getUserProfile:
            return "/api/v1/user/profile"
        case .updateUserProfile:
            return "/api/v1/user/profile"
        case .getUserUsage:
            return "/api/v1/user/usage"
        case .deleteAccount:
            return "/api/v1/user/account"
        case .updatePlayCount(let storyId):
            return "/api/v1/stories/\(storyId)/play"

        // Health
        case .healthCheck:
            return "/api/v1/health"

        // Analytics
        case .reportListeningSession:
            return "/api/v1/analytics/sessions"
        case .getAnalyticsSummary:
            return "/api/v1/analytics/summary"
        case .getListeningActivity:
            return "/api/v1/analytics/activity"
        case .getHeroAnalytics:
            return "/api/v1/analytics/heroes"
        case .getMilestones:
            return "/api/v1/analytics/milestones"
        case .getInsights:
            return "/api/v1/analytics/insights"
        }
    }

    var method: HTTPMethod {
        switch self {
        // GET requests
        case .getSession, .getHeroes, .getHero, .getStories, .getStory,
             .getCustomEvents, .getCustomEvent, .getUserProfile, .getUserUsage,
             .getIllustrationStatus, .healthCheck,
             .getAnalyticsSummary, .getListeningActivity, .getHeroAnalytics,
             .getMilestones, .getInsights,
             .getVisualProfile:
            return .GET

        // POST requests
        case .signIn, .signUp, .refreshSession, .signOut,
             .createHero, .createStory, .createCustomEvent,
             .generateAvatar, .generateAudio, .generateIllustrations,
             .enhanceCustomEvent, .reportListeningSession,
             .createVisualProfile, .extractVisualProfile,
             .updatePlayCount:
            return .POST

        // PATCH requests
        case .updateHero, .updateStory, .updateCustomEvent, .updateUserProfile,
             .updateVisualProfile:
            return .PATCH

        // DELETE requests
        case .deleteHero, .deleteStory, .deleteCustomEvent,
             .deleteVisualProfile, .deleteAccount:
            return .DELETE
        }
    }

    var headers: [String: String] {
        var headers = ["Content-Type": "application/json"]

        // Add query parameters as headers for GET requests
        switch self {
        case .getHeroes(let limit, let offset, let includeStories):
            headers["Accept"] = "application/json"
            // Query params will be in URL

        case .getStories(let heroId, let limit, let offset, let includeIllustrations):
            headers["Accept"] = "application/json"

        default:
            break
        }

        return headers
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .getHeroes(let limit, let offset, let includeStories):
            return [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "includeStories", value: "\(includeStories)")
            ]

        case .getHero(_, let includeStories):
            return [
                URLQueryItem(name: "includeStories", value: "\(includeStories)")
            ]

        case .getStories(let heroId, let limit, let offset, let includeIllustrations):
            var items = [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "includeIllustrations", value: "\(includeIllustrations)")
            ]
            if let heroId = heroId {
                items.append(URLQueryItem(name: "heroId", value: heroId))
            }
            return items

        case .getStory(_, let includeIllustrations):
            return [
                URLQueryItem(name: "includeIllustrations", value: "\(includeIllustrations)")
            ]

        case .getCustomEvents(let limit, let offset):
            return [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]

        case .getListeningActivity(let range):
            return [
                URLQueryItem(name: "range", value: range.apiValue)
            ]

        case .getAnalyticsSummary(let refresh):
            if refresh {
                return [URLQueryItem(name: "refresh", value: "true")]
            }
            return nil

        default:
            return nil
        }
    }

    var body: Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        switch self {
        case .signIn(let email, let password):
            return try? encoder.encode(["email": email, "password": password])

        case .signUp(let email, let password, let name):
            var data: [String: Any] = ["email": email, "password": password]
            if let name = name {
                data["name"] = name
            }
            return try? JSONSerialization.data(withJSONObject: data)

        case .createHero(let data):
            return try? encoder.encode(data)

        case .updateHero(_, let data):
            return try? encoder.encode(data)

        case .createStory(let data):
            return try? encoder.encode(data)

        case .updateStory(_, let data):
            return try? encoder.encode(data)

        case .createCustomEvent(let data):
            return try? encoder.encode(data)

        case .updateCustomEvent(_, let data):
            return try? encoder.encode(data)

        case .generateAvatar(_, let prompt):
            return try? encoder.encode(["prompt": prompt])

        case .generateAudio(_, let language, let voice):
            return try? encoder.encode(["language": language, "voice": voice])

        case .generateIllustrations:
            // Backend expects JSON body with optional style/maxIllustrations
            return try? encoder.encode(["style": "standard"])

        case .updateUserProfile(let data):
            return try? encoder.encode(data)

        case .reportListeningSession(let data):
            return try? encoder.encode(data)

        case .createVisualProfile(_, let data):
            return try? encoder.encode(data)

        case .updateVisualProfile(_, let data):
            return try? encoder.encode(data)

        default:
            return nil
        }
    }
}

// MARK: - Request DTOs

struct HeroCreateRequest: Codable {
    let name: String
    let age: Int
    let traits: [String]
    let specialAbilities: [String]?  // Backend expects array
    let appearance: String?  // Free-form appearance description
    let hairColor: String?
    let eyeColor: String?
    let skinTone: String?
    let height: String?
}

struct HeroUpdateRequest: Codable {
    let name: String?
    let age: Int?
    let traits: [String]?
    let specialAbilities: [String]?  // Backend expects array
    let appearance: String?  // Free-form appearance description
    let hairColor: String?
    let eyeColor: String?
    let skinTone: String?
    let height: String?
    let avatarUrl: String?
}

struct StoryCreateRequest: Codable {
    let heroId: String  // Backend uses cuid strings, not UUIDs
    let title: String?
    let eventType: String?
    let customEventId: String?  // Also a string ID
    let language: String
    let generateAudio: Bool
    let generateIllustrations: Bool
}

struct StoryUpdateRequest: Codable {
    let title: String?
    let content: String?
    let isFavorite: Bool?
}

struct CustomEventCreateRequest: Codable {
    let title: String
    let description: String
    let promptSeed: String
    let category: String
    let ageRange: String?
    let tone: String
}

struct CustomEventUpdateRequest: Codable {
    let title: String?
    let description: String?
    let promptSeed: String?
    let usageCount: Int?
    let isFavorite: Bool?
}

struct UserProfileUpdateRequest: Codable {
    let name: String?
    let preferredLanguage: String?
}

// MARK: - Visual Profile Request DTOs

struct VisualProfileCreateRequest: Codable {
    let hairStyle: String?
    let hairColor: String?
    let hairTexture: String?
    let eyeColor: String?
    let eyeShape: String?
    let skinTone: String?
    let facialFeatures: String?
    let bodyType: String?
    let height: String?
    let age: Int?
    let typicalClothing: String?
    let colorPalette: [String]?
    let accessories: String?
    let artStyle: String?
    let visualKeywords: [String]?
    let canonicalPrompt: String?
    let simplifiedPrompt: String?

    init(from profile: HeroVisualProfile) {
        self.hairStyle = profile.hairStyle
        self.hairColor = profile.hairColor
        self.hairTexture = profile.hairTexture
        self.eyeColor = profile.eyeColor
        self.eyeShape = profile.eyeShape
        self.skinTone = profile.skinTone
        self.facialFeatures = profile.facialFeatures
        self.bodyType = profile.bodyType
        self.height = profile.height
        self.age = profile.age
        self.typicalClothing = profile.typicalClothing
        self.colorPalette = profile.colorPalette
        self.accessories = profile.accessories
        self.artStyle = profile.artStyle
        self.visualKeywords = profile.visualKeywords
        self.canonicalPrompt = profile.canonicalPrompt
        self.simplifiedPrompt = profile.simplifiedPrompt
    }
}

struct VisualProfileUpdateRequest: Codable {
    let hairStyle: String?
    let hairColor: String?
    let hairTexture: String?
    let eyeColor: String?
    let eyeShape: String?
    let skinTone: String?
    let facialFeatures: String?
    let bodyType: String?
    let height: String?
    let age: Int?
    let typicalClothing: String?
    let colorPalette: [String]?
    let accessories: String?
    let artStyle: String?
    let visualKeywords: [String]?
    let canonicalPrompt: String?
    let simplifiedPrompt: String?

    init(from profile: HeroVisualProfile) {
        self.hairStyle = profile.hairStyle
        self.hairColor = profile.hairColor
        self.hairTexture = profile.hairTexture
        self.eyeColor = profile.eyeColor
        self.eyeShape = profile.eyeShape
        self.skinTone = profile.skinTone
        self.facialFeatures = profile.facialFeatures
        self.bodyType = profile.bodyType
        self.height = profile.height
        self.age = profile.age
        self.typicalClothing = profile.typicalClothing
        self.colorPalette = profile.colorPalette
        self.accessories = profile.accessories
        self.artStyle = profile.artStyle
        self.visualKeywords = profile.visualKeywords
        self.canonicalPrompt = profile.canonicalPrompt
        self.simplifiedPrompt = profile.simplifiedPrompt
    }
}

// Note: TimeRange enum and apiValue are defined in ReadingJourneyRepository.swift

// MARK: - Analytics Request DTOs

/// Request to report a listening session to the analytics backend
/// Matches POST /api/v1/analytics/sessions
struct ListeningSessionRequest: Codable {
    let storyId: String
    let startedAt: Date?
    let endedAt: Date?
    let duration: Int? // Duration in seconds (auto-calculated by backend if startedAt/endedAt provided)
    let completed: Bool

    init(storyId: String, startedAt: Date? = nil, endedAt: Date? = nil, duration: Int? = nil, completed: Bool = false) {
        self.storyId = storyId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.completed = completed
    }
}

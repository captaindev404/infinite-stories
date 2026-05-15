//
//  DisplayPathFormattingTests.swift
//  InfiniteStoriesTests
//
//  Characterization tests that pin down the current correct behavior of
//  display-path formatting (enum localizedName/localizedDescription helpers
//  and Story extension formatters). The l10n sweep (tasks #68–#87) produced
//  ~16 display regressions with zero coverage — these tests lock the fixes in
//  place so any future regression fails loudly instead of shipping silently.
//
//  Task: #88
//

import Testing
import Foundation
@testable import InfiniteStories

// MARK: - FR locale helper
//
// We cannot call `Locale.autoupdatingCurrent` to change the runtime locale
// inside a test. Instead we resolve the `fr` localization bundle directly and
// fetch the string manually. This mirrors what `String(localized: key)` does
// internally (it looks up `Bundle.main` for the current locale) but lets us
// pin the lookup to a specific language table.
private enum FRBundle {
    /// The app bundle (NOT `Bundle.main` — that's the test runner when running
    /// under Swift Testing). We pin to the bundle that owns `Hero`, which is
    /// the InfiniteStories app module and therefore the bundle that ships
    /// `Localizable.xcstrings`.
    static let appBundle: Bundle = Bundle(for: Hero.self)

    /// The `fr.lproj` sub-bundle of the app bundle. `nil` if FR is not a
    /// supported localization (which would itself be a regression — see the
    /// `FR locale regression` suite).
    static let bundle: Bundle? = {
        guard let path = appBundle.path(forResource: "fr", ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }()

    /// Look up `key` in the FR table. Returns the key itself when the lookup
    /// fails (Foundation's standard fallback contract) so assertions produce
    /// readable diffs.
    static func string(_ key: String) -> String {
        guard let bundle else { return key }
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

@Suite("Display path formatting")
struct DisplayPathFormattingTests {

    // MARK: - CharacterTrait ------------------------------------------------

    @Suite("CharacterTrait.localizedName")
    struct CharacterTraitTests {

        @Test("EN localizedName pins canonical xcstrings values",
              arguments: [
                (CharacterTrait.brave, "Brave"),
                (CharacterTrait.kind, "Kind"),
                (CharacterTrait.curious, "Curious"),
                (CharacterTrait.funny, "Funny"),
                (CharacterTrait.smart, "Smart"),
                (CharacterTrait.adventurous, "Adventurous"),
                (CharacterTrait.creative, "Creative"),
                (CharacterTrait.helpful, "Helpful"),
                (CharacterTrait.gentle, "Gentle"),
                (CharacterTrait.magical, "Magical"),
              ])
        func enLocalizedName(trait: CharacterTrait, expected: String) {
            // Device locale in CI is `en`; `localizedName` resolves against it.
            #expect(trait.localizedName == expected)
        }

        @Test("FR localizedName pins canonical xcstrings values",
              arguments: [
                ("model.trait.brave", "Courageux"),
                ("model.trait.kind", "Gentil"),
                ("model.trait.curious", "Curieux"),
                ("model.trait.funny", "Drôle"),
                ("model.trait.smart", "Intelligent"),
                ("model.trait.adventurous", "Aventurier"),
                ("model.trait.creative", "Créatif"),
                ("model.trait.helpful", "Serviable"),
                ("model.trait.gentle", "Doux"),
                ("model.trait.magical", "Magique"),
              ])
        func frLocalizedName(key: String, expected: String) {
            #expect(FRBundle.string(key) == expected)
        }

        @Test("Every case has a non-empty localizedName")
        func allCasesCovered() {
            for trait in CharacterTrait.allCases {
                #expect(!trait.localizedName.isEmpty)
            }
        }
    }

    // MARK: - StoryEvent ----------------------------------------------------

    @Suite("StoryEvent localized strings")
    struct StoryEventTests {

        @Test("EN localizedName pins canonical xcstrings values",
              arguments: [
                (StoryEvent.bedtime, "Bedtime Adventure"),
                (StoryEvent.schoolDay, "School Day Fun"),
                (StoryEvent.birthday, "Birthday Celebration"),
                (StoryEvent.weekend, "Weekend Explorer"),
                (StoryEvent.rainyDay, "Rainy Day Magic"),
                (StoryEvent.family, "Family Time"),
                (StoryEvent.friendship, "Making Friends"),
                (StoryEvent.learning, "Learning Something New"),
                (StoryEvent.helping, "Helping Others"),
                (StoryEvent.holiday, "Holiday Adventure"),
              ])
        func enLocalizedName(event: StoryEvent, expected: String) {
            #expect(event.localizedName == expected)
        }

        @Test("EN localizedDescription pins canonical xcstrings values",
              arguments: [
                (StoryEvent.bedtime, "A calm bedtime adventure to help prepare for sleep"),
                (StoryEvent.schoolDay, "An exciting day at school with learning and fun"),
                (StoryEvent.birthday, "A magical birthday celebration full of surprises"),
                (StoryEvent.weekend, "A fun weekend adventure exploring new places"),
                (StoryEvent.rainyDay, "A creative indoor adventure on a rainy day"),
                (StoryEvent.family, "A heartwarming adventure with the family"),
                (StoryEvent.friendship, "A story about making new friends and friendship"),
                (StoryEvent.learning, "An adventure while learning something exciting and new"),
                (StoryEvent.helping, "A story about helping others and being kind"),
                (StoryEvent.holiday, "A festive holiday adventure full of joy"),
              ])
        func enLocalizedDescription(event: StoryEvent, expected: String) {
            #expect(event.localizedDescription == expected)
        }

        @Test("EN descriptions use sentence case, not Title Case",
              arguments: StoryEvent.allCases)
        func sentenceCaseDescriptions(event: StoryEvent) {
            // Sentence case: first char uppercase, contains at least one
            // lowercase letter, and the count of uppercase word-initial letters
            // is low (a Title Case phrase like "A Calm Bedtime Adventure" would
            // have 4+; sentence case like "A calm bedtime adventure..." has 1).
            let desc = event.localizedDescription
            let first = desc.first.map { String($0) } ?? ""
            #expect(first == first.uppercased())
            let words = desc.split(separator: " ")
            let titleCased = words.filter { $0.first?.isUppercase ?? false }.count
            #expect(titleCased <= 2, "Description looks Title-Cased: \(desc)")
        }

        @Test("localizedDescription is distinct from promptSeed (promptSeed is EN-only, feeds the AI)",
              arguments: StoryEvent.allCases)
        func descriptionIsNotPromptSeed(event: StoryEvent) {
            // The bug was that early versions of the sweep returned `promptSeed`
            // for both — pin that they are decoupled, even if text happens to
            // be similar. We just assert the description comes from the
            // catalog key (ends in a real capital-start sentence).
            #expect(event.promptSeed.first?.isLowercase == true)
            #expect(event.localizedDescription.first?.isUppercase == true)
        }
    }

    // MARK: - CustomStoryEvent enums ---------------------------------------

    @Suite("CustomStoryEvent enums")
    struct CustomEventEnumTests {

        @Test("AgeRange EN localizedName pins xcstrings values",
              arguments: [
                (AgeRange.toddler, "2–4 years"),
                (AgeRange.preschool, "4–6 years"),
                (AgeRange.elementary, "6–10 years"),
                (AgeRange.all, "All Ages"),
              ])
        func ageRangeEN(range: AgeRange, expected: String) {
            #expect(range.localizedName == expected)
        }

        @Test("AgeRange.apiIdentifier mirrors rawValue (English, locale-free)",
              arguments: AgeRange.allCases)
        func ageRangeApiIdentifier(range: AgeRange) {
            #expect(range.apiIdentifier == range.rawValue)
        }

        @Test("StoryTone EN localizedName pins xcstrings values",
              arguments: [
                (StoryTone.calming, "Calming"),
                (StoryTone.exciting, "Exciting"),
                (StoryTone.educational, "Educational"),
                (StoryTone.funny, "Funny"),
                (StoryTone.inspiring, "Inspiring"),
                (StoryTone.mysterious, "Mysterious"),
                (StoryTone.balanced, "Balanced"),
                (StoryTone.cheerful, "Cheerful"),
              ])
        func storyToneEN(tone: StoryTone, expected: String) {
            #expect(tone.localizedName == expected)
        }

        @Test("StoryTone.apiIdentifier equals rawValue (task #87 refactor)",
              arguments: StoryTone.allCases)
        func storyToneApiIdentifier(tone: StoryTone) {
            #expect(tone.apiIdentifier == tone.rawValue)
        }
    }

    // MARK: - Story extension formatters -----------------------------------

    @Suite("Story extension formatters")
    struct StoryFormatterTests {

        /// Fresh hero + story fixture using the built-in-event initializer.
        /// Transient model — never touches SwiftData.
        private static func makeStory(content: String, playCount: Int = 0) -> Story {
            let hero = Hero(name: "Luna", primaryTrait: .brave, secondaryTrait: .kind)
            let story = Story(title: "Test", content: content, event: .bedtime, hero: hero)
            for _ in 0..<playCount { story.incrementPlayCount() }
            return story
        }

        @Test("wordCount splits on whitespace and ignores empties")
        func wordCount() {
            let story = Self.makeStory(content: "one two three four  five")
            #expect(story.wordCount == 5)
        }

        @Test("wordCount is 0 for empty content")
        func wordCountEmpty() {
            let story = Self.makeStory(content: "")
            #expect(story.wordCount == 0)
        }

        @Test("localizedWordCountLabel contains the count and an EN 'word' stem")
        func wordCountLabelEN() {
            let story = Self.makeStory(content: "one two three")
            let label = story.localizedWordCountLabel
            #expect(label.contains("3"))
            #expect(label.localizedCaseInsensitiveContains("word"))
        }

        @Test("localizedPlayCountLabel: 0 / 1 / 4 all contain 'Played' and the count",
              arguments: [0, 1, 4])
        func playCountLabelEN(count: Int) {
            let story = Self.makeStory(content: "hello", playCount: count)
            let label = story.localizedPlayCountLabel
            #expect(label.contains("Played"))
            #expect(label.contains("\(count)"))
        }

        @Test("localizedPlayCountLabel uses singular 'time' for 1, plural 'times' otherwise")
        func playCountPlural() {
            let one = Self.makeStory(content: "x", playCount: 1).localizedPlayCountLabel
            let four = Self.makeStory(content: "x", playCount: 4).localizedPlayCountLabel
            #expect(one.hasSuffix("time"))
            #expect(four.hasSuffix("times"))
        }

        @Test("localizedCreatedAtLabel starts with EN 'Created' prefix")
        func createdAtLabelEN() {
            let story = Self.makeStory(content: "x")
            // En format is "Created %@" — so the label must start with "Created ".
            #expect(story.localizedCreatedAtLabel.hasPrefix("Created "))
            // And must contain the locale-formatted date tail.
            #expect(story.localizedCreatedAtLabel.count > "Created ".count)
        }
    }

    // MARK: - FR locale regression ----------------------------------------

    @Suite("FR locale regression")
    struct FRLocaleRegressionTests {

        @Test("FR is a supported localization in the app bundle")
        func frIsSupported() {
            #expect(FRBundle.appBundle.localizations.contains("fr"))
            #expect(FRBundle.bundle != nil, "fr.lproj missing from app bundle")
        }

        @Test("CharacterTrait.funny FR must be 'Drôle', never the English value")
        func frFunnyTrait() {
            let value = FRBundle.string("model.trait.funny")
            #expect(value == "Drôle")
            #expect(value != "Funny")
        }

        @Test("StoryEvent.bedtime FR description must NOT match the EN promptSeed/description")
        func frBedtimeDescription() {
            let value = FRBundle.string("model.event.bedtime.description")
            #expect(value == "Une douce aventure du soir pour préparer le sommeil")
            // Previously-broken path: the enum returned promptSeed verbatim.
            #expect(value != "a calm bedtime adventure that helps prepare for sleep")
            #expect(value != "A calm bedtime adventure to help prepare for sleep")
        }

        @Test("story.card.event.custom FR must be 'Événement personnalisé', not 'Custom Event'")
        func frCustomEventBadge() {
            let value = FRBundle.string("story.card.event.custom")
            #expect(value == "Événement personnalisé")
            #expect(value != "Custom Event")
        }

        @Test("AgeRange.all FR must be 'Tous âges', not the rawValue 'All Ages'")
        func frAgeRangeAll() {
            let value = FRBundle.string("customEvent.ageRange.all")
            #expect(value == "Tous âges")
            #expect(value != "All Ages")
        }
    }
}

// MARK: - AgeRange wire-format contract (task #81 Option A) -----------------
//
// These tests lock the `AgeRange.rawValue` strings as the wire-format
// identifiers persisted to the backend. Editing any rawValue will break
// existing users' custom-event records on the next sync — task #89 tracks
// the structural fix that separates display from wire format. Until then,
// these tests fail loudly if anyone edits a rawValue.
//
// Note the ASCII hyphen (`-`) in rawValues vs the en-dash (`–`) that
// `localizedName` returns for display — do NOT conflate the two.

@Suite("AgeRange wire-format contract (task #81 Option A)")
struct AgeRangeWireFormatTests {

    @Test("rawValue strings are frozen wire identifiers",
          arguments: [
            (AgeRange.toddler, "2-4 years"),
            (AgeRange.preschool, "4-6 years"),
            (AgeRange.elementary, "6-10 years"),
            (AgeRange.all, "All Ages"),
          ])
    func rawValueFrozen(range: AgeRange, expected: String) {
        #expect(range.rawValue == expected)
    }

    @Test("round-trip through rawValue reconstructs the case",
          arguments: AgeRange.allCases)
    func roundTripViaRawValue(range: AgeRange) {
        let rebuilt = AgeRange(rawValue: range.rawValue)
        #expect(rebuilt == range)
    }

    @Test("JSON decode accepts the frozen rawValue",
          arguments: [
            (#""2-4 years""#, AgeRange.toddler),
            (#""4-6 years""#, AgeRange.preschool),
            (#""6-10 years""#, AgeRange.elementary),
            (#""All Ages""#, AgeRange.all),
          ])
    func jsonDecode(json: String, expected: AgeRange) throws {
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AgeRange.self, from: data)
        #expect(decoded == expected)
    }

    @Test("JSON encode emits the frozen rawValue",
          arguments: [
            (AgeRange.toddler, #""2-4 years""#),
            (AgeRange.preschool, #""4-6 years""#),
            (AgeRange.elementary, #""6-10 years""#),
            (AgeRange.all, #""All Ages""#),
          ])
    func jsonEncode(range: AgeRange, expected: String) throws {
        let data = try JSONEncoder().encode(range)
        let actual = String(data: data, encoding: .utf8)
        #expect(actual == expected)
    }
}

# AI DJ (Resonance) - Complete Developer Handbook

## Purpose

This handbook provides detailed explanations of every concept listed in learning.md. It assumes basic programming knowledge but explains Swift and iOS-specific concepts from the ground up. Use this as your primary reference while building the AI DJ project.

**How to use this handbook:**
- Each section starts with **why this concept matters for AI DJ**
- Code snippets include **what we're doing** and **what happens** explanations
- Real examples show **how AI DJ uses this concept**
- Key takeaways are highlighted at section ends

---

# TABLE OF CONTENTS

1. [Swift Language Fundamentals](#1-swift-language-fundamentals)
2. [Xcode & Apple Development Environment](#2-xcode--apple-development-environment)
3. [SwiftUI Framework](#3-swiftui-framework)
4. [Swift Concurrency & Combine](#4-swift-concurrency--combine)
5. [Data Persistence with CoreData](#5-data-persistence-with-coredata)
6. [iOS App Architecture Patterns](#6-ios-app-architecture-patterns)
7. [MusicKit Framework](#7-musickit-framework)
8. [HealthKit Framework](#8-healthkit-framework)
9. [watchOS Development](#9-watchos-development)
10. [WatchConnectivity Framework](#10-watchconnectivity-framework)
11. [macOS Development (Menu Bar Apps)](#11-macos-development-menu-bar-apps)
12. [Background Processing & App Lifecycle](#12-background-processing--app-lifecycle)
13. [Widgets & Complications](#13-widgets--complications)
14. [Biometrics & Signal Processing Concepts](#14-biometrics--signal-processing-concepts)
15. [Algorithm & Scoring System Design](#15-algorithm--scoring-system-design)
16. [Testing in Swift](#16-testing-in-swift)
17. [Security, Privacy & Entitlements](#17-security-privacy--entitlements)
18. [App Distribution & Deployment](#18-app-distribution--deployment)

---

# 1. SWIFT LANGUAGE FUNDAMENTALS

## Why This Matters for AI DJ

Swift is the language that powers every line of code in our AI DJ project. Whether we're reading heart rate data from Apple Watch, querying playlists from MusicKit, or calculating song scores, we'll write it all in Swift. Understanding Swift's safety features (like optionals and strong typing) is crucial because we're handling real-time health data where crashes or incorrect values could ruin the user experience.

**In AI DJ, you'll use Swift to:**
- Define data structures for songs, playlists, and biometric readings
- Write algorithms that calculate song scores based on user state
- Handle asynchronous operations like fetching health data
- Manage state across iOS, watchOS, and macOS platforms

---

## 1.1 Core Language Syntax

### Variables & Constants

Swift distinguishes between values that can change and values that stay fixed. This distinction helps the compiler catch bugs early and enables important performance optimizations. Unlike many other languages where mutability is the default, Swift encourages immutability by making `let` (constants) the preferred choice. This design philosophy stems from functional programming principles and helps prevent entire categories of bugs related to unexpected state changes.

When you declare a variable with `let`, you're making a promise to the compiler that this value will never change after its initial assignment. The compiler uses this information to optimize your code and catch mistakes at compile time rather than runtime. When you use `var`, you're explicitly signaling that this value will be modified during the program's execution.

**What we're doing:** Declaring storage for values in our program using Swift's two declaration keywords.

```swift
let constant = 42        // Cannot be changed after assignment
var variable = 42        // Can be reassigned
variable = 100          // OK - variables can change
// constant = 100       // Compile error! Constants cannot change
```

**What happens:** The compiler enforces immutability for `let` constants. If you try to modify a constant, your code won't compile. This prevents accidental changes to values that should stay fixed.

**Why this matters:**
- **`let` (constants):** Use by default. When we store a song's ID or a user's baseline heart rate, we don't want it accidentally changed. Constants also enable compiler optimizations.
- **`var` (variables):** Use when the value genuinely needs to change, like a running average of heart rate samples or the current playback position.

**AI DJ Example:**
```swift
// These never change once set, so we use 'let'
let songId = "abc123"
let userBaseline = 72.5  // Resting heart rate

// These change during playback, so we use 'var'
var currentBPM = 0.0
var isPlaying = false
var heartRateSamples: [Double] = []
```

---

### Type Inference and Explicit Types

Swift is a statically-typed language, meaning every variable has a fixed type that cannot change at runtime. However, Swift's type inference system means you rarely need to write types explicitly—the compiler analyzes your code and determines the appropriate type based on context. This gives you the safety of static typing with the convenience of dynamic-feeling code.

The type inference engine examines the right-hand side of assignments, function return types, and surrounding context to deduce types. For example, if you write `let x = 42`, Swift sees the integer literal and infers `Int`. If you write `let x = 42.0`, it infers `Double`. This happens at compile time, so there's no runtime performance cost—your code runs exactly as fast as if you had written all the types explicitly.

**What we're doing:** Letting Swift determine types automatically, or explicitly specifying them when needed for clarity or to override the default inference.

```swift
// Swift automatically determines these types from the values
let name = "AI DJ"       // Swift infers this is a String
let count = 42           // Swift infers this is an Int
let price = 9.99         // Swift infers this is a Double
```

**What happens:** The compiler analyzes the right-hand side of each assignment and determines the appropriate type. Once set, the type is fixed—you can't assign a String to a variable the compiler determined was an Int.

**When to be explicit:**
```swift
// Sometimes we need to tell Swift exactly what we want
let explicitDouble: Double = 42    // We want 42.0, not Int 42
let songId: String = "abc123"      // Being clear about the type
let heartRate: Float = 72.5        // Using Float instead of Double
```

**Why be explicit?** When working with HealthKit, values often need to be specific types. Heart rate is typically a `Double`, but some APIs expect `Float`. Being explicit prevents subtle type mismatch bugs.

---

### String Interpolation

We frequently need to combine text with values—for logging, UI display, or debugging. In many languages, this requires awkward concatenation with plus signs or format specifiers. Swift provides string interpolation, a clean syntax that lets you embed any expression directly within a string literal using the `\()` syntax.

String interpolation is not just syntactic sugar—it's type-safe and extensible. Any type that conforms to `CustomStringConvertible` (which includes all standard types) can be interpolated. You can even include complex expressions, method calls, and ternary operators inside the interpolation braces. The Swift compiler converts these interpolations into efficient string building operations at compile time.

**What we're doing:** Embedding variable values and expressions directly into strings using `\()` syntax, which Swift evaluates and converts to string representations.

```swift
let song = "Bohemian Rhapsody"
let artist = "Queen"
let bpm = 76

// Combine text and values seamlessly
let message = "Now playing: \(song) by \(artist)"
// Result: "Now playing: Bohemian Rhapsody by Queen"

let debugInfo = "Song BPM: \(bpm), matches target: \(bpm > 70)"
// Result: "Song BPM: 76, matches target: true"
```

**What happens:** Swift evaluates each `\()` expression and converts the result to a string, inserting it at that position. This works with any type that can be converted to a string.

**AI DJ Example:**
```swift
let heartRate = 85.0
let stressLevel = 0.3
let selectedSong = "Calm Waters"

print("HR: \(heartRate) BPM | Stress: \(stressLevel) | Playing: \(selectedSong)")
// Output: "HR: 85.0 BPM | Stress: 0.3 | Playing: Calm Waters"
```

---

### Basic Types

Swift provides built-in primitive types for common data, each carefully designed for specific use cases. Understanding which type to use is crucial for writing efficient, bug-free code. Swift's type system is stricter than languages like JavaScript or Python—you cannot accidentally mix an integer with a string, and numeric types don't implicitly convert to each other. This strictness catches bugs at compile time that would otherwise cause subtle runtime errors.

The numeric types in Swift come in various sizes (8, 16, 32, and 64 bits), but in most cases you'll use `Int` for whole numbers and `Double` for decimals. `Int` automatically uses the native word size of your platform (64-bit on all modern Apple devices), providing the best performance. `Double` uses 64-bit IEEE 754 floating point, offering approximately 15-17 significant decimal digits of precision—more than enough for biometric calculations in AI DJ.

**What we're doing:** Understanding the fundamental building blocks for storing different kinds of data and choosing the appropriate type for each use case.

```swift
// INTEGERS - Whole numbers
// Use for: counts, indices, discrete values
let age: Int = 30                    // Platform-native size (64-bit on modern devices)
let playCount: Int = 42              // How many times a song was played
let skipCount: Int = 3               // How many times user skipped

// FLOATING POINT - Numbers with decimals
// Use Double for most cases (better precision)
let heartRate: Double = 72.5         // 64-bit, ~15 decimal digits precision
let score: Double = 0.847            // Song ranking scores
let percentage: Float = 0.95         // 32-bit, ~6 decimal digits (rarely needed)

// TEXT
let title: String = "Hello"          // Song title, artist name, etc.
let emoji: Character = "🎵"          // Single character

// BOOLEAN - True/False
let isPlaying: Bool = true           // Only two possible values
let needsCalm: Bool = false
```

**What happens:** Swift allocates the appropriate amount of memory for each type. `Int` and `Double` are 64 bits on modern Apple devices, giving them large ranges and high precision.

**Important - Type Safety:**
Swift prevents you from accidentally mixing types that could cause data loss:

```swift
let intValue = 42
let doubleValue = 3.14

// This would cause a compile error:
// let sum = intValue + doubleValue  // Error: Can't add Int to Double!

// You must explicitly convert:
let sum = Double(intValue) + doubleValue  // OK: 45.14

// This prevents subtle bugs like:
// let result = 5 / 2       // In some languages this is 2.5, in Swift it's 2 (Int division)
let result = 5.0 / 2.0     // This is 2.5 (Double division)
```

**Why this matters for AI DJ:** When calculating song scores, we need precision. A score of 0.847 vs 0.85 could change which song gets selected. Using `Double` ensures we have the precision needed for our ranking algorithms.

---

### Collection Types

We constantly work with groups of data—lists of songs, heart rate samples, song scores. Swift provides three main collection types, each optimized for different access patterns. Choosing the right collection can make the difference between code that runs instantly and code that crawls, especially when processing hundreds of songs or thousands of health samples.

All Swift collections are value types that use copy-on-write optimization. This means passing a collection to a function or assigning it to another variable doesn't immediately copy all the data—Swift only creates a copy when you actually modify one of the copies. This gives you the safety of value semantics with the performance of reference semantics in most cases.

#### Array - Ordered Lists

Arrays are Swift's most commonly used collection type. They store elements in a specific order and allow duplicate values. Elements are accessed by their zero-based integer index. Under the hood, arrays use contiguous memory storage, which makes index-based access extremely fast (constant time O(1)) but insertion and deletion in the middle slower (linear time O(n)) because elements must be shifted.

**What we're doing:** Storing ordered sequences of items of the same type, where position matters and we may need to access elements by their numeric index.

```swift
// Creating arrays
var songs: [String] = ["Song A", "Song B", "Song C"]
var heartRateSamples = [72.0, 74.5, 71.0, 73.5]  // Type inferred as [Double]
var empty: [Double] = []  // Empty array, ready to be filled

// Accessing elements (indices start at 0)
let firstSong = songs[0]              // "Song A"
let lastSong = songs[songs.count - 1] // "Song C"

// Safer access with optional
let maybeSong = songs.first           // Optional("Song A")
let safeLast = songs.last             // Optional("Song C")
```

**What happens:** Arrays store elements in contiguous memory, making index access very fast (O(1)). Accessing an out-of-bounds index crashes your app, so always check bounds or use safe methods like `.first` and `.last`.

**Modifying arrays:**
```swift
// Adding elements
songs.append("Song D")                // Add to end: ["Song A", "Song B", "Song C", "Song D"]
songs.insert("Song Z", at: 0)         // Insert at position: ["Song Z", "Song A", ...]

// Removing elements
songs.remove(at: 1)                   // Remove second element
songs.removeLast()                    // Remove and return last element
songs.removeAll()                     // Clear the array

// Replacing
songs[0] = "New Song"                 // Replace first element
```

**Iterating (very common in AI DJ):**
```swift
// Process each song
for song in songs {
    print(song)
}

// When you need the index too
for (index, song) in songs.enumerated() {
    print("\(index + 1). \(song)")
}

// Calculate average of heart rate samples
var total = 0.0
for sample in heartRateSamples {
    total += sample
}
let average = total / Double(heartRateSamples.count)
```

**AI DJ Example:**
```swift
// Store the last 10 heart rate readings for smoothing
var recentHeartRates: [Double] = []

func recordHeartRate(_ rate: Double) {
    recentHeartRates.append(rate)

    // Keep only last 10 samples
    if recentHeartRates.count > 10 {
        recentHeartRates.removeFirst()
    }
}

func getSmoothedHeartRate() -> Double {
    guard !recentHeartRates.isEmpty else { return 0 }
    let sum = recentHeartRates.reduce(0, +)
    return sum / Double(recentHeartRates.count)
}
```

---

#### Dictionary - Key-Value Pairs

Dictionaries store associations between keys and values. Unlike arrays where you access elements by position, dictionaries let you access values using meaningful keys—like looking up a song's score by its ID. This is implemented using a hash table data structure, which provides average O(1) constant-time lookups regardless of how many items the dictionary contains. This makes dictionaries ideal for caching computed values, storing configurations, and mapping identifiers to objects.

The keys in a dictionary must conform to the `Hashable` protocol, which includes all of Swift's basic types (String, Int, Bool, etc.) and any custom types you make Hashable. Values can be any type. One important characteristic: dictionaries are unordered—you cannot rely on items being in any particular sequence when you iterate.

**What we're doing:** Storing data that can be looked up by a unique key, enabling fast retrieval without knowing the position of the data. This is perfect for mapping song IDs to scores or caching computed effectiveness ratings.

```swift
// Creating dictionaries
var songScores: [String: Double] = [
    "songA": 0.85,
    "songB": 0.72,
    "songC": 0.93
]

// Accessing values (returns Optional because key might not exist)
let scoreA = songScores["songA"]      // Optional(0.85)
let scoreMissing = songScores["xyz"]  // nil (key doesn't exist)

// Safe access with default value
let safeScore = songScores["xyz", default: 0.0]  // 0.0 (not nil)
```

**What happens:** Dictionaries use hash tables internally, making lookups extremely fast (O(1) average). Unlike arrays, order is not guaranteed.

**Modifying dictionaries:**
```swift
// Adding or updating (same syntax)
songScores["songA"] = 0.90           // Update existing key
songScores["songD"] = 0.88           // Add new key-value pair

// Removing
songScores["songB"] = nil            // Remove by setting to nil
songScores.removeValue(forKey: "songC")  // Remove with method

// Check if key exists
if songScores["songA"] != nil {
    print("songA has a score")
}
```

**Iterating:**
```swift
// Process all key-value pairs
for (songId, score) in songScores {
    print("\(songId): \(score)")
}

// Just keys or values
for songId in songScores.keys {
    print(songId)
}

for score in songScores.values {
    print(score)
}
```

**AI DJ Example:**
```swift
// Track effectiveness of each song for calming the user
var songCalmingEffect: [String: Double] = [:]

func updateSongEffect(songId: String, hrvChange: Double) {
    // Positive HRV change = calming effect
    let currentScore = songCalmingEffect[songId, default: 0.0]

    // Running average: blend new data with old
    let newScore = currentScore * 0.7 + hrvChange * 0.3
    songCalmingEffect[songId] = newScore
}

func getMostCalmingSong(from candidates: [String]) -> String? {
    var bestSong: String? = nil
    var bestScore = -Double.infinity

    for songId in candidates {
        let score = songCalmingEffect[songId, default: 0.0]
        if score > bestScore {
            bestScore = score
            bestSong = songId
        }
    }

    return bestSong
}
```

---

#### Set - Unique Unordered Collections

Sets are collections that store unique values with no defined order. Like dictionaries, they use hash tables internally, providing O(1) constant-time performance for insertion, deletion, and membership testing. The key difference from arrays is that sets cannot contain duplicates—adding a value that already exists has no effect.

Sets excel at tracking "have we seen this before?" scenarios and performing mathematical set operations like union, intersection, and difference. In AI DJ, sets are perfect for tracking which songs have been played in a session (preventing repeats) or finding songs that match multiple criteria simultaneously.

**What we're doing:** Storing unique items where we need fast membership testing ("is this song in the played set?") and don't care about order. Sets automatically enforce uniqueness—attempting to add a duplicate simply does nothing.

```swift
// Creating sets
var genres: Set<String> = ["Rock", "Pop", "Jazz"]
var playedSongs: Set<String> = []  // Track which songs we've played

// Sets automatically remove duplicates
var numbers: Set = [1, 2, 3, 3, 3]   // Becomes {1, 2, 3}
```

**What happens:** Sets use hash tables like dictionaries, making contains checks very fast (O(1)). Order is not preserved.

**Common operations:**
```swift
// Adding and removing
genres.insert("Classical")            // Add element
genres.remove("Pop")                  // Remove element

// Fast membership test
if genres.contains("Rock") {          // O(1) lookup
    print("Rock is available")
}

// Set operations (very useful!)
let myGenres: Set = ["Rock", "Pop", "Jazz"]
let yourGenres: Set = ["Pop", "Classical", "Jazz"]

let union = myGenres.union(yourGenres)              // All unique: {"Rock", "Pop", "Jazz", "Classical"}
let common = myGenres.intersection(yourGenres)      // Both have: {"Pop", "Jazz"}
let onlyMine = myGenres.subtracting(yourGenres)     // Only I have: {"Rock"}
```

**AI DJ Example:**
```swift
// Avoid playing the same song twice in a session
var playedInSession: Set<String> = []

func selectNextSong(candidates: [String]) -> String? {
    // Filter out already-played songs
    let available = candidates.filter { !playedInSession.contains($0) }

    guard let selected = available.first else {
        // All songs played, reset session
        playedInSession.removeAll()
        return candidates.first
    }

    playedInSession.insert(selected)
    return selected
}
```

**Key Takeaway - When to use which collection:**
| Collection | Use When | AI DJ Example |
|------------|----------|---------------|
| Array | Order matters, duplicates OK | Heart rate samples over time |
| Dictionary | Need fast lookup by key | Song scores by song ID |
| Set | Need uniqueness, order irrelevant | Played songs in session |

---

## 1.2 Control Flow

Control flow statements determine which code executes and in what order. Swift provides traditional constructs like `if`, `switch`, and loops, but with important safety enhancements. For example, Swift's `switch` statements must be exhaustive (covering all possible cases), and conditions must be explicitly Boolean (no implicit truthiness like in JavaScript or Python).

### if / else / else if

The `if` statement is the most basic control flow construct, executing code only when a condition is true. Unlike C or JavaScript, Swift requires the condition to be a genuine Boolean value—you cannot use integers, optionals, or other values as implicit booleans. This prevents common bugs where a programmer accidentally uses an assignment (`=`) instead of a comparison (`==`).

The `else if` clause allows chaining multiple conditions, with Swift evaluating them in order and executing only the first matching block. The optional `else` clause catches any case not matched by the preceding conditions. This top-to-bottom evaluation means you should order conditions from most specific to most general.

**What we're doing:** Making decisions in code based on Boolean conditions, directing program flow to different code paths depending on the current state.

```swift
let heartRate = 85

// Basic conditional
if heartRate < 60 {
    print("Low heart rate - very relaxed or athletic")
} else if heartRate < 100 {
    print("Normal heart rate")
} else {
    print("Elevated heart rate - stressed or active")
}
```

**What happens:** Swift evaluates conditions top-to-bottom and executes the first matching block. Only one block runs, even if multiple conditions are true.

**Ternary operator for simple cases:**
```swift
// When you just need to pick between two values
let status = heartRate > 100 ? "High" : "Normal"

// Equivalent to:
// let status: String
// if heartRate > 100 {
//     status = "High"
// } else {
//     status = "Normal"
// }
```

**AI DJ Example:**
```swift
func determineMusicNeed(heartRate: Double, recentTrend: Double) -> String {
    // recentTrend: positive = rising, negative = falling

    if heartRate > 100 && recentTrend > 0 {
        return "calm"        // High and rising: user needs calming music
    } else if heartRate > 100 && recentTrend <= 0 {
        return "maintain"    // High but falling: current approach working
    } else if heartRate < 60 {
        return "energize"    // Low HR: might need energy boost
    } else {
        return "neutral"     // Normal range
    }
}
```

---

### switch Statements

Swift's `switch` statement is far more powerful than its counterparts in C or Java. It supports pattern matching against any type (not just integers), requires exhaustiveness (you must handle every possible case), and doesn't fall through by default (no need for `break` statements). This design prevents the common bug of forgetting a `break` and accidentally executing unintended code.

The exhaustiveness requirement means the compiler verifies you've handled every possible value. For enums, this is checked against all cases. For other types, you need a `default` clause to catch unhandled values. This is a major safety feature—when you add a new case to an enum, the compiler tells you everywhere that needs updating.

Pattern matching in `switch` extends beyond simple equality. You can match ranges (`0..<60`), tuples, optionals with binding, and even use `where` clauses for additional conditions. This makes `switch` ideal for complex classification logic like determining user state from multiple biometric factors.

**What we're doing:** Handling multiple specific cases with pattern matching, ensuring exhaustive coverage of all possibilities. Swift's switch is a powerful tool for classifying values into categories.

```swift
let context = "workout"

switch context {
case "workout":
    print("Play energetic music")
case "sleep", "relax":              // Compound case - multiple values
    print("Play calm music")
case "focus":
    print("Play instrumental music")
default:                             // Required - must handle all cases
    print("Play anything")
}
```

**What happens:** Swift matches the value against each case and runs the matching block. Unlike C/Objective-C, Swift doesn't fall through to the next case automatically (no `break` needed).

**Pattern matching with ranges:**
```swift
let bpm = 120

switch bpm {
case 0..<60:
    print("Very slow - ambient, meditation")
case 60..<100:
    print("Moderate - chill, acoustic")
case 100..<140:
    print("Upbeat - pop, rock")
case 140...:                         // 140 and above
    print("Fast - electronic, workout")
default:
    print("Unknown")
}
```

**Value binding - capture matched values:**
```swift
let songMatch = ("energize", 0.87)

switch songMatch {
case ("calm", let score) where score > 0.8:
    print("Excellent calm song, score: \(score)")
case ("energize", let score) where score > 0.8:
    print("Excellent energy song, score: \(score)")
case (let category, let score):
    print("\(category) song with score \(score)")
}
```

**AI DJ Example:**
```swift
enum UserState {
    case resting
    case active
    case stressed
    case recovering
}

func selectPlaylistStrategy(for state: UserState, timeOfDay: Int) -> String {
    switch (state, timeOfDay) {
    case (.resting, 6..<10):
        return "gentle-morning"
    case (.resting, _):
        return "ambient"
    case (.active, _):
        return "high-energy"
    case (.stressed, 18..<24):
        return "evening-wind-down"
    case (.stressed, _):
        return "calming"
    case (.recovering, _):
        return "recovery-ramp"
    }
}
```

---

### guard Statements - Early Exit Pattern

The `guard` statement is one of Swift's most beloved features, embodying the "early return" or "bouncer pattern" used by experienced developers. The philosophy is simple: check for invalid conditions at the start of a function and exit immediately if they're not met, rather than wrapping your entire function body in nested `if` statements.

This pattern eliminates the "pyramid of doom"—the rightward drift of deeply nested conditions that makes code hard to read. With `guard`, your preconditions are checked at the top, any bound variables remain in scope for the rest of the function, and your main logic stays at the base indentation level. The compiler enforces that the `guard`'s else clause must exit the current scope (via `return`, `throw`, `break`, `continue`, or `fatalError`), guaranteeing that if execution continues past the guard, all conditions were satisfied.

**What we're doing:** Validating preconditions at the start of functions and exiting early if they're not met. This inverts the typical pattern of nesting success cases inside failure checks, leading to cleaner, more readable code.

```swift
func processHeartRate(_ rate: Double?) {
    // Without guard - nested "pyramid of doom"
    if let rate = rate {
        if rate > 0 && rate < 300 {
            // Actually process...
        }
    }

    // With guard - flat and readable
    guard let rate = rate else {
        print("No heart rate data")
        return  // Must exit the scope
    }

    guard rate > 0 && rate < 300 else {
        print("Invalid heart rate: \(rate)")
        return
    }

    // rate is now safely unwrapped and validated
    // All the main logic lives here, not indented
    calculateArousal(from: rate)
}
```

**What happens:** `guard` checks a condition. If the condition is false (or optional is nil), it runs the else block which MUST exit the current scope (return, throw, break, continue, or fatalError). If true, execution continues and any bound variables are available for the rest of the function.

**Why guard is better than if-let:**
1. **Validates early** - Errors handled at the top, not buried in code
2. **Keeps main logic unindented** - Easier to read
3. **Variables available after guard** - Unlike if-let where they're scoped to the if block

**AI DJ Example:**
```swift
func rankSongForCurrentState(
    song: Song?,
    currentHeartRate: Double?,
    hrvValue: Double?
) -> Double? {
    // Validate all inputs up front
    guard let song = song else {
        print("No song to rank")
        return nil
    }

    guard let hr = currentHeartRate, hr > 0 else {
        print("Invalid heart rate")
        return nil
    }

    guard let hrv = hrvValue, hrv > 0 else {
        print("Invalid HRV")
        return nil
    }

    // All inputs validated - now do the real work
    let bpmMatch = 1.0 - abs(Double(song.bpm) - hr) / 100.0
    let calmingEffect = song.energyLevel < 0.5 ? hrv / 50.0 : 0

    return bpmMatch * 0.6 + calmingEffect * 0.4
}
```

---

### Loops

**What we're doing:** Repeating code for each item in a collection or while a condition is true.

**for-in loops:**
```swift
// Iterate over array
let songs = ["Song A", "Song B", "Song C"]
for song in songs {
    print("Playing: \(song)")
}

// Iterate over range
for i in 1...5 {        // 1, 2, 3, 4, 5 (inclusive)
    print("Count: \(i)")
}

for i in 0..<songs.count {  // 0, 1, 2 (exclusive end)
    print("\(i): \(songs[i])")
}

// With enumerated for index + value
for (index, song) in songs.enumerated() {
    print("\(index + 1). \(song)")
}
```

**while loops:**
```swift
var attempts = 0
while attempts < 3 {
    if tryConnect() {
        break  // Exit loop early on success
    }
    attempts += 1
}

// repeat-while: always executes at least once
var response: Data?
repeat {
    response = fetchNextChunk()
    process(response)
} while response != nil
```

**AI DJ Example:**
```swift
func findBestMatch(candidates: [Song], targetBPM: Double) -> Song? {
    var bestSong: Song?
    var smallestDiff = Double.infinity

    for song in candidates {
        let diff = abs(Double(song.bpm) - targetBPM)
        if diff < smallestDiff {
            smallestDiff = diff
            bestSong = song
        }
    }

    return bestSong
}

// With early exit when perfect match found
func findExactBPMMatch(candidates: [Song], targetBPM: Int) -> Song? {
    for song in candidates {
        if song.bpm == targetBPM {
            return song  // Found it, stop searching
        }
    }
    return nil  // No exact match
}
```

---

### defer Statements

**What we're doing:** Scheduling code to run when leaving the current scope, regardless of how we exit (normal return, error throw, or early return).

```swift
func readSensorData() -> [Double] {
    let sensor = openSensor()

    defer {
        closeSensor(sensor)  // Always runs when function exits
        print("Sensor closed")
    }

    guard sensor.isReady else {
        return []  // defer runs here
    }

    let data = sensor.read()

    if data.isEmpty {
        return []  // defer runs here too
    }

    return data  // defer runs here as well
}
```

**What happens:** The defer block is registered when encountered, but executes when the scope exits. Multiple defers execute in reverse order (LIFO - last in, first out).

**AI DJ Example:**
```swift
func fetchAndProcessHealthData() async throws -> StateVector {
    let query = startHealthQuery()

    defer {
        stopHealthQuery(query)  // Always clean up the query
    }

    let samples = try await query.execute()

    guard !samples.isEmpty else {
        throw DataError.noSamples  // defer still runs
    }

    return processIntoStateVector(samples)  // defer runs after return
}
```

---

## 1.3 Functions

**What we're doing:** Organizing code into reusable, named blocks that can take inputs and return outputs.

### Basic Function Syntax

```swift
// No parameters, no return value
func greet() {
    print("Hello, AI DJ!")
}
greet()  // Call the function

// With parameters and return value
func add(a: Int, b: Int) -> Int {
    return a + b
}
let sum = add(a: 5, b: 3)  // 8

// Single expression - implicit return
func multiply(a: Int, b: Int) -> Int {
    a * b  // 'return' keyword optional for single expressions
}
```

**What happens:** When you call a function, Swift copies the argument values into the parameters, executes the function body, and returns the result. Parameters are constants by default—you can't modify them inside the function.

---

### Argument Labels and Parameter Names

Swift uses two names for function parameters: an external **argument label** (used when calling) and an internal **parameter name** (used inside the function).

```swift
// 'from' is the argument label, 'source' is the parameter name
func move(from source: String, to destination: String) {
    print("Moving from \(source) to \(destination)")
}
move(from: "A", to: "B")  // Reads naturally like English

// Omit external label with underscore
func greet(_ name: String) {
    print("Hello, \(name)")
}
greet("World")  // No label needed when calling

// Same name for both (most common)
func calculateScore(heartRate: Double) -> Double {
    return heartRate / 100.0
}
calculateScore(heartRate: 85.0)
```

**Why this matters:** Well-named argument labels make code read like prose: `move(from: "A", to: "B")` is clearer than `move("A", "B")`.

---

### Default Parameter Values

```swift
// Provide sensible defaults for optional parameters
func fetch(limit: Int = 50, offset: Int = 0) -> [Song] {
    // Implementation...
}

fetch()                         // Uses defaults: limit=50, offset=0
fetch(limit: 100)               // limit=100, offset=0
fetch(limit: 100, offset: 50)   // Both specified
```

**AI DJ Example:**
```swift
func rankSongs(
    candidates: [Song],
    targetBPM: Double,
    weightBPM: Double = 0.4,
    weightEnergy: Double = 0.3,
    weightFamiliarity: Double = 0.3
) -> [(Song, Double)] {
    // Default weights sum to 1.0, but caller can customize
    // ...
}

// Use defaults
let ranked = rankSongs(candidates: songs, targetBPM: 120)

// Override for workout scenario (weight BPM higher)
let workoutRanked = rankSongs(
    candidates: songs,
    targetBPM: 140,
    weightBPM: 0.6,
    weightEnergy: 0.3,
    weightFamiliarity: 0.1
)
```

---

### Functions as Values

In Swift, functions are "first-class citizens"—they can be assigned to variables, passed as arguments, and returned from other functions.

**What we're doing:** Treating functions like data, enabling powerful patterns like callbacks and functional programming.

```swift
// Function type: (Int, Int) -> Int
func multiply(a: Int, b: Int) -> Int { a * b }
func divide(a: Int, b: Int) -> Int { a / b }

// Assign function to variable
let operation: (Int, Int) -> Int = multiply
let result = operation(4, 5)  // 20

// Pass function as parameter
func apply(_ operation: (Int, Int) -> Int, to a: Int, and b: Int) -> Int {
    return operation(a, b)
}

apply(multiply, to: 3, and: 4)  // 12
apply(divide, to: 12, and: 3)   // 4
```

**AI DJ Example:**
```swift
// Define scoring strategies as functions
func calmingScorer(song: Song, state: StateVector) -> Double {
    return (1.0 - song.energyLevel) * state.stress
}

func energizingScorer(song: Song, state: StateVector) -> Double {
    return song.energyLevel * (1.0 - state.energy)
}

// Choose strategy based on context
func selectScoringStrategy(for need: MusicNeed) -> (Song, StateVector) -> Double {
    switch need {
    case .calm: return calmingScorer
    case .energize: return energizingScorer
    case .maintain: return { _, _ in 0.5 }  // Neutral score
    }
}

// Use selected strategy
let scorer = selectScoringStrategy(for: .calm)
let score = scorer(someSong, currentState)
```

---

## 1.4 Optionals

Optionals are Swift's way of handling the absence of a value. They're fundamental to Swift's safety and you'll use them constantly.

### What is an Optional?

**What we're doing:** Representing values that might or might not exist.

```swift
var name: String = "AI DJ"     // MUST always have a value
var nickname: String? = nil     // MAY or may not have a value

// Optional is actually an enum:
// enum Optional<T> {
//     case some(T)   // Has a value
//     case none      // No value (nil)
// }
```

**Why optionals exist:** Many values in programming are genuinely optional. A user might not have set a nickname. A network request might fail. A dictionary lookup might not find the key. Instead of using "magic values" (like -1 or empty string) to indicate absence, Swift makes it explicit with optionals.

**AI DJ Example:**
```swift
// These values might not exist
var currentlyPlayingSong: Song? = nil      // Nothing playing yet
var lastHeartRateReading: Double? = nil    // No reading yet
var userPreferredGenre: String? = nil      // User hasn't set preference

// These must always exist
var isPlaying: Bool = false                // Always true or false
var volume: Double = 0.8                   // Always has a value
```

---

### Unwrapping Optionals

Since optionals might not contain a value, you can't use them directly—you must "unwrap" them first.

**Force unwrapping (!) - Dangerous, avoid unless certain:**
```swift
let song: String? = "Yesterday"
let definitelySong = song!  // Crashes if song is nil!

// Only use when you're 100% certain the value exists
let bundlePath = Bundle.main.path(forResource: "config", ofType: "json")!
```

**Optional binding (if let) - Safe:**
```swift
let song: String? = getSong()

if let unwrappedSong = song {
    // unwrappedSong is a regular String here, not optional
    print("Playing: \(unwrappedSong)")
} else {
    print("No song selected")
}

// Swift 5.7+ shorthand - same name
if let song {
    print("Playing: \(song)")  // song is non-optional in this block
}

// Chain multiple optional bindings
if let song = currentSong,
   let artist = song.artist,
   let albumArt = song.albumArtURL {
    displayNowPlaying(song: song, artist: artist, art: albumArt)
}
```

**What happens:** `if let` checks if the optional contains a value. If yes, it creates a new non-optional constant with that value and runs the if block. If nil, it runs the else block.

---

**guard let - Early exit (preferred for validation):**
```swift
func play(song: String?) {
    guard let song = song else {
        print("No song to play")
        return
    }

    // song is non-optional for the rest of the function
    startPlayback(song)
    updateNowPlaying(song)
}
```

**Why guard is often better than if-let:**
- The unwrapped variable is available for the rest of the function, not just inside a block
- Keeps main logic at the top level, not indented
- Makes validation and error cases obvious at the start

---

**Nil coalescing (??) - Provide default value:**
```swift
let userBPM: Int? = getUserPreferredBPM()
let bpm = userBPM ?? 120  // Use 120 if userBPM is nil

// Equivalent to:
// let bpm = userBPM != nil ? userBPM! : 120

// Chain defaults
let theme = userTheme ?? systemTheme ?? "default"
```

**AI DJ Example:**
```swift
func getCurrentTargetBPM() -> Int {
    // Try user's explicit preference first
    // Then infer from heart rate
    // Finally use default
    return userPreferredBPM ?? inferredBPMFromHeartRate ?? 100
}
```

---

**Optional chaining (?.) - Navigate through optionals:**
```swift
// Without optional chaining - verbose
var artistName: String? = nil
if let song = currentSong {
    if let artist = song.artist {
        artistName = artist.name
    }
}

// With optional chaining - concise
let artistName = currentSong?.artist?.name
// Returns nil if any step in the chain is nil
```

**What happens:** Each `?` checks if the value before it is nil. If yes, the entire expression returns nil immediately. If no, it continues to the next part.

**AI DJ Example:**
```swift
// Safely navigate complex optional structures
let albumArt = currentSong?.album?.artwork?.url(width: 300, height: 300)

// Call methods on optionals
currentSong?.artist?.fetchBio()  // Only calls if both exist

// Access subscripts on optionals
let firstGenre = currentSong?.genres?[0]
```

---

## 1.5 Closures

Closures are self-contained blocks of code that can be passed around and executed later. They're essential for asynchronous programming, callbacks, and functional patterns.

### What is a Closure?

**What we're doing:** Creating anonymous functions that capture values from their surrounding context.

```swift
// Named function
func addTwo(x: Int) -> Int {
    return x + 2
}

// Equivalent closure
let addTwoClosure = { (x: Int) -> Int in
    return x + 2
}

// Both work the same way
addTwo(5)        // 7
addTwoClosure(5) // 7
```

**Closure syntax breakdown:**
```swift
{ (parameters) -> ReturnType in
    // body
}

// Full syntax
let multiply: (Int, Int) -> Int = { (a: Int, b: Int) -> Int in
    return a * b
}

// Swift can infer types from context
let multiply2: (Int, Int) -> Int = { a, b in
    return a * b
}

// Shorthand argument names: $0, $1, $2...
let multiply3: (Int, Int) -> Int = { $0 * $1 }

// When passed to a function, can use trailing closure syntax
let sorted = numbers.sorted { $0 < $1 }
```

---

### Closures in Practice

Closures are everywhere in Swift, especially for:

**1. Completion handlers (callbacks):**
```swift
func fetchSong(id: String, completion: @escaping (Song?) -> Void) {
    // Async work happens...
    DispatchQueue.main.async {
        completion(song)  // Call the closure when done
    }
}

// Using it
fetchSong(id: "123") { song in
    if let song = song {
        play(song)
    }
}
```

**2. Collection operations:**
```swift
let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

// map: transform each element
let doubled = numbers.map { $0 * 2 }
// [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]

// filter: keep elements matching condition
let evens = numbers.filter { $0 % 2 == 0 }
// [2, 4, 6, 8, 10]

// reduce: combine into single value
let sum = numbers.reduce(0) { accumulator, current in
    accumulator + current
}  // 55

// Shorthand
let sum2 = numbers.reduce(0, +)  // Same result
```

**3. Sorting:**
```swift
struct Song {
    let title: String
    let score: Double
}

var songs: [Song] = [...]

// Sort by score, highest first
songs.sort { $0.score > $1.score }

// Sort by title alphabetically
songs.sort { $0.title < $1.title }
```

**AI DJ Example:**
```swift
// Rank and filter songs using closures
func selectSongsForMood(
    candidates: [Song],
    mood: Mood,
    limit: Int = 10
) -> [Song] {
    return candidates
        // Filter to matching genres
        .filter { $0.genres.contains(mood.preferredGenre) }
        // Score each song
        .map { song in
            (song: song, score: calculateScore(song, for: mood))
        }
        // Sort by score descending
        .sorted { $0.score > $1.score }
        // Take top N
        .prefix(limit)
        // Extract just the songs
        .map { $0.song }
}
```

---

### Capturing Values

Closures can capture and store references to variables from their surrounding context.

**What we're doing:** Creating closures that "remember" values from when they were created.

```swift
func makeCounter() -> () -> Int {
    var count = 0

    let counter: () -> Int = {
        count += 1  // Captures 'count' from outer scope
        return count
    }

    return counter
}

let counter1 = makeCounter()
counter1()  // 1
counter1()  // 2
counter1()  // 3

let counter2 = makeCounter()  // Independent counter
counter2()  // 1
```

**What happens:** When the closure is created, it captures a reference to `count`. Even after `makeCounter()` returns, the closure keeps `count` alive and can modify it. Each call to `makeCounter()` creates a new `count` variable, so counters are independent.

---

### Avoiding Retain Cycles with Capture Lists

When closures capture `self` (a class instance), they can create retain cycles that leak memory.

**The problem:**
```swift
class SongPlayer {
    var currentSong: String = ""
    var onSongEnd: (() -> Void)?

    func setup() {
        // This creates a retain cycle!
        // Closure captures self strongly
        // self holds closure in onSongEnd
        // Neither can be deallocated
        onSongEnd = {
            print("Finished: \(self.currentSong)")
        }
    }
}
```

**The solution - capture lists:**
```swift
class SongPlayer {
    var currentSong: String = ""
    var onSongEnd: (() -> Void)?

    func setup() {
        // [weak self] breaks the retain cycle
        onSongEnd = { [weak self] in
            guard let self = self else { return }
            print("Finished: \(self.currentSong)")
        }
    }
}
```

**Capture list options:**
- `[weak self]` - self becomes optional, set to nil if deallocated
- `[unowned self]` - assumes self exists, crashes if accessed after deallocation

**When to use which:**
- `[weak self]` - When the closure might outlive self (most common)
- `[unowned self]` - When you're certain self will exist for the closure's lifetime

**AI DJ Example:**
```swift
class HeartRateMonitor {
    var onRateUpdate: ((Double) -> Void)?

    func startMonitoring() {
        healthKit.startHeartRateQuery { [weak self] samples in
            guard let self = self else { return }

            for sample in samples {
                self.process(sample)
                self.onRateUpdate?(sample.value)
            }
        }
    }

    private func process(_ sample: Sample) {
        // Process the sample
    }
}
```

---

## 1.6 Error Handling

Swift has a robust error handling system that makes it clear which functions can fail and forces you to handle those failures.

### Defining Errors

**What we're doing:** Creating custom error types that describe what can go wrong.

```swift
// Errors are typically enums conforming to Error protocol
enum NetworkError: Error {
    case noConnection
    case timeout
    case serverError(code: Int)      // With associated value
    case invalidData
}

enum DatabaseError: Error {
    case notFound
    case duplicateEntry
    case corruptData(details: String)
}

// Can also add descriptions
extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noConnection: return "No internet connection"
        case .timeout: return "Request timed out"
        case .serverError(let code): return "Server error: \(code)"
        case .invalidData: return "Invalid data received"
        }
    }
}
```

---

### Throwing and Catching Errors

**What we're doing:** Writing functions that can fail, and handling those failures gracefully.

```swift
// Mark throwing functions with 'throws'
func fetchSong(id: String) throws -> Song {
    guard isConnected else {
        throw NetworkError.noConnection
    }

    guard let song = database.find(id) else {
        throw DatabaseError.notFound
    }

    return song
}

// Calling throwing functions requires 'try'
do {
    let song = try fetchSong(id: "123")
    play(song)
} catch NetworkError.noConnection {
    showOfflineMessage()
} catch NetworkError.serverError(let code) {
    print("Server returned error: \(code)")
} catch DatabaseError.notFound {
    showSongNotFoundMessage()
} catch {
    // Generic catch for any other error
    print("Unexpected error: \(error)")
}
```

**What happens:** When `throw` is executed, Swift immediately exits the function and looks for a `catch` block that handles that error type. The error propagates up the call stack until caught.

---

### Error Propagation

You don't have to catch every error—you can propagate them to callers.

```swift
// This function throws, so it propagates errors from fetchSong
func loadPlaylist(ids: [String]) throws -> [Song] {
    var songs: [Song] = []

    for id in ids {
        let song = try fetchSong(id: id)  // Propagates if throws
        songs.append(song)
    }

    return songs
}

// Caller must handle the errors
do {
    let playlist = try loadPlaylist(ids: ["1", "2", "3"])
} catch {
    handleError(error)
}
```

---

### try? and try!

**try? - Convert error to nil:**
```swift
// If fetchSong throws, result is nil; otherwise, it's the song
let maybeSong = try? fetchSong(id: "123")  // Type: Song?

// Useful for optional chaining
if let song = try? fetchSong(id: "123") {
    play(song)
}
```

**try! - Force (crashes on error):**
```swift
// Only use when you're certain it won't fail
let song = try! fetchSong(id: "known-good-id")  // Crashes if error thrown
```

**AI DJ Example:**
```swift
func loadUserPreferences() -> UserPreferences {
    // Try to load from disk, fall back to defaults
    if let prefs = try? PreferencesStore.load() {
        return prefs
    }

    return UserPreferences.default
}
```

---

### The Result Type

An alternative to throwing that makes error handling more explicit.

**What we're doing:** Representing success or failure as a value that can be passed around.

```swift
func fetchSongResult(id: String) -> Result<Song, NetworkError> {
    guard isConnected else {
        return .failure(.noConnection)
    }

    if let song = database.find(id) {
        return .success(song)
    } else {
        return .failure(.serverError(code: 404))
    }
}

// Using Result
let result = fetchSongResult(id: "123")

switch result {
case .success(let song):
    play(song)
case .failure(let error):
    handleError(error)
}

// Or convert to throwing
do {
    let song = try result.get()
    play(song)
} catch {
    handleError(error)
}
```

**When to use Result vs throws:**
- **throws** - For synchronous functions, simpler syntax
- **Result** - For storing outcomes, async callbacks, when you need to pass errors around

---

## 1.7 Generics

Generics let you write flexible, reusable code that works with any type while maintaining type safety.

### Why Generics?

**The problem:** Without generics, you'd need separate functions for each type.

```swift
func swapInts(_ a: inout Int, _ b: inout Int) {
    let temp = a
    a = b
    b = temp
}

func swapStrings(_ a: inout String, _ b: inout String) {
    let temp = a
    a = b
    b = temp
}

// This is repetitive...
```

**The solution:** Use a generic type placeholder.

```swift
func swap<T>(_ a: inout T, _ b: inout T) {
    let temp = a
    a = b
    b = temp
}

var x = 5, y = 10
swap(&x, &y)  // Works with Int

var s1 = "hello", s2 = "world"
swap(&s1, &s2)  // Works with String

var song1 = Song(...), song2 = Song(...)
swap(&song1, &song2)  // Works with any type!
```

**What happens:** `T` is a placeholder that gets replaced with the actual type when you call the function. The compiler generates specialized versions as needed.

---

### Generic Types

**What we're doing:** Creating data structures that work with any type.

```swift
struct Stack<Element> {
    private var items: [Element] = []

    mutating func push(_ item: Element) {
        items.append(item)
    }

    mutating func pop() -> Element? {
        items.popLast()
    }

    var top: Element? {
        items.last
    }

    var isEmpty: Bool {
        items.isEmpty
    }
}

// Use with any type
var intStack = Stack<Int>()
intStack.push(1)
intStack.push(2)
intStack.pop()  // 2

var songStack = Stack<Song>()
songStack.push(Song(title: "Hello"))
```

**AI DJ Example:**
```swift
// Generic buffer for any type of samples
struct RingBuffer<T> {
    private var items: [T] = []
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
    }

    mutating func add(_ item: T) {
        if items.count >= capacity {
            items.removeFirst()
        }
        items.append(item)
    }

    var average: T where T: BinaryFloatingPoint {
        guard !items.isEmpty else { return 0 }
        let sum = items.reduce(0, +)
        return sum / T(items.count)
    }

    var all: [T] { items }
}

// Use for heart rate samples
var heartRateBuffer = RingBuffer<Double>(capacity: 10)
heartRateBuffer.add(72.5)
heartRateBuffer.add(74.0)
let avg = heartRateBuffer.average
```

---

### Type Constraints

Sometimes generics need to be constrained to types with certain capabilities.

```swift
// Only works with Comparable types
func findMax<T: Comparable>(_ array: [T]) -> T? {
    array.max()
}

// Multiple constraints
func process<T: Hashable & Codable>(_ item: T) {
    // T must be both Hashable and Codable
}

// Where clauses for complex constraints
func merge<T, U>(_ a: T, _ b: U) -> String
    where T: CustomStringConvertible, U: CustomStringConvertible {
    return a.description + b.description
}
```

**AI DJ Example:**
```swift
// Scorer that works with any song-like type
protocol Scorable {
    var energyLevel: Double { get }
    var bpm: Int { get }
    var familiarity: Double { get }
}

func rankItems<T: Scorable & Identifiable>(
    _ items: [T],
    targetBPM: Double
) -> [(item: T, score: Double)] {
    items.map { item in
        let bpmScore = 1.0 - abs(Double(item.bpm) - targetBPM) / 100.0
        let score = bpmScore * 0.5 + item.familiarity * 0.5
        return (item, score)
    }
    .sorted { $0.score > $1.score }
}
```

---

## 1.8 Memory Management (ARC)

Swift uses Automatic Reference Counting to manage memory for class instances. Understanding ARC prevents memory leaks.

### How ARC Works

**What's happening:** Swift tracks how many references point to each class instance. When the count reaches zero, the instance is deallocated.

```swift
class Song {
    let title: String

    init(title: String) {
        self.title = title
        print("\(title) initialized")
    }

    deinit {
        print("\(title) deallocated")
    }
}

var song1: Song? = Song(title: "Hello")  // Count: 1, prints "Hello initialized"
var song2 = song1   // Count: 2 (both point to same object)
var song3 = song1   // Count: 3

song1 = nil  // Count: 2
song2 = nil  // Count: 1
song3 = nil  // Count: 0, prints "Hello deallocated"
```

---

### Retain Cycles - The Problem

**What we're doing:** Understanding how strong references can prevent deallocation.

```swift
class Song {
    var artist: Artist?
}

class Artist {
    var songs: [Song] = []
}

var song: Song? = Song()
var artist: Artist? = Artist()

song!.artist = artist    // Song → Artist (strong)
artist!.songs.append(song!)  // Artist → Song (strong)

// This creates a cycle:
// Song → Artist → Song → Artist → ...

song = nil   // Song still exists (Artist references it)
artist = nil // Artist still exists (Song references it)
// Memory leak! Neither can be deallocated
```

---

### Breaking Cycles with weak and unowned

**weak - Optional reference that doesn't prevent deallocation:**
```swift
class Song {
    weak var artist: Artist?  // Weak reference
}

class Artist {
    var songs: [Song] = []  // Strong reference
}

// Now:
// Song -weak→ Artist ←strong- Song
// Artist -strong→ Song

// When artist = nil, Artist can be deallocated
// song.artist automatically becomes nil
```

**unowned - Non-optional reference that doesn't prevent deallocation:**
```swift
class CreditCard {
    unowned let customer: Customer  // Customer must exist for card to exist

    init(customer: Customer) {
        self.customer = customer
    }
}

// Use unowned when:
// - The referenced object will always exist while this object exists
// - You want non-optional semantics
// CAUTION: Accessing after deallocation causes crash!
```

**When to use which:**
| Reference Type | When to Use | Example |
|---------------|-------------|---------|
| strong (default) | Owner of the object | Artist owns their songs |
| weak | Child → parent, delegates | Song → Artist |
| unowned | Guaranteed to outlive | CreditCard → Customer |

**AI DJ Example:**
```swift
class NowPlayingController {
    var currentSong: Song?
    var onSongChange: ((Song?) -> Void)?

    func setupNotifications() {
        // Use weak self to avoid retain cycle
        NotificationCenter.default.addObserver(
            forName: .songEnded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSongEnded()  // self might be nil
        }
    }
}

class Song {
    weak var nowPlayingController: NowPlayingController?  // Avoid cycle
}
```

---

## Key Takeaways - Swift Fundamentals

1. **Use `let` by default**, `var` only when you need to mutate
2. **Optionals make nil explicit** - unwrap safely with `if let` or `guard let`
3. **Prefer `guard` for validation** - keeps main logic unindented
4. **Use closures for callbacks** - but watch for retain cycles with `[weak self]`
5. **Throw errors for recoverable failures** - use `Result` for async callbacks
6. **Generics enable reusable code** - constrain when you need specific capabilities
7. **Understand ARC** - use `weak` for delegates and parent references

---

# 2. XCODE & APPLE DEVELOPMENT ENVIRONMENT

## Why This Matters for AI DJ

Xcode is the only way to build apps for Apple platforms. Understanding it well will save you hours of frustration. For the AI DJ project specifically, you'll need to:
- Create a multi-target project (iOS, watchOS, macOS)
- Set up entitlements for HealthKit and MusicKit
- Debug across devices and simulators
- Use SwiftUI previews for rapid UI development

---

## 2.1 Xcode Interface

### The Four Main Areas

When you open Xcode, you see four distinct panels:

**1. Navigator Panel (Left - ⌘0 to toggle)**
This is your file browser and much more:
- **Project Navigator (⌘1):** Browse files, add/remove files, organize groups
- **Source Control (⌘2):** Git branches, commits, uncommitted changes
- **Symbol Navigator (⌘3):** All classes, functions, properties indexed
- **Find Navigator (⌘4):** Project-wide search with regex support
- **Issue Navigator (⌘5):** Errors and warnings from builds
- **Test Navigator (⌘6):** Test suites and their pass/fail status
- **Debug Navigator (⌘7):** CPU, memory, network during debugging
- **Breakpoint Navigator (⌘8):** All breakpoints in project

**2. Editor Area (Center)**
Where you write code. Features:
- Syntax highlighting and auto-completion
- Inline error and warning display
- Split view (⌃⌘T) for viewing multiple files
- SwiftUI Canvas (⌘⌥↩) for live previews

**3. Inspector Panel (Right - ⌘⌥0 to toggle)**
- **File Inspector:** File settings, target membership
- **Quick Help:** Documentation for selected symbol
- **Attributes Inspector:** UI element properties in Interface Builder

**4. Debug Area (Bottom - ⌘⇧Y to toggle)**
- Console: print() output, logs, errors
- Variables view: Inspect values during breakpoints

---

### Essential Keyboard Shortcuts

Learn these—they'll make you much faster:

```
BUILDING & RUNNING
⌘B          Build project
⌘R          Build and run
⌘.          Stop running
⌘U          Run tests
⌘⇧K         Clean build folder (when builds act weird)

NAVIGATION
⌘⇧O         Open Quickly - search files and symbols
⌃⌘J         Jump to definition (where is this defined?)
⌘⌥←/→       Navigate back/forward through history
⌘L          Go to line number
⌃⌥⌘↩        Open in new window

EDITING
⌃I          Re-indent selected code
⌘/          Toggle comment
⌘D          Duplicate line/selection
⌘⌥[/]       Move line up/down
⌃⌘E         Rename symbol in scope

PANELS
⌘0          Toggle navigator
⌘⌥0         Toggle inspector
⌘⇧Y         Toggle debug area
⌘↩          Toggle SwiftUI canvas
```

---

### SwiftUI Previews

One of Xcode's best features for UI development. Previews update live as you code.

**What we're doing:** Setting up live previews to see UI changes instantly without building and running.

```swift
struct NowPlayingView: View {
    var body: some View {
        VStack {
            Text("Now Playing")
            Text("Song Title")
        }
    }
}

// Preview provider
#Preview {
    NowPlayingView()
}

// Multiple previews
#Preview("Light Mode") {
    NowPlayingView()
}

#Preview("Dark Mode") {
    NowPlayingView()
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    NowPlayingView()
        .environment(\.sizeCategory, .accessibilityLarge)
}
```

**Tips:**
- Press ⌘↩ to toggle canvas on/off
- Click "Resume" if preview pauses
- Pin previews to keep them visible while editing other files
- Use `.previewDevice()` to see different device sizes

---

## 2.2 Project Structure

### Understanding Targets

A **target** defines what to build. Our AI DJ project needs multiple targets:

| Target | Platform | Purpose |
|--------|----------|---------|
| AIDJ | iOS | Main iPhone app |
| AIDJ Watch App | watchOS | Apple Watch companion |
| AIDJ macOS | macOS | Menu bar helper |
| AIDJWidgets | iOS | Lock screen and home screen widgets |
| AIDJTests | iOS | Unit tests |
| AIDJUITests | iOS | UI automation tests |

**Creating targets:** File → New → Target → Select platform and template

Each target has its own:
- Source files (or shares them via target membership)
- Build settings
- Entitlements and capabilities
- Info.plist

---

### Schemes

A **scheme** defines how to build, run, and test a target. Think of it as a "recipe" for working with your app.

Edit schemes: Product → Scheme → Edit Scheme (⌘⇧<)

**Scheme actions:**
- **Build:** Which targets and configurations to build
- **Run:** Launch arguments, environment variables
- **Test:** Which test suites to run
- **Profile:** Launch into Instruments for profiling
- **Analyze:** Static analysis for potential bugs
- **Archive:** Build for distribution

**AI DJ Tip:** Create separate schemes for:
- Development (debug build, simulator)
- Device testing (debug build, physical device)
- Release (optimized build for TestFlight)

---

### Build Configurations

Default configurations:
- **Debug:** Unoptimized, includes debug symbols, assertions enabled
- **Release:** Optimized, stripped symbols, for distribution

You can create custom configurations for:
- Staging/beta environments
- Different API endpoints
- Feature flags

---

## 2.3 Swift Package Manager

SPM is Apple's dependency manager, integrated directly into Xcode.

### Adding Dependencies

**Via Xcode:** File → Add Package Dependencies → Enter URL → Select version

**Version rules:**
| Rule | Syntax | Meaning |
|------|--------|---------|
| Up to Next Major | `from: "1.0.0"` | 1.x.x (most common) |
| Up to Next Minor | `.upToNextMinor(from: "1.2.0")` | 1.2.x |
| Exact | `exact: "1.2.3"` | Only this version |
| Branch | `.branch("main")` | Track a branch |
| Range | `"1.0.0"..<"2.0.0"` | Custom range |

### Creating Local Packages

For shared code between targets (like our `Brain` module):

1. File → New → Package
2. Drag package folder into project navigator
3. Add package dependency to targets that need it

**AI DJ Structure:**
```
AIDJ/
├── AIDJ/              (iOS app)
├── AIDJ Watch App/    (watchOS app)
├── AIDJ macOS/        (macOS app)
└── Packages/
    └── AIDJCore/      (shared logic)
        ├── Sources/
        │   ├── Brain/      (state engine, ranking)
        │   ├── HealthKit/  (health data access)
        │   └── MusicKit/   (music access)
        └── Tests/
```

---

## 2.4 Capabilities and Entitlements

Apple restricts access to sensitive features. You must request capabilities in Xcode.

### Adding Capabilities

1. Select project in navigator
2. Select target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"

**Capabilities needed for AI DJ:**

| Capability | Purpose |
|------------|---------|
| HealthKit | Read heart rate, HRV, workouts |
| MusicKit | Access Apple Music library |
| App Groups | Share data between app and extensions |
| Background Modes | Audio, Health updates, Background fetch |

**What happens when you add a capability:**
1. Entry added to entitlements file (.entitlements)
2. App ID configured in developer portal
3. Provisioning profile updated

### Entitlements File

An XML plist that declares what your app can do:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array>
        <string>health-records</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourcompany.aidj</string>
    </array>
</dict>
</plist>
```

---

## 2.5 Debugging

### Breakpoints

**Setting breakpoints:** Click the gutter (line number area) to add a breakpoint.

**Conditional breakpoints:** Right-click breakpoint → Edit Breakpoint
- Condition: `heartRate > 150`
- Action: Log message, play sound, run debugger command
- Options: Automatically continue after evaluating

**Symbolic breakpoints:** Break on any call to a method:
- Debug → Breakpoints → Create Symbolic Breakpoint
- Symbol: `-[UIViewController viewDidAppear:]`

### LLDB Commands

When stopped at a breakpoint, use the debug console:

```lldb
po object              # Print object description
p variable             # Print variable value
expr variable = 5      # Change variable value
bt                     # Backtrace (call stack)
c                      # Continue execution
n                      # Step over (next line)
s                      # Step into (enter function)
frame variable         # Show all local variables
```

### View Debugging

For UI issues: Debug → View Debugging → Capture View Hierarchy

This shows a 3D exploded view of your UI hierarchy—incredibly useful for finding layout issues.

---

## Key Takeaways - Xcode

1. **Learn the keyboard shortcuts** - ⌘⇧O (Open Quickly) and ⌘B (Build) are essential
2. **Use SwiftUI previews** - Faster iteration than build-and-run
3. **Understand targets and schemes** - You'll have multiple for AI DJ
4. **Set up capabilities early** - HealthKit and MusicKit require entitlements
5. **Use local packages for shared code** - Keeps code organized across platforms
6. **Master the debugger** - Breakpoints and LLDB save hours of debugging

---

# 3. SWIFTUI FRAMEWORK

## Why This Matters for AI DJ

SwiftUI is how we build the user interface across all Apple platforms—iOS, watchOS, and macOS. With SwiftUI, we write UI code once and it adapts to each platform. For AI DJ, we'll use SwiftUI to create:
- Now Playing screens with album art and song info
- Real-time heart rate displays
- Mood selection interfaces
- Watch complications and widgets

The declarative nature of SwiftUI means our UI automatically updates when data changes—perfect for real-time health data.

---

## 3.1 The Declarative Paradigm

### What Makes SwiftUI Different

**Imperative (old way - UIKit):**
```swift
// Create button
let button = UIButton()
button.setTitle("Play", for: .normal)
button.backgroundColor = .blue
view.addSubview(button)
button.frame = CGRect(x: 20, y: 100, width: 100, height: 44)
button.addTarget(self, action: #selector(playTapped), for: .touchUpInside)

// Later, to update:
button.setTitle("Pause", for: .normal)
```

**Declarative (SwiftUI):**
```swift
struct PlayerView: View {
    @State var isPlaying = false

    var body: some View {
        Button(isPlaying ? "Pause" : "Play") {
            isPlaying.toggle()
        }
        .padding()
        .background(.blue)
    }
}
// UI automatically updates when isPlaying changes!
```

**What happens:** In SwiftUI, you describe what you want based on the current state. When state changes, SwiftUI automatically figures out what needs to update and animates the changes.

---

### The View Protocol

Every SwiftUI view conforms to the `View` protocol:

```swift
protocol View {
    associatedtype Body: View
    var body: Self.Body { get }
}
```

**What this means:** Each view must provide a `body` property that returns another view (or composition of views). The `some View` return type hides the complex concrete type.

```swift
struct NowPlayingView: View {
    let songTitle: String
    let artistName: String

    var body: some View {
        VStack {
            Text(songTitle)
                .font(.title)
            Text(artistName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
```

---

## 3.2 Basic Views

### Text

**What we're doing:** Displaying text with various styles.

```swift
// Basic text
Text("Hello, World!")

// Styled text
Text("Now Playing")
    .font(.largeTitle)      // System font style
    .fontWeight(.bold)
    .foregroundStyle(.blue)
    .italic()

// Dynamic content
Text("BPM: \(heartRate, format: .number.precision(.fractionLength(0)))")
// Shows "BPM: 72" (no decimals)

// Formatted dates
Text(Date.now, style: .time)  // "3:45 PM"
Text(Date.now, style: .relative)  // "2 minutes ago"

// Markdown support (iOS 15+)
Text("**Bold** and *italic* and [links](https://example.com)")
```

---

### Image

**What we're doing:** Displaying images from SF Symbols, assets, or URLs.

```swift
// SF Symbols (built-in icons)
Image(systemName: "heart.fill")
    .font(.largeTitle)
    .foregroundStyle(.red)

// From asset catalog
Image("albumArt")
    .resizable()                    // Enable resizing
    .aspectRatio(contentMode: .fit) // Maintain proportions
    .frame(width: 200, height: 200)
    .clipShape(RoundedRectangle(cornerRadius: 12))

// Async image loading from URL
AsyncImage(url: albumArtURL) { phase in
    switch phase {
    case .empty:
        ProgressView()
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
    case .failure:
        Image(systemName: "music.note")
            .font(.largeTitle)
    @unknown default:
        EmptyView()
    }
}
.frame(width: 200, height: 200)
```

---

### Button

**What we're doing:** Creating tappable elements that trigger actions.

```swift
// Simple button
Button("Play") {
    startPlayback()
}

// With icon
Button {
    togglePlayback()
} label: {
    Label("Play", systemImage: "play.fill")
}
.buttonStyle(.borderedProminent)

// Custom styled button
Button(action: skipNext) {
    HStack {
        Image(systemName: "forward.fill")
        Text("Skip")
    }
    .padding()
    .background(.blue)
    .foregroundStyle(.white)
    .clipShape(Capsule())
}
```

**Button styles:**
```swift
Button("Tap") { }
    .buttonStyle(.automatic)      // Platform default
    .buttonStyle(.bordered)       // Bordered
    .buttonStyle(.borderedProminent)  // Prominent bordered
    .buttonStyle(.plain)          // No visual treatment
```

---

### Input Controls

**TextField:**
```swift
@State private var searchText = ""

TextField("Search songs...", text: $searchText)
    .textFieldStyle(.roundedBorder)
    .autocapitalization(.none)
    .onSubmit {
        performSearch()
    }

// Secure input
SecureField("Password", text: $password)
```

**Toggle:**
```swift
@State private var shuffleEnabled = false

Toggle("Shuffle", isOn: $shuffleEnabled)
Toggle(isOn: $shuffleEnabled) {
    Label("Shuffle", systemImage: "shuffle")
}
```

**Slider:**
```swift
@State private var volume = 0.5

Slider(value: $volume, in: 0...1) {
    Text("Volume")
} minimumValueLabel: {
    Image(systemName: "speaker")
} maximumValueLabel: {
    Image(systemName: "speaker.wave.3")
}
```

**Picker:**
```swift
@State private var selectedMood = "neutral"

Picker("Mood", selection: $selectedMood) {
    Text("Calm").tag("calm")
    Text("Neutral").tag("neutral")
    Text("Energize").tag("energize")
}
.pickerStyle(.segmented)

// Menu style
Picker("Genre", selection: $genre) {
    ForEach(genres, id: \.self) { genre in
        Text(genre)
    }
}
.pickerStyle(.menu)
```

---

## 3.3 Layout

### Stack Views

**VStack - Vertical arrangement:**
```swift
VStack(alignment: .leading, spacing: 8) {
    Text("Title")
    Text("Subtitle")
    Text("Description")
}
```

**HStack - Horizontal arrangement:**
```swift
HStack(spacing: 16) {
    Image(systemName: "heart.fill")
    Text("72 BPM")
    Spacer()  // Pushes remaining content to the right
    Text("Normal")
}
```

**ZStack - Layered (back to front):**
```swift
ZStack(alignment: .bottomTrailing) {
    Image("albumArt")
        .resizable()

    // Overlay badge
    Text("Playing")
        .padding(6)
        .background(.black.opacity(0.7))
        .clipShape(Capsule())
        .padding(8)
}
```

---

### Spacer and Padding

**Spacer:** Expands to fill available space.

```swift
HStack {
    Text("Left")
    Spacer()
    Text("Right")
}

VStack {
    Text("Top")
    Spacer()  // Pushes top to top, bottom to bottom
    Text("Bottom")
}
```

**Padding:** Adds space around a view.

```swift
Text("Hello")
    .padding()                    // Default padding all sides
    .padding(.horizontal, 20)     // Horizontal only
    .padding(.top, 10)           // Top only
    .padding(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
```

---

### Frame and Alignment

```swift
Text("Hello")
    .frame(width: 200, height: 100)  // Fixed size
    .frame(maxWidth: .infinity)      // Expand horizontally
    .frame(minHeight: 44)            // Minimum height
    .frame(maxWidth: .infinity, alignment: .leading)  // Left-aligned

// Alignment within frame
Text("Aligned")
    .frame(width: 200, height: 100, alignment: .topLeading)
```

---

### Lists and Grids

**List:**
```swift
struct Song: Identifiable {
    let id: UUID
    let title: String
    let artist: String
}

struct SongListView: View {
    let songs: [Song]

    var body: some View {
        List(songs) { song in
            HStack {
                VStack(alignment: .leading) {
                    Text(song.title)
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
        }
    }
}
```

**LazyVGrid:**
```swift
let columns = [
    GridItem(.adaptive(minimum: 150))  // As many as fit, min 150pt wide
]

LazyVGrid(columns: columns, spacing: 20) {
    ForEach(songs) { song in
        AlbumArtView(song: song)
    }
}
```

---

## 3.4 State Management

This is crucial for SwiftUI—understanding how data flows through your views.

### @State - Local View State

**What we're doing:** Creating mutable state that belongs to a single view.

```swift
struct PlayerControls: View {
    @State private var isPlaying = false  // View owns this state
    @State private var volume = 0.5

    var body: some View {
        VStack {
            Button(isPlaying ? "Pause" : "Play") {
                isPlaying.toggle()  // Modifying state triggers UI update
            }

            Slider(value: $volume)  // $volume is a Binding
        }
    }
}
```

**What happens:** When `@State` values change, SwiftUI re-renders the view. The `$` prefix creates a `Binding` that allows two-way data flow.

---

### @Binding - Shared Mutable State

**What we're doing:** Passing state down to child views so they can read and modify it.

```swift
struct ParentView: View {
    @State private var volume = 0.5

    var body: some View {
        VolumeSlider(volume: $volume)  // Pass binding to child
    }
}

struct VolumeSlider: View {
    @Binding var volume: Double  // Receive binding

    var body: some View {
        Slider(value: $volume, in: 0...1)
        // Changes here update ParentView's volume
    }
}
```

---

### @StateObject and @ObservedObject

For complex state that needs to persist or be shared, use `ObservableObject`:

```swift
// The data model
class NowPlayingState: ObservableObject {
    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var heartRate: Double = 0

    func play(_ song: Song) {
        currentSong = song
        isPlaying = true
    }
}

// View that owns the state object
struct ContentView: View {
    @StateObject private var nowPlaying = NowPlayingState()

    var body: some View {
        PlayerView(state: nowPlaying)
    }
}

// Child view that observes it
struct PlayerView: View {
    @ObservedObject var state: NowPlayingState

    var body: some View {
        VStack {
            if let song = state.currentSong {
                Text(song.title)
            }
            Text("HR: \(state.heartRate, format: .number)")
        }
    }
}
```

**When to use which:**
- `@StateObject` - View creates and owns the object (use in parent)
- `@ObservedObject` - View receives object from elsewhere (use in children)
- `@State` - Simple value types, local to view

---

### @EnvironmentObject - Dependency Injection

For data that many views need access to:

```swift
class AppState: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
}

// At app root
@main
struct AIDJApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)  // Inject into environment
        }
    }
}

// Any descendant view can access it
struct SettingsView: View {
    @EnvironmentObject var appState: AppState  // Pull from environment

    var body: some View {
        if appState.isAuthenticated {
            // Show settings
        }
    }
}
```

---

## 3.5 Navigation

### NavigationStack (iOS 16+)

```swift
struct MainView: View {
    var body: some View {
        NavigationStack {
            List(songs) { song in
                NavigationLink(value: song) {
                    SongRow(song: song)
                }
            }
            .navigationTitle("Songs")
            .navigationDestination(for: Song.self) { song in
                SongDetailView(song: song)
            }
        }
    }
}
```

### TabView

```swift
struct MainTabView: View {
    var body: some View {
        TabView {
            NowPlayingView()
                .tabItem {
                    Label("Now Playing", systemImage: "play.circle")
                }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
```

---

## 3.6 AI DJ Example - Now Playing View

Putting it all together:

```swift
struct NowPlayingView: View {
    @StateObject private var viewModel = NowPlayingViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Album Art
            AsyncImage(url: viewModel.currentSong?.artworkURL) { image in
                image.resizable()
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                    }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 10)

            // Song Info
            VStack(spacing: 4) {
                Text(viewModel.currentSong?.title ?? "Not Playing")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(viewModel.currentSong?.artist ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Biometric Info
            HStack(spacing: 30) {
                BiometricPill(
                    icon: "heart.fill",
                    value: "\(Int(viewModel.heartRate))",
                    unit: "BPM",
                    color: .red
                )

                BiometricPill(
                    icon: "waveform.path.ecg",
                    value: "\(Int(viewModel.hrv))",
                    unit: "HRV",
                    color: .green
                )
            }

            // Playback Controls
            HStack(spacing: 40) {
                Button { viewModel.previousSong() } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }

                Button { viewModel.togglePlayback() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }

                Button { viewModel.nextSong() } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
            }
            .foregroundStyle(.primary)

            // Why this song
            if let reason = viewModel.selectionReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// Reusable component
struct BiometricPill: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .fontWeight(.semibold)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }
}
```

---

## Key Takeaways - SwiftUI

1. **Think declaratively** - Describe what you want, not how to create it
2. **State drives UI** - When state changes, UI updates automatically
3. **Use the right state wrapper:**
   - `@State` for simple, local view state
   - `@StateObject` for complex objects you create
   - `@ObservedObject` for complex objects passed to you
   - `@EnvironmentObject` for app-wide state
4. **Modifiers create new views** - Order matters!
5. **Extract reusable components** - Like `BiometricPill` above
6. **Use previews** - Faster than build-and-run

---

# 4. SWIFT CONCURRENCY & COMBINE

## Why This Matters for AI DJ

AI DJ constantly performs asynchronous operations: fetching health data from HealthKit, querying songs from MusicKit, sending data between iPhone and Watch, and updating the UI with real-time biometrics. Swift's modern concurrency system (async/await) makes this code readable and safe, while Combine provides reactive streams for continuous data like heart rate updates.

**In AI DJ, you'll use concurrency for:**
- Fetching heart rate samples without blocking the UI
- Loading playlists and song metadata in parallel
- Streaming real-time health updates to the scoring algorithm
- Coordinating data between Watch and iPhone

---

## 4.1 Async/Await Basics

Swift's structured concurrency, introduced in Swift 5.5 and refined through Swift 6, represents a fundamental shift in how we write asynchronous code. According to [SwiftLee](https://www.avanderlee.com/swift/async-await/) and other Swift experts, async/await eliminates entire categories of bugs related to forgotten completions, retain cycles in closures, and the cognitive overhead of "callback hell." The Swift compiler now helps verify correctness of concurrent code at compile time rather than leaving you to discover race conditions at runtime.

### The Problem with Callbacks

Before async/await, asynchronous programming in Swift used completion handlers—closures that get called when an operation finishes. While functional, this approach leads to deeply nested code, scattered error handling, and a non-linear flow that's hard to follow. Each level of nesting adds cognitive load, and it's easy to forget to call a completion handler in some code path.

The async/await model transforms this into sequential-looking code. Your function suspends at `await` points, freeing the thread to do other work, then resumes exactly where it left off when the result is ready. The compiler tracks this flow, ensuring you handle errors properly and can't accidentally forget to await an async call.

**What we're doing:** Understanding why async/await is better than traditional callbacks, and how it transforms asynchronous code into readable, maintainable form.

```swift
// OLD WAY - Callback hell (nested, hard to read)
func loadDashboard() {
    fetchUser { user in
        fetchPlaylists(for: user) { playlists in
            fetchHealthData { health in
                // Finally do something with all the data
                // Error handling is scattered everywhere
            }
        }
    }
}

// NEW WAY - Async/await (linear, readable)
func loadDashboard() async throws {
    let user = try await fetchUser()
    let playlists = try await fetchPlaylists(for: user)
    let health = try await fetchHealthData()
    // Clean, linear code that reads top-to-bottom
}
```

**What happens:** With async/await, the function suspends at each `await` point, yielding the thread so other code can run. When the awaited operation completes, the Swift runtime resumes execution at exactly that point. Importantly, as noted by [zen8labs](https://www.zen8labs.com/insights/mobile-application/best-practices-for-mastering-concurrency-in-swift-with-async-await/), each await might resume on a different thread—you should never assume the thread remains the same across await points.

---

### Declaring Async Functions

The `async` keyword marks a function as potentially suspending—it might pause execution to wait for some operation to complete. When you call an async function, you must use `await`, which signals to the compiler and to readers that this is a suspension point. The combination of `async` and `throws` (written as `async throws`) indicates a function that can both suspend and fail.

One important performance consideration from [Medium's best practices guide](https://medium.com/@qquang269/async-await-in-swift-best-practices-and-pitfalls-to-avoid-865ddc2921dd): async functions have a slightly different calling convention than synchronous functions, meaning there's a small overhead. For hot paths called thousands of times, you might keep synchronous versions. But for I/O operations like network requests or health data queries, this overhead is negligible compared to the operation itself.

**What we're doing:** Creating functions that can perform asynchronous work by marking them with `async`, and optionally `throws` if they can fail. These functions can suspend their execution at `await` points without blocking any thread.

```swift
// Mark function as async - it can suspend
func fetchHeartRate() async -> Double {
    // Simulate async work
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    return 72.5
}

// Async function that can also throw errors
func fetchSong(id: String) async throws -> Song {
    guard let url = URL(string: "https://api.music.apple.com/songs/\(id)") else {
        throw NetworkError.invalidURL
    }

    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(Song.self, from: data)
}

// Calling async functions - must use await
func updateUI() async {
    let heartRate = await fetchHeartRate()  // Suspends here
    print("Heart rate: \(heartRate)")        // Resumes when done
}
```

**What happens:** The `async` keyword marks a function as asynchronous. Inside, you can use `await` to call other async functions. The function suspends at `await` points without blocking the thread—the thread is freed to do other work until the operation completes.

---

### Calling Async Code from Sync Context

**What we're doing:** Bridging between synchronous code (like SwiftUI views) and async functions.

```swift
// In SwiftUI, use .task modifier
struct HeartRateView: View {
    @State private var heartRate: Double = 0

    var body: some View {
        Text("HR: \(Int(heartRate)) BPM")
            .task {
                // This runs async when view appears
                heartRate = await fetchHeartRate()
            }
    }
}

// Or use Task to create async context
class ViewModel: ObservableObject {
    @Published var songs: [Song] = []

    func loadSongs() {
        Task {
            // Now we're in async context
            do {
                songs = try await fetchAllSongs()
            } catch {
                print("Failed to load: \(error)")
            }
        }
    }
}
```

**What happens:** `Task { }` creates a new asynchronous context. The `.task` modifier in SwiftUI automatically creates and cancels tasks tied to the view's lifecycle.

---

## 4.2 Structured Concurrency

### Task Groups - Parallel Execution

**What we're doing:** Running multiple async operations in parallel and collecting results.

```swift
// Fetch multiple songs in parallel
func fetchSongs(ids: [String]) async throws -> [Song] {
    try await withThrowingTaskGroup(of: Song.self) { group in
        for id in ids {
            group.addTask {
                try await fetchSong(id: id)
            }
        }

        var songs: [Song] = []
        for try await song in group {
            songs.append(song)
        }
        return songs
    }
}
```

**What happens:** Each `addTask` creates a child task that runs concurrently. The `for try await` loop collects results as they complete. If any task throws, the group cancels remaining tasks.

**AI DJ Example:**
```swift
// Fetch health data and music data in parallel
func loadDashboardData() async throws -> DashboardData {
    async let healthData = fetchHealthData()      // Starts immediately
    async let playlists = fetchPlaylists()        // Starts immediately
    async let recommendations = getRecommendations()  // Starts immediately

    // Wait for all three to complete
    return try await DashboardData(
        health: healthData,
        playlists: playlists,
        recommendations: recommendations
    )
}
```

**What happens:** `async let` starts each operation immediately and runs them concurrently. The `await` at the end waits for all to complete. This is faster than sequential awaits.

---

### Task Cancellation

**What we're doing:** Handling cancellation gracefully when operations are no longer needed.

```swift
func fetchWithCancellation() async throws -> [Song] {
    var songs: [Song] = []

    for id in songIds {
        // Check if task was cancelled
        try Task.checkCancellation()

        // Or check without throwing
        if Task.isCancelled {
            return songs  // Return partial results
        }

        let song = try await fetchSong(id: id)
        songs.append(song)
    }

    return songs
}

// Cancel a task
let task = Task {
    try await fetchWithCancellation()
}

// Later, if user navigates away
task.cancel()
```

**What happens:** `Task.checkCancellation()` throws `CancellationError` if cancelled. `Task.isCancelled` lets you check without throwing. Always handle cancellation in long-running operations.

---

## 4.3 Actors - Safe Concurrent State

### The Problem: Data Races

**What we're doing:** Understanding why we need actors for shared mutable state.

```swift
// UNSAFE - Data race possible
class UnsafeCounter {
    var count = 0

    func increment() {
        count += 1  // Multiple threads can conflict here
    }
}

// SAFE - Actor protects state
actor SafeCounter {
    var count = 0

    func increment() {
        count += 1  // Only one caller at a time
    }
}

// Using an actor
let counter = SafeCounter()
await counter.increment()  // Must await actor methods
let value = await counter.count  // Must await property access too
```

**What happens:** Actors serialize access to their state. Only one task can execute actor code at a time, preventing data races. All access from outside requires `await`.

---

### AI DJ Example - State Manager Actor

```swift
actor BiometricStateManager {
    private var heartRateSamples: [Double] = []
    private var hrvSamples: [Double] = []
    private let maxSamples = 60

    func addHeartRate(_ rate: Double) {
        heartRateSamples.append(rate)
        if heartRateSamples.count > maxSamples {
            heartRateSamples.removeFirst()
        }
    }

    func addHRV(_ hrv: Double) {
        hrvSamples.append(hrv)
        if hrvSamples.count > maxSamples {
            hrvSamples.removeFirst()
        }
    }

    var averageHeartRate: Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        return heartRateSamples.reduce(0, +) / Double(heartRateSamples.count)
    }

    var currentState: StateVector {
        StateVector(
            heartRate: averageHeartRate,
            hrv: hrvSamples.last ?? 0,
            trend: calculateTrend()
        )
    }

    private func calculateTrend() -> Double {
        guard heartRateSamples.count >= 10 else { return 0 }
        let recent = Array(heartRateSamples.suffix(5))
        let older = Array(heartRateSamples.suffix(10).prefix(5))
        return recent.average - older.average
    }
}

// Usage
let stateManager = BiometricStateManager()

// From HealthKit callback
Task {
    await stateManager.addHeartRate(75.0)
    let state = await stateManager.currentState
    await updateMusicSelection(for: state)
}
```

---

### MainActor - UI Thread Safety

**What we're doing:** Ensuring UI updates happen on the main thread.

```swift
// Mark entire class as MainActor
@MainActor
class NowPlayingViewModel: ObservableObject {
    @Published var currentSong: Song?
    @Published var heartRate: Double = 0

    func updateHeartRate(_ rate: Double) {
        heartRate = rate  // Safe - guaranteed on main thread
    }
}

// Or mark individual functions
class DataManager {
    @MainActor
    func updateUI(with data: Data) {
        // This always runs on main thread
    }

    func processInBackground() async {
        let result = await heavyComputation()

        // Switch to main thread for UI update
        await MainActor.run {
            updateUI(with: result)
        }
    }
}
```

**What happens:** `@MainActor` ensures code runs on the main thread. Use it for all UI-related code. SwiftUI's `@Published` properties should be updated on MainActor.

---

## 4.4 Combine Framework

### Publishers and Subscribers

**What we're doing:** Creating reactive streams of values over time.

```swift
import Combine

// Publisher emits values over time
let heartRatePublisher = PassthroughSubject<Double, Never>()

// Subscriber receives values
let cancellable = heartRatePublisher
    .sink { rate in
        print("Heart rate: \(rate)")
    }

// Emit values
heartRatePublisher.send(72.0)
heartRatePublisher.send(75.0)
heartRatePublisher.send(71.0)

// Store cancellable to keep subscription alive
var cancellables = Set<AnyCancellable>()
heartRatePublisher
    .sink { rate in
        print("Rate: \(rate)")
    }
    .store(in: &cancellables)
```

**What happens:** Publishers emit values, operators transform them, subscribers receive them. `sink` creates a subscriber. Store the `AnyCancellable` or the subscription ends immediately.

---

### Common Operators

**What we're doing:** Transforming and filtering streams of data.

```swift
let heartRates = PassthroughSubject<Double, Never>()

heartRates
    // Transform values
    .map { rate in
        rate > 100 ? "High" : "Normal"
    }
    // Filter values
    .filter { $0 == "High" }
    // Remove duplicates
    .removeDuplicates()
    // Debounce rapid changes (wait 0.5s of stability)
    .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
    // Receive on main thread
    .receive(on: DispatchQueue.main)
    // Subscribe
    .sink { status in
        showAlert(status)
    }
    .store(in: &cancellables)
```

**Key operators for AI DJ:**
| Operator | Purpose | AI DJ Use Case |
|----------|---------|----------------|
| `map` | Transform values | Convert HR to stress level |
| `filter` | Keep matching values | Only process significant changes |
| `debounce` | Wait for stability | Avoid rapid song switching |
| `throttle` | Limit rate | Cap UI updates to 1/second |
| `combineLatest` | Merge streams | Combine HR + HRV into state |
| `removeDuplicates` | Skip unchanged | Don't re-rank if state unchanged |

---

### AI DJ Example - Reactive State Processing

```swift
class BiometricProcessor: ObservableObject {
    @Published var currentState: UserState = .neutral
    @Published var recommendedMood: MusicMood = .neutral

    private var cancellables = Set<AnyCancellable>()

    private let heartRateSubject = PassthroughSubject<Double, Never>()
    private let hrvSubject = PassthroughSubject<Double, Never>()

    init() {
        setupPipeline()
    }

    private func setupPipeline() {
        // Combine heart rate and HRV into unified state
        Publishers.CombineLatest(
            heartRateSubject
                .collect(.byTime(RunLoop.main, .seconds(5)))  // Collect 5 seconds
                .map { samples in samples.reduce(0, +) / Double(samples.count) },
            hrvSubject
        )
        .map { (avgHR, hrv) -> UserState in
            // Determine user state from biometrics
            if avgHR > 100 && hrv < 30 {
                return .stressed
            } else if avgHR < 65 && hrv > 50 {
                return .relaxed
            } else if avgHR > 85 {
                return .active
            } else {
                return .neutral
            }
        }
        .removeDuplicates()
        .debounce(for: .seconds(10), scheduler: RunLoop.main)  // Stable for 10s
        .receive(on: DispatchQueue.main)
        .sink { [weak self] state in
            self?.currentState = state
            self?.recommendedMood = state.suggestedMood
        }
        .store(in: &cancellables)
    }

    func recordHeartRate(_ rate: Double) {
        heartRateSubject.send(rate)
    }

    func recordHRV(_ hrv: Double) {
        hrvSubject.send(hrv)
    }
}
```

---

### Converting Between Async/Await and Combine

```swift
// Combine publisher to async sequence
let heartRates: some Publisher<Double, Never> = ...

for await rate in heartRates.values {
    print("Rate: \(rate)")
}

// Async function to publisher
func fetchSongsPublisher() -> AnyPublisher<[Song], Error> {
    Future { promise in
        Task {
            do {
                let songs = try await fetchSongs()
                promise(.success(songs))
            } catch {
                promise(.failure(error))
            }
        }
    }
    .eraseToAnyPublisher()
}
```

---

## Key Takeaways - Swift Concurrency & Combine

1. **Use async/await for cleaner async code** - Reads linearly, handles errors naturally
2. **Use `async let` for parallel operations** - Fetch health and music data simultaneously
3. **Actors protect shared state** - Use for biometric state management
4. **MainActor for UI updates** - All @Published properties should update on MainActor
5. **Combine for reactive streams** - Perfect for continuous heart rate data
6. **Debounce to avoid rapid changes** - Don't switch songs every heartbeat
7. **Always handle cancellation** - Users navigate away, operations should stop

---

# 5. DATA PERSISTENCE WITH COREDATA

## Why This Matters for AI DJ

AI DJ needs to persist data locally: user preferences, song effectiveness history, baseline biometric profiles, and listening patterns. CoreData provides a robust object graph and persistence layer that syncs across devices via iCloud. This allows the AI to learn from past sessions and improve recommendations over time.

**In AI DJ, you'll use CoreData for:**
- Storing historical song effectiveness scores
- Persisting user's baseline heart rate and HRV
- Caching playlist and song metadata
- Syncing preferences between iPhone, Watch, and Mac

---

## 5.1 CoreData Stack

### Understanding the Components

**What we're doing:** Setting up the foundation for data persistence.

```swift
import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "AIDJModel")

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }

        // Enable automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // Background context for heavy operations
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
}
```

**What happens:**
- `NSPersistentContainer` manages the entire CoreData stack
- `viewContext` is the main thread context for UI
- Background contexts prevent blocking the UI during heavy operations

---

### Data Model (.xcdatamodeld)

**What we're doing:** Defining entities (tables) and attributes (columns) in Xcode's data model editor.

```
// In Xcode: File → New → Data Model

Entity: SongHistory
├── Attributes:
│   ├── songId: String
│   ├── title: String
│   ├── artist: String
│   ├── playCount: Integer 32
│   ├── skipCount: Integer 32
│   ├── averageHeartRateEffect: Double
│   ├── averageHRVEffect: Double
│   ├── lastPlayed: Date
│   └── effectivenessScore: Double
└── Relationships:
    └── contexts: [PlayContext] (to-many)

Entity: PlayContext
├── Attributes:
│   ├── timestamp: Date
│   ├── heartRateBefore: Double
│   ├── heartRateAfter: Double
│   ├── hrvBefore: Double
│   ├── hrvAfter: Double
│   ├── wasSkipped: Boolean
│   └── playDuration: Double
└── Relationships:
    └── song: SongHistory (to-one)
```

---

### Generated Entity Classes

**What we're doing:** Using Xcode-generated NSManagedObject subclasses.

```swift
// Xcode generates these from your data model
// Editor → Create NSManagedObject Subclass

@objc(SongHistory)
public class SongHistory: NSManagedObject {
    @NSManaged public var songId: String
    @NSManaged public var title: String
    @NSManaged public var artist: String
    @NSManaged public var playCount: Int32
    @NSManaged public var skipCount: Int32
    @NSManaged public var effectivenessScore: Double
    @NSManaged public var lastPlayed: Date?
    @NSManaged public var contexts: Set<PlayContext>
}

extension SongHistory {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongHistory> {
        return NSFetchRequest<SongHistory>(entityName: "SongHistory")
    }

    var skipRate: Double {
        guard playCount > 0 else { return 0 }
        return Double(skipCount) / Double(playCount)
    }
}
```

---

## 5.2 CRUD Operations

### Creating Objects

**What we're doing:** Inserting new records into CoreData.

```swift
func recordSongPlay(
    songId: String,
    title: String,
    artist: String,
    context: PlayContext
) {
    let viewContext = PersistenceController.shared.viewContext

    // Check if song already exists
    let fetchRequest: NSFetchRequest<SongHistory> = SongHistory.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "songId == %@", songId)

    do {
        let results = try viewContext.fetch(fetchRequest)

        let song: SongHistory
        if let existing = results.first {
            song = existing
            song.playCount += 1
        } else {
            song = SongHistory(context: viewContext)
            song.songId = songId
            song.title = title
            song.artist = artist
            song.playCount = 1
            song.skipCount = 0
        }

        song.lastPlayed = Date()
        song.contexts.insert(context)

        try viewContext.save()
    } catch {
        print("Failed to save: \(error)")
    }
}
```

---

### Reading with Fetch Requests

**What we're doing:** Querying data with predicates and sort descriptors.

```swift
// Simple fetch all
func fetchAllSongHistory() -> [SongHistory] {
    let request: NSFetchRequest<SongHistory> = SongHistory.fetchRequest()
    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \SongHistory.lastPlayed, ascending: false)
    ]

    do {
        return try PersistenceController.shared.viewContext.fetch(request)
    } catch {
        print("Fetch failed: \(error)")
        return []
    }
}

// Fetch with predicate (filter)
func fetchEffectiveSongs(minScore: Double) -> [SongHistory] {
    let request: NSFetchRequest<SongHistory> = SongHistory.fetchRequest()
    request.predicate = NSPredicate(
        format: "effectivenessScore >= %f AND playCount >= %d",
        minScore, 3
    )
    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \SongHistory.effectivenessScore, ascending: false)
    ]
    request.fetchLimit = 50

    do {
        return try PersistenceController.shared.viewContext.fetch(request)
    } catch {
        return []
    }
}

// Compound predicates
func fetchSongsForCalming() -> [SongHistory] {
    let request: NSFetchRequest<SongHistory> = SongHistory.fetchRequest()

    let highEffectiveness = NSPredicate(format: "effectivenessScore >= 0.7")
    let lowSkipRate = NSPredicate(format: "skipCount < playCount * 0.2")
    let recentlyEffective = NSPredicate(format: "lastPlayed > %@",
        Calendar.current.date(byAdding: .day, value: -30, to: Date())! as NSDate)

    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        highEffectiveness, lowSkipRate, recentlyEffective
    ])

    do {
        return try PersistenceController.shared.viewContext.fetch(request)
    } catch {
        return []
    }
}
```

---

### Updating and Deleting

```swift
// Update
func updateSongEffectiveness(songId: String, newScore: Double) {
    let context = PersistenceController.shared.viewContext
    let request: NSFetchRequest<SongHistory> = SongHistory.fetchRequest()
    request.predicate = NSPredicate(format: "songId == %@", songId)

    do {
        if let song = try context.fetch(request).first {
            // Blend new score with historical (exponential moving average)
            song.effectivenessScore = song.effectivenessScore * 0.7 + newScore * 0.3
            try context.save()
        }
    } catch {
        print("Update failed: \(error)")
    }
}

// Delete
func deleteSongHistory(song: SongHistory) {
    let context = PersistenceController.shared.viewContext
    context.delete(song)

    do {
        try context.save()
    } catch {
        print("Delete failed: \(error)")
    }
}

// Batch delete (efficient for many records)
func clearOldHistory(olderThan days: Int) {
    let context = PersistenceController.shared.viewContext
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

    let request = NSFetchRequest<NSFetchRequestResult>(entityName: "PlayContext")
    request.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)

    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

    do {
        try context.execute(deleteRequest)
        try context.save()
    } catch {
        print("Batch delete failed: \(error)")
    }
}
```

---

## 5.3 SwiftUI Integration

### @FetchRequest Property Wrapper

**What we're doing:** Automatically fetching and observing CoreData in SwiftUI views.

```swift
struct SongHistoryListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SongHistory.lastPlayed, ascending: false)],
        predicate: NSPredicate(format: "playCount >= 1"),
        animation: .default
    )
    private var songs: FetchedResults<SongHistory>

    var body: some View {
        List(songs) { song in
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Plays: \(song.playCount)")
                    Spacer()
                    Text("Score: \(song.effectivenessScore, format: .percent)")
                }
                .font(.caption)
            }
        }
    }
}

// Inject the context at app level
@main
struct AIDJApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}
```

**What happens:** `@FetchRequest` automatically executes the query and updates the view when data changes. No manual refresh needed.

---

## 5.4 Background Processing and CloudKit Sync

### Background Context Operations

```swift
func processPlaySession(data: SessionData) {
    // Use background context for heavy work
    let backgroundContext = PersistenceController.shared.newBackgroundContext()

    backgroundContext.perform {
        // All work here is off the main thread
        for songData in data.songs {
            let song = SongHistory(context: backgroundContext)
            song.songId = songData.id
            song.title = songData.title
            // ... set other properties
        }

        do {
            try backgroundContext.save()
            // Changes automatically merge to viewContext
        } catch {
            print("Background save failed: \(error)")
        }
    }
}
```

### CloudKit Integration

```swift
// In PersistenceController init
init() {
    container = NSPersistentCloudKitContainer(name: "AIDJModel")

    // Configure for CloudKit sync
    guard let description = container.persistentStoreDescriptions.first else {
        fatalError("No store description")
    }

    description.setOption(true as NSNumber,
        forKey: NSPersistentHistoryTrackingKey)
    description.setOption(true as NSNumber,
        forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

    container.loadPersistentStores { _, error in
        if let error = error {
            fatalError("Store failed: \(error)")
        }
    }

    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
}
```

**What happens:** `NSPersistentCloudKitContainer` automatically syncs data to iCloud. Changes on iPhone appear on Mac and Watch automatically.

---

## Key Takeaways - CoreData

1. **Use NSPersistentContainer** - Manages the entire stack for you
2. **viewContext for UI, background context for heavy work** - Never block main thread
3. **@FetchRequest in SwiftUI** - Automatic updates when data changes
4. **Predicates filter data** - Learn NSPredicate format strings
5. **Use CloudKit container for sync** - Free iCloud sync across devices
6. **Batch operations for bulk changes** - More efficient than one-by-one
7. **Store effectiveness scores** - AI DJ learns from history

---

# 6. iOS APP ARCHITECTURE PATTERNS

## Why This Matters for AI DJ

A well-architected app is easier to test, debug, and extend. AI DJ has complex logic: biometric processing, music scoring, cross-device communication. Without good architecture, this becomes spaghetti code. MVVM (Model-View-ViewModel) separates concerns so the Brain can be tested without UI, and views stay simple.

**In AI DJ, architecture helps you:**
- Test the scoring algorithm independently
- Share Brain logic between iOS, watchOS, and macOS
- Keep SwiftUI views simple and focused on display
- Mock HealthKit and MusicKit for testing

---

## 6.1 MVVM Pattern

### The Three Layers

**What we're doing:** Separating data (Model), display (View), and logic (ViewModel).

```swift
// MODEL - Pure data structures
struct Song: Identifiable {
    let id: String
    let title: String
    let artist: String
    let bpm: Int
    let energyLevel: Double
}

struct BiometricState {
    let heartRate: Double
    let hrv: Double
    let trend: Double

    var stressLevel: Double {
        // High HR + Low HRV = stress
        let hrFactor = min(1.0, max(0, (heartRate - 60) / 60))
        let hrvFactor = 1.0 - min(1.0, hrv / 100)
        return (hrFactor + hrvFactor) / 2
    }
}

// VIEWMODEL - Business logic, state management
@MainActor
class NowPlayingViewModel: ObservableObject {
    @Published var currentSong: Song?
    @Published var biometrics: BiometricState?
    @Published var isPlaying = false
    @Published var songQueue: [Song] = []

    private let musicService: MusicServiceProtocol
    private let healthService: HealthServiceProtocol
    private let brain: ScoringBrain

    init(
        musicService: MusicServiceProtocol,
        healthService: HealthServiceProtocol,
        brain: ScoringBrain
    ) {
        self.musicService = musicService
        self.healthService = healthService
        self.brain = brain
    }

    func selectNextSong() async {
        guard let state = biometrics else { return }

        let candidates = await musicService.getPlaylistSongs()
        let ranked = brain.rankSongs(candidates, for: state)

        if let best = ranked.first {
            currentSong = best.song
            await musicService.play(best.song)
            isPlaying = true
        }
    }
}

// VIEW - Pure UI, delegates to ViewModel
struct NowPlayingView: View {
    @StateObject private var viewModel: NowPlayingViewModel

    init(viewModel: NowPlayingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack {
            if let song = viewModel.currentSong {
                Text(song.title)
                    .font(.title)
                Text(song.artist)
                    .foregroundStyle(.secondary)
            }

            if let bio = viewModel.biometrics {
                HStack {
                    Label("\(Int(bio.heartRate))", systemImage: "heart.fill")
                    Label("\(Int(bio.hrv))", systemImage: "waveform.path.ecg")
                }
            }

            Button(viewModel.isPlaying ? "Pause" : "Play") {
                Task {
                    await viewModel.selectNextSong()
                }
            }
        }
    }
}
```

---

## 6.2 Dependency Injection

### Protocol-Based Dependencies

**What we're doing:** Using protocols so we can swap implementations (real vs mock).

```swift
// Define protocols for dependencies
protocol MusicServiceProtocol {
    func getPlaylistSongs() async -> [Song]
    func play(_ song: Song) async
    func pause()
}

protocol HealthServiceProtocol {
    var heartRatePublisher: AnyPublisher<Double, Never> { get }
    var hrvPublisher: AnyPublisher<Double, Never> { get }
    func requestAuthorization() async throws
}

// Real implementation
class MusicKitService: MusicServiceProtocol {
    func getPlaylistSongs() async -> [Song] {
        // Real MusicKit API calls
    }

    func play(_ song: Song) async {
        // Real playback
    }

    func pause() {
        // Real pause
    }
}

// Mock for testing
class MockMusicService: MusicServiceProtocol {
    var mockSongs: [Song] = []
    var playedSong: Song?

    func getPlaylistSongs() async -> [Song] {
        return mockSongs
    }

    func play(_ song: Song) async {
        playedSong = song
    }

    func pause() {}
}
```

---

### Dependency Container

**What we're doing:** Centralizing dependency creation for easy swapping.

```swift
class DependencyContainer {
    static let shared = DependencyContainer()

    lazy var musicService: MusicServiceProtocol = MusicKitService()
    lazy var healthService: HealthServiceProtocol = HealthKitService()
    lazy var brain: ScoringBrain = ScoringBrain()
    lazy var persistence: PersistenceController = PersistenceController.shared

    func makeNowPlayingViewModel() -> NowPlayingViewModel {
        NowPlayingViewModel(
            musicService: musicService,
            healthService: healthService,
            brain: brain
        )
    }
}

// For testing
class TestDependencyContainer: DependencyContainer {
    override init() {
        super.init()
        musicService = MockMusicService()
        healthService = MockHealthService()
    }
}
```

---

## 6.3 Service Layer Pattern

### Encapsulating External APIs

**What we're doing:** Wrapping HealthKit and MusicKit behind clean interfaces.

```swift
class HealthKitService: HealthServiceProtocol {
    private let healthStore = HKHealthStore()
    private let heartRateSubject = PassthroughSubject<Double, Never>()
    private let hrvSubject = PassthroughSubject<Double, Never>()

    var heartRatePublisher: AnyPublisher<Double, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }

    var hrvPublisher: AnyPublisher<Double, Never> {
        hrvSubject.eraseToAnyPublisher()
    }

    func requestAuthorization() async throws {
        let types: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN)
        ]

        try await healthStore.requestAuthorization(toShare: [], read: types)
    }

    func startMonitoring() {
        // Set up HKObserverQuery for heart rate
        let heartRateType = HKQuantityType(.heartRate)

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deleted, anchor, error in
            self?.processHeartRateSamples(samples as? [HKQuantitySample] ?? [])
        }

        query.updateHandler = { [weak self] query, samples, deleted, anchor, error in
            self?.processHeartRateSamples(samples as? [HKQuantitySample] ?? [])
        }

        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKQuantitySample]) {
        for sample in samples {
            let rate = sample.quantity.doubleValue(for: .beatsPerMinute)
            heartRateSubject.send(rate)
        }
    }
}
```

---

## 6.4 The Brain - Core Logic Module

### Separating Algorithm from Infrastructure

**What we're doing:** Creating a pure logic module with no dependencies on Apple frameworks.

```swift
// This can be in a Swift Package, shared across all platforms
struct ScoringBrain {
    struct ScoredSong {
        let song: Song
        let score: Double
        let reasons: [String]
    }

    func rankSongs(_ songs: [Song], for state: BiometricState) -> [ScoredSong] {
        songs.map { song in
            let (score, reasons) = calculateScore(song: song, state: state)
            return ScoredSong(song: song, score: score, reasons: reasons)
        }
        .sorted { $0.score > $1.score }
    }

    private func calculateScore(song: Song, state: BiometricState) -> (Double, [String]) {
        var score = 0.0
        var reasons: [String] = []

        // BPM matching
        let bpmDiff = abs(Double(song.bpm) - state.heartRate)
        let bpmScore = max(0, 1.0 - bpmDiff / 50.0)
        score += bpmScore * 0.3
        if bpmScore > 0.7 {
            reasons.append("BPM matches your rhythm")
        }

        // Energy matching to stress
        let needsCalm = state.stressLevel > 0.6
        let energyScore: Double
        if needsCalm {
            energyScore = 1.0 - song.energyLevel
            if energyScore > 0.7 {
                reasons.append("Calming energy for relaxation")
            }
        } else {
            energyScore = song.energyLevel
            if energyScore > 0.7 {
                reasons.append("Energetic vibe")
            }
        }
        score += energyScore * 0.4

        // Could add more factors: familiarity, recency, etc.

        return (score, reasons)
    }
}
```

**Why this matters:** The Brain has no dependencies on UIKit, SwiftUI, HealthKit, or MusicKit. It's pure Swift logic that can be:
- Unit tested with simple inputs
- Shared via Swift Package across iOS, watchOS, macOS
- Developed and refined independently

---

## Key Takeaways - Architecture

1. **MVVM separates concerns** - Models hold data, ViewModels hold logic, Views display
2. **Protocols enable testing** - Mock dependencies for unit tests
3. **Dependency injection** - Pass dependencies in, don't create them inside
4. **Service layer wraps APIs** - Clean interface to HealthKit, MusicKit
5. **Brain is pure logic** - No Apple framework dependencies, fully testable
6. **Swift Packages share code** - Same Brain on iOS, watchOS, macOS

---

# 7. MUSICKIT FRAMEWORK

## Why This Matters for AI DJ

MusicKit is how AI DJ accesses Apple Music. It provides the song library, playback control, and metadata like BPM and energy level. Without MusicKit, there's no music to play. Understanding MusicKit deeply lets you query songs efficiently, control playback smoothly, and access the rich metadata needed for intelligent song selection.

**In AI DJ, you'll use MusicKit for:**
- Fetching user's playlists and library
- Getting song metadata (BPM, energy, genre)
- Controlling playback (play, pause, skip)
- Searching the Apple Music catalog

---

## 7.1 Authorization

### Requesting Music Access

**What we're doing:** Getting permission to access the user's Apple Music.

```swift
import MusicKit

class MusicAuthorizationManager {
    func requestAccess() async -> Bool {
        let status = await MusicAuthorization.request()

        switch status {
        case .authorized:
            print("Full access granted")
            return true
        case .denied:
            print("User denied access")
            return false
        case .notDetermined:
            print("Not yet determined")
            return false
        case .restricted:
            print("Restricted by parental controls")
            return false
        @unknown default:
            return false
        }
    }

    var isAuthorized: Bool {
        MusicAuthorization.currentStatus == .authorized
    }
}
```

**What happens:** The system shows a permission dialog. User must grant access for MusicKit to work. Check status before making any MusicKit calls.

**Info.plist requirement:**
```xml
<key>NSAppleMusicUsageDescription</key>
<string>AI DJ needs access to your music library to select songs based on your biometrics.</string>
```

---

## 7.2 Fetching Music

### User's Library

**What we're doing:** Accessing playlists and songs from the user's library.

```swift
// Fetch all user playlists
func fetchUserPlaylists() async throws -> [Playlist] {
    let request = MusicLibraryRequest<Playlist>()
    let response = try await request.response()
    return Array(response.items)
}

// Fetch songs from a specific playlist
func fetchSongs(from playlist: Playlist) async throws -> [Song] {
    // Load the tracks relationship
    let detailedPlaylist = try await playlist.with([.tracks])

    guard let tracks = detailedPlaylist.tracks else {
        return []
    }

    return tracks.compactMap { track -> Song? in
        guard case .song(let song) = track else { return nil }
        return song
    }
}

// Fetch user's recently played
func fetchRecentlyPlayed() async throws -> [Song] {
    let request = MusicRecentlyPlayedRequest<Song>()
    let response = try await request.response()
    return Array(response.items)
}
```

---

### Song Properties and Metadata

**What we're doing:** Accessing the rich metadata MusicKit provides.

```swift
func analyzeSong(_ song: Song) -> SongAnalysis {
    return SongAnalysis(
        id: song.id.rawValue,
        title: song.title,
        artist: song.artistName,
        album: song.albumTitle ?? "Unknown",
        duration: song.duration ?? 0,
        // Audio features (when available)
        bpm: song.tempo,  // Beats per minute
        genres: song.genreNames,
        releaseDate: song.releaseDate,
        // Artwork
        artworkURL: song.artwork?.url(width: 300, height: 300)
    )
}

struct SongAnalysis {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let bpm: Int?
    let genres: [String]
    let releaseDate: Date?
    let artworkURL: URL?

    // Estimate energy from genre (when audio analysis unavailable)
    var estimatedEnergy: Double {
        let highEnergyGenres = ["Electronic", "Dance", "Hip-Hop", "Rock", "Pop"]
        let lowEnergyGenres = ["Classical", "Jazz", "Ambient", "Acoustic"]

        for genre in genres {
            if highEnergyGenres.contains(where: { genre.contains($0) }) {
                return 0.8
            }
            if lowEnergyGenres.contains(where: { genre.contains($0) }) {
                return 0.3
            }
        }
        return 0.5  // Default medium energy
    }
}
```

---

### Searching the Catalog

```swift
// Search Apple Music catalog
func searchSongs(query: String) async throws -> [Song] {
    var request = MusicCatalogSearchRequest(
        term: query,
        types: [Song.self]
    )
    request.limit = 25

    let response = try await request.response()
    return Array(response.songs)
}

// Search with filters
func searchCalmingSongs() async throws -> [Song] {
    var request = MusicCatalogSearchRequest(
        term: "relaxing acoustic",
        types: [Song.self]
    )
    request.limit = 50

    let response = try await request.response()

    // Filter to slower songs
    return response.songs.filter { song in
        if let bpm = song.tempo {
            return bpm < 100
        }
        return true  // Include if BPM unknown
    }
}
```

---

## 7.3 Playback Control

### System Music Player

**What we're doing:** Controlling music playback through the system player.

```swift
class MusicPlayerController: ObservableObject {
    private let player = SystemMusicPlayer.shared

    @Published var isPlaying = false
    @Published var currentSong: Song?
    @Published var playbackTime: TimeInterval = 0

    init() {
        observePlaybackState()
    }

    func play(_ song: Song) async throws {
        player.queue = [song]
        try await player.play()
        currentSong = song
        isPlaying = true
    }

    func playPlaylist(_ playlist: Playlist, startingAt song: Song? = nil) async throws {
        player.queue = .init(playlist: playlist, startingAt: song)
        try await player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func resume() async throws {
        try await player.play()
        isPlaying = true
    }

    func skipToNext() async throws {
        try await player.skipToNextEntry()
    }

    func skipToPrevious() async throws {
        try await player.skipToPreviousEntry()
    }

    private func observePlaybackState() {
        // Observe player state changes
        Task {
            for await state in player.state.objectWillChange.values {
                await MainActor.run {
                    self.isPlaying = player.state.playbackStatus == .playing
                    self.playbackTime = player.playbackTime
                }
            }
        }
    }
}
```

---

### Queue Management

**What we're doing:** Building and managing the playback queue for AI DJ.

```swift
class SmartQueueManager {
    private let player = SystemMusicPlayer.shared
    private var upcomingSongs: [Song] = []

    func buildQueue(from rankedSongs: [ScoredSong]) async throws {
        // Take top 10 ranked songs
        upcomingSongs = rankedSongs.prefix(10).map { $0.song }

        guard let first = upcomingSongs.first else { return }

        // Set up queue with first song
        player.queue = [first]
        try await player.play()
    }

    func queueNext(_ song: Song) async throws {
        // Insert at front of queue
        try await player.queue.insert(song, position: .afterCurrentEntry)
    }

    func replaceUpcoming(with songs: [Song]) async throws {
        // Clear and rebuild queue based on new rankings
        player.queue = .init(for: songs)
    }

    // Called when biometrics change significantly
    func adaptQueue(for newState: BiometricState, brain: ScoringBrain) async throws {
        // Re-rank remaining songs
        let reranked = brain.rankSongs(upcomingSongs, for: newState)
        try await replaceUpcoming(with: reranked.map { $0.song })
    }
}
```

---

## 7.4 AI DJ MusicKit Service

### Complete Integration Example

```swift
class AIDJMusicService: MusicServiceProtocol, ObservableObject {
    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var currentPlaylist: Playlist?
    @Published var queue: [Song] = []

    private let player = SystemMusicPlayer.shared

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
    }

    // MARK: - Library Access

    func getPlaylists() async throws -> [Playlist] {
        let request = MusicLibraryRequest<Playlist>()
        let response = try await request.response()
        return Array(response.items)
    }

    func getSongs(from playlist: Playlist) async throws -> [Song] {
        let detailed = try await playlist.with([.tracks])
        return detailed.tracks?.compactMap { track -> Song? in
            guard case .song(let song) = track else { return nil }
            return song
        } ?? []
    }

    // MARK: - Playback

    func play(_ song: Song) async throws {
        player.queue = [song]
        try await player.play()
        await MainActor.run {
            currentSong = song
            isPlaying = true
        }
    }

    func playQueue(_ songs: [Song]) async throws {
        guard !songs.isEmpty else { return }

        player.queue = .init(for: songs)
        try await player.play()

        await MainActor.run {
            queue = songs
            currentSong = songs.first
            isPlaying = true
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func skip() async throws {
        try await player.skipToNextEntry()

        // Update current song
        if let entry = player.queue.currentEntry,
           case .song(let song) = entry.item {
            await MainActor.run {
                currentSong = song
            }
        }
    }

    // MARK: - Smart Selection

    func selectSongsForMood(
        from playlist: Playlist,
        mood: MusicMood,
        limit: Int = 20
    ) async throws -> [Song] {
        let allSongs = try await getSongs(from: playlist)

        // Filter based on mood
        return allSongs.filter { song in
            switch mood {
            case .calm:
                return (song.tempo ?? 100) < 100
            case .energize:
                return (song.tempo ?? 100) > 120
            case .focus:
                // Prefer instrumental or consistent tempo
                return song.genreNames.contains("Instrumental") ||
                       song.genreNames.contains("Classical")
            case .neutral:
                return true
            }
        }
        .prefix(limit)
        .shuffled()
    }
}
```

---

## Key Takeaways - MusicKit

1. **Request authorization first** - Nothing works without user permission
2. **Use MusicLibraryRequest for user's music** - Playlists, recently played
3. **Load relationships explicitly** - Use `.with([.tracks])` to get playlist songs
4. **SystemMusicPlayer for playback** - Shared player, queue management
5. **Tempo/BPM available on Song** - Key for AI DJ's rhythm matching
6. **Build smart queues** - Re-rank and rebuild as biometrics change

---

# 8. HEALTHKIT FRAMEWORK

## Why This Matters for AI DJ

HealthKit is Apple's centralized health data repository, providing a secure and privacy-focused way to access biometric information from Apple Watch and other sources. For AI DJ, HealthKit is the foundation of intelligent music selection—it provides the real-time heart rate and HRV data that drive our scoring algorithm.

Understanding HealthKit's query model is essential because health data is fundamentally different from other data sources. It's sensitive (requiring explicit user authorization), time-series based (samples arrive continuously), and sourced from multiple devices (Watch, iPhone, third-party apps). HealthKit provides several query types optimized for different access patterns, as detailed by [Apple's documentation](https://developer.apple.com/documentation/healthkit) and the [HealthKit blog by dmtopolog](https://dmtopolog.com/healthkit-changes-observing/).

**In AI DJ, you'll use HealthKit for:**
- Reading real-time heart rate from Apple Watch (via HKAnchoredObjectQuery)
- Accessing HRV for stress detection (typically updated less frequently)
- Detecting active workouts (changes monitoring frequency)
- Building user's baseline profile from historical data (via HKSampleQuery)
- Receiving background updates even when the app isn't active (via HKObserverQuery)

---

## 8.1 Authorization

HealthKit has the strictest privacy model of any Apple framework. Users see exactly which data types you're requesting and can grant or deny each type individually. Unlike most permissions where you get a simple yes/no, with HealthKit you might have read access to heart rate but not sleep data. Your app cannot determine whether authorization was denied or simply not requested—this is intentional privacy protection.

### Requesting Health Permissions

Authorization must be requested before any HealthKit operations. The request is asynchronous and displays a system UI showing exactly what data you're requesting. Best practice is to request permissions at the moment they're needed (e.g., when user enables biometric features) rather than at app launch.

**What we're doing:** Getting permission to read health data. HealthKit is strict about privacy, and the user sees every data type you request.

```swift
import HealthKit

class HealthKitManager {
    let healthStore = HKHealthStore()

    // Types we want to read
    let readTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned),
        HKCategoryType(.sleepAnalysis),
        HKWorkoutType.workoutType()
    ]

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(
            toShare: [],  // We only read, not write
            read: readTypes
        )
    }

    func checkAuthorizationStatus() -> Bool {
        // Note: Can only check for types we requested
        let heartRateType = HKQuantityType(.heartRate)
        let status = healthStore.authorizationStatus(for: heartRateType)
        return status == .sharingAuthorized
    }
}

enum HealthKitError: Error {
    case notAvailable
    case notAuthorized
    case noData
}
```

**Info.plist requirements:**
```xml
<key>NSHealthShareUsageDescription</key>
<string>AI DJ reads your heart rate and HRV to select music that matches your current state.</string>
```

---

## 8.2 Reading Health Data

### Querying Recent Samples

**What we're doing:** Fetching the most recent health measurements.

```swift
extension HealthKitManager {
    // Get most recent heart rate
    func fetchLatestHeartRate() async throws -> Double {
        let heartRateType = HKQuantityType(.heartRate)

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            // Handled via continuation below
        }

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(throwing: HealthKitError.noData)
                    return
                }

                let bpm = sample.quantity.doubleValue(
                    for: HKUnit.count().unitDivided(by: .minute())
                )
                continuation.resume(returning: bpm)
            }

            healthStore.execute(query)
        }
    }

    // Get samples from time range
    func fetchHeartRateSamples(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKQuantitySample] {
        let heartRateType = HKQuantityType(.heartRate)

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                ]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let quantitySamples = samples as? [HKQuantitySample] ?? []
                continuation.resume(returning: quantitySamples)
            }

            healthStore.execute(query)
        }
    }
}
```

---

### Heart Rate Variability (HRV)

**What we're doing:** Reading HRV, which indicates stress vs relaxation.

```swift
extension HealthKitManager {
    func fetchLatestHRV() async throws -> Double {
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                ]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(throwing: HealthKitError.noData)
                    return
                }

                // HRV is in milliseconds
                let hrv = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: hrv)
            }

            healthStore.execute(query)
        }
    }

    // Interpret HRV value
    func interpretHRV(_ hrv: Double) -> StressLevel {
        // Higher HRV = more relaxed
        // These thresholds vary by individual
        switch hrv {
        case 0..<20:
            return .high      // Very stressed
        case 20..<40:
            return .moderate  // Somewhat stressed
        case 40..<70:
            return .low       // Relaxed
        default:
            return .veryLow   // Very relaxed
        }
    }
}
```

---

## 8.3 Real-Time Monitoring

HealthKit provides two primary query types for monitoring changes: **HKObserverQuery** and **HKAnchoredObjectQuery**. Understanding their differences is crucial for building an efficient health monitoring system.

According to [Apple's documentation](https://developer.apple.com/documentation/healthkit/hkobserverquery) and [developer analysis](https://dmtopolog.com/healthkit-changes-observing/):

| Feature | HKObserverQuery | HKAnchoredObjectQuery |
|---------|-----------------|----------------------|
| Notifies of changes | ✅ | ✅ |
| Returns actual data | ❌ (notification only) | ✅ (includes samples) |
| Tracks additions & deletions | ❌ | ✅ |
| Background delivery | ✅ | ❌ |
| Uses anchors to track position | ❌ | ✅ |

**The typical pattern**: Use HKObserverQuery with background delivery to wake your app when changes occur in the background. Use HKAnchoredObjectQuery for foreground monitoring because it returns actual data and tracks your position in the stream via anchors.

### Observer Queries

HKObserverQuery is a "wake up call"—it notifies you that something changed but doesn't tell you what. You must run a separate query to get the actual data. Its main advantage is **background delivery**: iOS can wake your app when new data arrives, even if your app isn't running.

One important caveat from [developer forums](https://developer.apple.com/forums/thread/22012): the observer callback may fire more frequently than actual data changes. It's triggered when your app comes to foreground regardless of whether data changed. Don't assume new data exists just because the callback fired.

**What we're doing:** Setting up a notification system that alerts us when new health data is recorded, allowing us to then fetch the latest values.

```swift
extension HealthKitManager {
    private var observerQuery: HKObserverQuery?

    func startMonitoringHeartRate(
        handler: @escaping (Double) -> Void
    ) {
        let heartRateType = HKQuantityType(.heartRate)

        let query = HKObserverQuery(
            sampleType: heartRateType,
            predicate: nil
        ) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }

            // Fetch the latest sample when notified
            Task {
                if let rate = try? await self?.fetchLatestHeartRate() {
                    await MainActor.run {
                        handler(rate)
                    }
                }
                completionHandler()
            }
        }

        observerQuery = query
        healthStore.execute(query)
    }

    func stopMonitoringHeartRate() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
    }
}
```

---

### Anchored Object Queries

HKAnchoredObjectQuery is the more powerful query for real-time monitoring. As explained by [DevFright's tutorial](https://www.devfright.com/how-to-use-healthkit-hkanchoredobjectquery/), it provides several advantages:

1. **Returns actual samples** - No need for a second query
2. **Tracks position with anchors** - Only returns new samples since your last check
3. **Reports deletions** - Know when samples are removed (rare but important)
4. **Continuous monitoring** - With `updateHandler`, it becomes a long-running query

The anchor mechanism works like a bookmark in the HealthKit database. When you first query, pass `nil` for the anchor to get all matching samples. HealthKit returns the samples plus a new anchor. Save this anchor and pass it to subsequent queries to receive only samples added since that point. This is extremely efficient for streaming data.

**Limitation**: Anchored queries only run while your app is active. For background delivery, you must use HKObserverQuery to wake the app, then run an anchored query to fetch the actual changes.

**What we're doing:** Setting up efficient, incremental data fetching that only returns samples we haven't seen yet. The anchor tracks our position in the data stream.

```swift
class HeartRateMonitor {
    private let healthStore = HKHealthStore()
    private var anchor: HKQueryAnchor?  // Saves our position in the data stream
    private var query: HKAnchoredObjectQuery?

    var onNewSamples: (([Double]) -> Void)?

    func startMonitoring() {
        let heartRateType = HKQuantityType(.heartRate)

        // Pass our saved anchor, or nil for first query
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deleted, newAnchor, error in
            self?.handleNewSamples(samples, newAnchor: newAnchor)
        }

        // This handler is called for subsequent updates
        query.updateHandler = { [weak self] query, samples, deleted, newAnchor, error in
            self?.handleNewSamples(samples, newAnchor: newAnchor)
        }

        self.query = query
        healthStore.execute(query)
    }

    private func handleNewSamples(_ samples: [HKSample]?, newAnchor: HKQueryAnchor?) {
        guard let samples = samples as? [HKQuantitySample] else { return }

        // Save anchor for next query
        anchor = newAnchor

        // Convert to BPM values
        let rates = samples.map { sample in
            sample.quantity.doubleValue(for: .beatsPerMinute())
        }

        if !rates.isEmpty {
            onNewSamples?(rates)
        }
    }

    func stopMonitoring() {
        if let query = query {
            healthStore.stop(query)
        }
    }
}
```

---

## 8.4 AI DJ HealthKit Service

### Complete Integration

```swift
class AIDJHealthService: ObservableObject {
    private let healthStore = HKHealthStore()
    private var heartRateMonitor: HeartRateMonitor?
    private var cancellables = Set<AnyCancellable>()

    @Published var currentHeartRate: Double = 0
    @Published var currentHRV: Double = 0
    @Published var isMonitoring = false

    // Subjects for reactive streams
    let heartRateSubject = PassthroughSubject<Double, Never>()
    let hrvSubject = PassthroughSubject<Double, Never>()

    // MARK: - Authorization

    func requestAuthorization() async throws {
        let types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKWorkoutType.workoutType()
        ]

        try await healthStore.requestAuthorization(toShare: [], read: types)
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }

        let monitor = HeartRateMonitor()

        monitor.onNewSamples = { [weak self] rates in
            guard let latest = rates.last else { return }

            Task { @MainActor in
                self?.currentHeartRate = latest
                self?.heartRateSubject.send(latest)
            }
        }

        monitor.startMonitoring()
        heartRateMonitor = monitor
        isMonitoring = true

        // Also poll HRV periodically (updated less frequently)
        startHRVPolling()
    }

    private func startHRVPolling() {
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.fetchLatestHRV()
                }
            }
            .store(in: &cancellables)
    }

    private func fetchLatestHRV() async {
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)

        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let hrv = sample.quantity.doubleValue(for: .secondUnit(with: .milli))

            Task { @MainActor in
                self?.currentHRV = hrv
                self?.hrvSubject.send(hrv)
            }
        }

        healthStore.execute(query)
    }

    func stopMonitoring() {
        heartRateMonitor?.stopMonitoring()
        heartRateMonitor = nil
        isMonitoring = false
        cancellables.removeAll()
    }

    // MARK: - Historical Data

    func fetchBaseline() async throws -> UserBaseline {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        // Fetch resting heart rate samples (during sleep/rest periods)
        let restingHR = try await fetchRestingHeartRate(since: oneWeekAgo)

        // Fetch HRV history
        let hrvHistory = try await fetchHRVHistory(since: oneWeekAgo)

        return UserBaseline(
            restingHeartRate: restingHR,
            averageHRV: hrvHistory.reduce(0, +) / Double(hrvHistory.count),
            hrvRange: (hrvHistory.min() ?? 0, hrvHistory.max() ?? 100)
        )
    }

    private func fetchRestingHeartRate(since date: Date) async throws -> Double {
        // Query heart rate during typical sleep hours (midnight to 6am)
        // This approximates resting heart rate
        // Implementation similar to fetchHeartRateSamples with time filtering
        return 65.0  // Placeholder
    }

    private func fetchHRVHistory(since date: Date) async throws -> [Double] {
        // Similar query pattern for HRV samples
        return [45, 50, 42, 55, 48]  // Placeholder
    }
}

struct UserBaseline {
    let restingHeartRate: Double
    let averageHRV: Double
    let hrvRange: (min: Double, max: Double)

    // Is current state elevated compared to baseline?
    func isElevated(currentHR: Double) -> Bool {
        currentHR > restingHeartRate * 1.3  // 30% above resting
    }

    // Is current HRV indicating stress?
    func isStressed(currentHRV: Double) -> Bool {
        currentHRV < averageHRV * 0.7  // 30% below average
    }
}
```

---

## Key Takeaways - HealthKit

1. **Always check availability** - `HKHealthStore.isHealthDataAvailable()`
2. **Request only what you need** - Users see every type you request
3. **Use anchored queries for streaming** - Efficient, only gets new samples
4. **HRV indicates stress** - Low HRV = stressed, High HRV = relaxed
5. **Build baselines from history** - Personalized thresholds are more accurate
6. **Handle authorization denial gracefully** - App should work without health data

---

# 9. WATCHOS DEVELOPMENT

## Why This Matters for AI DJ

Apple Watch is where the biometric magic happens. The Watch has the sensors (heart rate, accelerometer) and sits on the user's wrist all day. For AI DJ, the Watch app collects real-time biometrics and sends them to iPhone. It can also display Now Playing info and quick controls. Understanding watchOS development means building a seamless experience where the Watch is the sensor and the iPhone is the brain.

**In AI DJ, the Watch app will:**
- Continuously read heart rate and HRV
- Send biometric data to iPhone via WatchConnectivity
- Display current song and biometric status
- Provide quick controls (skip, pause)

---

## 9.1 watchOS Project Setup

### Creating a Watch App

**What we're doing:** Adding a watchOS target to the existing iOS project.

```
In Xcode:
1. File → New → Target
2. Choose "watchOS" → "App"
3. Name it "AIDJ Watch App"
4. Ensure "Watch App for Existing iOS App" is selected
5. Click Finish

This creates:
AIDJ Watch App/
├── AIDJWatchApp.swift     (App entry point)
├── ContentView.swift       (Main view)
├── Assets.xcassets        (Watch-specific assets)
└── Info.plist
```

**What happens:** Xcode creates a watchOS target that's paired with your iOS app. The Watch app and iOS app share a bundle identifier prefix.

---

### watchOS SwiftUI Differences

**What we're doing:** Understanding how SwiftUI differs on Watch.

```swift
import SwiftUI

struct WatchNowPlayingView: View {
    @StateObject private var viewModel = WatchViewModel()

    var body: some View {
        // NavigationStack instead of NavigationView
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Smaller, more compact layouts
                    HeartRateGauge(rate: viewModel.heartRate)
                        .frame(height: 80)

                    Text(viewModel.currentSong?.title ?? "Not Playing")
                        .font(.headline)
                        .lineLimit(2)

                    // Digital Crown for volume
                    Slider(value: $viewModel.volume)
                        .focusable()  // Enables Digital Crown

                    // Compact controls
                    HStack {
                        Button(action: viewModel.previousTrack) {
                            Image(systemName: "backward.fill")
                        }

                        Button(action: viewModel.togglePlayback) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: viewModel.nextTrack) {
                            Image(systemName: "forward.fill")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("AI DJ")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Custom gauge for heart rate
struct HeartRateGauge: View {
    let rate: Double

    var body: some View {
        Gauge(value: rate, in: 40...180) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
        } currentValueLabel: {
            Text("\(Int(rate))")
                .font(.system(.title, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(rate > 100 ? .red : .green)
    }
}
```

**Watch-specific considerations:**
- Smaller screen (40-49mm diagonal)
- Limited memory (~32MB for apps)
- Digital Crown for scrolling and input
- No keyboard—use voice or gestures
- Brief interactions—users glance, not stare

---

## 9.2 HealthKit on watchOS

### Direct Sensor Access

**What we're doing:** Reading heart rate directly on Watch (faster than iPhone).

```swift
import HealthKit

class WatchHealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?

    @Published var currentHeartRate: Double = 0
    @Published var currentHRV: Double = 0

    func startHeartRateMonitoring() {
        let heartRateType = HKQuantityType(.heartRate)

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        heartRateQuery = query
        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample],
              let latest = samples.last else { return }

        let rate = latest.quantity.doubleValue(for: .beatsPerMinute())

        Task { @MainActor in
            self.currentHeartRate = rate
        }
    }

    func stopMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
    }
}
```

---

### Workout Sessions

**What we're doing:** Starting a workout session to get continuous heart rate.

```swift
import HealthKit
import WorkoutKit

class WorkoutManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published var heartRate: Double = 0
    @Published var isActive = false

    func startWorkout() async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other  // AI DJ listening session
        configuration.locationType = .indoor

        session = try HKWorkoutSession(
            healthStore: healthStore,
            configuration: configuration
        )
        builder = session?.associatedWorkoutBuilder()

        session?.delegate = self
        builder?.delegate = self

        // Start collecting data
        builder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        let startDate = Date()
        session?.startActivity(with: startDate)
        try await builder?.beginCollection(at: startDate)

        await MainActor.run {
            isActive = true
        }
    }

    func endWorkout() async {
        session?.end()

        do {
            try await builder?.endCollection(at: Date())
            try await builder?.finishWorkout()
        } catch {
            print("Failed to end workout: \(error)")
        }

        await MainActor.run {
            isActive = false
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                       didChangeTo toState: HKWorkoutSessionState,
                       from fromState: HKWorkoutSessionState,
                       date: Date) {
        // Handle state changes
    }

    func workoutSession(_ workoutSession: HKWorkoutSession,
                       didFailWithError error: Error) {
        print("Workout session failed: \(error)")
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                       didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  quantityType == HKQuantityType(.heartRate) else { continue }

            let statistics = workoutBuilder.statistics(for: quantityType)
            let rate = statistics?.mostRecentQuantity()?.doubleValue(for: .beatsPerMinute()) ?? 0

            Task { @MainActor in
                self.heartRate = rate
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events
    }
}
```

**Why workout sessions?** During a workout session, Apple Watch samples heart rate more frequently (every few seconds vs every 5 minutes). For AI DJ, this gives much more responsive data.

---

## 9.3 Watch App Architecture

### Watch View Model

```swift
class WatchViewModel: ObservableObject {
    @Published var currentSong: SongInfo?
    @Published var heartRate: Double = 0
    @Published var hrv: Double = 0
    @Published var isPlaying = false
    @Published var volume: Double = 0.5

    private let healthManager = WatchHealthManager()
    private let connectivityManager = WatchConnectivityManager.shared

    init() {
        setupHealthMonitoring()
        setupConnectivity()
    }

    private func setupHealthMonitoring() {
        // Forward health updates
        healthManager.$currentHeartRate
            .assign(to: &$heartRate)

        healthManager.startHeartRateMonitoring()
    }

    private func setupConnectivity() {
        // Receive song updates from iPhone
        connectivityManager.onSongUpdate = { [weak self] song in
            Task { @MainActor in
                self?.currentSong = song
            }
        }

        // Send health data to iPhone
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.sendBiometricsToPhone()
            }
            .store(in: &cancellables)
    }

    private func sendBiometricsToPhone() {
        let data: [String: Any] = [
            "heartRate": heartRate,
            "hrv": hrv,
            "timestamp": Date().timeIntervalSince1970
        ]
        connectivityManager.send(data)
    }

    func togglePlayback() {
        connectivityManager.sendAction(.togglePlayback)
    }

    func nextTrack() {
        connectivityManager.sendAction(.nextTrack)
    }

    func previousTrack() {
        connectivityManager.sendAction(.previousTrack)
    }

    private var cancellables = Set<AnyCancellable>()
}
```

---

## Key Takeaways - watchOS

1. **Watch is the sensor** - Best place for real-time biometrics
2. **Design for glances** - Small screen, brief interactions
3. **Workout sessions = frequent HR** - Essential for responsive data
4. **Send data to iPhone** - Watch collects, iPhone processes
5. **Conserve battery** - Minimize wake time, batch updates
6. **Use Digital Crown** - Natural input for volume, scrolling

---

# 10. WATCHCONNECTIVITY FRAMEWORK

## Why This Matters for AI DJ

WatchConnectivity is the bridge between Apple Watch and iPhone. The Watch collects biometrics, the iPhone runs the Brain and controls music. WatchConnectivity transfers this data in real-time, handles background delivery, and keeps the two devices in sync even when one is asleep.

**In AI DJ, WatchConnectivity handles:**
- Sending heart rate from Watch to iPhone
- Sending Now Playing info from iPhone to Watch
- Syncing user preferences across devices
- Handling playback control commands from Watch

---

## 10.1 Setup and Activation

### Session Configuration

**What we're doing:** Setting up the communication channel between devices.

```swift
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    private let session = WCSession.default

    @Published var isReachable = false
    @Published var isPaired = false

    override init() {
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    var isSessionActive: Bool {
        session.activationState == .activated
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession,
                activationDidCompleteWith activationState: WCSessionActivationState,
                error: Error?) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isReachable = session.isReachable
        }
    }

    // iOS only - required delegate methods
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle session becoming inactive
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session
        session.activate()
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }
}
```

---

## 10.2 Data Transfer Methods

### Application Context (Latest State)

**What we're doing:** Sending the current state that overwrites previous values.

```swift
extension WatchConnectivityManager {
    // Send current state (overwrites previous)
    func updateContext(_ data: [String: Any]) {
        guard session.activationState == .activated else { return }

        do {
            try session.updateApplicationContext(data)
        } catch {
            print("Failed to update context: \(error)")
        }
    }

    // iPhone sends song info to Watch
    func sendNowPlaying(song: SongInfo) {
        let context: [String: Any] = [
            "songTitle": song.title,
            "artist": song.artist,
            "artworkData": song.artworkData ?? Data(),
            "isPlaying": song.isPlaying
        ]
        updateContext(context)
    }
}

// Receiving on Watch
extension WatchConnectivityManager {
    func session(_ session: WCSession,
                didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let title = applicationContext["songTitle"] as? String,
               let artist = applicationContext["artist"] as? String {
                let song = SongInfo(title: title, artist: artist)
                onSongUpdate?(song)
            }
        }
    }

    var onSongUpdate: ((SongInfo) -> Void)?
}
```

**When to use:** Current state that should always be latest (Now Playing info, user preferences).

---

### Message Sending (Real-time)

**What we're doing:** Sending immediate messages when both devices are reachable.

```swift
extension WatchConnectivityManager {
    // Real-time message (requires reachability)
    func sendMessage(_ message: [String: Any],
                    replyHandler: (([String: Any]) -> Void)? = nil) {
        guard session.isReachable else {
            print("Watch not reachable")
            return
        }

        session.sendMessage(message, replyHandler: replyHandler) { error in
            print("Message failed: \(error)")
        }
    }

    // Watch sends biometrics to iPhone
    func sendBiometrics(heartRate: Double, hrv: Double) {
        let message: [String: Any] = [
            "type": "biometrics",
            "heartRate": heartRate,
            "hrv": hrv,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendMessage(message)
    }

    // Watch sends control command
    func sendAction(_ action: PlaybackAction) {
        let message: [String: Any] = [
            "type": "action",
            "action": action.rawValue
        ]
        sendMessage(message)
    }
}

enum PlaybackAction: String {
    case togglePlayback
    case nextTrack
    case previousTrack
    case like
    case skip
}

// Receiving on iPhone
extension WatchConnectivityManager {
    func session(_ session: WCSession,
                didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            guard let type = message["type"] as? String else { return }

            switch type {
            case "biometrics":
                if let hr = message["heartRate"] as? Double,
                   let hrv = message["hrv"] as? Double {
                    onBiometricsReceived?(hr, hrv)
                }
            case "action":
                if let actionRaw = message["action"] as? String,
                   let action = PlaybackAction(rawValue: actionRaw) {
                    onActionReceived?(action)
                }
            default:
                break
            }
        }
    }

    var onBiometricsReceived: ((Double, Double) -> Void)?
    var onActionReceived: ((PlaybackAction) -> Void)?
}
```

**When to use:** Time-sensitive data (biometrics, playback commands).

---

### User Info Transfer (Queued)

**What we're doing:** Queuing data for background delivery when devices aren't connected.

```swift
extension WatchConnectivityManager {
    // Queue for background delivery
    func queueBiometricBatch(_ samples: [BiometricSample]) {
        let userInfo: [String: Any] = [
            "type": "biometricBatch",
            "samples": samples.map { $0.toDictionary() }
        ]
        session.transferUserInfo(userInfo)
    }
}

struct BiometricSample {
    let heartRate: Double
    let hrv: Double
    let timestamp: Date

    func toDictionary() -> [String: Any] {
        return [
            "heartRate": heartRate,
            "hrv": hrv,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }
}

// Receiving queued data
extension WatchConnectivityManager {
    func session(_ session: WCSession,
                didReceiveUserInfo userInfo: [String: Any]) {
        guard let type = userInfo["type"] as? String,
              type == "biometricBatch",
              let samplesData = userInfo["samples"] as? [[String: Any]] else {
            return
        }

        let samples = samplesData.compactMap { dict -> BiometricSample? in
            guard let hr = dict["heartRate"] as? Double,
                  let hrv = dict["hrv"] as? Double,
                  let ts = dict["timestamp"] as? TimeInterval else {
                return nil
            }
            return BiometricSample(heartRate: hr, hrv: hrv, timestamp: Date(timeIntervalSince1970: ts))
        }

        onBiometricBatchReceived?(samples)
    }

    var onBiometricBatchReceived: (([BiometricSample]) -> Void)?
}
```

**When to use:** Data that must be delivered eventually but not immediately (batch uploads, historical data).

---

## 10.3 Complete AI DJ Connectivity

### iPhone Side

```swift
class iPhoneConnectivityService: ObservableObject {
    private let connectivity = WatchConnectivityManager.shared

    @Published var latestHeartRate: Double = 0
    @Published var latestHRV: Double = 0
    @Published var isWatchConnected = false

    init() {
        setupHandlers()
    }

    private func setupHandlers() {
        connectivity.onBiometricsReceived = { [weak self] hr, hrv in
            Task { @MainActor in
                self?.latestHeartRate = hr
                self?.latestHRV = hrv
            }
        }

        connectivity.onActionReceived = { [weak self] action in
            self?.handlePlaybackAction(action)
        }

        connectivity.$isReachable
            .assign(to: &$isWatchConnected)
    }

    private func handlePlaybackAction(_ action: PlaybackAction) {
        switch action {
        case .togglePlayback:
            MusicPlayerController.shared.togglePlayback()
        case .nextTrack:
            Task { try? await MusicPlayerController.shared.skipToNext() }
        case .previousTrack:
            Task { try? await MusicPlayerController.shared.skipToPrevious() }
        case .like:
            // Record positive feedback
            break
        case .skip:
            // Record skip and advance
            Task { try? await MusicPlayerController.shared.skipToNext() }
        }
    }

    func sendNowPlayingToWatch(song: Song, isPlaying: Bool) {
        let info = SongInfo(
            title: song.title,
            artist: song.artistName,
            isPlaying: isPlaying
        )
        connectivity.sendNowPlaying(song: info)
    }
}
```

### Watch Side

```swift
class WatchConnectivityService: ObservableObject {
    private let connectivity = WatchConnectivityManager.shared
    private var pendingSamples: [BiometricSample] = []

    @Published var currentSong: SongInfo?

    init() {
        connectivity.onSongUpdate = { [weak self] song in
            Task { @MainActor in
                self?.currentSong = song
            }
        }
    }

    func sendBiometrics(heartRate: Double, hrv: Double) {
        if connectivity.isReachable {
            // Send immediately
            connectivity.sendBiometrics(heartRate: heartRate, hrv: hrv)
        } else {
            // Queue for later
            pendingSamples.append(BiometricSample(
                heartRate: heartRate,
                hrv: hrv,
                timestamp: Date()
            ))

            // Batch send when we have enough
            if pendingSamples.count >= 10 {
                connectivity.queueBiometricBatch(pendingSamples)
                pendingSamples.removeAll()
            }
        }
    }

    func sendPlaybackCommand(_ action: PlaybackAction) {
        connectivity.sendAction(action)
    }
}
```

---

## Key Takeaways - WatchConnectivity

1. **Three transfer methods** - Context (latest), Message (real-time), UserInfo (queued)
2. **Check isReachable before messages** - Fall back to queued transfer
3. **Context overwrites** - Use for current state like Now Playing
4. **UserInfo queues** - Use for batched biometrics when disconnected
5. **Handle both directions** - Watch sends biometrics, iPhone sends song info
6. **Activate on both devices** - Session must be active on iPhone and Watch

---

# 11. MACOS DEVELOPMENT (MENU BAR APPS)

## Why This Matters for AI DJ

The macOS menu bar app is a lightweight companion that runs in the background. It provides quick access to AI DJ controls, shows current song info, and can display biometric data synced from iPhone. Menu bar apps are unobtrusive—always available but never in the way.

**In AI DJ, the macOS app will:**
- Show Now Playing in the menu bar
- Display synced heart rate from iPhone/Watch
- Provide quick playback controls
- Run in the background without a Dock icon

---

## 11.1 Menu Bar App Structure

### App Configuration

**What we're doing:** Creating an app that lives in the menu bar instead of the Dock.

```swift
import SwiftUI

@main
struct AIDJMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No WindowGroup - this is a menu bar only app
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }

    private func setupMenuBar() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        // Set up the button
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "AI DJ")
            button.action = #selector(togglePopover)
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView()
        )
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

**Info.plist for menu bar only app:**
```xml
<key>LSUIElement</key>
<true/>
```

This hides the app from the Dock, making it menu bar only.

---

### Menu Bar Content View

```swift
struct MenuBarContentView: View {
    @StateObject private var viewModel = MenuBarViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // Now Playing
            if let song = viewModel.currentSong {
                NowPlayingCard(song: song, isPlaying: viewModel.isPlaying)
            } else {
                Text("Not Playing")
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Biometrics (synced from iPhone)
            if viewModel.hasHealthData {
                HStack {
                    Label("\(Int(viewModel.heartRate)) BPM", systemImage: "heart.fill")
                        .foregroundStyle(.red)
                    Spacer()
                    Label("\(Int(viewModel.hrv)) HRV", systemImage: "waveform.path.ecg")
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }

            Divider()

            // Controls
            HStack(spacing: 20) {
                Button(action: viewModel.previousTrack) {
                    Image(systemName: "backward.fill")
                }

                Button(action: viewModel.togglePlayback) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)

                Button(action: viewModel.nextTrack) {
                    Image(systemName: "forward.fill")
                }
            }

            Divider()

            // Quick actions
            Button("Open AI DJ on iPhone") {
                // This would use Universal Links or Handoff
            }
            .buttonStyle(.link)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.link)
            .foregroundStyle(.red)
        }
        .padding()
        .frame(width: 280)
    }
}

struct NowPlayingCard: View {
    let song: SongInfo
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "music.note")
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}
```

---

## 11.2 Syncing with iPhone

### CloudKit or Custom Sync

**What we're doing:** Receiving Now Playing info from iPhone.

```swift
class MenuBarViewModel: ObservableObject {
    @Published var currentSong: SongInfo?
    @Published var isPlaying = false
    @Published var heartRate: Double = 0
    @Published var hrv: Double = 0
    @Published var hasHealthData = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupCloudKitSync()
    }

    private func setupCloudKitSync() {
        // Listen for iCloud key-value store changes
        NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification
        )
        .sink { [weak self] notification in
            self?.handleCloudUpdate()
        }
        .store(in: &cancellables)

        // Initial load
        handleCloudUpdate()
    }

    private func handleCloudUpdate() {
        let store = NSUbiquitousKeyValueStore.default

        if let title = store.string(forKey: "nowPlayingTitle"),
           let artist = store.string(forKey: "nowPlayingArtist") {
            currentSong = SongInfo(title: title, artist: artist)
        }

        isPlaying = store.bool(forKey: "isPlaying")
        heartRate = store.double(forKey: "heartRate")
        hrv = store.double(forKey: "hrv")
        hasHealthData = heartRate > 0
    }

    // Controls send commands back to iPhone
    func togglePlayback() {
        // Use iCloud or push notification to trigger iPhone
        let store = NSUbiquitousKeyValueStore.default
        store.set("togglePlayback", forKey: "pendingCommand")
        store.synchronize()
    }

    func nextTrack() {
        let store = NSUbiquitousKeyValueStore.default
        store.set("nextTrack", forKey: "pendingCommand")
        store.synchronize()
    }

    func previousTrack() {
        let store = NSUbiquitousKeyValueStore.default
        store.set("previousTrack", forKey: "pendingCommand")
        store.synchronize()
    }
}
```

---

## 11.3 macOS-Specific Considerations

### Keyboard Shortcuts

```swift
extension AppDelegate {
    func setupGlobalHotkeys() {
        // Note: Requires accessibility permissions for global hotkeys
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // Command + Shift + P to toggle playback
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 35 {
                self.togglePlayback()
            }
        }
    }

    private func togglePlayback() {
        // Send to view model
    }
}
```

### Menu Bar Icon Updates

```swift
extension AppDelegate {
    func updateMenuBarIcon(isPlaying: Bool, heartRate: Double?) {
        guard let button = statusItem.button else { return }

        if isPlaying {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Playing")

            // Optionally show heart rate in menu bar
            if let hr = heartRate {
                button.title = " \(Int(hr))"
            }
        } else {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Paused")
            button.title = ""
        }
    }
}
```

---

## Key Takeaways - macOS Menu Bar

1. **LSUIElement = true** - Hides from Dock, menu bar only
2. **NSStatusItem** - Creates the menu bar icon
3. **NSPopover** - Shows content when clicking menu bar item
4. **Sync via iCloud** - NSUbiquitousKeyValueStore for simple sync
5. **No window needed** - Settings scene for preferences
6. **Lightweight** - Menu bar apps should be minimal

---

# 12. BACKGROUND PROCESSING & APP LIFECYCLE

## Why This Matters for AI DJ

Music apps need to keep playing when the user switches to other apps. AI DJ also needs to continue monitoring health data and updating song selection in the background. Understanding the iOS app lifecycle and background modes is essential for a seamless experience.

**In AI DJ, background processing handles:**
- Continuing music playback when app is backgrounded
- Receiving HealthKit updates in the background
- Periodic data sync between devices
- Processing biometric data while screen is off

---

## 12.1 App Lifecycle

### SwiftUI App Lifecycle

**What we're doing:** Responding to app state changes.

```swift
@main
struct AIDJApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // App is in foreground
                handleBecameActive()
            case .inactive:
                // App is transitioning (between active and background)
                handleBecameInactive()
            case .background:
                // App is in background
                handleEnteredBackground()
            @unknown default:
                break
            }
        }
    }

    private func handleBecameActive() {
        // Resume health monitoring
        HealthService.shared.startMonitoring()
        // Refresh now playing state
        MusicService.shared.syncState()
    }

    private func handleBecameInactive() {
        // Prepare for possible background
        DataManager.shared.saveState()
    }

    private func handleEnteredBackground() {
        // Schedule background tasks
        BackgroundTaskManager.shared.scheduleRefresh()
    }
}
```

---

### Scene Phase States

```
┌─────────────────────────────────────────────────────────┐
│                    App Lifecycle                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  .active ◄──────────► .inactive ◄──────────► .background │
│    │                      │                      │       │
│    │ User is              │ Transitioning        │ User  │
│    │ interacting          │ (call coming,        │ left  │
│    │                      │  control center)     │ app   │
│                                                          │
│  Full UI      │        Limited        │      Suspended   │
│  Unlimited    │        Short tasks    │      Frozen      │
│  resources    │        allowed        │      state       │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 12.2 Background Modes

### Enabling Background Capabilities

**What we're doing:** Declaring which background modes the app uses.

In Xcode: Target → Signing & Capabilities → + Capability → Background Modes

**Background modes for AI DJ:**
- [x] Audio, AirPlay, and Picture in Picture (music playback)
- [x] Background fetch (periodic data refresh)
- [x] Background processing (long tasks)
- [x] Remote notifications (push-triggered updates)

---

### Audio Background Mode

**What we're doing:** Keeping music playing when app is backgrounded.

```swift
import AVFoundation

class AudioSessionManager {
    static let shared = AudioSessionManager()

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowAirPlay]
            )
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
}
```

**What happens:** With `.playback` category and audio background mode enabled, music continues when the app is backgrounded.

---

### Background Tasks (BGTaskScheduler)

**What we're doing:** Scheduling work to run periodically in the background.

```swift
import BackgroundTasks

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    private let refreshTaskIdentifier = "com.aidj.refresh"
    private let processingTaskIdentifier = "com.aidj.processing"

    func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleRefreshTask(task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: processingTaskIdentifier,
            using: nil
        ) { task in
            self.handleProcessingTask(task as! BGProcessingTask)
        }
    }

    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule refresh: \(error)")
        }
    }

    func scheduleProcessing() {
        let request = BGProcessingTaskRequest(identifier: processingTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule processing: \(error)")
        }
    }

    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleRefresh()

        // Create a task to do the work
        let refreshOperation = Task {
            do {
                // Sync data from Watch
                await WatchConnectivityManager.shared.syncPendingData()

                // Update song recommendations
                await RecommendationEngine.shared.refresh()

                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        // Handle cancellation
        task.expirationHandler = {
            refreshOperation.cancel()
        }
    }

    private func handleProcessingTask(_ task: BGProcessingTask) {
        // Long-running background work
        let processingOperation = Task {
            // Analyze historical data for improved recommendations
            await DataAnalyzer.shared.analyzeHistory()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            processingOperation.cancel()
        }
    }
}
```

**Info.plist:**
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.aidj.refresh</string>
    <string>com.aidj.processing</string>
</array>
```

---

## 12.3 HealthKit Background Delivery

### Receiving Health Updates in Background

**What we're doing:** Getting notified when new health data is recorded.

```swift
extension HealthKitManager {
    func enableBackgroundDelivery() {
        let heartRateType = HKQuantityType(.heartRate)

        healthStore.enableBackgroundDelivery(
            for: heartRateType,
            frequency: .immediate
        ) { success, error in
            if success {
                print("Background delivery enabled for heart rate")
            } else if let error = error {
                print("Failed to enable background delivery: \(error)")
            }
        }
    }

    func setupBackgroundObserver() {
        let heartRateType = HKQuantityType(.heartRate)

        let query = HKObserverQuery(
            sampleType: heartRateType,
            predicate: nil
        ) { [weak self] query, completionHandler, error in
            // Called when new heart rate samples are recorded
            Task {
                if let rate = try? await self?.fetchLatestHeartRate() {
                    await self?.processBackgroundHeartRate(rate)
                }
            }

            // Must call completion handler
            completionHandler()
        }

        healthStore.execute(query)
    }

    private func processBackgroundHeartRate(_ rate: Double) async {
        // Send to Watch Connectivity
        WatchConnectivityManager.shared.updateContext([
            "latestHeartRate": rate,
            "timestamp": Date().timeIntervalSince1970
        ])

        // Maybe trigger song change if significant
        if rate > 120 {
            // User's heart rate elevated - might need calmer music
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .heartRateElevated,
                    object: nil,
                    userInfo: ["heartRate": rate]
                )
            }
        }
    }
}

extension Notification.Name {
    static let heartRateElevated = Notification.Name("heartRateElevated")
}
```

---

## Key Takeaways - Background Processing

1. **Audio mode keeps music playing** - Essential for any music app
2. **BGTaskScheduler for periodic work** - Register tasks at app launch
3. **HealthKit background delivery** - Get notified of new health data
4. **Handle expiration** - Always implement expirationHandler
5. **Scene phase for lifecycle** - .active, .inactive, .background
6. **Save state on background** - User might not return for hours

---

# 13. WIDGETS & COMPLICATIONS

## Why This Matters for AI DJ

Widgets bring AI DJ to the home screen and lock screen. A glance at the widget shows what's playing and current biometrics. Watch complications do the same on the wrist. These aren't interactive apps—they're snapshots that update periodically to keep the user informed.

**In AI DJ, widgets and complications show:**
- Current song and artist
- Heart rate and stress level
- Music mood/recommendation
- Quick launch into the app

---

## 13.1 iOS Widgets (WidgetKit)

### Widget Structure

**What we're doing:** Creating a widget extension that displays AI DJ info.

```swift
import WidgetKit
import SwiftUI

struct AIDJWidget: Widget {
    let kind: String = "AIDJWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AIDJTimelineProvider()) { entry in
            AIDJWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("AI DJ")
        .description("Shows what's playing and your current state")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
```

---

### Timeline Provider

**What we're doing:** Providing snapshots and timeline entries for the widget.

```swift
struct AIDJTimelineProvider: TimelineProvider {
    typealias Entry = AIDJWidgetEntry

    // Placeholder shown while loading
    func placeholder(in context: Context) -> AIDJWidgetEntry {
        AIDJWidgetEntry(
            date: Date(),
            songTitle: "AI DJ",
            artist: "Select a song",
            heartRate: 72,
            mood: .neutral
        )
    }

    // Quick snapshot for widget gallery
    func getSnapshot(in context: Context, completion: @escaping (AIDJWidgetEntry) -> Void) {
        let entry = AIDJWidgetEntry(
            date: Date(),
            songTitle: "Calm Waves",
            artist: "Relaxation Artist",
            heartRate: 68,
            mood: .calm
        )
        completion(entry)
    }

    // Timeline of entries
    func getTimeline(in context: Context, completion: @escaping (Timeline<AIDJWidgetEntry>) -> Void) {
        // Read from shared container (App Groups)
        let sharedDefaults = UserDefaults(suiteName: "group.com.aidj.shared")

        let entry = AIDJWidgetEntry(
            date: Date(),
            songTitle: sharedDefaults?.string(forKey: "nowPlayingTitle") ?? "Not Playing",
            artist: sharedDefaults?.string(forKey: "nowPlayingArtist") ?? "",
            heartRate: sharedDefaults?.double(forKey: "heartRate") ?? 0,
            mood: MusicMood(rawValue: sharedDefaults?.string(forKey: "mood") ?? "") ?? .neutral
        )

        // Refresh in 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}

struct AIDJWidgetEntry: TimelineEntry {
    let date: Date
    let songTitle: String
    let artist: String
    let heartRate: Double
    let mood: MusicMood
}
```

---

### Widget Views

```swift
struct AIDJWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: AIDJTimelineProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: AIDJWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundStyle(entry.mood.color)
                Spacer()
                if entry.heartRate > 0 {
                    Label("\(Int(entry.heartRate))", systemImage: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Text(entry.songTitle)
                .font(.headline)
                .lineLimit(2)

            Text(entry.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let entry: AIDJWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(entry.mood.color.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundStyle(entry.mood.color)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.songTitle)
                    .font(.headline)
                    .lineLimit(2)

                Text(entry.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack {
                    Label("\(Int(entry.heartRate)) BPM", systemImage: "heart.fill")
                        .foregroundStyle(.red)

                    Spacer()

                    Text(entry.mood.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(entry.mood.color.opacity(0.2))
                        .clipShape(Capsule())
                }
                .font(.caption)
            }
        }
        .padding()
    }
}

// Lock screen widget
struct CircularWidgetView: View {
    let entry: AIDJWidgetEntry

    var body: some View {
        Gauge(value: entry.heartRate, in: 40...180) {
            Image(systemName: "heart.fill")
        } currentValueLabel: {
            Text("\(Int(entry.heartRate))")
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct RectangularWidgetView: View {
    let entry: AIDJWidgetEntry

    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.songTitle)
                .font(.headline)
                .lineLimit(1)
            Text(entry.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

---

### Updating Widgets from Main App

```swift
// In main app, when song changes
func updateWidget() {
    // Write to shared container
    let sharedDefaults = UserDefaults(suiteName: "group.com.aidj.shared")
    sharedDefaults?.set(currentSong.title, forKey: "nowPlayingTitle")
    sharedDefaults?.set(currentSong.artist, forKey: "nowPlayingArtist")
    sharedDefaults?.set(currentHeartRate, forKey: "heartRate")
    sharedDefaults?.set(currentMood.rawValue, forKey: "mood")

    // Tell WidgetKit to refresh
    WidgetCenter.shared.reloadAllTimelines()
}
```

---

## 13.2 Watch Complications

### ClockKit Complications

**What we're doing:** Displaying AI DJ info on the Watch face.

```swift
import ClockKit
import SwiftUI

class ComplicationController: NSObject, CLKComplicationDataSource {

    // Current data
    func currentTimelineEntry(
        for complication: CLKComplication
    ) async -> CLKComplicationTimelineEntry? {
        let template = makeTemplate(for: complication.family)
        return CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
    }

    // Placeholder
    func getLocalizableSampleTemplate(
        for complication: CLKComplication
    ) async -> CLKComplicationTemplate? {
        return makeTemplate(for: complication.family)
    }

    private func makeTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate {
        // Get data from shared storage
        let heartRate = UserDefaults.standard.double(forKey: "heartRate")
        let songTitle = UserDefaults.standard.string(forKey: "songTitle") ?? "AI DJ"

        switch family {
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "heart.fill")!)
            )

        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularView(
                ComplicationCircularView(heartRate: heartRate)
            )

        case .graphicRectangular:
            return CLKComplicationTemplateGraphicRectangularFullView(
                ComplicationRectangularView(songTitle: songTitle, heartRate: heartRate)
            )

        default:
            return CLKComplicationTemplateCircularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "music.note")!)
            )
        }
    }
}

struct ComplicationCircularView: View {
    let heartRate: Double

    var body: some View {
        Gauge(value: heartRate, in: 40...180) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct ComplicationRectangularView: View {
    let songTitle: String
    let heartRate: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(songTitle)
                    .font(.headline)
                Text("\(Int(heartRate)) BPM")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Spacer()
        }
    }
}
```

---

## Key Takeaways - Widgets & Complications

1. **Widgets are snapshots** - Not interactive apps, just views
2. **Timeline provider gives entries** - WidgetKit calls for updates
3. **Use App Groups for shared data** - Main app writes, widget reads
4. **Call reloadAllTimelines()** - When data changes in main app
5. **Support multiple families** - Small, medium, lock screen
6. **Complications use ClockKit** - Similar concept for Watch faces

---

# 14. BIOMETRICS & SIGNAL PROCESSING

## Why This Matters for AI DJ

Raw heart rate and HRV numbers are just data—meaningless without interpretation. A heart rate of 90 BPM might be "elevated" for one person but "resting" for another. To make intelligent music decisions, AI DJ must transform raw sensor readings into meaningful user state classifications, and this requires understanding both the physiology behind the numbers and the mathematics of signal processing.

This section covers two interconnected domains: **biometrics** (the science of what heart rate and HRV actually mean physiologically) and **signal processing** (the mathematical techniques for cleaning noisy data, detecting trends, and making reliable classifications). These concepts draw on resources like the [Elite HRV Knowledge Base](https://elitehrv.com/what-is-heart-rate-variability) for physiological understanding and [Khan Academy's Statistics courses](https://www.khanacademy.org/math/statistics-probability) for the mathematical foundations.

**In AI DJ, biometric processing includes:**
- Establishing personal baselines (critical for accurate interpretation)
- Smoothing noisy sensor data (removing random fluctuations)
- Detecting trends and anomalies (is the user calming down or getting more stressed?)
- Classifying user states (mapping numbers to actionable categories)

---

## 14.1 Heart Rate Fundamentals

Heart rate is the number of times your heart beats per minute (BPM). It's controlled by the autonomic nervous system (ANS), which has two branches: the **sympathetic** (fight-or-flight, increases HR) and **parasympathetic** (rest-and-digest, decreases HR). Understanding this is key to AI DJ's logic: when someone is stressed, their sympathetic system is activated, raising heart rate. Calming music may help activate the parasympathetic response.

**Key physiological facts:**
- **Resting heart rate**: 60-100 BPM for most adults; athletes may be 40-60 BPM
- **Maximum heart rate**: Roughly 220 minus age (e.g., 190 BPM for a 30-year-old)
- **Response time**: Heart rate changes within seconds of stimulus changes
- **Individual variation**: What's "high" for one person is "normal" for another—baselines are essential

### Understanding Heart Rate

Population averages are useful starting points, but personalized baselines are far more accurate. A trained athlete with a resting HR of 50 BPM is in a very different state at 90 BPM (80% elevation) than an untrained person with resting HR of 75 BPM at the same 90 BPM (only 20% elevation). AI DJ should classify based on deviation from personal baseline, not absolute values.

**What we're doing:** Building a classification system that interprets heart rate relative to a user's personal baseline rather than using absolute thresholds.

```swift
struct HeartRateAnalyzer {
    // Population averages (will be personalized)
    struct Baselines {
        static let restingHR: ClosedRange<Double> = 60...100
        static let athleteRestingHR: ClosedRange<Double> = 40...60
        static let elevatedHR: Double = 100
        static let maxHR: (age: Int) -> Double = { age in Double(220 - age) }
    }

    // Interpret a single reading
    func classify(_ heartRate: Double, baseline: Double) -> HeartRateZone {
        let percentOfBaseline = heartRate / baseline

        switch percentOfBaseline {
        case ..<0.9:
            return .belowBaseline  // Very relaxed or cold
        case 0.9..<1.1:
            return .baseline       // Normal resting
        case 1.1..<1.3:
            return .slightlyElevated  // Light activity or mild stress
        case 1.3..<1.6:
            return .elevated       // Moderate activity or stress
        case 1.6..<1.8:
            return .high           // Intense activity or high stress
        default:
            return .veryHigh       // Near max HR
        }
    }
}

enum HeartRateZone: String {
    case belowBaseline = "Below Baseline"
    case baseline = "Baseline"
    case slightlyElevated = "Slightly Elevated"
    case elevated = "Elevated"
    case high = "High"
    case veryHigh = "Very High"

    var suggestedMusicEnergy: Double {
        switch self {
        case .belowBaseline: return 0.4    // Gentle, can energize slightly
        case .baseline: return 0.5          // Neutral
        case .slightlyElevated: return 0.5  // Maintain
        case .elevated: return 0.3          // Start calming
        case .high: return 0.2              // Strongly calming
        case .veryHigh: return 0.1          // Very calming
        }
    }
}
```

---

### Heart Rate Variability (HRV)

Heart Rate Variability is arguably the most valuable biometric for AI DJ because it directly reflects the balance between sympathetic (stress) and parasympathetic (relaxation) nervous system activity. Unlike heart rate, which can be elevated by both physical exercise and psychological stress, HRV specifically reflects **autonomic balance**—making it excellent for detecting mental/emotional stress.

**The science explained:**
Your heart doesn't beat like a metronome. Even at rest, there's natural variation in the time between beats (the "RR intervals"). A healthy, relaxed nervous system produces **high variability**—the parasympathetic system modulates heart rate breath-by-breath. When stressed, the sympathetic system dominates with steady adrenaline output, producing **low variability**—the heart beats more mechanically.

**SDNN** (Standard Deviation of NN intervals) is the HRV metric Apple Watch reports. It's the standard deviation of the time intervals between normal heartbeats, measured in milliseconds. Typical values range from 20-80ms, though this varies dramatically by age, fitness, and individual physiology.

**Critical insight**: HRV is even more individual than heart rate. An HRV of 40ms might indicate relaxation for one person and stress for another. Personal baselines are essential, and we use z-scores (standard deviations from personal mean) for classification.

**What we're doing:** Classifying stress levels based on how the current HRV reading compares to the user's personal baseline using statistical z-scores.

```swift
struct HRVAnalyzer {
    /*
    HRV = variation in time between heartbeats
    Higher HRV = more adaptable nervous system = relaxed
    Lower HRV = less variation = stressed or fatigued

    Apple Watch reports SDNN (standard deviation of NN intervals)
    Typical values: 20-80 ms

    We use z-scores for classification:
    z = (current - mean) / stdDev
    Positive z = above average (more relaxed than usual)
    Negative z = below average (more stressed than usual)
    */

    // HRV is highly individual - must establish baseline
    func establishBaseline(from samples: [Double]) -> HRVBaseline {
        guard !samples.isEmpty else {
            return HRVBaseline(mean: 50, stdDev: 15) // Population default
        }

        let mean = samples.reduce(0, +) / Double(samples.count)

        let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count)
        let stdDev = sqrt(variance)

        return HRVBaseline(mean: mean, stdDev: stdDev)
    }

    func classify(_ hrv: Double, baseline: HRVBaseline) -> StressLevel {
        let zScore = (hrv - baseline.mean) / baseline.stdDev

        switch zScore {
        case 1...:
            return .veryLow     // HRV above average = very relaxed
        case 0..<1:
            return .low         // HRV slightly above average = relaxed
        case -1..<0:
            return .moderate    // HRV slightly below = mild stress
        case -2..<(-1):
            return .high        // HRV well below = stressed
        default:
            return .veryHigh    // HRV very low = very stressed or fatigued
        }
    }
}

struct HRVBaseline {
    let mean: Double
    let stdDev: Double
}

enum StressLevel: String {
    case veryLow = "Very Relaxed"
    case low = "Relaxed"
    case moderate = "Moderate"
    case high = "Stressed"
    case veryHigh = "Very Stressed"

    var needsCalming: Bool {
        self == .high || self == .veryHigh
    }
}
```

---

## 14.2 Signal Processing

Signal processing is the mathematical discipline of extracting useful information from noisy data. Apple Watch sensors are remarkably accurate, but all sensors have some noise—random fluctuations that don't reflect actual physiological changes. Without smoothing, a heart rate stream might jump from 72 to 78 to 71 to 75, making it hard to determine the "true" value or detect genuine trends.

We use two fundamental techniques: **moving averages** (for smoothing) and **linear regression** (for trend detection). These are simple enough to implement efficiently on-device while being powerful enough for our needs.

### Moving Average (Smoothing)

A moving average replaces each data point with the average of itself and its neighbors. This reduces noise while preserving the overall signal shape. There are two common variants:

**Simple Moving Average (SMA)**: Average of the last N values. Easy to understand but gives equal weight to all values in the window, and older readings affect the result as much as recent ones.

**Exponential Moving Average (EMA)**: Weighted average where recent values have exponentially more influence. Controlled by alpha (α), the "smoothing factor." Higher α = more responsive to recent changes but less smoothing. Lower α = smoother but slower to react.

The EMA formula is: `EMA_today = α × value_today + (1-α) × EMA_yesterday`

For heart rate, α = 0.3 works well—responsive enough to detect changes within a few readings, smooth enough to filter single-reading spikes.

**What we're doing:** Removing random noise from sensor readings while preserving genuine physiological changes. This produces cleaner data for trend detection and classification.

```swift
class SignalProcessor {
    // Simple moving average
    func movingAverage(_ values: [Double], windowSize: Int) -> [Double] {
        guard values.count >= windowSize else { return values }

        var result: [Double] = []

        for i in 0...(values.count - windowSize) {
            let window = values[i..<(i + windowSize)]
            let average = window.reduce(0, +) / Double(windowSize)
            result.append(average)
        }

        return result
    }

    // Exponential moving average (weights recent values more)
    func exponentialMovingAverage(_ values: [Double], alpha: Double = 0.3) -> [Double] {
        guard !values.isEmpty else { return [] }

        var result: [Double] = [values[0]]

        for i in 1..<values.count {
            let ema = alpha * values[i] + (1 - alpha) * result[i - 1]
            result.append(ema)
        }

        return result
    }
}
```

---

### Trend Detection

Knowing the current value isn't enough—we need to know the **direction**. Is heart rate rising (indicating increasing stress or activity) or falling (indicating the user is calming down)? This influences song selection: a falling HR might mean the current calming music is working and we should continue the approach, while a rising HR might signal the need for a different strategy.

We implement two trend detection approaches:

**Split-half comparison**: Divide recent samples into "older" and "newer" halves, compare their averages. Simple and robust, but only gives coarse direction (rising/falling/stable).

**Linear regression**: Fit a straight line through the data points and examine the slope. Mathematically rigorous, gives a continuous measure of how fast values are changing. A slope of +2 means "rising by 2 BPM per sample period."

The linear regression formula for slope is:
```
slope = (n×Σxy - Σx×Σy) / (n×Σx² - (Σx)²)
```

Where x is the sample index and y is the value. Positive slope = rising, negative = falling, near-zero = stable.

**What we're doing:** Determining whether biometric values are trending upward, downward, or staying stable. This information helps decide whether current music intervention is working or needs adjustment.

```swift
extension SignalProcessor {
    enum Trend {
        case rising
        case falling
        case stable

        var description: String {
            switch self {
            case .rising: return "↑ Rising"
            case .falling: return "↓ Falling"
            case .stable: return "→ Stable"
            }
        }
    }

    func detectTrend(_ values: [Double], threshold: Double = 0.05) -> Trend {
        guard values.count >= 3 else { return .stable }

        // Compare recent average to older average
        let midpoint = values.count / 2
        let older = Array(values.prefix(midpoint))
        let recent = Array(values.suffix(midpoint))

        let olderAvg = older.reduce(0, +) / Double(older.count)
        let recentAvg = recent.reduce(0, +) / Double(recent.count)

        let percentChange = (recentAvg - olderAvg) / olderAvg

        if percentChange > threshold {
            return .rising
        } else if percentChange < -threshold {
            return .falling
        } else {
            return .stable
        }
    }

    // More sophisticated: linear regression slope
    func linearTrend(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }

        let n = Double(values.count)
        let indices = values.indices.map { Double($0) }

        let sumX = indices.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(indices, values).map { $0 * $1 }.reduce(0, +)
        let sumX2 = indices.map { $0 * $0 }.reduce(0, +)

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)

        return slope  // Positive = rising, Negative = falling
    }
}
```

---

## 14.3 User State Classification

The ultimate goal of biometric processing is to answer a simple question: "What kind of music does this user need right now?" We answer this by combining multiple signals (HR, HRV, trends) into a single **UserState** classification that our scoring algorithm can act on.

### Combining Signals

Neither heart rate nor HRV alone tells the complete story. Consider these scenarios:
- **High HR + Low HRV**: Almost certainly stressed (unless in vigorous workout)
- **High HR + High HRV**: Likely exercising (sympathetic activation but healthy variability)
- **Low HR + Low HRV**: Could be fatigued or ill
- **Low HR + High HRV**: Relaxed and recovered

By combining multiple signals, we can disambiguate scenarios and make more accurate classifications. We also incorporate **trends**—a rising HR is different from a stable high HR, even if the absolute value is the same. Rising suggests the intervention isn't working; stable suggests a steady state.

The classification outputs a **MusicIntervention** recommendation: urgently calming, gently calming, maintaining, or potentially energizing. This feeds directly into the scoring algorithm's weight selection and energy targeting.

**What we're doing:** Fusing heart rate, HRV, and trend information into a unified user state that directly informs music selection strategy.

```swift
struct UserStateClassifier {
    let hrAnalyzer = HeartRateAnalyzer()
    let hrvAnalyzer = HRVAnalyzer()
    let signalProcessor = SignalProcessor()

    func classify(
        heartRateSamples: [Double],
        hrvSamples: [Double],
        hrBaseline: Double,
        hrvBaseline: HRVBaseline
    ) -> UserState {
        // Smooth the data
        let smoothedHR = signalProcessor.exponentialMovingAverage(heartRateSamples)
        let smoothedHRV = signalProcessor.exponentialMovingAverage(hrvSamples)

        // Get current values
        let currentHR = smoothedHR.last ?? hrBaseline
        let currentHRV = smoothedHRV.last ?? hrvBaseline.mean

        // Classify each metric
        let hrZone = hrAnalyzer.classify(currentHR, baseline: hrBaseline)
        let stressLevel = hrvAnalyzer.classify(currentHRV, baseline: hrvBaseline)

        // Detect trends
        let hrTrend = signalProcessor.detectTrend(smoothedHR)
        let hrvTrend = signalProcessor.detectTrend(smoothedHRV)

        // Combine into user state
        return UserState(
            heartRate: currentHR,
            hrv: currentHRV,
            heartRateZone: hrZone,
            stressLevel: stressLevel,
            heartRateTrend: hrTrend,
            hrvTrend: hrvTrend,
            needsIntervention: determineIntervention(hrZone: hrZone, stress: stressLevel, hrTrend: hrTrend)
        )
    }

    private func determineIntervention(
        hrZone: HeartRateZone,
        stress: StressLevel,
        hrTrend: SignalProcessor.Trend
    ) -> MusicIntervention {
        // High stress + elevated HR + rising = urgent calming needed
        if stress.needsCalming && (hrZone == .elevated || hrZone == .high) && hrTrend == .rising {
            return .urgentCalm
        }

        // High stress but stable = gentle calming
        if stress.needsCalming {
            return .gentleCalm
        }

        // Low HR, relaxed state = could energize if desired
        if hrZone == .belowBaseline && stress == .veryLow {
            return .canEnergize
        }

        // Everything normal
        return .maintain
    }
}

struct UserState {
    let heartRate: Double
    let hrv: Double
    let heartRateZone: HeartRateZone
    let stressLevel: StressLevel
    let heartRateTrend: SignalProcessor.Trend
    let hrvTrend: SignalProcessor.Trend
    let needsIntervention: MusicIntervention
}

enum MusicIntervention {
    case urgentCalm     // Play calming music immediately
    case gentleCalm     // Gradually shift to calmer music
    case maintain       // Current music is fine
    case canEnergize    // User is very relaxed, could boost energy

    var targetEnergy: ClosedRange<Double> {
        switch self {
        case .urgentCalm: return 0.0...0.3
        case .gentleCalm: return 0.2...0.5
        case .maintain: return 0.3...0.7
        case .canEnergize: return 0.5...0.9
        }
    }
}
```

---

## Key Takeaways - Biometrics & Signal Processing

1. **Personalized baselines** - Population averages are starting points only
2. **HRV indicates stress** - Lower HRV = more stressed
3. **Smooth noisy data** - Use moving averages to reduce sensor noise
4. **Detect trends** - Rising HR might need intervention before it peaks
5. **Combine signals** - HR + HRV together tell more than either alone
6. **Context matters** - 120 BPM during workout vs rest means different things

---

# 15. ALGORITHM & SCORING SYSTEM DESIGN

## Why This Matters for AI DJ

The scoring algorithm is the brain of AI DJ—the intelligence that transforms raw biometric data into meaningful music selections. Unlike simple rule-based systems ("if heart rate high, play slow music"), a well-designed scoring algorithm can weigh multiple factors simultaneously, learn from user preferences over time, and adapt to different contexts. This is what separates a smart DJ from a random playlist shuffler.

The core challenge in algorithm design is **multi-criteria decision making**: we have multiple factors that matter (BPM match, energy level, user history, recency) and we need to combine them into a single decision about which song to play next. This is a well-studied problem in machine learning and recommendation systems, drawing on techniques from [Google's Feature Engineering course](https://developers.google.com/machine-learning/crash-course/representation/feature-engineering) and [Microsoft's Learning to Rank research](https://www.microsoft.com/en-us/research/project/learning-to-rank/).

**In AI DJ, the scoring system:**
- Ranks songs by fitness for current state using weighted multi-factor scoring
- Balances multiple factors (BPM match, energy, familiarity) with configurable weights
- Explains why a song was selected (transparency for user trust)
- Learns from user feedback over time using reinforcement learning principles
- Handles the exploration-exploitation tradeoff to discover new favorites

---

## 15.1 Scoring Fundamentals

### Multi-Factor Scoring

The heart of AI DJ's intelligence is a **weighted linear combination** of multiple scoring factors. Each factor produces a score between 0 and 1, representing how well a song matches that criterion. These individual scores are then multiplied by weights (also 0 to 1, summing to 1.0) and added together to produce a final composite score.

**The mathematical formula is:**

```
FinalScore = Σ (weight_i × score_i) for all factors i
           = (w_bpm × s_bpm) + (w_energy × s_energy) + (w_stress × s_stress) + ...
```

This approach is powerful because:
1. **Interpretable**: You can explain exactly why a song scored high or low
2. **Tunable**: Adjusting weights changes behavior predictably
3. **Efficient**: O(n) to score n songs, no complex optimization needed
4. **Extensible**: Adding new factors is straightforward

The challenge is **feature engineering**—designing scoring functions that accurately capture what makes a song "good" for a given situation. Each individual score function must:
- Return values consistently in the 0-1 range (normalization)
- Respond appropriately to edge cases (missing data, extreme values)
- Align with human intuition about what "good" means

**What we're doing:** Combining multiple criteria into a single score using a weighted sum, where each factor contributes proportionally to its assigned weight.

```swift
struct SongScorer {
    // Weights for different factors (must sum to 1.0)
    struct Weights {
        var bpmMatch: Double = 0.25
        var energyMatch: Double = 0.30
        var stressResponse: Double = 0.20
        var familiarity: Double = 0.15
        var recency: Double = 0.10

        // Weights can be adjusted based on context
        static let workout = Weights(
            bpmMatch: 0.35,
            energyMatch: 0.35,
            stressResponse: 0.10,
            familiarity: 0.10,
            recency: 0.10
        )

        static let relaxation = Weights(
            bpmMatch: 0.15,
            energyMatch: 0.35,
            stressResponse: 0.30,
            familiarity: 0.15,
            recency: 0.05
        )
    }

    func score(song: Song, state: UserState, history: SongHistory?, weights: Weights) -> ScoredSong {
        var components: [ScoreComponent] = []

        // 1. BPM Match (how close is song BPM to heart rate?)
        let bpmScore = calculateBPMScore(songBPM: song.bpm, heartRate: state.heartRate)
        components.append(ScoreComponent(
            factor: "BPM Match",
            score: bpmScore,
            weight: weights.bpmMatch,
            reason: bpmScore > 0.7 ? "Rhythm matches your heartbeat" : nil
        ))

        // 2. Energy Match (does song energy match what user needs?)
        let energyScore = calculateEnergyScore(
            songEnergy: song.energyLevel,
            intervention: state.needsIntervention
        )
        components.append(ScoreComponent(
            factor: "Energy Match",
            score: energyScore,
            weight: weights.energyMatch,
            reason: energyScore > 0.7 ? describeEnergyMatch(intervention: state.needsIntervention) : nil
        ))

        // 3. Stress Response (has this song helped with stress before?)
        let stressScore = history?.effectivenessForCalming ?? 0.5
        components.append(ScoreComponent(
            factor: "Stress Response",
            score: stressScore,
            weight: weights.stressResponse,
            reason: stressScore > 0.7 ? "Previously helped you relax" : nil
        ))

        // 4. Familiarity (known songs can be comforting)
        let familiarityScore = calculateFamiliarityScore(playCount: history?.playCount ?? 0)
        components.append(ScoreComponent(
            factor: "Familiarity",
            score: familiarityScore,
            weight: weights.familiarity,
            reason: familiarityScore > 0.7 ? "One of your favorites" : nil
        ))

        // 5. Recency penalty (avoid repeating recent songs)
        let recencyScore = calculateRecencyScore(lastPlayed: history?.lastPlayed)
        components.append(ScoreComponent(
            factor: "Freshness",
            score: recencyScore,
            weight: weights.recency,
            reason: nil
        ))

        // Calculate weighted total
        let totalScore = components.reduce(0.0) { sum, component in
            sum + (component.score * component.weight)
        }

        // Collect non-nil reasons
        let reasons = components.compactMap { $0.reason }

        return ScoredSong(
            song: song,
            score: totalScore,
            components: components,
            reasons: reasons
        )
    }

    // MARK: - Score Calculations

    private func calculateBPMScore(songBPM: Int?, heartRate: Double) -> Double {
        guard let bpm = songBPM else { return 0.5 } // Unknown BPM = neutral

        let diff = abs(Double(bpm) - heartRate)

        // Perfect match at 0 diff, falls off as diff increases
        // Score of 0.5 at 30 BPM difference, 0 at 60+
        return max(0, 1.0 - diff / 60.0)
    }

    private func calculateEnergyScore(songEnergy: Double, intervention: MusicIntervention) -> Double {
        let targetRange = intervention.targetEnergy

        if targetRange.contains(songEnergy) {
            // Perfect - energy is in target range
            return 1.0
        } else if songEnergy < targetRange.lowerBound {
            // Song is calmer than needed
            let diff = targetRange.lowerBound - songEnergy
            return max(0, 1.0 - diff * 2)
        } else {
            // Song is more energetic than needed
            let diff = songEnergy - targetRange.upperBound
            return max(0, 1.0 - diff * 2)
        }
    }

    private func calculateFamiliarityScore(playCount: Int) -> Double {
        // Diminishing returns on familiarity
        // 0 plays = 0.3 (unknown is slightly negative)
        // 1-5 plays = 0.5-0.8 (building familiarity)
        // 6+ plays = 0.8-1.0 (well known)
        switch playCount {
        case 0:
            return 0.3
        case 1...5:
            return 0.5 + Double(playCount) * 0.06
        default:
            return min(1.0, 0.8 + Double(playCount - 5) * 0.02)
        }
    }

    private func calculateRecencyScore(lastPlayed: Date?) -> Double {
        guard let lastPlayed = lastPlayed else {
            return 1.0  // Never played = fully fresh
        }

        let hoursSincePlay = Date().timeIntervalSince(lastPlayed) / 3600

        switch hoursSincePlay {
        case ..<1:
            return 0.0  // Played within last hour = don't repeat
        case 1..<4:
            return 0.3  // Played recently = mostly avoid
        case 4..<24:
            return 0.6  // Played today = slight penalty
        default:
            return 1.0  // Not played today = fresh
        }
    }

    private func describeEnergyMatch(intervention: MusicIntervention) -> String {
        switch intervention {
        case .urgentCalm:
            return "Calming energy for relaxation"
        case .gentleCalm:
            return "Gently calming"
        case .maintain:
            return "Matches your current vibe"
        case .canEnergize:
            return "Upbeat to boost your energy"
        }
    }
}

struct ScoreComponent {
    let factor: String
    let score: Double
    let weight: Double
    let reason: String?

    var weightedScore: Double {
        score * weight
    }
}

struct ScoredSong {
    let song: Song
    let score: Double
    let components: [ScoreComponent]
    let reasons: [String]

    var primaryReason: String {
        reasons.first ?? "Good match for your current state"
    }
}
```

---

## 15.2 Ranking and Selection

### Ranking Songs

Once we can score individual songs, the ranking problem is straightforward: score all candidates and sort by score descending. The highest-scoring song is our selection. However, there are important considerations in how we implement this.

**Computational Complexity**: With n songs, we perform n scoring operations (each O(1) with constant factors) and one sort (O(n log n)). For typical playlist sizes (100-1000 songs), this completes in milliseconds. However, if scoring involves database lookups or expensive computations, we might cache results or score incrementally.

**Determinism vs Variety**: Always picking the top song can lead to repetitive selections. If the same song consistently scores highest, the user might hear it repeatedly. We address this through recency penalties and exploration strategies (covered below).

**Context-Aware Weighting**: Different situations call for different priorities. During a workout, BPM match and energy might matter most. During relaxation, stress-relief history becomes more important. We implement this by maintaining multiple weight presets and selecting based on context.

**What we're doing:** Scoring all candidate songs against the current user state, sorting them by score, and selecting the best match. The ranking incorporates context-aware weight selection to adapt to different usage scenarios.

```swift
class MusicBrain {
    private let scorer = SongScorer()
    private let historyStore: SongHistoryStore

    init(historyStore: SongHistoryStore) {
        self.historyStore = historyStore
    }

    func rankSongs(
        candidates: [Song],
        state: UserState,
        context: MusicContext = .default
    ) -> [ScoredSong] {
        let weights = selectWeights(for: context)

        return candidates
            .map { song in
                let history = historyStore.getHistory(for: song.id)
                return scorer.score(song: song, state: state, history: history, weights: weights)
            }
            .sorted { $0.score > $1.score }
    }

    func selectNextSong(
        from candidates: [Song],
        state: UserState,
        context: MusicContext = .default
    ) -> ScoredSong? {
        let ranked = rankSongs(candidates: candidates, state: state, context: context)
        return ranked.first
    }

    private func selectWeights(for context: MusicContext) -> SongScorer.Weights {
        switch context {
        case .workout:
            return .workout
        case .relaxation, .sleep:
            return .relaxation
        case .focus:
            return SongScorer.Weights(
                bpmMatch: 0.15,
                energyMatch: 0.20,
                stressResponse: 0.25,
                familiarity: 0.30,  // Familiar music is less distracting
                recency: 0.10
            )
        case .default:
            return SongScorer.Weights()
        }
    }
}

enum MusicContext {
    case `default`
    case workout
    case relaxation
    case sleep
    case focus
}
```

---

### Exploration vs Exploitation

This is one of the fundamental problems in recommendation systems, known as the **multi-armed bandit problem**. The dilemma: should we **exploit** what we know works (play songs that have performed well) or **explore** less-known options that might be even better?

**The Problem with Pure Exploitation**: If we always pick the highest-scoring song, we never discover new favorites. A song the user hasn't heard yet has no history data, so it gets a neutral familiarity score and can't compete with established favorites. The user's experience becomes stale.

**The Problem with Pure Exploration**: Random selection ignores everything we've learned. The user experiences a seemingly random playlist with no connection to their state.

**ε-Greedy Strategy**: The simplest solution is to exploit most of the time (e.g., 90%) but randomly explore occasionally (10%). This is called ε-greedy (epsilon-greedy) where ε is the exploration rate. It's simple but crude—exploration is completely random without considering how uncertain we are about different options.

**Thompson Sampling**: A more sophisticated approach that naturally balances exploration and exploitation. The key insight is that **uncertainty should drive exploration**. Songs we've played many times have stable, reliable scores. Songs we've rarely played have uncertain scores—they might be better or worse than we think. Thompson Sampling adds random noise proportional to this uncertainty, giving less-known songs a chance to bubble up occasionally.

The mathematical intuition: if a song's true quality is unknown, its observed score is a sample from a probability distribution. By sampling from this distribution (approximated by adding uncertainty-scaled noise), we naturally explore uncertain options while still preferring likely-good choices.

**What we're doing:** Implementing strategies that balance between selecting known-good songs (exploitation) and trying less-familiar songs to discover new favorites (exploration). We use epsilon-greedy for simplicity and Thompson Sampling for smarter uncertainty-aware exploration.

```swift
extension MusicBrain {
    func selectWithExploration(
        from candidates: [Song],
        state: UserState,
        explorationRate: Double = 0.1
    ) -> ScoredSong? {
        let ranked = rankSongs(candidates: candidates, state: state)

        guard !ranked.isEmpty else { return nil }

        // 90% of the time, pick the best song (exploitation)
        // 10% of the time, pick randomly from top 20% (exploration)
        if Double.random(in: 0...1) > explorationRate {
            return ranked.first
        } else {
            let topTwentyPercent = max(1, ranked.count / 5)
            let explorationPool = Array(ranked.prefix(topTwentyPercent))
            return explorationPool.randomElement()
        }
    }

    // Thompson Sampling - smarter, uncertainty-aware exploration
    // Songs with fewer plays have higher uncertainty, giving them
    // a chance to "win" occasionally through positive noise
    func selectWithThompsonSampling(
        from candidates: [Song],
        state: UserState
    ) -> ScoredSong? {
        let ranked = rankSongs(candidates: candidates, state: state)

        // Add randomness based on uncertainty
        // Songs with fewer plays have higher uncertainty
        let sampledScores = ranked.map { scored -> (ScoredSong, Double) in
            let history = historyStore.getHistory(for: scored.song.id)
            let playCount = history?.playCount ?? 0

            // Uncertainty decreases as we gather more data
            // After 10 plays, uncertainty is ~0.09; after 100 plays, ~0.01
            let uncertainty = 1.0 / (Double(playCount) + 1)
            let noise = Double.random(in: -uncertainty...uncertainty)

            return (scored, scored.score + noise)
        }

        return sampledScores.max { $0.1 < $1.1 }?.0
    }
}
```

---

## 15.3 Learning from Feedback

The most powerful aspect of AI DJ is its ability to learn and improve over time. Unlike static recommendation systems, AI DJ observes user behavior and adjusts its model accordingly. This is a form of **online learning** or **reinforcement learning**—the system takes actions (plays songs), observes outcomes (user response), and updates its beliefs (effectiveness scores).

### Implicit vs Explicit Feedback

**Explicit feedback** is when users directly rate content (thumbs up/down, 5-star ratings). It's high-quality signal but rare—most users don't rate most content.

**Implicit feedback** is derived from user behavior: did they skip the song? How much of it did they listen to? Did they adjust volume? Implicit feedback is abundant but noisy—maybe they skipped because of an interruption, not because they disliked the song.

AI DJ primarily uses implicit feedback because:
1. It requires no user effort
2. Every song play generates data
3. Combined with biometric data, it's actually more reliable than explicit ratings
4. Users may not consciously know what helps them relax—their body does

### The Feedback Loop

The learning loop works as follows:
1. **Before song**: Capture current biometric state (HR, HRV)
2. **During song**: Monitor for skip, track play duration
3. **After song**: Capture new biometric state, calculate delta
4. **Update model**: Adjust song's effectiveness scores based on:
   - **Completion rate**: Did user listen fully? (higher = positive signal)
   - **Skip rate**: How often is this song skipped? (lower = better)
   - **Biometric delta**: Did HR decrease and HRV increase? (= calming effect)
   - **Context match**: Did the song help achieve the intended intervention?

### Exponential Moving Average for Learning

We use exponential moving average (EMA) to blend new observations with historical data. This gives more weight to recent experiences while still remembering the past. The formula:

```
new_score = α × new_observation + (1 - α) × old_score
```

Where α (alpha) is the learning rate, typically 0.1-0.3. Higher α = faster adaptation to new data but more susceptible to noise. Lower α = more stable but slower to adapt.

**What we're doing:** Learning from user behavior without explicit ratings, using implicit signals like skip rate, completion rate, and most importantly, biometric changes that indicate whether the song achieved its intended effect.

```swift
class FeedbackProcessor {
    private let historyStore: SongHistoryStore

    init(historyStore: SongHistoryStore) {
        self.historyStore = historyStore
    }

    // Called when a song finishes or user takes action
    func processFeedback(
        song: Song,
        action: UserAction,
        biometricsBefore: UserState,
        biometricsAfter: UserState?
    ) {
        var history = historyStore.getHistory(for: song.id) ?? SongHistory(songId: song.id)

        // Update play/skip counts
        switch action {
        case .listenedFully:
            history.playCount += 1
            history.completionRate = updateRunningAverage(
                current: history.completionRate,
                new: 1.0,
                count: history.playCount
            )
        case .skipped(let percentPlayed):
            history.playCount += 1
            history.skipCount += 1
            history.completionRate = updateRunningAverage(
                current: history.completionRate,
                new: percentPlayed,
                count: history.playCount
            )
        case .liked:
            history.likeCount += 1
        case .disliked:
            history.dislikeCount += 1
        }

        // Update effectiveness scores based on biometric changes
        if let after = biometricsAfter {
            let hrvChange = after.hrv - biometricsBefore.hrv
            let hrChange = biometricsBefore.heartRate - after.heartRate

            // Positive HRV change + HR decrease = calming effect
            if biometricsBefore.stressLevel.needsCalming {
                let calmingEffect = (hrvChange / 20) + (hrChange / 20)  // Normalize
                history.effectivenessForCalming = updateRunningAverage(
                    current: history.effectivenessForCalming,
                    new: min(1, max(0, 0.5 + calmingEffect)),
                    count: history.playCount
                )
            }
        }

        history.lastPlayed = Date()
        historyStore.save(history)
    }

    private func updateRunningAverage(current: Double, new: Double, count: Int) -> Double {
        // Exponential moving average
        let alpha = 1.0 / Double(min(count, 10))  // Cap influence of single data point
        return current * (1 - alpha) + new * alpha
    }
}

enum UserAction {
    case listenedFully
    case skipped(percentPlayed: Double)
    case liked
    case disliked
}

struct SongHistory {
    let songId: String
    var playCount: Int = 0
    var skipCount: Int = 0
    var likeCount: Int = 0
    var dislikeCount: Int = 0
    var completionRate: Double = 0.5
    var effectivenessForCalming: Double = 0.5
    var effectivenessForEnergizing: Double = 0.5
    var lastPlayed: Date?
}
```

---

## 15.4 Advanced Scoring Concepts

### Normalization and Feature Scaling

All scoring factors must produce values in a consistent range (0 to 1) for the weighted sum to work properly. Without normalization, a factor producing values 0-100 would dominate one producing values 0-1, regardless of weights.

Common normalization approaches:
- **Min-Max**: `(value - min) / (max - min)` → maps to 0-1
- **Linear decay**: `max(0, 1 - value / threshold)` → 1 at 0, 0 at threshold
- **Sigmoid**: `1 / (1 + e^(-k*(value-midpoint)))` → smooth S-curve

For BPM matching, we use linear decay from perfect match (1.0) to threshold difference (0.0). This provides intuitive, predictable behavior.

### Cold Start Problem

New songs have no history data—no play counts, no effectiveness scores. This is the "cold start" problem. Our solution:
- Default scores to 0.5 (neutral) rather than 0 (bad) or 1 (good)
- Use Thompson Sampling to give new songs exploration chances
- Leverage song metadata (genre, BPM) for initial estimates
- After 5-10 plays, learned scores become reliable

### Score Smoothing and Stability

Raw scores can fluctuate significantly based on small input changes. To prevent jarring song selection changes, we can apply smoothing:
- **Temporal smoothing**: Average scores over the last N biometric readings
- **Hysteresis**: Require a minimum score advantage before switching from current song
- **Momentum**: Consider not just current fit but trend direction

### Weight Tuning

The default weights are starting points. Optimal weights depend on:
- User population characteristics
- Music library composition
- Specific goals (stress reduction vs exercise motivation)

Weights can be tuned through:
- **A/B testing**: Compare different weight sets on user satisfaction metrics
- **Bayesian optimization**: Systematically search weight space
- **User personalization**: Allow users to adjust factor importance

---

## Key Takeaways - Algorithm & Scoring

1. **Weighted linear combination** - Each factor scores 0-1, weights sum to 1.0, final score is weighted sum
2. **Normalization is critical** - All factors must produce comparable scales
3. **Context-adaptive weights** - Workout emphasizes BPM/energy; relaxation emphasizes calming history
4. **Explainability builds trust** - Users should understand why songs are chosen
5. **Explore vs exploit** - Thompson Sampling balances trying new songs vs proven favorites
6. **Implicit feedback is gold** - Skips, completion rate, and biometric deltas reveal true preference
7. **EMA for learning** - Exponential moving average balances recency with stability
8. **Cold start handling** - Default to neutral (0.5), let exploration discover quality
9. **The algorithm IS the product** - This scoring logic is what makes AI DJ smart

---

# 16. TESTING IN SWIFT

## Why This Matters for AI DJ

Untested code is broken code waiting to happen. AI DJ has complex logic: scoring algorithms, biometric processing, state machines. Testing ensures the Brain makes correct decisions. It also lets you refactor with confidence and catch regressions before users do.

**In AI DJ, testing covers:**
- Unit tests for scoring algorithm
- Integration tests for HealthKit/MusicKit services
- UI tests for critical flows
- Snapshot tests for widget appearances

---

## 16.1 XCTest Basics

### Writing Unit Tests

**What we're doing:** Testing individual functions in isolation.

```swift
import XCTest
@testable import AIDJ

class SongScorerTests: XCTestCase {

    var scorer: SongScorer!

    override func setUp() {
        super.setUp()
        scorer = SongScorer()
    }

    override func tearDown() {
        scorer = nil
        super.tearDown()
    }

    // MARK: - BPM Score Tests

    func testBPMScore_perfectMatch_returns1() {
        // Given
        let song = Song.mock(bpm: 75)
        let state = UserState.mock(heartRate: 75)

        // When
        let result = scorer.score(
            song: song,
            state: state,
            history: nil,
            weights: .init()
        )

        // Then
        let bpmComponent = result.components.first { $0.factor == "BPM Match" }
        XCTAssertEqual(bpmComponent?.score, 1.0, accuracy: 0.01)
    }

    func testBPMScore_30bpmDifference_returns0_5() {
        let song = Song.mock(bpm: 100)
        let state = UserState.mock(heartRate: 70)

        let result = scorer.score(song: song, state: state, history: nil, weights: .init())

        let bpmComponent = result.components.first { $0.factor == "BPM Match" }
        XCTAssertEqual(bpmComponent?.score ?? 0, 0.5, accuracy: 0.01)
    }

    func testBPMScore_60bpmDifference_returns0() {
        let song = Song.mock(bpm: 130)
        let state = UserState.mock(heartRate: 70)

        let result = scorer.score(song: song, state: state, history: nil, weights: .init())

        let bpmComponent = result.components.first { $0.factor == "BPM Match" }
        XCTAssertEqual(bpmComponent?.score ?? 0, 0.0, accuracy: 0.01)
    }

    // MARK: - Energy Score Tests

    func testEnergyScore_matchesUrgentCalm_returnsHigh() {
        let song = Song.mock(energyLevel: 0.2)  // Calm song
        let state = UserState.mock(needsIntervention: .urgentCalm)

        let result = scorer.score(song: song, state: state, history: nil, weights: .init())

        let energyComponent = result.components.first { $0.factor == "Energy Match" }
        XCTAssertGreaterThan(energyComponent?.score ?? 0, 0.8)
    }

    func testEnergyScore_tooEnergeticForCalm_returnsLow() {
        let song = Song.mock(energyLevel: 0.9)  // High energy song
        let state = UserState.mock(needsIntervention: .urgentCalm)

        let result = scorer.score(song: song, state: state, history: nil, weights: .init())

        let energyComponent = result.components.first { $0.factor == "Energy Match" }
        XCTAssertLessThan(energyComponent?.score ?? 1, 0.5)
    }

    // MARK: - Overall Score Tests

    func testOverallScore_perfectSong_scoresHigh() {
        let song = Song.mock(bpm: 70, energyLevel: 0.2)
        let state = UserState.mock(heartRate: 70, needsIntervention: .urgentCalm)
        let history = SongHistory.mock(playCount: 10, effectivenessForCalming: 0.9)

        let result = scorer.score(song: song, state: state, history: history, weights: .init())

        XCTAssertGreaterThan(result.score, 0.8)
        XCTAssertFalse(result.reasons.isEmpty)
    }
}

// MARK: - Test Mocks

extension Song {
    static func mock(bpm: Int? = 100, energyLevel: Double = 0.5) -> Song {
        Song(
            id: UUID().uuidString,
            title: "Test Song",
            artist: "Test Artist",
            bpm: bpm,
            energyLevel: energyLevel
        )
    }
}

extension UserState {
    static func mock(
        heartRate: Double = 70,
        hrv: Double = 50,
        needsIntervention: MusicIntervention = .maintain
    ) -> UserState {
        UserState(
            heartRate: heartRate,
            hrv: hrv,
            heartRateZone: .baseline,
            stressLevel: .low,
            heartRateTrend: .stable,
            hrvTrend: .stable,
            needsIntervention: needsIntervention
        )
    }
}

extension SongHistory {
    static func mock(
        playCount: Int = 5,
        effectivenessForCalming: Double = 0.5
    ) -> SongHistory {
        var history = SongHistory(songId: "test")
        history.playCount = playCount
        history.effectivenessForCalming = effectivenessForCalming
        return history
    }
}
```

---

## 16.2 Async Testing

### Testing Async Functions

**What we're doing:** Testing functions that use async/await.

```swift
class HealthKitServiceTests: XCTestCase {

    var mockHealthStore: MockHealthStore!
    var service: HealthKitService!

    override func setUp() {
        mockHealthStore = MockHealthStore()
        service = HealthKitService(healthStore: mockHealthStore)
    }

    func testFetchLatestHeartRate_returnsMostRecent() async throws {
        // Given
        mockHealthStore.mockHeartRateSamples = [
            MockSample(value: 70, date: Date().addingTimeInterval(-60)),
            MockSample(value: 75, date: Date().addingTimeInterval(-30)),
            MockSample(value: 80, date: Date())  // Most recent
        ]

        // When
        let result = try await service.fetchLatestHeartRate()

        // Then
        XCTAssertEqual(result, 80)
    }

    func testFetchLatestHeartRate_noData_throws() async {
        // Given
        mockHealthStore.mockHeartRateSamples = []

        // When/Then
        do {
            _ = try await service.fetchLatestHeartRate()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? HealthKitError, .noData)
        }
    }
}

// Mock HealthKit store for testing
class MockHealthStore: HealthStoreProtocol {
    var mockHeartRateSamples: [MockSample] = []

    func execute(_ query: HKQuery) {
        // Simulate query execution
    }

    func fetchLatestSample(type: HKQuantityType) async throws -> HKQuantitySample? {
        return mockHeartRateSamples.last?.toHKSample()
    }
}
```

---

## 16.3 Dependency Injection for Testability

### Protocol-Based Dependencies

**What we're doing:** Making components testable by injecting dependencies.

```swift
// Instead of creating dependencies internally, inject them
class NowPlayingViewModel: ObservableObject {
    private let musicService: MusicServiceProtocol
    private let healthService: HealthServiceProtocol
    private let brain: MusicBrainProtocol

    // Inject dependencies - can be real or mock
    init(
        musicService: MusicServiceProtocol,
        healthService: HealthServiceProtocol,
        brain: MusicBrainProtocol
    ) {
        self.musicService = musicService
        self.healthService = healthService
        self.brain = brain
    }
}

// In tests, inject mocks
class NowPlayingViewModelTests: XCTestCase {

    func testSelectNextSong_usesTopRankedSong() async {
        // Given
        let mockMusic = MockMusicService()
        mockMusic.mockPlaylistSongs = [
            Song.mock(title: "Song A"),
            Song.mock(title: "Song B")
        ]

        let mockHealth = MockHealthService()
        mockHealth.mockHeartRate = 70

        let mockBrain = MockMusicBrain()
        mockBrain.mockTopSong = Song.mock(title: "Song B")

        let viewModel = NowPlayingViewModel(
            musicService: mockMusic,
            healthService: mockHealth,
            brain: mockBrain
        )

        // When
        await viewModel.selectNextSong()

        // Then
        XCTAssertEqual(viewModel.currentSong?.title, "Song B")
        XCTAssertEqual(mockMusic.playedSong?.title, "Song B")
    }
}
```

---

## 16.4 UI Testing

### XCUITest Basics

**What we're doing:** Testing the actual UI interactions.

```swift
import XCTest

class AIDJUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]  // Use test data
        app.launch()
    }

    func testPlaybackControls() {
        // Given
        let playButton = app.buttons["PlayPauseButton"]

        // When - tap play
        playButton.tap()

        // Then - button should change to pause
        XCTAssertTrue(app.buttons["PauseButton"].exists ||
                     playButton.label.contains("Pause"))
    }

    func testNavigationToSettings() {
        // Given
        let settingsButton = app.buttons["SettingsButton"]

        // When
        settingsButton.tap()

        // Then
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }

    func testHeartRateDisplay() {
        // Given - mock heart rate data in launch arguments

        // Then
        let heartRateLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'BPM'")
        ).firstMatch

        XCTAssertTrue(heartRateLabel.exists)
    }
}
```

---

## Key Takeaways - Testing

1. **Unit test the Brain** - Scoring logic should be thoroughly tested
2. **Use mocks for external services** - Don't hit real HealthKit in tests
3. **Dependency injection enables testing** - Pass dependencies, don't create them
4. **Async tests with `async throws`** - XCTest supports async natively
5. **UI tests for critical paths** - Playback controls, navigation
6. **Test edge cases** - Empty data, nil values, extreme inputs

---

# 17. SECURITY, PRIVACY & ENTITLEMENTS

## Why This Matters for AI DJ

AI DJ handles sensitive data: health metrics and music listening history. Users trust us with their heart rate data. Apple mandates specific privacy protections, and violating them means App Store rejection. Beyond compliance, respecting privacy builds user trust.

**In AI DJ, security and privacy cover:**
- Requesting only necessary permissions
- Securing stored health data
- Explaining data usage to users
- Proper entitlements configuration

---

## 17.1 Privacy Permissions

### Info.plist Privacy Descriptions

**What we're doing:** Explaining why we need each permission.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <!-- HealthKit -->
    <key>NSHealthShareUsageDescription</key>
    <string>AI DJ reads your heart rate and heart rate variability to select music that matches your current state, helping you relax or energize as needed.</string>

    <!-- Music Library -->
    <key>NSAppleMusicUsageDescription</key>
    <string>AI DJ needs access to your Apple Music library to play songs from your playlists.</string>

    <!-- Microphone (if using for ambient sound analysis) -->
    <key>NSMicrophoneUsageDescription</key>
    <string>AI DJ can listen to ambient sound to enhance music selection for your environment.</string>

    <!-- Location (if using for context) -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>AI DJ uses your location to suggest music appropriate for your current environment (gym, home, commute).</string>
</dict>
</plist>
```

**Best practices:**
- Explain the benefit to the user, not just what you access
- Be specific: "heart rate to select calming music" not "health data"
- Request permissions at the point of use, not at app launch

---

### Progressive Permission Requests

**What we're doing:** Requesting permissions only when needed, with context.

```swift
class PermissionManager: ObservableObject {
    @Published var healthPermissionStatus: PermissionStatus = .notDetermined
    @Published var musicPermissionStatus: PermissionStatus = .notDetermined

    enum PermissionStatus {
        case notDetermined
        case authorized
        case denied
    }

    // Called when user first tries to use biometric features
    func requestHealthPermission() async -> Bool {
        // Show explanation first
        // "To select music that matches your state, AI DJ needs to read your heart rate."

        let healthManager = HealthKitManager()

        do {
            try await healthManager.requestAuthorization()
            await MainActor.run {
                healthPermissionStatus = .authorized
            }
            return true
        } catch {
            await MainActor.run {
                healthPermissionStatus = .denied
            }
            return false
        }
    }

    // Called when user first tries to play music
    func requestMusicPermission() async -> Bool {
        let status = await MusicAuthorization.request()

        await MainActor.run {
            switch status {
            case .authorized:
                musicPermissionStatus = .authorized
            default:
                musicPermissionStatus = .denied
            }
        }

        return status == .authorized
    }
}

// In UI
struct OnboardingView: View {
    @StateObject private var permissions = PermissionManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("AI DJ needs a few permissions to work its magic")

            // Health permission card
            PermissionCard(
                title: "Health Data",
                description: "Read your heart rate to select the perfect music",
                icon: "heart.fill",
                status: permissions.healthPermissionStatus,
                action: {
                    Task {
                        await permissions.requestHealthPermission()
                    }
                }
            )

            // Music permission card
            PermissionCard(
                title: "Apple Music",
                description: "Access your playlists and play songs",
                icon: "music.note",
                status: permissions.musicPermissionStatus,
                action: {
                    Task {
                        await permissions.requestMusicPermission()
                    }
                }
            )
        }
    }
}
```

---

## 17.2 Data Security

### Keychain for Sensitive Data

**What we're doing:** Storing sensitive data securely.

```swift
import Security

class KeychainManager {
    enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case notFound
        case invalidData
    }

    func save(_ data: Data, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Update existing item
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)

            guard updateStatus == errSecSuccess else {
                throw KeychainError.unknown(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unknown(status)
        }
    }

    func retrieve(service: String, account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw status == errSecItemNotFound ? KeychainError.notFound : KeychainError.unknown(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
}
```

---

## 17.3 Entitlements

### Required Entitlements for AI DJ

**What we're doing:** Configuring app capabilities in Xcode.

```xml
<!-- AIDJ.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <!-- HealthKit access -->
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array>
        <string>health-records</string>
    </array>

    <!-- App Groups for sharing data with widgets and watch -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourcompany.aidj</string>
    </array>

    <!-- iCloud for CloudKit sync -->
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.yourcompany.aidj</string>
    </array>

    <!-- Background modes -->
    <key>com.apple.developer.background-modes</key>
    <array>
        <string>audio</string>
        <string>fetch</string>
        <string>processing</string>
    </array>
</dict>
</plist>
```

---

## Key Takeaways - Security & Privacy

1. **Request minimum permissions** - Only what you truly need
2. **Explain benefits in privacy strings** - "To help you relax" not "to read data"
3. **Progressive permission requests** - Ask at point of use, not app launch
4. **Use Keychain for secrets** - Never store tokens in UserDefaults
5. **Configure entitlements correctly** - HealthKit, App Groups, Background Modes
6. **App Privacy labels** - Accurately declare data collection in App Store Connect

---

# 18. APP DISTRIBUTION & DEPLOYMENT

## Why This Matters for AI DJ

Building the app is just the beginning. Getting it to users means navigating TestFlight, App Store Review, and release management. Understanding this process prevents rejection, enables rapid iteration, and ensures smooth updates.

**In AI DJ, distribution covers:**
- TestFlight for beta testing
- App Store submission
- Handling review feedback
- Managing releases across platforms

---

## 18.1 Build & Archive

### Preparing for Distribution

**What we're doing:** Creating a build ready for TestFlight or App Store.

```
In Xcode:
1. Select "Any iOS Device" as destination (not a simulator)
2. Product → Archive
3. Wait for archive to complete
4. Organizer window opens automatically

Archive checklist:
□ Version number updated (CFBundleShortVersionString)
□ Build number incremented (CFBundleVersion)
□ Correct provisioning profile (App Store Distribution)
□ All targets building successfully
□ No warnings in release configuration
```

---

### Automatic Version Numbering

```swift
// In Build Settings, you can use scripts to auto-increment

// Build Phase Script (Run Script):
// Automatically increment build number

buildNumber=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${PROJECT_DIR}/${INFOPLIST_FILE}")
buildNumber=$(($buildNumber + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "${PROJECT_DIR}/${INFOPLIST_FILE}"
```

---

## 18.2 TestFlight

### Uploading to TestFlight

**What we're doing:** Distributing beta builds to testers.

```
1. In Organizer, select your archive
2. Click "Distribute App"
3. Choose "App Store Connect"
4. Choose "Upload"
5. Follow prompts (signing, symbols, etc.)
6. Wait for upload and processing (~15-30 minutes)

In App Store Connect:
1. Go to TestFlight tab
2. Wait for build to finish processing
3. Add testers (internal or external)
4. Submit for Beta App Review (external only)
```

---

### Managing Test Groups

```
Internal Testers:
- Up to 100 Apple Developer team members
- No review required
- Immediate access after processing

External Testers:
- Up to 10,000 users
- Requires Beta App Review (usually 24-48 hours)
- Invite via email or public link
- Can create multiple groups (e.g., "Early Adopters", "Bug Hunters")

Test Information:
- What to Test: "Try creating a workout playlist and monitor how songs change with your heart rate"
- App Description: Brief for testers
- Feedback Email: Where bug reports go
```

---

## 18.3 App Store Submission

### App Store Connect Setup

**What we're doing:** Preparing the App Store listing.

```
App Information:
├── Name: AI DJ - Biometric Music
├── Subtitle: Music that matches your mood
├── Primary Category: Music
├── Secondary Category: Health & Fitness
├── Privacy Policy URL: Required for HealthKit apps
├── Age Rating: 4+ (no objectionable content)
└── Copyright: © 2026 Your Company

App Privacy:
├── Data Used to Track You: None (ideally)
├── Data Linked to You:
│   ├── Health & Fitness (heart rate, HRV)
│   └── Usage Data (song play history)
└── Data Not Linked to You:
    └── Diagnostics

Pricing:
├── Price: Free (or price tier)
├── In-App Purchases: (if applicable)
└── Availability: All territories or specific

Screenshots (required for each device size):
├── iPhone 6.7" (1290 × 2796)
├── iPhone 6.5" (1284 × 2778)
├── iPhone 5.5" (1242 × 2208)
├── iPad Pro 12.9" (2048 × 2732)
└── Apple Watch (varies by size)

App Preview Videos: Optional but recommended
```

---

### Common Review Rejections and How to Avoid

```swift
// 1. Guideline 2.1 - App Completeness
// Problem: Crashes, placeholder content, broken features
// Solution: Test thoroughly, use TestFlight first

// 2. Guideline 4.2 - Minimum Functionality
// Problem: App doesn't do enough, or is just a website wrapper
// Solution: Ensure unique native functionality

// 3. Guideline 5.1.1 - Data Collection and Privacy
// Problem: Collecting data without clear purpose or consent
// Solution:
struct HealthPermissionView: View {
    var body: some View {
        VStack {
            Text("Why we need health access")
                .font(.headline)
            Text("AI DJ reads your heart rate in real-time to select music that helps you relax or energize. This data never leaves your device.")
            Button("Allow Access") {
                // Request permission
            }
        }
    }
}

// 4. Guideline 2.3.3 - Accurate Screenshots
// Problem: Screenshots don't match app functionality
// Solution: Use actual app screenshots, not mockups

// 5. Guideline 4.0 - Design
// Problem: Poor user experience, confusing navigation
// Solution: Follow Human Interface Guidelines
```

---

### Responding to Rejections

```
If rejected:
1. Read the rejection reason carefully
2. Don't argue - understand their concern
3. Fix the issue
4. Reply in Resolution Center explaining your fix
5. Resubmit for review

Common resolution strategies:
- Add demo mode if login required
- Improve permission request explanations
- Fix crashes (check crash logs in Organizer)
- Add missing privacy policy
- Remove misleading marketing claims
```

---

## 18.4 Release Management

### Phased Releases

**What we're doing:** Gradually rolling out updates to catch issues.

```
App Store Connect → App Store → Version → Phased Release

Phased Release Schedule:
Day 1: 1% of users
Day 2: 2% of users
Day 3: 5% of users
Day 4: 10% of users
Day 5: 20% of users
Day 6: 50% of users
Day 7: 100% of users

Benefits:
- Catch issues before affecting everyone
- Can pause or halt if problems arise
- Users can still manually update if eager

Monitoring during rollout:
- Watch crash reports in Xcode Organizer
- Monitor App Store reviews
- Check analytics for engagement drops
```

---

### Multi-Platform Releases

**What we're doing:** Coordinating iOS, watchOS, and macOS releases.

```
For AI DJ:
1. iOS app is primary - submit first
2. watchOS app is bundled with iOS (same submission)
3. macOS is separate app record

Best practice:
- Keep version numbers aligned across platforms
- Test Watch features with iOS app together
- Submit macOS separately but coordinate timing

In App Store Connect:
- iOS + watchOS: One app record, both platforms in same submission
- macOS: Separate app record, can share iCloud container
```

---

## Key Takeaways - Distribution

1. **Archive from "Any iOS Device"** - Not simulator
2. **Use TestFlight extensively** - Catch issues before public release
3. **Prepare app metadata early** - Screenshots, descriptions, privacy labels
4. **Read rejection reasons carefully** - Understand, don't argue
5. **Use phased releases** - Protect users from widespread bugs
6. **Keep platforms in sync** - Coordinate iOS, watchOS, macOS releases

---

# Conclusion

You've now covered everything needed to build AI DJ:

1. **Swift Fundamentals** - The language powering it all
2. **Xcode** - Your development environment
3. **SwiftUI** - Building the user interface
4. **Concurrency** - Handling async operations
5. **CoreData** - Persisting learning data
6. **Architecture** - Organizing code properly
7. **MusicKit** - Accessing Apple Music
8. **HealthKit** - Reading biometrics
9. **watchOS** - The sensor on the wrist
10. **WatchConnectivity** - Bridging Watch and iPhone
11. **macOS** - Menu bar companion
12. **Background Processing** - Keeping music playing
13. **Widgets** - Glanceable info
14. **Biometrics** - Understanding the data
15. **Algorithms** - The scoring brain
16. **Testing** - Ensuring quality
17. **Security** - Protecting user data
18. **Distribution** - Getting it to users

Now go build something amazing.

---

*Last Updated: 2026-02-06*

import Foundation

/// The emoji tabs, in the order the category strip renders them. Recents leads, the way
/// stock puts the clock tab first.
public enum EmojiCategory: String, CaseIterable, Identifiable, Sendable {
    case recents
    case smileys
    case people
    case nature
    case food
    case activity
    case travel
    case objects
    case symbols
    case flags

    public var id: String { rawValue }

    /// SF Symbol for the tab. Matches the system picker's vocabulary so the strip reads
    /// as familiar rather than invented.
    public var symbolName: String {
        switch self {
        case .recents: "clock"
        case .smileys: "face.smiling"
        case .people: "person.2"
        case .nature: "leaf"
        case .food: "fork.knife"
        case .activity: "figure.run"
        case .travel: "car"
        case .objects: "lightbulb"
        case .symbols: "number"
        case .flags: "flag"
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .recents: "Recently used"
        case .smileys: "Smileys and emotion"
        case .people: "People and body"
        case .nature: "Animals and nature"
        case .food: "Food and drink"
        case .activity: "Activity"
        case .travel: "Travel and places"
        case .objects: "Objects"
        case .symbols: "Symbols"
        case .flags: "Flags"
        }
    }
}

/// Our own emoji table.
///
/// iOS vends no emoji catalog to third-party keyboards — there is no public API that
/// returns the system's emoji, their categories, or their order — so a keyboard that
/// wants an emoji page ships its own. This is a curated common set rather than the full
/// Unicode inventory: a keyboard extension has a tight memory budget, and the long tail
/// of an exhaustive table costs more than it earns.
///
/// Every entry inserts as ordinary text through `insertText`, so the keyboard's promise
/// is unchanged: the runes stay on the keycaps, the payload stays plain.
public enum EmojiCatalog {
    /// How many recents the strip remembers. Two rows' worth on a typical phone.
    public static let recentsLimit = 24

    public static func emoji(in category: EmojiCategory) -> [String] {
        switch category {
        case .recents: return []
        case .smileys: return smileys
        case .people: return people
        case .nature: return nature
        case .food: return food
        case .activity: return activity
        case .travel: return travel
        case .objects: return objects
        case .symbols: return symbols
        case .flags: return flags
        }
    }

    /// Recents after picking `emoji`: most recent first, no duplicates, bounded.
    ///
    /// Re-picking something already in the list moves it to the front rather than
    /// adding a second copy — otherwise a favourite would fill the whole strip.
    public static func recents(after emoji: String, in current: [String]) -> [String] {
        var updated = current.filter { $0 != emoji }
        updated.insert(emoji, at: 0)
        if updated.count > recentsLimit {
            updated = Array(updated.prefix(recentsLimit))
        }
        return updated
    }

    // MARK: - Tables

    private static let smileys = [
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "🫠", "😉",
        "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "🥲", "😋", "😛",
        "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🫢", "🤫", "🤔", "🫡", "🤐", "🤨",
        "😐", "😑", "😶", "🫥", "😏", "😒", "🙄", "😬", "😮‍💨", "🤥", "😌", "😔",
        "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢", "🤮", "🥵", "🥶", "😵", "🤯",
        "🤠", "🥳", "🥸", "😎", "🤓", "🧐", "😕", "🫤", "😟", "🙁", "😯", "😲",
        "🥺", "🥹", "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣",
        "😞", "😓", "😩", "😫", "🥱", "😤", "😡", "😠", "🤬", "😈", "👿", "💀",
    ]

    private static let people = [
        "👋", "🤚", "🖐", "✋", "🖖", "🫱", "🫲", "🫳", "🫴", "👌", "🤌", "🤏",
        "✌️", "🤞", "🫰", "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "👍",
        "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "🫶", "👐", "🤲", "🤝", "🙏",
        "💅", "🤳", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻", "👃", "🧠", "🫀",
        "👀", "👁", "👅", "👄", "🫦", "👶", "🧒", "👦", "👧", "🧑", "👨", "👩",
        "🧔", "👴", "👵", "🙋", "🙆", "🙅", "💁", "🙇", "🤦", "🤷", "🧑‍🎤", "🧑‍🚀",
        "👻", "🎃", "🤖", "👽", "🧙", "🧛", "🧟", "🧜", "🧚", "👼", "🫂", "👤",
    ]

    private static let nature = [
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐻‍❄️", "🐨", "🐯", "🦁",
        "🐮", "🐷", "🐸", "🐵", "🙈", "🙉", "🙊", "🐒", "🦍", "🦧", "🐔", "🐧",
        "🐦", "🐤", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🪲",
        "🐛", "🦋", "🐌", "🐞", "🐜", "🦗", "🕷", "🦂", "🐢", "🐍", "🦎", "🐙",
        "🦑", "🦐", "🦞", "🦀", "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈", "🐊",
        "🐅", "🐆", "🦓", "🦛", "🐘", "🦣", "🦏", "🐪", "🦒", "🦘", "🐃", "🐂",
        "🌵", "🎄", "🌲", "🌳", "🌴", "🪵", "🌱", "🌿", "☘️", "🍀", "🎍", "🪴",
        "🍃", "🍂", "🍁", "🍄", "🐚", "🪨", "🌾", "💐", "🌷", "🌹", "🥀", "🌺",
        "🌸", "🌼", "🌻", "🌞", "🌝", "🌛", "🌜", "🌚", "🌕", "🌙", "⭐️", "🌟",
        "✨", "⚡️", "🔥", "💥", "☄️", "🌈", "☁️", "🌧", "⛈", "❄️", "☃️", "💧",
    ]

    private static let food = [
        "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒",
        "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶",
        "🫑", "🌽", "🥕", "🫒", "🧄", "🧅", "🥔", "🍠", "🥐", "🥯", "🍞", "🥖",
        "🥨", "🧀", "🥚", "🍳", "🧈", "🥞", "🧇", "🥓", "🍔", "🍟", "🍕", "🌭",
        "🥪", "🌮", "🌯", "🫔", "🥙", "🧆", "🥘", "🍝", "🍜", "🍲", "🍛", "🍣",
        "🍱", "🥟", "🦪", "🍤", "🍙", "🍚", "🍘", "🍥", "🥠", "🍢", "🍡", "🍧",
        "🍨", "🍦", "🥧", "🧁", "🍰", "🎂", "🍮", "🍭", "🍬", "🍫", "🍿", "🍩",
        "🍪", "☕️", "🍵", "🧃", "🥤", "🧋", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸",
    ]

    private static let activity = [
        "⚽️", "🏀", "🏈", "⚾️", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓",
        "🏸", "🏒", "🏑", "🥍", "🏏", "🪃", "🥅", "⛳️", "🪁", "🏹", "🎣", "🤿",
        "🥊", "🥋", "🎽", "🛹", "🛼", "🛷", "⛸", "🥌", "🎿", "⛷", "🏂", "🪂",
        "🏋️", "🤼", "🤸", "⛹️", "🤺", "🤾", "🏌️", "🏇", "🧘", "🏄", "🏊", "🤽",
        "🚣", "🧗", "🚵", "🚴", "🏆", "🥇", "🥈", "🥉", "🏅", "🎖", "🏵", "🎗",
        "🎫", "🎟", "🎪", "🤹", "🎭", "🩰", "🎨", "🎬", "🎤", "🎧", "🎼", "🎹",
        "🥁", "🪘", "🎷", "🎺", "🪗", "🎸", "🪕", "🎻", "🎲", "♟", "🎯", "🎳",
    ]

    private static let travel = [
        "🚗", "🚕", "🚙", "🚌", "🚎", "🏎", "🚓", "🚑", "🚒", "🚐", "🛻", "🚚",
        "🚛", "🚜", "🦯", "🦽", "🦼", "🛴", "🚲", "🛵", "🏍", "🛺", "🚨", "🚔",
        "🚍", "🚘", "🚖", "🚡", "🚠", "🚟", "🚃", "🚋", "🚞", "🚝", "🚄", "🚅",
        "🚈", "🚂", "🚆", "🚇", "🚊", "🚉", "✈️", "🛫", "🛬", "🛩", "💺", "🛰",
        "🚀", "🛸", "🚁", "🛶", "⛵️", "🚤", "🛥", "🛳", "⛴", "🚢", "⚓️", "🪝",
        "⛽️", "🚏", "🚦", "🚥", "🗺", "🗿", "🗽", "🗼", "🏰", "🏯", "🏟", "🎡",
        "🎢", "🎠", "⛲️", "⛱", "🏖", "🏝", "🏜", "🌋", "⛰", "🏔", "🗻", "🏕",
        "🏠", "🏡", "🏘", "🏢", "🏬", "🏭", "🏥", "🏦", "🏨", "🏪", "🏫", "⛪️",
    ]

    private static let objects = [
        "⌚️", "📱", "💻", "⌨️", "🖥", "🖨", "🖱", "💽", "💾", "💿", "📀", "📼",
        "📷", "📸", "📹", "🎥", "📽", "📞", "☎️", "📟", "📠", "📺", "📻", "🎙",
        "⏰", "⏱", "⏲", "🕰", "⌛️", "⏳", "📡", "🔋", "🔌", "💡", "🔦", "🕯",
        "🪔", "🧯", "🛢", "💸", "💵", "💴", "💶", "💷", "🪙", "💰", "💳", "💎",
        "⚖️", "🪜", "🧰", "🪛", "🔧", "🔨", "⚒", "🛠", "⛏", "🪚", "🔩", "⚙️",
        "🧱", "⛓", "🧲", "🔫", "💣", "🧨", "🪓", "🔪", "🗡", "⚔️", "🛡", "🚬",
        "⚰️", "🪦", "🏺", "🔮", "📿", "🧿", "💈", "⚗️", "🔭", "🔬", "🕳", "💊",
        "💉", "🩸", "🩹", "🩺", "🚪", "🪑", "🛏", "🛋", "🪞", "🪟", "🧸", "🖼",
        "📚", "📖", "📕", "📗", "📘", "📙", "📓", "📒", "📃", "📜", "📄", "📰",
        "🔑", "🗝", "🔒", "🔓", "🔏", "🔐", "✏️", "✒️", "🖋", "🖊", "🖌", "🖍",
    ]

    private static let symbols = [
        "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕",
        "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️", "🕉", "☸️",
        "✡️", "🔯", "🕎", "☯️", "☦️", "⛎", "♈️", "♉️", "♊️", "♋️", "♌️", "♍️",
        "♎️", "♏️", "♐️", "♑️", "♒️", "♓️", "🆔", "⚛️", "🉑", "☢️", "☣️", "📴",
        "📳", "🈶", "🈚️", "🈸", "🈺", "🈷️", "✴️", "🆚", "💮", "🉐", "㊙️", "㊗️",
        "🈴", "🈵", "🈹", "🈲", "🅰️", "🅱️", "🆎", "🆑", "🅾️", "🆘", "❌", "⭕️",
        "🛑", "⛔️", "📛", "🚫", "💯", "💢", "♨️", "🚷", "🚯", "🚳", "🚱", "🔞",
        "📵", "🚭", "❗️", "❕", "❓", "❔", "‼️", "⁉️", "🔅", "🔆", "〽️", "⚠️",
        "🔱", "⚜️", "🔰", "♻️", "✅", "🈯️", "💹", "❇️", "✳️", "❎", "🌐", "💠",
        "✔️", "☑️", "🔘", "🔴", "🟠", "🟡", "🟢", "🔵", "🟣", "⚫️", "⚪️", "🟤",
    ]

    private static let flags = [
        "🏳️", "🏴", "🏴‍☠️", "🏁", "🚩", "🏳️‍🌈", "🏳️‍⚧️", "🇺🇳", "🇦🇷", "🇦🇺", "🇦🇹", "🇧🇪",
        "🇧🇷", "🇨🇦", "🇨🇱", "🇨🇳", "🇨🇴", "🇨🇿", "🇩🇰", "🇪🇬", "🇫🇮", "🇫🇷", "🇩🇪", "🇬🇷",
        "🇭🇰", "🇭🇺", "🇮🇸", "🇮🇳", "🇮🇩", "🇮🇪", "🇮🇱", "🇮🇹", "🇯🇵", "🇰🇪", "🇰🇷", "🇲🇽",
        "🇲🇦", "🇳🇱", "🇳🇿", "🇳🇬", "🇳🇴", "🇵🇰", "🇵🇪", "🇵🇭", "🇵🇱", "🇵🇹", "🇷🇴", "🇷🇺",
        "🇸🇦", "🇷🇸", "🇸🇬", "🇿🇦", "🇪🇸", "🇸🇪", "🇨🇭", "🇹🇭", "🇹🇷", "🇺🇦", "🇦🇪", "🇬🇧",
        "🇺🇸", "🇺🇾", "🇻🇳", "🇼🇸", "🇯🇲", "🇨🇺", "🇩🇴", "🇬🇹", "🇭🇳", "🇨🇷", "🇵🇦", "🇻🇪",
    ]
}

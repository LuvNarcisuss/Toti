import Foundation

/// One photograph for each person who appears in chats, rooms, comments, or as a film credit.
/// The same name keeps the same photograph everywhere. Credits are not the photographed people.
enum ArtistPortraits {
    static let people: [String: String] = [
        "Maya": "Portrait1", "Leo": "Portrait2", "Zoe": "Portrait3", "Noah": "Portrait4",
        "Aria": "Portrait5", "Finn": "Portrait6", "Ivy": "Portrait7", "Oliver": "Portrait8",
        "Elena": "Portrait9", "Emma": "Portrait10", "Priya": "Portrait11", "Nina": "Portrait12",
        "Sofia": "Portrait13", "Isla": "Portrait14", "Chloe": "Portrait15", "Ruby": "Portrait16",
        "Leah": "Portrait17", "Mila": "Portrait18", "Grace": "Portrait19", "Ella": "Portrait20",
        "Freya": "Portrait21", "Alice": "Portrait22", "Lily": "Portrait23", "Eva": "Portrait24",
        "Hazel": "Portrait25", "Rose": "Portrait26", "Lucy": "Portrait27", "Clara": "Portrait28",
        "Mabel": "Portrait29", "Lena": "Portrait30", "Riley": "Portrait31", "Luca": "Portrait32",
        "Owen": "Portrait33", "Jay": "Portrait34", "Lucas": "Portrait35", "Theo": "Portrait36",
        "Marcus": "Portrait37", "Ethan": "Portrait38", "Adam": "Portrait39", "Oscar": "Portrait40",
        "Alex": "Portrait41", "Jude": "Portrait42", "Hugo": "Portrait43", "Max": "Portrait44",
        "James": "Portrait45", "Daniel": "Portrait46", "Felix": "Portrait47", "Ben": "Portrait48",
        "Cole": "Portrait49", "Miles": "Portrait50",
    ]

    static let creators: [String: String] = [
        "local-owner": "PortraitLocal",
        "pexels:Los Muertos Crew": "Portrait55",
        "pexels:Ivan S": "Portrait51",
        "pexels:Kampus Production": "Portrait52",
        "pexels:cottonbro studio": "Portrait53",
        "pexels:ANTONI SHKRABA production": "Portrait54",
        "pexels:Polina Tankilevitch": "Portrait55",
        "pexels:MART PRODUCTION": "Portrait56",
        "pexels:Tima Miroshnichenko": "Portrait57",
        "pexels:Yaroslav Shuraev": "Portrait58",
        "pexels:Allan Mas": "Portrait59",
        "pexels:Marc Espejo": "Portrait60",
        "pexels:Shuttercraftsman": "Portrait61",
        "pexels:Pavel Danilyuk": "Portrait62",
        "pexels:KoolShooters": "Portrait63",
        "pexels:RDNE Stock project": "Portrait64",
        "pexels:Mikhail Nilov": "Portrait65",
        "pexels:Budgeron Bach": "Portrait66",
        "pexels:Antoni Shkraba": "Portrait67",
        "pexels:Sol Pinto": "Portrait68",
        "pexels:E CG": "Portrait69",
        "pexels:Ekaterina Antipova": "Portrait70",
        "pexels:ArtHouse Studio": "Portrait71",
        "pexels:VincaniTV": "Portrait72",
        "pexels:Jenny Coogan; Robin Jung": "Portrait73",
        "pexels:Lainey Silver": "Portrait74",
        "pexels:Streetz Ahead": "Portrait75",
        "pexels:Neil Sweeney": "Portrait76",
        "pexels:Vina Castelli": "Portrait77",
        "pexels:GoldMinka": "Portrait78",
    ]

    static func asset(forName name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        return people[name] ?? people[first] ?? "Portrait1"
    }

    static func asset(forCreator id: String) -> String {
        creators[id] ?? "PortraitLocal"
    }
}

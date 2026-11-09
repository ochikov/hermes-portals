import Foundation

enum PortalsLanguage {
    static var code = UserDefaults.standard.string(forKey: "interfaceLanguage") == "bg" ? "bg" : "en"
    static let clickGuide = "HOW TO CLICK\n1  Point at the target and pause.\n2  Touch thumb + index tips briefly.\n3  Separate them and point again → click.\nKeep the other fingers comfortably curled."
    static let tapGuide = "INDEX TAP\n1  Point comfortably → start at screen center.\n2  Move slowly for precise aiming.\n3  Bend your index down, then up → click.\nKeep your palm still while tapping.\nFaster hand movement gives more cursor travel.\nRecenter resets the comfortable starting point."
    static let instructions = "Show one hand, with your wrist in view.\n1  Hold an open palm still for 1 second to start.\n2  Move: point with your index; relax the other fingers.\n3  Click: follow your selected gesture in the live hand panel.\n4  Scroll: raise index + middle fingers and move up/down.\n5  Switch apps: hold an open palm briefly, then swipe.\nAfter a tracking pause, point to resume. After a fist pause, use an open palm. Escape stops camera and control."
    static func text(_ source: String) -> String {
        guard code == "bg" else { return source }
        if let value = bulgarian[source] { return value }
        if source.hasPrefix("Switched to ") { return "Отворено приложение: " + source.dropFirst("Switched to ".count) }
        if source.hasPrefix("Preview · "), source.hasSuffix(" · no Mac input") {
            let pose = String(source.dropFirst("Preview · ".count).dropLast(" · no Mac input".count))
            return "Преглед · \(text(pose)) · без управление"
        }
        if let range = source.range(of: " · "), source.hasSuffix("/21 joints") {
            return text(String(source[..<range.lowerBound]).lowercased()) + " · " + source[range.upperBound...].replacingOccurrences(of: "joints", with: "стави")
        }
        return source // Preserve an unexpected system error rather than hide it.
    }
    private static let bulgarian: [String: String] = [
        "Your hand. Your Mac.": "Твоята ръка. Твоят Mac.",
        "Pointer sensitivity": "Чувствителност на курсора",
        "Low · larger movements": "Ниска · по-големи движения",
        "Medium · smaller movements": "Средна · по-малки движения",
        "High · very small movements": "Висока · съвсем малки движения",
        "Sensitivity changed · start control again": "Чувствителността е сменена · пусни управлението отново",
        "Recenter": "Центрирай",
        "Point comfortably · cursor will start at the center": "Посочи удобно · курсорът ще започне от центъра",
        "Index tap": "Тапване с показалец",
        "Thumb + index pinch": "Палец + показалец",
        "Click gesture changed · start control again": "Жестът за клик е сменен · пусни управлението отново",
        "Index tap ready · thumb not needed": "Готов за тапване · палецът не участва",
        "Show your index and curled middle finger": "Покажи показалеца и свития среден пръст",
        "Move your hand to aim · bend your index to tap": "Мести ръката за курсора · свий показалеца за клик",
        "Moving only · keep the other fingers curled to tap": "Само движение · свий другите пръсти за тапване",
        "Bend your index, then straighten to tap": "Свий само показалеца надолу и го изправи за клик",
        "Cursor locked · bend only your index finger": "Курсорът е заключен · свий само показалеца",
        "Straighten your index finger → click": "Сега изправи показалеца → клик",
        "Tap cancelled · point at the target again": "Тапването е отменено · насочи курсора отново",
        "Tap too small or brief · no click": "Твърде кратко или слабо свиване · няма клик",
        "Hermes Portals · Mac Control": "Hermes Portals · Управление на Mac",
        "Portals · Live hand": "Portals · Ръката на живо",
        "Local camera gestures · works while other apps are in front": "Жестове през камерата · работи и в други приложения",
        "Your live camera and hand skeleton stay visible in a floating panel on the right.": "Камерата, ставите на ръката и указанията остават видими в панела вдясно.",
        "Show live hand": "Покажи ръката", "Start preview": "Само преглед",
        "Start Mac control": "Управлявай Mac", "Stop / Esc": "Стоп / Esc",
        "Controls": "Настройки", "Control display": "Управляван екран",
        "Request Accessibility…": "Разреши Accessibility…", "Show app in Finder": "Покажи във Finder",
        "Show controller": "Покажи настройките", "Stop — Escape": "Стоп — Escape", "Quit": "Изход",
        "LIVE HAND / ON THIS MAC": "РЪКАТА НА ЖИВО / ЛОКАЛНО",
        "Preview never sends Mac input. Video stays on this Mac; nothing is recorded. Closing this window keeps the menu bar controller running. Use Stop or Escape to finish.": "Прегледът не управлява Mac. Видеото остава тук и не се записва. Затварянето на настройките оставя приложението в менюто. Стоп или Escape спира управлението.",
        clickGuide: "КАК ДА КЛИКНЕШ\n1  Посочи целта и спри за момент.\n2  Допри върховете на палеца и показалеца.\n3  Раздели ги и посочи пак → клик.\nОстаналите пръсти са спокойно свити.",
        tapGuide: "ТАПВАНЕ С ПОКАЗАЛЕЦ\n1  Посочи удобно → начало в центъра.\n2  Мести бавно за точно прицелване.\n3  Свий показалеца надолу и нагоре → клик.\nДланта стои на място при тапване.\nПо-бързо движение → по-голям ход.\n„Центрирай“ задава нова удобна позиция.",
        instructions: "Покажи една ръка, заедно с китката.\n1  Задръж отворена длан за 1 секунда, за да започнеш.\n2  Движение: сочи с показалеца; другите пръсти са свити.\n3  Клик: следвай избрания жест в панела с камерата.\n4  Скрол: вдигни показалец + среден пръст и движи нагоре/надолу.\n5  Смяна на апове: задръж отворена длан, после плъзни.\nСлед изгубена ръка посочи пак; след юмрук отвори длан. Escape спира камерата и управлението.",
        "Camera": "Камера", "allowed": "разрешена", "not requested": "не е поискана", "not allowed": "няма достъп",
        "Camera off": "Камерата е изключена",
        "Camera off · choose Preview or Mac control": "Камерата е изключена · избери преглед или управление",
        "No mouse or app actions have been sent": "Още няма изпратени команди",
        "No input sent": "Няма изпратени команди", "No input sent in this session": "Още няма изпратени команди в тази проба",
        "Show one hand and wrist": "Покажи една ръка заедно с китката",
        "Show only one hand": "Покажи само една ръка",
        "Show your hand and wrist": "Покажи ръката и китката пред камерата",
        "Show your index fingertip and wrist": "Не виждам ясно показалеца или китката",
        "Moving only · show your thumb and curl the other fingers to click": "Само движение · покажи палеца и свий другите пръсти за клик",
        "Tracking unavailable · try Preview again": "Проследяването е недостъпно · пусни преглед отново",
        "Hold an open palm still to take control": "Задръж отворена длан за 1 секунда, за да започнеш",
        "Hold an open palm still for a moment": "Покажи отворена длан и задръж за 1 секунда",
        "Hold your palm still…": "Задръж дланта неподвижна…",
        "Hand not clear · hold an open palm to resume": "Ръката се загуби · покажи отворена длан, за да продължиш",
        "Ready · point, pinch, two fingers or palm swipe": "Готово · посочи с показалеца, за да движиш курсора",
        "Point · touch thumb to index, then separate to click": "За клик: допри палец и показалец, после ги раздели",
        "Release pinch to click": "Сега раздели палец и показалец → клик",
        "Point first, then pinch": "Първо посочи целта и спри, после допри палец и показалец",
        "Pinch cancelled": "Кликът е отменен · посочи целта отново",
        "Pinch too brief · no click": "Твърде кратък жест или неясно отпускане · няма клик",
        "Click": "Клик", "Single click sent": "Изпратен е един клик", "Scrolling": "Скролиране",
        "Two fingers · move up or down to scroll": "Два пръста · движи нагоре или надолу за скрол",
        "App switched · relax your fingers before another swipe": "Приложението е сменено · отпусни пръстите преди следващия жест",
        "Open palm · hold briefly, then swipe left or right": "Отворена длан · задръж за момент, после плъзни наляво/надясно",
        "Fist · hold still for one second to pause": "Юмрук · задръж неподвижно за 1 секунда за пауза",
        "Parked · hold an open palm to resume": "Пауза · задръж отворена длан, за да продължиш",
        "Show a clear pointing, two-finger or open-palm pose": "Посочи с един пръст, вдигни два или отвори дланта",
        "Preview only · Mac input is off": "Само преглед · управлението е изключено",
        "Preview only · no Mac input": "Само преглед · без управление",
        "Tracking delayed · control paused": "Проследяването закъснява · управлението е на пауза",
        "Tracking briefly unclear · keep your hand in view": "За момент не виждам ръката ясно · дръж я пред камерата",
        "Tracking restored · point to continue": "Отново виждам ръката · посочи, за да продължиш",
        "Tracking paused · point steadily to resume": "Проследяването е на пауза · посочи, за да продължиш",
        "Keep pointing · resuming movement…": "Продължи да сочиш · възстановявам движението…",
        "Waiting for camera frames · Mac input paused": "Изчаквам камерата · управлението е на пауза",
        "Camera off · preview cleared": "Камерата е изключена · прегледът е изчистен",
        "Starting camera…": "Пускам камерата…",
        "Stopped · camera and Mac input are off": "Спряно · камерата и управлението са изключени",
        "Stopped with Escape": "Спряно с Escape", "Stopped from Portals": "Спряно от Portals",
        "Live hand closed · camera and control stopped": "Панелът е затворен · камерата и управлението са спрени",
        "Stopped for sleep or session change": "Спряно при заспиване или смяна на сесията",
        "Display selected · start again to take control": "Екранът е избран · пусни управлението отново",
        "Display layout changed · choose a display and start again": "Екраните се промениха · избери екран и започни отново",
        "Accessibility permission is required": "Нужен е достъп Accessibility",
        "Mac control needs Accessibility permission. Use Request Accessibility below.": "За управление е нужен Accessibility. Натисни „Разреши Accessibility…“.",
        "Allow this app in Privacy & Security → Accessibility, then press Start Mac control.": "Разреши това приложение в Privacy & Security → Accessibility, после натисни „Управлявай Mac“.",
        "Accessibility permission is no longer available": "Достъпът Accessibility вече не е наличен",
        "Accessibility permission was removed · control stopped": "Достъпът Accessibility е отнет · управлението е спряно",
        "Accessibility permission was removed": "Достъпът Accessibility е отнет",
        "Camera permission was removed": "Достъпът до камерата е отнет",
        "Camera access was declined. Allow it in System Settings to use gestures.": "Достъпът до камерата е отказан. Разреши го в System Settings за жестове.",
        "Camera access is not allowed. Enable it in Privacy & Security → Camera.": "Няма достъп до камерата. Разреши го в Privacy & Security → Camera.",
        "Escape monitoring is unavailable. Reopen the app after allowing Accessibility.": "Escape не може да се следи. Отвори приложението отново след разрешаване на Accessibility.",
        "No camera available": "Няма налична камера", "Camera could not be configured": "Камерата не може да се настрои",
        "Camera did not start; check Camera permission": "Камерата не тръгна; провери разрешението",
        "Mouse event unavailable": "Командата за мишката е недостъпна",
        "No other app is running": "Няма друго отворено приложение", "App could not be activated": "Приложението не може да се отвори",
        "point": "сочене", "aim": "само движение", "pinch": "допрени палец и показалец", "scroll": "два пръста",
        "palm": "отворена длан", "fist": "юмрук", "unknown": "неясна поза", "no clear hand": "неясна ръка",
        "Off": "Изключено", "Waiting": "Изчаква", "Control": "Управление", "Preview": "Преглед",
    ]
}

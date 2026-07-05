import Foundation

enum HotelStayLocationCatalog {
    struct Country: Sendable {
        let code: String
        let zhHans: String
        let zhHant: String
        let english: String
        let ja: String
        let ko: String
        let aliases: [String]
        let cities: [City]

        nonisolated var localizedName: String {
            switch HotelStayLocationCatalog.languageKey {
            case "zh-Hant":
                return zhHant
            case "zh-Hans":
                return zhHans
            case "ja":
                return ja
            case "ko":
                return ko
            default:
                return english
            }
        }

        nonisolated func matches(_ value: String) -> Bool {
            let normalizedValue = HotelStayLocationCatalog.normalized(value)
            guard !normalizedValue.isEmpty else { return false }
            return ([code, zhHans, zhHant, english, ja, ko, localizedName] + aliases)
                .map(HotelStayLocationCatalog.normalized)
                .contains(normalizedValue)
        }

        nonisolated func localizedCityName(matching value: String) -> String? {
            cities.first { $0.matches(value) }?.localizedName
        }
    }

    struct City: Sendable {
        let english: String
        let zhHans: String
        let zhHant: String
        let ja: String
        let ko: String
        let aliases: [String]

        nonisolated var localizedName: String {
            switch HotelStayLocationCatalog.languageKey {
            case "zh-Hant":
                return zhHant
            case "zh-Hans":
                return zhHans
            case "ja":
                return ja
            case "ko":
                return ko
            default:
                return english
            }
        }

        nonisolated func matches(_ value: String) -> Bool {
            let normalizedValue = HotelStayLocationCatalog.normalized(value)
            guard !normalizedValue.isEmpty else { return false }
            return ([english, zhHans, zhHant, ja, ko, localizedName] + aliases)
                .map(HotelStayLocationCatalog.normalized)
                .contains(normalizedValue)
        }
    }

    nonisolated static func localizedLocation(city: String, country: String) -> (city: String, country: String) {
        let matchedCountry = self.country(matching: country) ?? self.country(containingCity: city)
        let localizedCountry = matchedCountry?.localizedName ?? country.trimmingCharacters(in: .whitespacesAndNewlines)
        let localizedCity = localizedCityName(matching: city, country: matchedCountry)
            ?? localizedCityName(matching: city)
            ?? city.trimmingCharacters(in: .whitespacesAndNewlines)
        return (localizedCity, localizedCountry)
    }

    nonisolated static func countryOptions() -> [String] {
        activeCountries.map(\.localizedName)
    }

    nonisolated static func cityOptions(for country: Country?) -> [String] {
        if let country {
            return country.cities.map(\.localizedName)
        }
        return fallbackCities.map(\.localizedName)
    }

    nonisolated static func country(matching value: String) -> Country? {
        activeCountries.first { $0.matches(value) }
    }

    nonisolated static func localizedCityName(matching value: String, country: Country? = nil) -> String? {
        if let country, let city = country.localizedCityName(matching: value) {
            return city
        }
        return activeCountries.lazy.compactMap { $0.localizedCityName(matching: value) }.first
    }

    nonisolated private static func country(containingCity value: String) -> Country? {
        activeCountries.first { country in
            country.cities.contains { $0.matches(value) }
        }
    }

    nonisolated private static var languageKey: String {
        let identifier = AppLanguagePreference.current.locale.identifier.lowercased()
        if identifier.hasPrefix("ko") {
            return "ko"
        }
        if identifier.hasPrefix("ja") {
            return "ja"
        }
        if identifier.contains("hant") || identifier.contains("_tw") || identifier.contains("_hk") || identifier.contains("_mo") {
            return "zh-Hant"
        }
        if identifier.hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }

    nonisolated private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "·", with: "")
            .lowercased()
    }

    nonisolated private static func city(
        _ english: String,
        zhHans: String,
        zhHant: String,
        ja: String,
        ko: String,
        aliases: [String] = []
    ) -> City {
        City(
            english: english,
            zhHans: zhHans,
            zhHant: zhHant,
            ja: ja,
            ko: ko,
            aliases: aliases
        )
    }

    nonisolated private static func country(
        _ code: String,
        zhHans: String,
        zhHant: String,
        english: String,
        ja: String,
        ko: String,
        aliases: [String] = [],
        cities: [City]
    ) -> Country {
        Country(
            code: code,
            zhHans: zhHans,
            zhHant: zhHant,
            english: english,
            ja: ja,
            ko: ko,
            aliases: aliases,
            cities: cities
        )
    }

    nonisolated private static var activeCountries: [Country] {
        guard let catalog = CommonAPICatalogService.cachedPlacesCatalog() else {
            return countries
        }

        let citiesByCountry = Dictionary(grouping: catalog.cities, by: \.countryCode)
        let mappedCountries = catalog.countries.map { country in
            let cities = (citiesByCountry[country.countryCode] ?? []).map { city in
                City(
                    english: city.names.en,
                    zhHans: city.names.zhHans,
                    zhHant: city.names.zhHant,
                    ja: city.names.ja,
                    ko: city.names.ko,
                    aliases: [city.id] + remoteCityAliasExtras[city.id, default: []]
                )
            }
            return Country(
                code: country.countryCode,
                zhHans: country.names.zhHans,
                zhHant: country.names.zhHant,
                english: country.names.en,
                ja: country.names.ja,
                ko: country.names.ko,
                aliases: [country.id] + remoteCountryAliasExtras[country.countryCode, default: []],
                cities: cities
            )
        }

        return mappedCountries.isEmpty ? countries : mappedCountries
    }

    nonisolated private static let remoteCountryAliasExtras: [String: [String]] = [
        "CN": ["Mainland China", "PRC"],
        "MO": ["Macao"],
        "KR": ["Korea"],
        "US": ["United States of America", "USA", "US"],
        "GB": ["UK", "Great Britain"],
        "AE": ["UAE"]
    ]

    nonisolated private static let remoteCityAliasExtras: [String: [String]] = [
        "city.cn.xian": ["Xian"],
        "city.mo.macau": ["Macao"],
        "city.us.new-york": ["NYC"],
        "city.us.washington": ["Washington DC", "Washington, DC"]
    ]

    nonisolated private static let countries: [Country] = [
        country(
            "CN",
            zhHans: "中国",
            zhHant: "中國",
            english: "China",
            ja: "中国",
            ko: "중국", aliases: ["Mainland China", "PRC"],
            cities: [
            city("Beijing", zhHans: "北京", zhHant: "北京", ja: "北京", ko: "베이징"),
            city("Shanghai", zhHans: "上海", zhHant: "上海", ja: "上海", ko: "상하이"),
            city("Guangzhou", zhHans: "广州", zhHant: "廣州", ja: "広州", ko: "광저우"),
            city("Shenzhen", zhHans: "深圳", zhHant: "深圳", ja: "深セン", ko: "선전"),
            city("Chongqing", zhHans: "重庆", zhHant: "重慶", ja: "重慶", ko: "충칭"),
            city("Chengdu", zhHans: "成都", zhHant: "成都", ja: "成都", ko: "청두"),
            city("Hangzhou", zhHans: "杭州", zhHant: "杭州", ja: "杭州", ko: "항저우"),
            city("Nanjing", zhHans: "南京", zhHant: "南京", ja: "南京", ko: "난징"),
            city("Tianjin", zhHans: "天津", zhHant: "天津", ja: "天津", ko: "톈진"),
            city("Xi'an", zhHans: "西安", zhHant: "西安", ja: "西安", ko: "시안", aliases: ["Xian"]),
            city("Wuhan", zhHans: "武汉", zhHant: "武漢", ja: "武漢", ko: "우한"),
            city("Suzhou", zhHans: "苏州", zhHant: "蘇州", ja: "蘇州", ko: "쑤저우"),
            city("Qingdao", zhHans: "青岛", zhHant: "青島", ja: "青島", ko: "칭다오"),
            city("Xiamen", zhHans: "厦门", zhHant: "廈門", ja: "厦門", ko: "샤먼"),
            city("Sanya", zhHans: "三亚", zhHant: "三亞", ja: "三亜", ko: "싼야")
            ]
        ),
        country(
            "HK",
            zhHans: "香港（中国）",
            zhHant: "香港（中國）",
            english: "Hong Kong (China)",
            ja: "香港（中国）",
            ko: "홍콩(중국)",
            aliases: ["中国香港", "中國香港", "Hong Kong", "香港", "홍콩"],
            cities: [
            city("Hong Kong", zhHans: "香港", zhHant: "香港", ja: "香港", ko: "홍콩")
            ]
        ),
        country(
            "MO",
            zhHans: "澳门（中国）",
            zhHant: "澳門（中國）",
            english: "Macau (China)",
            ja: "マカオ（中国）",
            ko: "마카오(중국)",
            aliases: ["中国澳门", "中國澳門", "Macau", "Macao", "澳门", "澳門", "マカオ", "마카오"],
            cities: [
            city("Macau", zhHans: "澳门", zhHant: "澳門", ja: "マカオ", ko: "마카오", aliases: ["Macao"])
            ]
        ),
        country(
            "TW",
            zhHans: "台湾（中国）",
            zhHant: "台灣（中國）",
            english: "Taiwan (China)",
            ja: "台湾（中国）",
            ko: "대만(중국)",
            aliases: ["中国台湾", "中國台灣", "Taiwan", "台湾", "台灣", "대만"],
            cities: [
            city("Taipei", zhHans: "台北", zhHant: "台北", ja: "台北", ko: "타이베이"),
            city("Taichung", zhHans: "台中", zhHant: "台中", ja: "台中", ko: "타이중"),
            city("Kaohsiung", zhHans: "高雄", zhHant: "高雄", ja: "高雄", ko: "가오슝"),
            city("Tainan", zhHans: "台南", zhHant: "台南", ja: "台南", ko: "타이난")
            ]
        ),
        country(
            "JP",
            zhHans: "日本",
            zhHant: "日本",
            english: "Japan",
            ja: "日本",
            ko: "일본",
            cities: [
            city("Tokyo", zhHans: "东京", zhHant: "東京", ja: "東京", ko: "도쿄"),
            city("Osaka", zhHans: "大阪", zhHant: "大阪", ja: "大阪", ko: "오사카"),
            city("Kyoto", zhHans: "京都", zhHant: "京都", ja: "京都", ko: "교토"),
            city("Yokohama", zhHans: "横滨", zhHant: "橫濱", ja: "横浜", ko: "요코하마"),
            city("Nagoya", zhHans: "名古屋", zhHant: "名古屋", ja: "名古屋", ko: "나고야"),
            city("Fukuoka", zhHans: "福冈", zhHant: "福岡", ja: "福岡", ko: "후쿠오카"),
            city("Sapporo", zhHans: "札幌", zhHant: "札幌", ja: "札幌", ko: "삿포로"),
            city("Naha", zhHans: "那霸", zhHant: "那霸", ja: "那覇", ko: "나하")
            ]
        ),
        country(
            "KR",
            zhHans: "韩国",
            zhHant: "韓國",
            english: "South Korea",
            ja: "韓国",
            ko: "대한민국", aliases: ["Korea"],
            cities: [
            city("Seoul", zhHans: "首尔", zhHant: "首爾", ja: "ソウル", ko: "서울"),
            city("Busan", zhHans: "釜山", zhHant: "釜山", ja: "釜山", ko: "부산"),
            city("Incheon", zhHans: "仁川", zhHant: "仁川", ja: "仁川", ko: "인천"),
            city("Jeju", zhHans: "济州", zhHant: "濟州", ja: "済州", ko: "제주"),
            city("Daegu", zhHans: "大邱", zhHant: "大邱", ja: "大邱", ko: "대구")
            ]
        ),
        country(
            "SG",
            zhHans: "新加坡",
            zhHant: "新加坡",
            english: "Singapore",
            ja: "シンガポール",
            ko: "싱가포르",
            cities: [
            city("Singapore", zhHans: "新加坡", zhHant: "新加坡", ja: "シンガポール", ko: "싱가포르")
            ]
        ),
        country(
            "TH",
            zhHans: "泰国",
            zhHant: "泰國",
            english: "Thailand",
            ja: "タイ",
            ko: "태국",
            cities: [
            city("Bangkok", zhHans: "曼谷", zhHant: "曼谷", ja: "バンコク", ko: "방콕"),
            city("Phuket", zhHans: "普吉", zhHant: "普吉", ja: "プーケット", ko: "푸켓"),
            city("Chiang Mai", zhHans: "清迈", zhHant: "清邁", ja: "チェンマイ", ko: "치앙마이"),
            city("Pattaya", zhHans: "芭提雅", zhHant: "芭達雅", ja: "パタヤ", ko: "파타야")
            ]
        ),
        country(
            "MY",
            zhHans: "马来西亚",
            zhHant: "馬來西亞",
            english: "Malaysia",
            ja: "マレーシア",
            ko: "말레이시아",
            cities: [
            city("Kuala Lumpur", zhHans: "吉隆坡", zhHant: "吉隆坡", ja: "クアラルンプール", ko: "쿠알라룸푸르"),
            city("Penang", zhHans: "槟城", zhHant: "檳城", ja: "ペナン", ko: "페낭"),
            city("Johor Bahru", zhHans: "新山", zhHant: "新山", ja: "ジョホールバル", ko: "조호르바루"),
            city("Kota Kinabalu", zhHans: "亚庇", zhHant: "亞庇", ja: "コタキナバル", ko: "코타키나발루")
            ]
        ),
        country(
            "ID",
            zhHans: "印度尼西亚",
            zhHant: "印尼",
            english: "Indonesia",
            ja: "インドネシア",
            ko: "인도네시아",
            cities: [
            city("Jakarta", zhHans: "雅加达", zhHant: "雅加達", ja: "ジャカルタ", ko: "자카르타"),
            city("Bali", zhHans: "巴厘岛", zhHant: "峇里島", ja: "バリ", ko: "발리"),
            city("Surabaya", zhHans: "泗水", zhHant: "泗水", ja: "スラバヤ", ko: "수라바야")
            ]
        ),
        country(
            "VN",
            zhHans: "越南",
            zhHant: "越南",
            english: "Vietnam",
            ja: "ベトナム",
            ko: "베트남",
            cities: [
            city("Ho Chi Minh City", zhHans: "胡志明市", zhHant: "胡志明市", ja: "ホーチミン", ko: "호찌민"),
            city("Hanoi", zhHans: "河内", zhHant: "河內", ja: "ハノイ", ko: "하노이"),
            city("Da Nang", zhHans: "岘港", zhHant: "峴港", ja: "ダナン", ko: "다낭")
            ]
        ),
        country(
            "PH",
            zhHans: "菲律宾",
            zhHant: "菲律賓",
            english: "Philippines",
            ja: "フィリピン",
            ko: "필리핀",
            cities: [
            city("Manila", zhHans: "马尼拉", zhHant: "馬尼拉", ja: "マニラ", ko: "마닐라"),
            city("Cebu", zhHans: "宿务", zhHant: "宿霧", ja: "セブ", ko: "세부")
            ]
        ),
        country(
            "US",
            zhHans: "美国",
            zhHant: "美國",
            english: "United States",
            ja: "アメリカ",
            ko: "미국", aliases: ["United States of America", "USA", "US"],
            cities: [
            city("New York", zhHans: "纽约", zhHant: "紐約", ja: "ニューヨーク", ko: "뉴욕", aliases: ["NYC"]),
            city("Los Angeles", zhHans: "洛杉矶", zhHant: "洛杉磯", ja: "ロサンゼルス", ko: "로스앤젤레스"),
            city("San Francisco", zhHans: "旧金山", zhHant: "舊金山", ja: "サンフランシスコ", ko: "샌프란시스코"),
            city("Las Vegas", zhHans: "拉斯维加斯", zhHant: "拉斯維加斯", ja: "ラスベガス", ko: "라스베이거스"),
            city("Seattle", zhHans: "西雅图", zhHant: "西雅圖", ja: "シアトル", ko: "시애틀"),
            city("Chicago", zhHans: "芝加哥", zhHant: "芝加哥", ja: "シカゴ", ko: "시카고"),
            city("Boston", zhHans: "波士顿", zhHant: "波士頓", ja: "ボストン", ko: "보스턴"),
            city("Washington, DC", zhHans: "华盛顿", zhHant: "華盛頓", ja: "ワシントンD.C.", ko: "워싱턴 D.C.", aliases: ["Washington DC", "Washington, DC"]),
            city("Miami", zhHans: "迈阿密", zhHant: "邁阿密", ja: "マイアミ", ko: "마이애미"),
            city("Orlando", zhHans: "奥兰多", zhHant: "奧蘭多", ja: "オーランド", ko: "올랜도")
            ]
        ),
        country(
            "GB",
            zhHans: "英国",
            zhHant: "英國",
            english: "United Kingdom",
            ja: "イギリス",
            ko: "영국", aliases: ["UK", "Great Britain"],
            cities: [
            city("London", zhHans: "伦敦", zhHant: "倫敦", ja: "ロンドン", ko: "런던"),
            city("Manchester", zhHans: "曼彻斯特", zhHant: "曼徹斯特", ja: "マンチェスター", ko: "맨체스터"),
            city("Edinburgh", zhHans: "爱丁堡", zhHant: "愛丁堡", ja: "エディンバラ", ko: "에든버러"),
            city("Birmingham", zhHans: "伯明翰", zhHant: "伯明罕", ja: "バーミンガム", ko: "버밍엄")
            ]
        ),
        country(
            "FR",
            zhHans: "法国",
            zhHant: "法國",
            english: "France",
            ja: "フランス",
            ko: "프랑스",
            cities: [
            city("Paris", zhHans: "巴黎", zhHant: "巴黎", ja: "パリ", ko: "파리"),
            city("Nice", zhHans: "尼斯", zhHant: "尼斯", ja: "ニース", ko: "니스"),
            city("Lyon", zhHans: "里昂", zhHant: "里昂", ja: "リヨン", ko: "리옹"),
            city("Marseille", zhHans: "马赛", zhHant: "馬賽", ja: "マルセイユ", ko: "마르세유")
            ]
        ),
        country(
            "DE",
            zhHans: "德国",
            zhHant: "德國",
            english: "Germany",
            ja: "ドイツ",
            ko: "독일",
            cities: [
            city("Berlin", zhHans: "柏林", zhHant: "柏林", ja: "ベルリン", ko: "베를린"),
            city("Munich", zhHans: "慕尼黑", zhHant: "慕尼黑", ja: "ミュンヘン", ko: "뮌헨"),
            city("Frankfurt", zhHans: "法兰克福", zhHant: "法蘭克福", ja: "フランクフルト", ko: "프랑크푸르트"),
            city("Hamburg", zhHans: "汉堡", zhHant: "漢堡", ja: "ハンブルク", ko: "함부르크")
            ]
        ),
        country(
            "IT",
            zhHans: "意大利",
            zhHant: "義大利",
            english: "Italy",
            ja: "イタリア",
            ko: "이탈리아",
            cities: [
            city("Rome", zhHans: "罗马", zhHant: "羅馬", ja: "ローマ", ko: "로마"),
            city("Milan", zhHans: "米兰", zhHant: "米蘭", ja: "ミラノ", ko: "밀라노"),
            city("Venice", zhHans: "威尼斯", zhHant: "威尼斯", ja: "ヴェネツィア", ko: "베네치아"),
            city("Florence", zhHans: "佛罗伦萨", zhHant: "佛羅倫斯", ja: "フィレンツェ", ko: "피렌체")
            ]
        ),
        country(
            "ES",
            zhHans: "西班牙",
            zhHant: "西班牙",
            english: "Spain",
            ja: "スペイン",
            ko: "스페인",
            cities: [
            city("Madrid", zhHans: "马德里", zhHant: "馬德里", ja: "マドリード", ko: "마드리드"),
            city("Barcelona", zhHans: "巴塞罗那", zhHant: "巴塞隆納", ja: "バルセロナ", ko: "바르셀로나"),
            city("Seville", zhHans: "塞维利亚", zhHant: "塞維利亞", ja: "セビリア", ko: "세비야"),
            city("Valencia", zhHans: "瓦伦西亚", zhHant: "瓦倫西亞", ja: "バレンシア", ko: "발렌시아")
            ]
        ),
        country(
            "NL",
            zhHans: "荷兰",
            zhHant: "荷蘭",
            english: "Netherlands",
            ja: "オランダ",
            ko: "네덜란드",
            cities: [
            city("Amsterdam", zhHans: "阿姆斯特丹", zhHant: "阿姆斯特丹", ja: "アムステルダム", ko: "암스테르담"),
            city("Rotterdam", zhHans: "鹿特丹", zhHant: "鹿特丹", ja: "ロッテルダム", ko: "로테르담")
            ]
        ),
        country(
            "CH",
            zhHans: "瑞士",
            zhHant: "瑞士",
            english: "Switzerland",
            ja: "スイス",
            ko: "스위스",
            cities: [
            city("Zurich", zhHans: "苏黎世", zhHant: "蘇黎世", ja: "チューリッヒ", ko: "취리히"),
            city("Geneva", zhHans: "日内瓦", zhHant: "日內瓦", ja: "ジュネーブ", ko: "제네바"),
            city("Lucerne", zhHans: "卢塞恩", zhHant: "琉森", ja: "ルツェルン", ko: "루체른")
            ]
        ),
        country(
            "AT",
            zhHans: "奥地利",
            zhHant: "奧地利",
            english: "Austria",
            ja: "オーストリア",
            ko: "오스트리아",
            cities: [
            city("Vienna", zhHans: "维也纳", zhHant: "維也納", ja: "ウィーン", ko: "빈"),
            city("Salzburg", zhHans: "萨尔茨堡", zhHant: "薩爾斯堡", ja: "ザルツブルク", ko: "잘츠부르크")
            ]
        ),
        country(
            "AU",
            zhHans: "澳大利亚",
            zhHant: "澳洲",
            english: "Australia",
            ja: "オーストラリア",
            ko: "호주",
            cities: [
            city("Sydney", zhHans: "悉尼", zhHant: "雪梨", ja: "シドニー", ko: "시드니"),
            city("Melbourne", zhHans: "墨尔本", zhHant: "墨爾本", ja: "メルボルン", ko: "멜버른"),
            city("Brisbane", zhHans: "布里斯班", zhHant: "布里斯本", ja: "ブリスベン", ko: "브리즈번"),
            city("Perth", zhHans: "珀斯", zhHant: "伯斯", ja: "パース", ko: "퍼스")
            ]
        ),
        country(
            "CA",
            zhHans: "加拿大",
            zhHant: "加拿大",
            english: "Canada",
            ja: "カナダ",
            ko: "캐나다",
            cities: [
            city("Toronto", zhHans: "多伦多", zhHant: "多倫多", ja: "トロント", ko: "토론토"),
            city("Vancouver", zhHans: "温哥华", zhHant: "溫哥華", ja: "バンクーバー", ko: "밴쿠버"),
            city("Montreal", zhHans: "蒙特利尔", zhHant: "蒙特婁", ja: "モントリオール", ko: "몬트리올"),
            city("Calgary", zhHans: "卡尔加里", zhHant: "卡加利", ja: "カルガリー", ko: "캘거리")
            ]
        ),
        country(
            "AE",
            zhHans: "阿联酋",
            zhHant: "阿聯酋",
            english: "United Arab Emirates",
            ja: "アラブ首長国連邦",
            ko: "아랍에미리트", aliases: ["UAE"],
            cities: [
            city("Dubai", zhHans: "迪拜", zhHant: "杜拜", ja: "ドバイ", ko: "두바이"),
            city("Abu Dhabi", zhHans: "阿布扎比", zhHant: "阿布達比", ja: "アブダビ", ko: "아부다비")
            ]
        )
    ]

    nonisolated private static var fallbackCities: [City] {
        activeCountries.flatMap(\.cities).prefix(32).map { $0 }
    }
}

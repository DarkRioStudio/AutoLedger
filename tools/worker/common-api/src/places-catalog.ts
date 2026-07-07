export const supportedLocales = ["zh-Hans", "zh-Hant", "en", "ja", "ko"] as const;

export type SupportedLocale = (typeof supportedLocales)[number];
export type LocalizedText = Record<SupportedLocale, string>;
export type PlaceTag = "capital" | "tourism" | "hotel" | "business" | "transit" | "resort" | "municipality" | "district";

export type CountryRecord = {
  id: string;
  countryCode: string;
  names: LocalizedText;
  defaultCurrencyCode: string;
  tags: PlaceTag[];
};

export type CityRecord = {
  id: string;
  countryCode: string;
  names: LocalizedText;
  latitude: number;
  longitude: number;
  timezone: string;
  tags: PlaceTag[];
  administrativeLevel?: "city" | "district";
  parentId?: string;
};

type DistrictDefinition = {
  slug: string;
  names: readonly [string, string, string, string, string];
  latitude: number;
  longitude: number;
  tags: PlaceTag[];
};

export const placeCatalogSchemaVersion = 1;
export const placeCatalogResourceVersion = "2026.07.07.1";
export const placeCatalogGeneratedAt = "2026-07-07T06:00:00.000Z";

export const countries = [
  country("country.cn", "CN", ["中国", "中國", "China", "中国", "중국"], "CNY", ["capital", "tourism", "hotel"]),
  country("country.hk", "HK", ["香港（中国）", "香港（中國）", "Hong Kong (China)", "香港（中国）", "홍콩(중국)"], "HKD", ["tourism", "hotel", "business"]),
  country("country.mo", "MO", ["澳门（中国）", "澳門（中國）", "Macau (China)", "マカオ（中国）", "마카오(중국)"], "MOP", ["tourism", "hotel"]),
  country("country.tw", "TW", ["台湾（中国）", "台灣（中國）", "Taiwan (China)", "台湾（中国）", "대만(중국)"], "TWD", ["tourism", "hotel"]),
  country("country.jp", "JP", ["日本", "日本", "Japan", "日本", "일본"], "JPY", ["tourism", "hotel"]),
  country("country.kr", "KR", ["韩国", "韓國", "South Korea", "韓国", "대한민국"], "KRW", ["tourism", "hotel"]),
  country("country.sg", "SG", ["新加坡", "新加坡", "Singapore", "シンガポール", "싱가포르"], "SGD", ["tourism", "hotel", "business"]),
  country("country.th", "TH", ["泰国", "泰國", "Thailand", "タイ", "태국"], "THB", ["tourism", "hotel", "resort"]),
  country("country.my", "MY", ["马来西亚", "馬來西亞", "Malaysia", "マレーシア", "말레이시아"], "MYR", ["tourism", "hotel"]),
  country("country.id", "ID", ["印度尼西亚", "印尼", "Indonesia", "インドネシア", "인도네시아"], "IDR", ["tourism", "hotel", "resort"]),
  country("country.vn", "VN", ["越南", "越南", "Vietnam", "ベトナム", "베트남"], "VND", ["tourism", "hotel"]),
  country("country.ph", "PH", ["菲律宾", "菲律賓", "Philippines", "フィリピン", "필리핀"], "PHP", ["tourism", "hotel"]),
  country("country.us", "US", ["美国", "美國", "United States", "アメリカ", "미국"], "USD", ["tourism", "hotel", "business"]),
  country("country.gb", "GB", ["英国", "英國", "United Kingdom", "イギリス", "영국"], "GBP", ["tourism", "hotel", "business"]),
  country("country.fr", "FR", ["法国", "法國", "France", "フランス", "프랑스"], "EUR", ["tourism", "hotel"]),
  country("country.de", "DE", ["德国", "德國", "Germany", "ドイツ", "독일"], "EUR", ["tourism", "hotel", "business"]),
  country("country.it", "IT", ["意大利", "義大利", "Italy", "イタリア", "이탈리아"], "EUR", ["tourism", "hotel"]),
  country("country.es", "ES", ["西班牙", "西班牙", "Spain", "スペイン", "스페인"], "EUR", ["tourism", "hotel"]),
  country("country.nl", "NL", ["荷兰", "荷蘭", "Netherlands", "オランダ", "네덜란드"], "EUR", ["tourism", "hotel", "business"]),
  country("country.ch", "CH", ["瑞士", "瑞士", "Switzerland", "スイス", "스위스"], "CHF", ["tourism", "hotel"]),
  country("country.at", "AT", ["奥地利", "奧地利", "Austria", "オーストリア", "오스트리아"], "EUR", ["tourism", "hotel"]),
  country("country.au", "AU", ["澳大利亚", "澳洲", "Australia", "オーストラリア", "호주"], "AUD", ["tourism", "hotel"]),
  country("country.ca", "CA", ["加拿大", "加拿大", "Canada", "カナダ", "캐나다"], "CAD", ["tourism", "hotel"]),
  country("country.ae", "AE", ["阿联酋", "阿聯酋", "United Arab Emirates", "アラブ首長国連邦", "아랍에미리트"], "AED", ["tourism", "hotel", "business"])
] satisfies CountryRecord[];

export const cities = [
  city("city.cn.beijing", "CN", ["北京", "北京", "Beijing", "北京", "베이징"], 39.9042, 116.4074, "Asia/Shanghai", ["capital", "hotel", "business", "municipality"]),
  ...municipalityDistricts("city.cn.beijing", "CN", ["北京", "北京", "Beijing", "北京", "베이징"], "Asia/Shanghai", [
    district("dongcheng", ["东城区", "東城區", "Dongcheng District", "東城区", "둥청구"], 39.9289, 116.4164, ["capital", "hotel"]),
    district("xicheng", ["西城区", "西城區", "Xicheng District", "西城区", "시청구"], 39.9123, 116.3659, ["capital", "hotel"]),
    district("chaoyang", ["朝阳区", "朝陽區", "Chaoyang District", "朝陽区", "차오양구"], 39.9215, 116.4431, ["business", "hotel"]),
    district("fengtai", ["丰台区", "豐台區", "Fengtai District", "豊台区", "펑타이구"], 39.8584, 116.2867, ["hotel"]),
    district("shijingshan", ["石景山区", "石景山區", "Shijingshan District", "石景山区", "스징산구"], 39.9066, 116.2229, ["hotel"]),
    district("haidian", ["海淀区", "海淀區", "Haidian District", "海淀区", "하이뎬구"], 39.9599, 116.2981, ["business", "hotel"]),
    district("mentougou", ["门头沟区", "門頭溝區", "Mentougou District", "門頭溝区", "먼터우거우구"], 39.9404, 116.1017, ["tourism"]),
    district("fangshan", ["房山区", "房山區", "Fangshan District", "房山区", "팡산구"], 39.7479, 116.1433, ["tourism"]),
    district("tongzhou", ["通州区", "通州區", "Tongzhou District", "通州区", "퉁저우구"], 39.9025, 116.6564, ["hotel"]),
    district("shunyi", ["顺义区", "順義區", "Shunyi District", "順義区", "순이구"], 40.1302, 116.6547, ["transit", "hotel"]),
    district("changping", ["昌平区", "昌平區", "Changping District", "昌平区", "창핑구"], 40.2207, 116.2312, ["hotel"]),
    district("daxing", ["大兴区", "大興區", "Daxing District", "大興区", "다싱구"], 39.7289, 116.3414, ["transit", "hotel"]),
    district("huairou", ["怀柔区", "懷柔區", "Huairou District", "懐柔区", "화이러우구"], 40.316, 116.632, ["tourism"]),
    district("pinggu", ["平谷区", "平谷區", "Pinggu District", "平谷区", "핑구구"], 40.1406, 117.1214, ["tourism"]),
    district("miyun", ["密云区", "密雲區", "Miyun District", "密雲区", "미윈구"], 40.3774, 116.843, ["tourism"]),
    district("yanqing", ["延庆区", "延慶區", "Yanqing District", "延慶区", "옌칭구"], 40.4567, 115.9749, ["tourism"])
  ]),
  city("city.cn.shanghai", "CN", ["上海", "上海", "Shanghai", "上海", "상하이"], 31.2304, 121.4737, "Asia/Shanghai", ["tourism", "hotel", "business", "municipality"]),
  ...municipalityDistricts("city.cn.shanghai", "CN", ["上海", "上海", "Shanghai", "上海", "상하이"], "Asia/Shanghai", [
    district("huangpu", ["黄浦区", "黃浦區", "Huangpu District", "黄浦区", "황푸구"], 31.2317, 121.4846, ["tourism", "hotel", "business"]),
    district("xuhui", ["徐汇区", "徐匯區", "Xuhui District", "徐匯区", "쉬후이구"], 31.1885, 121.4368, ["hotel", "business"]),
    district("changning", ["长宁区", "長寧區", "Changning District", "長寧区", "창닝구"], 31.2204, 121.4246, ["hotel", "business"]),
    district("jingan", ["静安区", "靜安區", "Jing'an District", "静安区", "징안구"], 31.229, 121.4598, ["hotel", "business"]),
    district("putuo", ["普陀区", "普陀區", "Putuo District", "普陀区", "푸퉈구"], 31.2495, 121.3955, ["hotel"]),
    district("hongkou", ["虹口区", "虹口區", "Hongkou District", "虹口区", "훙커우구"], 31.2646, 121.5051, ["hotel"]),
    district("yangpu", ["杨浦区", "楊浦區", "Yangpu District", "楊浦区", "양푸구"], 31.2596, 121.526, ["hotel", "business"]),
    district("minhang", ["闵行区", "閔行區", "Minhang District", "閔行区", "민항구"], 31.1128, 121.3817, ["hotel", "business"]),
    district("baoshan", ["宝山区", "寶山區", "Baoshan District", "宝山区", "바오산구"], 31.4055, 121.4899, ["hotel"]),
    district("jiading", ["嘉定区", "嘉定區", "Jiading District", "嘉定区", "자딩구"], 31.3756, 121.2653, ["hotel"]),
    district("pudong", ["浦东新区", "浦東新區", "Pudong New Area", "浦東新区", "푸둥신구"], 31.2215, 121.5447, ["transit", "hotel", "business"]),
    district("jinshan", ["金山区", "金山區", "Jinshan District", "金山区", "진산구"], 30.7419, 121.3416, ["hotel"]),
    district("songjiang", ["松江区", "松江區", "Songjiang District", "松江区", "쑹장구"], 31.0326, 121.2277, ["tourism", "hotel"]),
    district("qingpu", ["青浦区", "青浦區", "Qingpu District", "青浦区", "칭푸구"], 31.1512, 121.1242, ["tourism", "hotel"]),
    district("fengxian", ["奉贤区", "奉賢區", "Fengxian District", "奉賢区", "펑셴구"], 30.9184, 121.474, ["hotel"]),
    district("chongming", ["崇明区", "崇明區", "Chongming District", "崇明区", "충밍구"], 31.6236, 121.3975, ["tourism"])
  ]),
  city("city.cn.guangzhou", "CN", ["广州", "廣州", "Guangzhou", "広州", "광저우"], 23.1291, 113.2644, "Asia/Shanghai", ["hotel", "business"]),
  city("city.cn.shenzhen", "CN", ["深圳", "深圳", "Shenzhen", "深セン", "선전"], 22.5431, 114.0579, "Asia/Shanghai", ["hotel", "business"]),
  city("city.cn.chongqing", "CN", ["重庆", "重慶", "Chongqing", "重慶", "충칭"], 29.563, 106.5516, "Asia/Shanghai", ["tourism", "hotel", "municipality"]),
  ...municipalityDistricts("city.cn.chongqing", "CN", ["重庆", "重慶", "Chongqing", "重慶", "충칭"], "Asia/Shanghai", [
    district("yuzhong", ["渝中区", "渝中區", "Yuzhong District", "渝中区", "위중구"], 29.5528, 106.5689, ["business", "hotel"]),
    district("dadukou", ["大渡口区", "大渡口區", "Dadukou District", "大渡口区", "다두커우구"], 29.4844, 106.4823, ["hotel"]),
    district("jiangbei", ["江北区", "江北區", "Jiangbei District", "江北区", "장베이구"], 29.6066, 106.5743, ["business", "hotel"]),
    district("shapingba", ["沙坪坝区", "沙坪壩區", "Shapingba District", "沙坪壩区", "사핑바구"], 29.5412, 106.4574, ["hotel"]),
    district("jiulongpo", ["九龙坡区", "九龍坡區", "Jiulongpo District", "九龍坡区", "주룽포구"], 29.5023, 106.5111, ["hotel"]),
    district("nanan", ["南岸区", "南岸區", "Nan'an District", "南岸区", "난안구"], 29.5231, 106.6449, ["tourism", "hotel"]),
    district("beibei", ["北碚区", "北碚區", "Beibei District", "北碚区", "베이베이구"], 29.805, 106.3956, ["tourism", "hotel"]),
    district("yubei", ["渝北区", "渝北區", "Yubei District", "渝北区", "위베이구"], 29.7181, 106.6312, ["transit", "hotel", "business"]),
    district("banan", ["巴南区", "巴南區", "Banan District", "巴南区", "바난구"], 29.4027, 106.5404, ["hotel"]),
    district("wanzhou", ["万州区", "萬州區", "Wanzhou District", "万州区", "완저우구"], 30.8078, 108.4087, ["hotel"]),
    district("qianjiang", ["黔江区", "黔江區", "Qianjiang District", "黔江区", "첸장구"], 29.5332, 108.7707, ["tourism", "hotel"]),
    district("fuling", ["涪陵区", "涪陵區", "Fuling District", "涪陵区", "푸링구"], 29.7031, 107.3893, ["hotel"]),
    district("changshou", ["长寿区", "長壽區", "Changshou District", "長寿区", "창서우구"], 29.8579, 107.0817, ["hotel"]),
    district("jiangjin", ["江津区", "江津區", "Jiangjin District", "江津区", "장진구"], 29.2901, 106.2596, ["hotel"]),
    district("hechuan", ["合川区", "合川區", "Hechuan District", "合川区", "허촨구"], 29.9721, 106.2763, ["hotel"]),
    district("yongchuan", ["永川区", "永川區", "Yongchuan District", "永川区", "융촨구"], 29.356, 105.9274, ["hotel"]),
    district("nanchuan", ["南川区", "南川區", "Nanchuan District", "南川区", "난촨구"], 29.1579, 107.0989, ["tourism", "hotel"]),
    district("qijiang", ["綦江区", "綦江區", "Qijiang District", "綦江区", "치장구"], 29.0281, 106.6514, ["hotel"]),
    district("dazu", ["大足区", "大足區", "Dazu District", "大足区", "다쭈구"], 29.7005, 105.7153, ["tourism", "hotel"]),
    district("bishan", ["璧山区", "璧山區", "Bishan District", "璧山区", "비산구"], 29.5936, 106.2273, ["hotel"]),
    district("tongliang", ["铜梁区", "銅梁區", "Tongliang District", "銅梁区", "퉁량구"], 29.8399, 106.0564, ["hotel"]),
    district("tongnan", ["潼南区", "潼南區", "Tongnan District", "潼南区", "퉁난구"], 30.191, 105.8406, ["hotel"]),
    district("rongchang", ["荣昌区", "榮昌區", "Rongchang District", "栄昌区", "룽창구"], 29.4049, 105.5945, ["hotel"]),
    district("kaizhou", ["开州区", "開州區", "Kaizhou District", "開州区", "카이저우구"], 31.1607, 108.3931, ["hotel"]),
    district("liangping", ["梁平区", "梁平區", "Liangping District", "梁平区", "량핑구"], 30.6737, 107.8, ["hotel"]),
    district("wulong", ["武隆区", "武隆區", "Wulong District", "武隆区", "우룽구"], 29.3257, 107.7599, ["tourism", "hotel"])
  ]),
  city("city.cn.chengdu", "CN", ["成都", "成都", "Chengdu", "成都", "청두"], 30.5728, 104.0668, "Asia/Shanghai", ["tourism", "hotel"]),
  city("city.cn.hangzhou", "CN", ["杭州", "杭州", "Hangzhou", "杭州", "항저우"], 30.2741, 120.1551, "Asia/Shanghai", ["tourism", "hotel", "business"]),
  city("city.cn.nanjing", "CN", ["南京", "南京", "Nanjing", "南京", "난징"], 32.0603, 118.7969, "Asia/Shanghai", ["tourism", "hotel"]),
  city("city.cn.tianjin", "CN", ["天津", "天津", "Tianjin", "天津", "톈진"], 39.3434, 117.3616, "Asia/Shanghai", ["hotel", "business", "municipality"]),
  ...municipalityDistricts("city.cn.tianjin", "CN", ["天津", "天津", "Tianjin", "天津", "톈진"], "Asia/Shanghai", [
    district("heping", ["和平区", "和平區", "Heping District", "和平区", "허핑구"], 39.1172, 117.2145, ["business", "hotel"]),
    district("hedong", ["河东区", "河東區", "Hedong District", "河東区", "허둥구"], 39.1283, 117.2517, ["hotel"]),
    district("hexi", ["河西区", "河西區", "Hexi District", "河西区", "허시구"], 39.1096, 117.2234, ["business", "hotel"]),
    district("nankai", ["南开区", "南開區", "Nankai District", "南開区", "난카이구"], 39.1382, 117.1507, ["hotel"]),
    district("hebei", ["河北区", "河北區", "Hebei District", "河北区", "허베이구"], 39.149, 117.1966, ["hotel"]),
    district("hongqiao", ["红桥区", "紅橋區", "Hongqiao District", "紅橋区", "훙차오구"], 39.1646, 117.1515, ["hotel"]),
    district("dongli", ["东丽区", "東麗區", "Dongli District", "東麗区", "둥리구"], 39.0868, 117.3136, ["hotel"]),
    district("xiqing", ["西青区", "西青區", "Xiqing District", "西青区", "시칭구"], 39.1394, 117.0089, ["hotel"]),
    district("jinnan", ["津南区", "津南區", "Jinnan District", "津南区", "진난구"], 38.9896, 117.3573, ["hotel"]),
    district("beichen", ["北辰区", "北辰區", "Beichen District", "北辰区", "베이천구"], 39.2256, 117.1356, ["hotel"]),
    district("wuqing", ["武清区", "武清區", "Wuqing District", "武清区", "우칭구"], 39.3841, 117.0444, ["hotel"]),
    district("baodi", ["宝坻区", "寶坻區", "Baodi District", "宝坻区", "바오디구"], 39.7173, 117.3097, ["hotel"]),
    district("binhai", ["滨海新区", "濱海新區", "Binhai New Area", "浜海新区", "빈하이신구"], 39.0032, 117.7107, ["transit", "hotel", "business"]),
    district("ninghe", ["宁河区", "寧河區", "Ninghe District", "寧河区", "닝허구"], 39.3294, 117.8281, ["hotel"]),
    district("jinghai", ["静海区", "靜海區", "Jinghai District", "静海区", "징하이구"], 38.9357, 116.9744, ["hotel"]),
    district("jizhou", ["蓟州区", "薊州區", "Jizhou District", "薊州区", "지저우구"], 40.0453, 117.4083, ["tourism", "hotel"])
  ]),
  city("city.cn.xian", "CN", ["西安", "西安", "Xi'an", "西安", "시안"], 34.3416, 108.9398, "Asia/Shanghai", ["tourism", "hotel"]),
  city("city.cn.wuhan", "CN", ["武汉", "武漢", "Wuhan", "武漢", "우한"], 30.5928, 114.3055, "Asia/Shanghai", ["hotel", "business"]),
  city("city.cn.suzhou", "CN", ["苏州", "蘇州", "Suzhou", "蘇州", "쑤저우"], 31.2989, 120.5853, "Asia/Shanghai", ["tourism", "hotel"]),
  city("city.cn.qingdao", "CN", ["青岛", "青島", "Qingdao", "青島", "칭다오"], 36.0671, 120.3826, "Asia/Shanghai", ["tourism", "hotel"]),
  city("city.cn.xiamen", "CN", ["厦门", "廈門", "Xiamen", "厦門", "샤먼"], 24.4798, 118.0894, "Asia/Shanghai", ["tourism", "hotel"]),
  city("city.cn.sanya", "CN", ["三亚", "三亞", "Sanya", "三亜", "싼야"], 18.2528, 109.5119, "Asia/Shanghai", ["resort", "tourism", "hotel"]),
  city("city.hk.hong-kong", "HK", ["香港", "香港", "Hong Kong", "香港", "홍콩"], 22.3193, 114.1694, "Asia/Hong_Kong", ["tourism", "hotel", "business"]),
  city("city.mo.macau", "MO", ["澳门", "澳門", "Macau", "マカオ", "마카오"], 22.1987, 113.5439, "Asia/Macau", ["tourism", "hotel"]),
  city("city.tw.taipei", "TW", ["台北", "台北", "Taipei", "台北", "타이베이"], 25.033, 121.5654, "Asia/Taipei", ["capital", "tourism", "hotel"]),
  city("city.tw.taichung", "TW", ["台中", "台中", "Taichung", "台中", "타이중"], 24.1477, 120.6736, "Asia/Taipei", ["tourism", "hotel"]),
  city("city.tw.kaohsiung", "TW", ["高雄", "高雄", "Kaohsiung", "高雄", "가오슝"], 22.6273, 120.3014, "Asia/Taipei", ["tourism", "hotel"]),
  city("city.tw.tainan", "TW", ["台南", "台南", "Tainan", "台南", "타이난"], 22.9997, 120.227, "Asia/Taipei", ["tourism", "hotel"]),
  city("city.jp.tokyo", "JP", ["东京", "東京", "Tokyo", "東京", "도쿄"], 35.6762, 139.6503, "Asia/Tokyo", ["capital", "tourism", "hotel", "business"]),
  city("city.jp.osaka", "JP", ["大阪", "大阪", "Osaka", "大阪", "오사카"], 34.6937, 135.5023, "Asia/Tokyo", ["tourism", "hotel", "business"]),
  city("city.jp.kyoto", "JP", ["京都", "京都", "Kyoto", "京都", "교토"], 35.0116, 135.7681, "Asia/Tokyo", ["tourism", "hotel"]),
  city("city.jp.yokohama", "JP", ["横滨", "橫濱", "Yokohama", "横浜", "요코하마"], 35.4437, 139.638, "Asia/Tokyo", ["tourism", "hotel"]),
  city("city.jp.nagoya", "JP", ["名古屋", "名古屋", "Nagoya", "名古屋", "나고야"], 35.1815, 136.9066, "Asia/Tokyo", ["hotel", "business"]),
  city("city.jp.fukuoka", "JP", ["福冈", "福岡", "Fukuoka", "福岡", "후쿠오카"], 33.5902, 130.4017, "Asia/Tokyo", ["tourism", "hotel"]),
  city("city.jp.sapporo", "JP", ["札幌", "札幌", "Sapporo", "札幌", "삿포로"], 43.0618, 141.3545, "Asia/Tokyo", ["tourism", "hotel"]),
  city("city.jp.naha", "JP", ["那霸", "那霸", "Naha", "那覇", "나하"], 26.2124, 127.6792, "Asia/Tokyo", ["resort", "tourism", "hotel"]),
  city("city.kr.seoul", "KR", ["首尔", "首爾", "Seoul", "ソウル", "서울"], 37.5665, 126.978, "Asia/Seoul", ["capital", "tourism", "hotel", "business"]),
  city("city.kr.busan", "KR", ["釜山", "釜山", "Busan", "釜山", "부산"], 35.1796, 129.0756, "Asia/Seoul", ["tourism", "hotel"]),
  city("city.kr.incheon", "KR", ["仁川", "仁川", "Incheon", "仁川", "인천"], 37.4563, 126.7052, "Asia/Seoul", ["transit", "hotel"]),
  city("city.kr.jeju", "KR", ["济州", "濟州", "Jeju", "済州", "제주"], 33.4996, 126.5312, "Asia/Seoul", ["resort", "tourism", "hotel"]),
  city("city.kr.daegu", "KR", ["大邱", "大邱", "Daegu", "大邱", "대구"], 35.8714, 128.6014, "Asia/Seoul", ["hotel", "business"]),
  city("city.sg.singapore", "SG", ["新加坡", "新加坡", "Singapore", "シンガポール", "싱가포르"], 1.3521, 103.8198, "Asia/Singapore", ["capital", "tourism", "hotel", "business"]),
  city("city.th.bangkok", "TH", ["曼谷", "曼谷", "Bangkok", "バンコク", "방콕"], 13.7563, 100.5018, "Asia/Bangkok", ["capital", "tourism", "hotel"]),
  city("city.th.phuket", "TH", ["普吉", "普吉", "Phuket", "プーケット", "푸켓"], 7.8804, 98.3923, "Asia/Bangkok", ["resort", "tourism", "hotel"]),
  city("city.th.chiang-mai", "TH", ["清迈", "清邁", "Chiang Mai", "チェンマイ", "치앙마이"], 18.7883, 98.9853, "Asia/Bangkok", ["tourism", "hotel"]),
  city("city.th.pattaya", "TH", ["芭提雅", "芭達雅", "Pattaya", "パタヤ", "파타야"], 12.9236, 100.8825, "Asia/Bangkok", ["resort", "tourism", "hotel"]),
  city("city.my.kuala-lumpur", "MY", ["吉隆坡", "吉隆坡", "Kuala Lumpur", "クアラルンプール", "쿠알라룸푸르"], 3.139, 101.6869, "Asia/Kuala_Lumpur", ["capital", "tourism", "hotel", "business"]),
  city("city.my.penang", "MY", ["槟城", "檳城", "Penang", "ペナン", "페낭"], 5.4141, 100.3288, "Asia/Kuala_Lumpur", ["tourism", "hotel"]),
  city("city.my.johor-bahru", "MY", ["新山", "新山", "Johor Bahru", "ジョホールバル", "조호르바루"], 1.4927, 103.7414, "Asia/Kuala_Lumpur", ["hotel", "transit"]),
  city("city.my.kota-kinabalu", "MY", ["亚庇", "亞庇", "Kota Kinabalu", "コタキナバル", "코타키나발루"], 5.9804, 116.0735, "Asia/Kuching", ["resort", "tourism", "hotel"]),
  city("city.id.jakarta", "ID", ["雅加达", "雅加達", "Jakarta", "ジャカルタ", "자카르타"], -6.2088, 106.8456, "Asia/Jakarta", ["capital", "hotel", "business"]),
  city("city.id.bali", "ID", ["巴厘岛", "峇里島", "Bali", "バリ", "발리"], -8.4095, 115.1889, "Asia/Makassar", ["resort", "tourism", "hotel"]),
  city("city.id.surabaya", "ID", ["泗水", "泗水", "Surabaya", "スラバヤ", "수라바야"], -7.2575, 112.7521, "Asia/Jakarta", ["hotel", "business"]),
  city("city.vn.ho-chi-minh-city", "VN", ["胡志明市", "胡志明市", "Ho Chi Minh City", "ホーチミン", "호찌민"], 10.8231, 106.6297, "Asia/Ho_Chi_Minh", ["tourism", "hotel", "business"]),
  city("city.vn.hanoi", "VN", ["河内", "河內", "Hanoi", "ハノイ", "하노이"], 21.0278, 105.8342, "Asia/Ho_Chi_Minh", ["capital", "tourism", "hotel"]),
  city("city.vn.da-nang", "VN", ["岘港", "峴港", "Da Nang", "ダナン", "다낭"], 16.0544, 108.2022, "Asia/Ho_Chi_Minh", ["resort", "tourism", "hotel"]),
  city("city.ph.manila", "PH", ["马尼拉", "馬尼拉", "Manila", "マニラ", "마닐라"], 14.5995, 120.9842, "Asia/Manila", ["capital", "tourism", "hotel"]),
  city("city.ph.cebu", "PH", ["宿务", "宿霧", "Cebu", "セブ", "세부"], 10.3157, 123.8854, "Asia/Manila", ["resort", "tourism", "hotel"]),
  city("city.us.new-york", "US", ["纽约", "紐約", "New York", "ニューヨーク", "뉴욕"], 40.7128, -74.006, "America/New_York", ["tourism", "hotel", "business"]),
  city("city.us.los-angeles", "US", ["洛杉矶", "洛杉磯", "Los Angeles", "ロサンゼルス", "로스앤젤레스"], 34.0522, -118.2437, "America/Los_Angeles", ["tourism", "hotel", "business"]),
  city("city.us.san-francisco", "US", ["旧金山", "舊金山", "San Francisco", "サンフランシスコ", "샌프란시스코"], 37.7749, -122.4194, "America/Los_Angeles", ["tourism", "hotel", "business"]),
  city("city.us.las-vegas", "US", ["拉斯维加斯", "拉斯維加斯", "Las Vegas", "ラスベガス", "라스베이거스"], 36.1716, -115.1391, "America/Los_Angeles", ["resort", "tourism", "hotel"]),
  city("city.us.seattle", "US", ["西雅图", "西雅圖", "Seattle", "シアトル", "시애틀"], 47.6062, -122.3321, "America/Los_Angeles", ["tourism", "hotel", "business"]),
  city("city.us.chicago", "US", ["芝加哥", "芝加哥", "Chicago", "シカゴ", "시카고"], 41.8781, -87.6298, "America/Chicago", ["tourism", "hotel", "business"]),
  city("city.us.boston", "US", ["波士顿", "波士頓", "Boston", "ボストン", "보스턴"], 42.3601, -71.0589, "America/New_York", ["tourism", "hotel", "business"]),
  city("city.us.washington", "US", ["华盛顿", "華盛頓", "Washington, DC", "ワシントンD.C.", "워싱턴 D.C."], 38.9072, -77.0369, "America/New_York", ["capital", "tourism", "hotel"]),
  city("city.us.miami", "US", ["迈阿密", "邁阿密", "Miami", "マイアミ", "마이애미"], 25.7617, -80.1918, "America/New_York", ["resort", "tourism", "hotel"]),
  city("city.us.orlando", "US", ["奥兰多", "奧蘭多", "Orlando", "オーランド", "올랜도"], 28.5383, -81.3792, "America/New_York", ["tourism", "hotel", "resort"]),
  city("city.gb.london", "GB", ["伦敦", "倫敦", "London", "ロンドン", "런던"], 51.5072, -0.1276, "Europe/London", ["capital", "tourism", "hotel", "business"]),
  city("city.gb.manchester", "GB", ["曼彻斯特", "曼徹斯特", "Manchester", "マンチェスター", "맨체스터"], 53.4808, -2.2426, "Europe/London", ["tourism", "hotel", "business"]),
  city("city.gb.edinburgh", "GB", ["爱丁堡", "愛丁堡", "Edinburgh", "エディンバラ", "에든버러"], 55.9533, -3.1883, "Europe/London", ["tourism", "hotel"]),
  city("city.gb.birmingham", "GB", ["伯明翰", "伯明罕", "Birmingham", "バーミンガム", "버밍엄"], 52.4862, -1.8904, "Europe/London", ["hotel", "business"]),
  city("city.fr.paris", "FR", ["巴黎", "巴黎", "Paris", "パリ", "파리"], 48.8566, 2.3522, "Europe/Paris", ["capital", "tourism", "hotel"]),
  city("city.fr.nice", "FR", ["尼斯", "尼斯", "Nice", "ニース", "니스"], 43.7102, 7.262, "Europe/Paris", ["resort", "tourism", "hotel"]),
  city("city.fr.lyon", "FR", ["里昂", "里昂", "Lyon", "リヨン", "리옹"], 45.764, 4.8357, "Europe/Paris", ["tourism", "hotel"]),
  city("city.fr.marseille", "FR", ["马赛", "馬賽", "Marseille", "マルセイユ", "마르세유"], 43.2965, 5.3698, "Europe/Paris", ["tourism", "hotel"]),
  city("city.de.berlin", "DE", ["柏林", "柏林", "Berlin", "ベルリン", "베를린"], 52.52, 13.405, "Europe/Berlin", ["capital", "tourism", "hotel", "business"]),
  city("city.de.munich", "DE", ["慕尼黑", "慕尼黑", "Munich", "ミュンヘン", "뮌헨"], 48.1351, 11.582, "Europe/Berlin", ["tourism", "hotel", "business"]),
  city("city.de.frankfurt", "DE", ["法兰克福", "法蘭克福", "Frankfurt", "フランクフルト", "프랑크푸르트"], 50.1109, 8.6821, "Europe/Berlin", ["transit", "hotel", "business"]),
  city("city.de.hamburg", "DE", ["汉堡", "漢堡", "Hamburg", "ハンブルク", "함부르크"], 53.5511, 9.9937, "Europe/Berlin", ["tourism", "hotel"]),
  city("city.it.rome", "IT", ["罗马", "羅馬", "Rome", "ローマ", "로마"], 41.9028, 12.4964, "Europe/Rome", ["capital", "tourism", "hotel"]),
  city("city.it.milan", "IT", ["米兰", "米蘭", "Milan", "ミラノ", "밀라노"], 45.4642, 9.19, "Europe/Rome", ["tourism", "hotel", "business"]),
  city("city.it.venice", "IT", ["威尼斯", "威尼斯", "Venice", "ヴェネツィア", "베네치아"], 45.4408, 12.3155, "Europe/Rome", ["tourism", "hotel"]),
  city("city.it.florence", "IT", ["佛罗伦萨", "佛羅倫斯", "Florence", "フィレンツェ", "피렌체"], 43.7696, 11.2558, "Europe/Rome", ["tourism", "hotel"]),
  city("city.es.madrid", "ES", ["马德里", "馬德里", "Madrid", "マドリード", "마드리드"], 40.4168, -3.7038, "Europe/Madrid", ["capital", "tourism", "hotel"]),
  city("city.es.barcelona", "ES", ["巴塞罗那", "巴塞隆納", "Barcelona", "バルセロナ", "바르셀로나"], 41.3874, 2.1686, "Europe/Madrid", ["tourism", "hotel"]),
  city("city.es.seville", "ES", ["塞维利亚", "塞維利亞", "Seville", "セビリア", "세비야"], 37.3891, -5.9845, "Europe/Madrid", ["tourism", "hotel"]),
  city("city.es.valencia", "ES", ["瓦伦西亚", "瓦倫西亞", "Valencia", "バレンシア", "발렌시아"], 39.4699, -0.3763, "Europe/Madrid", ["tourism", "hotel"]),
  city("city.nl.amsterdam", "NL", ["阿姆斯特丹", "阿姆斯特丹", "Amsterdam", "アムステルダム", "암스테르담"], 52.3676, 4.9041, "Europe/Amsterdam", ["capital", "tourism", "hotel", "business"]),
  city("city.nl.rotterdam", "NL", ["鹿特丹", "鹿特丹", "Rotterdam", "ロッテルダム", "로테르담"], 51.9244, 4.4777, "Europe/Amsterdam", ["hotel", "business"]),
  city("city.ch.zurich", "CH", ["苏黎世", "蘇黎世", "Zurich", "チューリッヒ", "취리히"], 47.3769, 8.5417, "Europe/Zurich", ["tourism", "hotel", "business"]),
  city("city.ch.geneva", "CH", ["日内瓦", "日內瓦", "Geneva", "ジュネーブ", "제네바"], 46.2044, 6.1432, "Europe/Zurich", ["tourism", "hotel", "business"]),
  city("city.ch.lucerne", "CH", ["卢塞恩", "琉森", "Lucerne", "ルツェルン", "루체른"], 47.0502, 8.3093, "Europe/Zurich", ["tourism", "hotel"]),
  city("city.at.vienna", "AT", ["维也纳", "維也納", "Vienna", "ウィーン", "빈"], 48.2082, 16.3738, "Europe/Vienna", ["capital", "tourism", "hotel"]),
  city("city.at.salzburg", "AT", ["萨尔茨堡", "薩爾斯堡", "Salzburg", "ザルツブルク", "잘츠부르크"], 47.8095, 13.055, "Europe/Vienna", ["tourism", "hotel"]),
  city("city.au.sydney", "AU", ["悉尼", "雪梨", "Sydney", "シドニー", "시드니"], -33.8688, 151.2093, "Australia/Sydney", ["tourism", "hotel", "business"]),
  city("city.au.melbourne", "AU", ["墨尔本", "墨爾本", "Melbourne", "メルボルン", "멜버른"], -37.8136, 144.9631, "Australia/Melbourne", ["tourism", "hotel", "business"]),
  city("city.au.brisbane", "AU", ["布里斯班", "布里斯本", "Brisbane", "ブリスベン", "브리즈번"], -27.4698, 153.0251, "Australia/Brisbane", ["tourism", "hotel"]),
  city("city.au.perth", "AU", ["珀斯", "伯斯", "Perth", "パース", "퍼스"], -31.9523, 115.8613, "Australia/Perth", ["tourism", "hotel"]),
  city("city.ca.toronto", "CA", ["多伦多", "多倫多", "Toronto", "トロント", "토론토"], 43.6532, -79.3832, "America/Toronto", ["tourism", "hotel", "business"]),
  city("city.ca.vancouver", "CA", ["温哥华", "溫哥華", "Vancouver", "バンクーバー", "밴쿠버"], 49.2827, -123.1207, "America/Vancouver", ["tourism", "hotel"]),
  city("city.ca.montreal", "CA", ["蒙特利尔", "蒙特婁", "Montreal", "モントリオール", "몬트리올"], 45.5019, -73.5674, "America/Toronto", ["tourism", "hotel"]),
  city("city.ca.calgary", "CA", ["卡尔加里", "卡加利", "Calgary", "カルガリー", "캘거리"], 51.0447, -114.0719, "America/Edmonton", ["tourism", "hotel"]),
  city("city.ae.dubai", "AE", ["迪拜", "杜拜", "Dubai", "ドバイ", "두바이"], 25.2048, 55.2708, "Asia/Dubai", ["tourism", "hotel", "business"]),
  city("city.ae.abu-dhabi", "AE", ["阿布扎比", "阿布達比", "Abu Dhabi", "アブダビ", "아부다비"], 24.4539, 54.3773, "Asia/Dubai", ["capital", "tourism", "hotel"])
] satisfies CityRecord[];

export const placesCatalog = {
  schemaVersion: placeCatalogSchemaVersion,
  resourceVersion: placeCatalogResourceVersion,
  generatedAt: placeCatalogGeneratedAt,
  supportedLocales,
  defaultLocale: "en" satisfies SupportedLocale,
  fallbackLocales: ["en", "zh-Hans"] satisfies SupportedLocale[],
  countries,
  cities
};

function country(
  id: string,
  countryCode: string,
  nameValues: readonly [string, string, string, string, string],
  defaultCurrencyCode: string,
  tags: PlaceTag[]
): CountryRecord {
  return {
    id,
    countryCode,
    names: localized(nameValues),
    defaultCurrencyCode,
    tags
  };
}

function city(
  id: string,
  countryCode: string,
  nameValues: readonly [string, string, string, string, string],
  latitude: number,
  longitude: number,
  timezone: string,
  tags: PlaceTag[]
): CityRecord {
  return {
    id,
    countryCode,
    names: localized(nameValues),
    latitude,
    longitude,
    timezone,
    tags,
    administrativeLevel: "city"
  };
}

function district(
  slug: string,
  nameValues: readonly [string, string, string, string, string],
  latitude: number,
  longitude: number,
  tags: PlaceTag[]
): DistrictDefinition {
  return {
    slug,
    names: nameValues,
    latitude,
    longitude,
    tags
  };
}

function municipalityDistricts(
  parentId: string,
  countryCode: string,
  cityNameValues: readonly [string, string, string, string, string],
  timezone: string,
  districts: DistrictDefinition[]
): CityRecord[] {
  return districts.map((record) => ({
    id: `${parentId}.${record.slug}`,
    countryCode,
    names: localized(prefixedDistrictNames(cityNameValues, record.names)),
    latitude: record.latitude,
    longitude: record.longitude,
    timezone,
    tags: uniqueTags(["district", ...record.tags]),
    administrativeLevel: "district",
    parentId
  }));
}

function prefixedDistrictNames(
  cityNameValues: readonly [string, string, string, string, string],
  districtNameValues: readonly [string, string, string, string, string]
): readonly [string, string, string, string, string] {
  return [
    `${cityNameValues[0]} - ${districtNameValues[0]}`,
    `${cityNameValues[1]} - ${districtNameValues[1]}`,
    `${cityNameValues[2]} - ${districtNameValues[2]}`,
    `${cityNameValues[3]} - ${districtNameValues[3]}`,
    `${cityNameValues[4]} - ${districtNameValues[4]}`
  ];
}

function uniqueTags(tags: PlaceTag[]): PlaceTag[] {
  return Array.from(new Set(tags));
}

function localized(values: readonly [string, string, string, string, string]): LocalizedText {
  return {
    "zh-Hans": values[0],
    "zh-Hant": values[1],
    en: values[2],
    ja: values[3],
    ko: values[4]
  };
}

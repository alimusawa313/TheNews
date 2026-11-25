import Foundation

/// Deterministic offline data for demo mode, previews and UI tests.
/// Source names are real NewsAPI sources; article headlines are labelled samples.
actor StubNewsRepository: NewsRepository {
    nonisolated enum Scenario: String, Sendable {
        case standard, empty, failure, flakyPagination
    }

    static let articlesPerSource = 45

    private let scenario: Scenario
    private let latency: Duration
    private var failedKeys: Set<String> = []

    init(scenario: Scenario = .standard, latency: Duration = .milliseconds(600)) {
        self.scenario = scenario
        self.latency = latency
    }

    func sources(category: NewsCategory?) async throws(APIError) -> [NewsSource] {
        try await simulateNetwork()
        guard scenario != .empty else { return [] }
        return category.map { StubCatalog.sources(in: $0) } ?? NewsCategory.allCases.flatMap(StubCatalog.sources(in:))
    }

    func articles(sourceID: String, page: Int) async throws(APIError) -> Page<Article> {
        try await simulateNetwork()
        try failOnce(key: "articles-\(sourceID)", page: page)
        let total = scenario == .empty ? 0 : Self.articlesPerSource
        let name = StubCatalog.allSources.first { $0.id == sourceID }?.name ?? sourceID
        return StubCatalog.page(page, total: total) { i in "Sample headline \(i) from \(name)" } source: { _ in (sourceID, name) }
    }

    func searchArticles(query: String, page: Int) async throws(APIError) -> Page<Article> {
        try await simulateNetwork()
        try failOnce(key: "search-\(query)", page: page)
        let total = scenario == .empty || query.count < 2 ? 0 : 30
        let pool = StubCatalog.allSources
        return StubCatalog.page(page, total: total) { i in "Sample headline \(i) about “\(query)”" } source: { i in
            let source = pool[i % pool.count]
            return (source.id, source.name)
        }
    }

    func validateKey() async throws(APIError) {
        try await simulateNetwork()
    }

    private func simulateNetwork() async throws(APIError) {
        do { try await Task.sleep(for: latency) } catch { throw .cancelled }
        if scenario == .failure { throw .offline }
    }

    private func failOnce(key: String, page: Int) throws(APIError) {
        guard scenario == .flakyPagination, page == 2, !failedKeys.contains(key) else { return }
        failedKeys.insert(key)
        throw .timedOut
    }
}

nonisolated enum StubCatalog {
    private static let table: [NewsCategory: [(String, String, String, String)]] = [
        .general: [("bbc-news", "BBC News", "bbc.co.uk", "International news, features and analysis."), ("associated-press", "Associated Press", "apnews.com", "Independent global news organization."), ("al-jazeera-english", "Al Jazeera English", "aljazeera.com", "News and analysis from around the world."), ("cnn", "CNN", "cnn.com", "Breaking news and in-depth coverage."), ("the-washington-post", "The Washington Post", "washingtonpost.com", "National and world news and opinion."), ("reuters", "Reuters", "reuters.com", "Business, financial and world news."), ("abc-news", "ABC News", "abcnews.go.com", "US and world news and video.")],
        .business: [("bloomberg", "Bloomberg", "bloomberg.com", "Business, markets and financial news."), ("business-insider", "Business Insider", "businessinsider.com", "Business, finance and tech news."), ("fortune", "Fortune", "fortune.com", "Business news and analysis."), ("the-wall-street-journal", "The Wall Street Journal", "wsj.com", "Business and financial news."), ("financial-post", "Financial Post", "financialpost.com", "Canadian business and investing news."), ("australian-financial-review", "Australian Financial Review", "afr.com", "Business, markets and economy.")],
        .technology: [("the-verge", "The Verge", "theverge.com", "Technology, science, art and culture."), ("techcrunch", "TechCrunch", "techcrunch.com", "Startup and technology news."), ("ars-technica", "Ars Technica", "arstechnica.com", "Technology news and analysis."), ("wired", "Wired", "wired.com", "How technology shapes our lives."), ("engadget", "Engadget", "engadget.com", "Gadgets and consumer electronics."), ("hacker-news", "Hacker News", "news.ycombinator.com", "Links and discussion for builders."), ("techradar", "TechRadar", "techradar.com", "Tech reviews and news.")],
        .science: [("new-scientist", "New Scientist", "newscientist.com", "Science and technology news."), ("national-geographic", "National Geographic", "nationalgeographic.com", "Science, exploration and nature."), ("next-big-future", "Next Big Future", "nextbigfuture.com", "Emerging science and technology.")],
        .health: [("medical-news-today", "Medical News Today", "medicalnewstoday.com", "Medical and health news.")],
        .sports: [("espn", "ESPN", "espn.com", "Scores, news and analysis."), ("bbc-sport", "BBC Sport", "bbc.co.uk", "Sport news and results."), ("bleacher-report", "Bleacher Report", "bleacherreport.com", "Sports news and highlights."), ("fox-sports", "Fox Sports", "foxsports.com", "Scores, news and video."), ("talksport", "talkSPORT", "talksport.com", "Football and sports news."), ("the-sport-bible", "The Sport Bible", "sportbible.com", "Sports stories and culture.")],
        .entertainment: [("entertainment-weekly", "Entertainment Weekly", "ew.com", "Film, TV and music news."), ("ign", "IGN", "ign.com", "Games, movies and TV."), ("polygon", "Polygon", "polygon.com", "Gaming and entertainment."), ("buzzfeed", "Buzzfeed", "buzzfeed.com", "Entertainment and culture."), ("mashable", "Mashable", "mashable.com", "Culture, tech and entertainment."), ("mtv-news", "MTV News", "mtv.com", "Music and pop culture news.")]
    ]

    static func sources(in category: NewsCategory) -> [NewsSource] {
        (table[category] ?? []).map { id, name, domain, summary in
            NewsSource(id: id, name: name, summary: summary, url: URL(string: "https://\(domain)"), category: category)
        }
    }

    static var allSources: [NewsSource] { NewsCategory.allCases.flatMap(sources(in:)) }

    static func page(_ page: Int, total: Int, title: (Int) -> String, source: (Int) -> (String, String)) -> Page<Article> {
        let size = NewsEndpoint.pageSize
        let start = (page - 1) * size
        let end = min(start + size, total)
        let reference = Date(timeIntervalSince1970: 1_795_600_000)
        let items: [Article] = start < end ? (start..<end).map { i in
            let (id, name) = source(i)
            return Article(
                sourceID: id, sourceName: name, author: "Sample author",
                title: title(i + 1),
                summary: "Demo mode: the description NewsAPI returns for this story appears here.",
                url: URL(string: "https://example.com/\(id)/story-\(i + 1)")!,
                imageURL: nil,
                publishedAt: reference.addingTimeInterval(TimeInterval(-i * 2_700))
            )
        } : []
        return Page(page: page, items: items, totalResults: total, pageSize: size)
    }
}

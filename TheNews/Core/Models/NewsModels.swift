import Foundation

nonisolated struct NewsSource: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let summary: String
    let url: URL?
    let category: NewsCategory?
    let language: String?
    let country: String?

    init(id: String, name: String, summary: String, url: URL?, category: NewsCategory?, language: String? = "en", country: String? = nil) {
        self.id = id
        self.name = name
        self.summary = summary
        self.url = url
        self.category = category
        self.language = language
        self.country = country
    }

    private enum CodingKeys: String, CodingKey { case id, name, description, url, category, language, country }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        summary = try c.decodeIfPresent(String.self, forKey: .description)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url).flatMap(URL.init(string:))
        category = try c.decodeIfPresent(String.self, forKey: .category).flatMap(NewsCategory.init(rawValue:))
        language = try c.decodeIfPresent(String.self, forKey: .language)
        country = try c.decodeIfPresent(String.self, forKey: .country)
    }

    /// "theverge.com"
    var domain: String { url.map(Formatters.domain(of:)) ?? name.lowercased() }
}

nonisolated struct Article: Decodable, Hashable, Identifiable, Sendable {
    let sourceID: String?
    let sourceName: String
    let author: String?
    let title: String
    let summary: String?
    let url: URL
    let imageURL: URL?
    let publishedAt: Date?

    var id: String { url.absoluteString }

    init(sourceID: String?, sourceName: String, author: String?, title: String, summary: String?, url: URL, imageURL: URL?, publishedAt: Date?) {
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.author = author
        self.title = title
        self.summary = summary
        self.url = url
        self.imageURL = imageURL
        self.publishedAt = publishedAt
    }

    private enum CodingKeys: String, CodingKey { case source, author, title, description, url, urlToImage, publishedAt }
    private struct SourceRef: Decodable { let id: String?; let name: String? }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let source = try c.decodeIfPresent(SourceRef.self, forKey: .source)
        guard let link = try c.decodeIfPresent(String.self, forKey: .url).flatMap(URL.init(string:)),
              link.scheme?.hasPrefix("http") == true else {
            throw DecodingError.dataCorruptedError(forKey: .url, in: c, debugDescription: "Missing article URL")
        }
        sourceID = source?.id
        sourceName = source?.name?.nilIfBlank ?? Formatters.domain(of: link)
        author = try c.decodeIfPresent(String.self, forKey: .author)?.nilIfBlank
        title = try c.decodeIfPresent(String.self, forKey: .title)?.nilIfBlank ?? "Untitled"
        summary = try c.decodeIfPresent(String.self, forKey: .description)?.nilIfBlank
        url = link
        imageURL = try c.decodeIfPresent(String.self, forKey: .urlToImage)?.nilIfBlank.flatMap(URL.init(string:))
        publishedAt = Formatters.timestamp(try c.decodeIfPresent(String.self, forKey: .publishedAt))
    }

    /// NewsAPI keeps deleted stories in results with a "[Removed]" placeholder.
    var isRemoved: Bool { title == "[Removed]" || url.host() == "removed.com" }
}

/// A page of results. NewsAPI's free plan stops at 100 results per query.
nonisolated struct Page<Item: Sendable>: Sendable {
    static var resultCap: Int { 100 }

    let page: Int
    let items: [Item]
    let totalResults: Int
    let pageSize: Int

    var hasMore: Bool { page * pageSize < min(totalResults, Self.resultCap) && !items.isEmpty }
}

nonisolated extension Page: Equatable where Item: Equatable {}

nonisolated struct SourcesResponse: Decodable, Sendable {
    let sources: [NewsSource]
    private enum CodingKeys: String, CodingKey { case sources }
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sources = try c.decodeIfPresent(LossyArray<NewsSource>.self, forKey: .sources)?.elements ?? []
    }
}

nonisolated struct ArticlesResponse: Decodable, Sendable {
    let totalResults: Int
    let articles: [Article]
    private enum CodingKeys: String, CodingKey { case totalResults, articles }
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let all = try c.decodeIfPresent(LossyArray<Article>.self, forKey: .articles)?.elements ?? []
        articles = all.filter { !$0.isRemoved }
        totalResults = try c.decodeIfPresent(Int.self, forKey: .totalResults) ?? all.count
    }
}

nonisolated struct NewsAPIErrorBody: Decodable, Sendable {
    let status: String?
    let code: String?
    let message: String?
}

/// Decodes an array while skipping elements that fail to decode.
nonisolated struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]
    private struct Skip: Decodable {}
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                decoded.append(element)
            } else {
                _ = try? container.decode(Skip.self)
            }
        }
        elements = decoded
    }
}

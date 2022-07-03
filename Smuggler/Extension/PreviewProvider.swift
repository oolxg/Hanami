//
//  PreviewProvider.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation
import SwiftUI

extension PreviewProvider {
    static var dev: DeveloperPreview {
        DeveloperPreview.shared
    }
}

class DeveloperPreview {
    static let shared = DeveloperPreview()
    
    private init() { }
    
    let volume = MangaVolume(dummyInit: true)
    
    let chapter = Chapter(
        chapterIndex: 1.2,
        count: 2,
        id: UUID(),
        others: [UUID(), UUID(), UUID()]
    )
    
    let coverArtInfo = CoverArtInfo(
        id: UUID(uuidString: "5609b1de-523f-4d78-b698-40527a7abd90")!,
        type: .coverArt,
        attributes: .init(
            description: "",
            volume: "1",
            fileName: "9c8d9166-7b7e-4376-849b-faa50c3df7ef.jpg",
            locale: "ja",
            createdAt: Date(timeIntervalSince1970: 1652567400),
            updatedAt: Date(timeIntervalSince1970: 1652567700),
            version: 1
        ),
        relationships: [
            .init(
                id: UUID(uuidString: "a30bb9f2-97db-45d3-b7f1-8e4b65e8b2d4")!,
                type: .manga
            ),
            .init(
                id: UUID(uuidString: "a8b6d978-9707-4f34-ad78-04c7378b383b")!,
                type: .user
            )
        ]
    )

    let manga = Manga(
        id: UUID(uuidString: "a30bb9f2-97db-45d3-b7f1-8e4b65e8b2d4")!,
        type: .manga,
        attributes: .init(
            title: LocalizedString(
                en: "JoJo's Bizarre Adventure Part 6: Stone Ocean (Fan-Coloured)",
                ru: nil,
                jp: nil,
                jpRo: nil,
                zh: nil,
                zhRo: nil),
            altTitles: LocalizedString(
                en: "Konosuba",
                ru: nil,
                jp: "Konosuba",
                jpRo: nil,
                zh: nil,
                zhRo: nil
            ),
            description: LocalizedString(
                en: "The sixth story arc of JoJo's Bizarre Adventure.\n\nIn Florida, 2011, Jolyne Cujoh" +
                " sits in a jail cell like her father Jotaro once did; yet this situation is not of her own choice." +
                " Framed for a crime she didn’t commit, Jolyne is ready to resign to a dire fate as a prisoner" +
                " of Green Dolphin Street Jail. When all hope seems lost, a gift from Jotaro awakens her ability, " +
                " a Stand called Stone Free. Now armed with the power to change her fate, Jolyne sets out to find an" +
                " escape from the stone ocean that holds her.\n\nHowever, she soon discovers that her incarceration" +
                " is merely a small part of agrand plot: one that not only takes aim at her family, but has " +
                " additional far-reaching consequences. What's more, the mastermind is lurking within the very" +
                " same prison, and is under the protection of a lineup of menacing Stand users.",
                ru: nil,
                jp: nil,
                jpRo: nil,
                zh: nil,
                zhRo: nil
            ),
            isLocked: false,
            originalLanguage: "ja",
            status: .completed,
            contentRating: .safe,
            tags: [
                Tag(
                    id: UUID(),
                    type: .tag,
                    attributes: .init(
                        name: .init(
                            en: .action
                        ),
                        group: .genre,
                        version: 1
                    ),
                    relationships: nil
                ),
                Tag(
                    id: UUID(),
                    type: .tag,
                    attributes: .init(
                        name: .init(
                            en: .fanColored
                        ),
                        group: .format,
                        version: 1
                    ),
                    relationships: nil
                )
            ],
            state: .published,
            createdAt: Date(timeIntervalSince1970: 1652567400),
            updatedAt: Date(timeIntervalSince1970: 1652567700),
            lastVolume: "",
            lastChapter: "",
            publicationDemographic: .seinen,
            year: 2022
        ),
        relationships: [
            Relationship(
                id: UUID(uuidString: "5609b1de-523f-4d78-b698-40527a7abd90")!,
                type: .coverArt,
                related: nil,
                attributes: nil
            ),
            Relationship(
                id: UUID(uuidString: "03e4afc4-cd94-45a0-bb36-dfd34fa370b3")!,
                type: .author,
                related: nil,
                attributes: nil
            ),
            Relationship(
                id: UUID(uuidString: "03e4afc4-cd94-45a0-bb36-dfd34fa370b3")!,
                type: .artist,
                related: nil,
                attributes: nil
            )
        ]
    )
}

//
//  PreviewProvider.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import Foundation
import SwiftUI

#if DEBUG
extension PreviewProvider {
    static var dev: DeveloperPreview {
        DeveloperPreview.shared
    }
}

class DeveloperPreview {
    static let shared = DeveloperPreview()
    
    private init() { }
    
    let chapter = Chapter(
        index: 1.2,
        id: UUID(),
        others: [UUID(), UUID(), UUID()]
    )
    
    let manga = Manga(
        id: UUID(uuidString: "a30bb9f2-97db-45d3-b7f1-8e4b65e8b2d4")!,
        attributes: .init(
            title: LocalizedString(
                en: "JoJo's Bizarre Adventure Part 6: Stone Ocean (Fan-Coloured)"
            ),
            altTitles: LocalizedString(
                en: "Konosuba",
                jp: "Konosuba"
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
                " same prison, and is under the protection of a lineup of menacing Stand users."
            ),
            isLocked: false,
            originalLanguage: "ja",
            status: .completed,
            contentRating: .safe,
            tags: [
                Tag(
                    id: UUID(),
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
        relationships: [ ]
    )
}
#endif

//
//  AboutView.swift
//  Hanami
//
//  Created by Oleg on 18.03.23.
//

import SwiftUI
import ComposableArchitecture
import NukeUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @State private var userTappedOnCopyURL = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    HStack {
                        LazyImage(url: Defaults.Links.githubAvatarLink)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .onTapGesture { openURL(Defaults.Links.githubUserLink) }
                        
                        Text("Hey-hey 🖖, my name is Oleg!")
                    }
                    
                    Rectangle()
                        .foregroundColor(.theme.secondaryText)
                        .frame(height: 1.5)
                    
                    Text(
                        LocalizedStringKey(
                            // swiftlint:disable line_length
                            "This project uses MangaDEX API to fetch manga, descriptions, etc., that you can find in the app. " +
                            "Since this is a completely **non-commercial** project, development may not go as fast as desired. " +
                            "If you want to participate in the development, for example, add the localization of the " +
                            "application, a new feature, or just help financially, you can do it using the links below."
                            // swiftlint:enable line_length
                        )
                    )

                    VStack {
                        Image("bmc-violet")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .onTapGesture { openURL(Defaults.Links.bmcLink) }
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .frame(width: 200, height: 70)
                            .overlay {
                                HStack(spacing: 5) {
                                    Image("gh-mark-white")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 35)
                                    
                                    Image("gh-logo-white")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 35)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .onTapGesture { openURL(Defaults.Links.githubProjectLink) }
                    }
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.darkGray)
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                        
                        if #available(iOS 16.0, *) {
                            ShareLink("Share Hanami - Manga Reader", item: Defaults.Links.testFlightLinkt)
                                .foregroundColor(.white)
                        } else {
                        Button {
                            UIPasteboard.general.url = Defaults.Links.testFlightLinkt
                            userTappedOnCopyURL = true
                        } label: {
                            Label(
                                "Copy TestFlight link to start using",
                                systemImage: userTappedOnCopyURL ? "checkmark" : "rectangle.on.rectangle"
                            )
                            .foregroundColor(.white)
                        }
                        }
                    }
                    
                    VStack(spacing: 5) {
                        Text("From 🇩🇪 with ❤️")
                            .foregroundColor(.theme.secondaryText)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("Version: \(AppUtil.version)")
                            .foregroundColor(.theme.secondaryText)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("About")
            .padding(.horizontal)
        }
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}

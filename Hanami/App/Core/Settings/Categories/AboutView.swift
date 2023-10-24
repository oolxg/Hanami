//
//  AboutView.swift
//  Hanami
//
//  Created by Oleg on 18.03.23.
//

import SwiftUI
import Kingfisher
import UIExtensions
import Utils

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @State private var userTappedOnCopyURL = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    header
                    
                    Rectangle()
                        .foregroundColor(.theme.secondaryText)
                        .frame(height: 1.5)

                    description
                    
                    buttons
                    
                    footer
                }
            }
            .navigationTitle("About")
            .padding(.horizontal)
        }
    }
}

extension AboutView {
    private var header: some View {
        HStack {
            KFImage(Defaults.Links.githubAvatarLink)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .onTapGesture { openURL(Defaults.Links.githubUserLink) }
            
            Text("Hey-hey 🖖, my name is Oleg!")
        }
    }
    
    private var description: some View {
        Text(
            LocalizedStringKey(
                "This project uses MangaDEX API to fetch manga, descriptions, etc., that you can find in the app. " +
                "Since this is a completely **non-commercial** project, development may not go as fast as desired. " +
                "If you want to participate in the development, for example, add the localization of the " +
                "application, a new feature, or just help financially, you can do it using the links below."
            )
        )
    }
    
    private var buttons: some  View {
        VStack {
            HStack {
                Image("bmc-violet")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .onTapGesture { openURL(Defaults.Links.bmcLink) }
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .onTapGesture { openURL(Defaults.Links.githubProjectLink) }
            }
            .frame(height: 50)
            
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.theme.darkGray)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                
                if #available(iOS 16.0, *) {
                    ShareLink("Share Hanami - Manga Reader", item: Defaults.Links.testFlightLink)
                        .foregroundColor(.white)
                } else {
                    Button {
                        UIPasteboard.general.url = Defaults.Links.testFlightLink
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
        }
    }
    
    private var footer: some View {
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
